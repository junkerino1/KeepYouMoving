import 'dart:async';

import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';

import '../config/api_config.dart';

/// Runs the Cloudflare Turnstile challenge and returns a runtime token.
///
/// Uses the headless "invisible" widget where supported; the token is
/// transient and is never persisted or logged.
class TurnstileService {
  /// Upper bound for the whole challenge (the widget has its own 8s
  /// script-load timeout; this guards the awaiting side as well).
  static const Duration _timeout = Duration(seconds: 20);

  /// Obtains a fresh Turnstile token.
  ///
  /// The challenge always runs in invisible (headless) mode — no visible
  /// widget is ever shown. Throws [TurnstileException] when the challenge
  /// fails or times out. The headless WebView is always disposed.
  Future<String> getToken() async {
    final turnstile = CloudflareTurnstile.invisible(
      siteKey: ApiConfig.turnstileSiteKey,
      // Must match the domain allowlisted in the Turnstile widget config.
      baseUrl: "https://keepyoumoving.samsam123.name.my",
      action: 'app-bootstrap',
      options: TurnstileOptions(
        theme: TurnstileTheme.auto,
        retryAutomatically: true,
        refreshExpired: TurnstileRefreshExpired.auto,
      ),
    );
    try {
      final token = await turnstile.getToken().timeout(_timeout);
      if (token == null || token.isEmpty) {
        throw const TurnstileException('No token received from Turnstile.');
      }
      return token;
    } on TurnstileException {
      rethrow;
    } on TimeoutException {
      throw const TurnstileException('Turnstile challenge timed out.');
    } catch (e) {
      throw TurnstileException('Turnstile challenge failed: $e');
    } finally {
      await turnstile.dispose();
    }
  }
}
