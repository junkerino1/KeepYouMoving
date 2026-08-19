import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/account.dart';
import '../models/session.dart';
import 'api_service.dart';
import 'app_metadata.dart';
import 'secure_token_store.dart';

class AuthService extends ChangeNotifier {
  AuthService({SecureTokenStore? store, ApiService? api})
      : _store = store ?? SecureTokenStore(),
        _api = api ?? ApiService();

  final SecureTokenStore _store;
  final ApiService _api;

  Account? _account;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<Uri>? _linkSub;
  String? _lastHandledCallback;

  Account? get account => _account;
  bool get isLoggedIn => _account != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Restores session from secure storage on app start.
  Future<void> restoreSession() async {
    final token = await _store.readAccountToken();
    if (token == null || token.isEmpty) return;
    ApiService.setAccountToken(token);
    await fetchAccount();
  }

  /// Starts listening for the OAuth deep link callback.
  void listenForOAuthCallback() {
    _linkSub?.cancel();
    final appLinks = AppLinks();
    _linkSub = appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (Object error) =>
          debugPrint('[auth] deep-link stream error: $error'),
    );
    // uriLinkStream covers warm-app links, but Android may deliver the OAuth
    // callback as the launch intent when the process was not running.
    unawaited(_readInitialLink(appLinks));
    debugPrint('[auth] OAuth deep-link listener attached');
  }

  Future<void> _readInitialLink(AppLinks appLinks) async {
    try {
      final uri = await appLinks.getInitialLink();
      if (uri != null) _handleIncomingLink(uri);
    } catch (error) {
      debugPrint('[auth] could not read initial deep link: $error');
    }
  }

  void _handleIncomingLink(Uri uri) {
    debugPrint(
        '[auth] deep link received: ${uri.scheme}://${uri.host}${uri.path}');
    if (uri.scheme.toLowerCase() != 'keepyoumoving' ||
        uri.host.toLowerCase() != 'oauth' ||
        uri.path != '/callback') {
      debugPrint('[auth] deep link ignored: unsupported callback URI');
      return;
    }
    final callbackKey = uri.toString();
    if (_lastHandledCallback == callbackKey) {
      debugPrint('[auth] duplicate OAuth callback ignored');
      return;
    }
    _lastHandledCallback = callbackKey;
    debugPrint('[auth] OAuth callback accepted');
    unawaited(_handleOAuthCallback(uri));
  }

  /// Calls the backend to get the Google OAuth URL, then opens it in browser.
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.postRoot('account/retrieve-oauth-url');
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      final oauthUrl = data['oauth_url'] as String?;
      if (oauthUrl == null || oauthUrl.isEmpty) {
        throw Exception('No OAuth URL returned');
      }
      final uri = Uri.parse(oauthUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open browser');
      }
    } catch (e) {
      _error = 'Could not start sign-in. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handles the OAuth callback deep link.
  Future<void> _handleOAuthCallback(Uri uri) async {
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code == null || state == null) {
      debugPrint('[auth] OAuth callback missing code or state');
      _error = 'Invalid sign-in response.';
      _isLoading = false;
      notifyListeners();
      return;
    }
    await _exchangeCodeForSession(code, state);
  }

  /// Exchanges the OAuth code for an access token via the backend.
  Future<void> _exchangeCodeForSession(String code, String state) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiService.waitForRequiredHeaders();
      debugPrint('[auth] exchanging OAuth callback with backend');
      final response = await _api.postRoot(
        'account/oauth-callback',
        body: {'code': code, 'state': state},
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      final session = data['session'] as Map<String, dynamic>? ?? {};
      final accessToken = session['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('No access token returned');
      }
      await _store.writeAccountToken(accessToken);
      ApiService.setAccountToken(accessToken);
      _account = await _withProfilePicture(
        Account.fromJson(data['account'] as Map<String, dynamic>? ?? {}),
      );
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Sign-in failed. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches the current account details from the backend.
  Future<void> fetchAccount() async {
    try {
      final response = await _api.getRoot('account/me');
      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          await _store.clearAccountToken();
          ApiService.setAccountToken(null);
          _account = null;
          notifyListeners();
        }
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      _account = await _withProfilePicture(
        Account.fromJson(data['account'] as Map<String, dynamic>? ?? {}),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<Account> _withProfilePicture(Account account) async {
    final mediaId = account.profileMediaId;
    if (mediaId == null || mediaId.isEmpty) return account;
    final url = await getMediaDownloadUrl(mediaId);
    return account.copyWith(profilePictureUrl: url);
  }

  /// Returns a short-lived download URL for a ready profile image.
  Future<String?> getMediaDownloadUrl(String mediaId) async {
    try {
      final response = await _api.getRoot('media/$mediaId');
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      return data['download_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Updates account fields and optionally uploads a new profile picture.
  Future<bool> updateProfile({
    required String fullName,
    String? dateOfBirth,
    XFile? profileImage,
  }) async {
    try {
      String? mediaId = _account?.profileMediaId;
      if (profileImage != null) {
        mediaId = await _uploadProfilePicture(profileImage);
        if (mediaId == null) return false;
      }
      final body = <String, dynamic>{
        'full_name': fullName.trim(),
        if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty)
          'date_of_birth': dateOfBirth.trim(),
        if (mediaId != null && mediaId.isNotEmpty) 'profile_media_id': mediaId,
      };
      final response =
          await _api.postRoot('account/update-details', body: body);
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      final accountJson = data['account'] as Map<String, dynamic>? ?? {};
      _account = await _withProfilePicture(Account.fromJson(accountJson));
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('[auth] profile update failed: $error');
      return false;
    }
  }

  Future<String?> _uploadProfilePicture(XFile file) async {
    await AppMetadata.initialize();
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final filename = file.name.isNotEmpty ? file.name : 'profile.jpg';
    final contentType = lookupMimeType(filename, headerBytes: bytes);
    if (contentType == null || !contentType.startsWith('image/')) return null;
    final stampedFilename =
        '${ApiService.deviceId}_${DateTime.now().millisecondsSinceEpoch}_$filename';
    final authorize = await _api.postRoot(
      'media/uploads',
      body: {
        'purpose': 'profile_picture',
        'filename': stampedFilename,
        'content_type': contentType,
        'size_bytes': bytes.length,
      },
    );
    if (authorize.statusCode != 201) return null;
    final decoded = jsonDecode(authorize.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    final media = data['media'] as Map<String, dynamic>? ?? {};
    final upload = data['upload'] as Map<String, dynamic>? ?? {};
    final mediaId = media['id'] as String?;
    final uploadUrl = upload['url'] as String?;
    if (mediaId == null || uploadUrl == null) return null;
    final uploadHeaders = (upload['headers'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, '$value'));
    final uploaded = await _api.putExternal(
      Uri.parse(uploadUrl),
      bytes: bytes,
      headers: uploadHeaders,
    );
    if (uploaded.statusCode < 200 || uploaded.statusCode >= 300) return null;
    final complete = await _api.postRoot('media/uploads/$mediaId/complete');
    if (complete.statusCode != 200) return null;
    final completeJson = jsonDecode(complete.body) as Map<String, dynamic>;
    final completeMedia =
        (completeJson['data'] as Map<String, dynamic>?)?['media'];
    if (completeMedia is! Map<String, dynamic> ||
        completeMedia['state'] != 'ready') {
      return null;
    }
    return mediaId;
  }

  /// Fetches the list of sessions for the current account.
  Future<List<AccountSession>> fetchSessions() async {
    try {
      final response = await _api.getRoot('account/sessions');
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      final items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => AccountSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Revokes a specific session by ID.
  Future<bool> revokeSession(String sessionId) async {
    try {
      final response = await _api.postRoot(
        'account/sessions/revoke',
        body: {'session_id': sessionId},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Logs out the current session and clears local state.
  Future<void> logout() async {
    try {
      await _api.postRoot('account/logout');
    } catch (_) {}
    await _store.clearAccountToken();
    ApiService.setAccountToken(null);
    _account = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }
}
