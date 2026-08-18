import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/account.dart';
import '../models/session.dart';
import 'api_service.dart';
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
      onError: (_) {},
    );
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme.toLowerCase() != 'keepyoumoving' ||
        uri.host.toLowerCase() != 'oauth' ||
        uri.path != '/callback') {
      return;
    }
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
      _error = 'Invalid sign-in response.';
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
      _account =
          Account.fromJson(data['account'] as Map<String, dynamic>? ?? {});
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
      _account =
          Account.fromJson(data['account'] as Map<String, dynamic>? ?? {});
      notifyListeners();
    } catch (_) {}
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
