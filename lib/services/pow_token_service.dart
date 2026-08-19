import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../config/api_config.dart';
import 'api_service.dart';
import 'app_metadata.dart';
import 'secure_token_store.dart';
import 'turnstile_service.dart';

/// A proof-of-work token issued by the backend, bound to this device.
class PowToken {
  const PowToken({required this.token, required this.expiresAt});

  /// The bearer token (never logged).
  final String token;

  /// Unix seconds at which the token expires.
  final int expiresAt;

  /// True while the token is usable, treating the last [leeway] before
  /// expiry as already-expired so we refresh proactively.
  bool isValidAt(DateTime now, {Duration leeway = const Duration(minutes: 5)}) {
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    return nowSec < expiresAt - leeway.inSeconds;
  }
}

/// Thrown when the PoW exchange fails or the response is malformed.
class PowTokenException implements Exception {
  PowTokenException(this.message);

  final String message;

  @override
  String toString() => 'PowTokenException: $message';
}

/// Obtains, persists, and reuses the proof-of-work token.
///
/// Policy (documented — the backend returns `expires_in`/`expires_at`): reuse a
/// stored token until it is within 5 minutes of expiry, then refresh via a
/// fresh Turnstile challenge + `POST {{prod_base}}/security/pow-token`. Errors
/// are never cached, so a retry re-runs the exchange.
class PowTokenService {
  PowTokenService({
    SecureTokenStore? store,
    TurnstileService? turnstile,
    ApiService? api,
  })  : _store = store ?? SecureTokenStore(),
        _turnstile = turnstile ?? TurnstileService(),
        _api = api ?? ApiService();

  final SecureTokenStore _store;
  final TurnstileService _turnstile;
  final ApiService _api;

  Future<PowToken>? _inFlight;

  /// Returns a usable PoW token for [deviceId], reusing a valid stored token
  /// and refreshing only when absent/expired/near-expiry. Single-flight: a
  /// concurrent caller shares the same exchange and the in-flight slot is
  /// released on completion (success or failure).
  Future<PowToken> getOrRefresh(String deviceId) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _getOrRefresh(deviceId);
    _inFlight = future;
    future.whenComplete(() => _inFlight = null);
    return future;
  }

  Future<PowToken> _getOrRefresh(String deviceId) async {
    final cached = await cachedIfUsable();
    if (cached != null) return cached;
    final turnstileToken = await _turnstile.getToken();
    return exchange(deviceId, turnstileToken: turnstileToken);
  }

  /// Returns the stored PoW token while it is still usable, else `null`.
  Future<PowToken?> cachedIfUsable() async {
    final token = await _store.readPowToken();
    if (token == null || token.isEmpty) return null;
    final expiresAt = await _store.readPowExpiresAt();
    if (expiresAt == null) return null; // no expiry contract → refresh
    final pow = PowToken(token: token, expiresAt: expiresAt);
    return pow.isValidAt(DateTime.now()) ? pow : null;
  }

  /// Exchanges a Turnstile token for a PoW token and persists it.
  ///
  /// Uses the security base — never the `/public-transport/` prefix.
  Future<PowToken> exchange(
    String deviceId, {
    required String turnstileToken,
  }) async {
    await AppMetadata.initialize();
    final body = {
      'turnstile_token': turnstileToken,
      'device_id': deviceId,
      'platform': AppMetadata.platform,
      'device_model': AppMetadata.deviceModel,
      'app_version': AppMetadata.appVersion,
    };
    // Debug breadcrumb: log the exchange request. The Turnstile token is a
    // one-time credential and is deliberately redacted (never logged).
    debugPrint('[pow-token] POST ${ApiConfig.securityBase}'
        '${ApiConfig.powTokenEndpoint} '
        '{device_id: $deviceId, platform: ${AppMetadata.platform}, '
        'device_model: ${AppMetadata.deviceModel}, '
        'app_version: ${AppMetadata.appVersion}, turnstile_token: [redacted]}');
    final response = await _api.postSecurity(
      ApiConfig.powTokenEndpoint,
      body: body,
    );
    debugPrint('[pow-token] response status: ${response.statusCode}');
    if (response.statusCode != 201) {
      debugPrint('[pow-token] POW API Failed Response: ${response.body}');
      throw PowTokenException(
        'PoW exchange failed (HTTP ${response.statusCode}).',
      );
      // Output whole JSON
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final token = data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw PowTokenException('PoW response did not contain a token.');
    }
    final expiresAt = data?['expires_at'] as int?;
    final expiresIn = data?['expires_in'] as int?;
    // Prefer the absolute expiry; fall back to `expires_in` seconds from now.
    final resolvedExpiry = expiresAt ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expiresIn ?? 86400);

    final pow = PowToken(token: token, expiresAt: resolvedExpiry);
    await _store.writePowToken(token, expiresAt: resolvedExpiry);
    return pow;
  }
}
