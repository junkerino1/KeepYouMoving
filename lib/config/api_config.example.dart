/// Backend endpoints and security configuration for the RapidTransit KL app.
///
/// TEMPLATE FILE — this file is committed to version control and is **not**
/// used directly by the app. Copy it to `api_config.dart` (which is
/// git-ignored) and fill in the placeholders:
///
/// ```sh
/// cp lib/config/api_config.example.dart lib/config/api_config.dart
/// ```
///
/// [prodBase] is the single environment root. Public-transport (transit)
/// endpoints live under `/public-transport/`; security endpoints (the PoW
/// token exchange) live under `/security/`. The base-path split is centralised
/// here and in [ApiService] so the prefix is never scattered across callers.
class ApiConfig {
  /// Environment root. Must match a domain allowed in the Cloudflare Turnstile
  /// widget configuration (kept here so it can be overridden per environment).
  ///
  /// Replace with your backend host, e.g. `https://keepyoumoving-be.example.com/prod/public`.
  static const String prodBase = 'https://YOUR_BACKEND_HOST/prod/public';

  /// Base for every public-transport endpoint (transit data).
  static const String publicTransportBase = '$prodBase/public-transport/';

  /// Base for security endpoints (e.g. the PoW token exchange).
  static const String securityBase = '$prodBase/security/';

  /// Cloudflare Turnstile site key (invisible, app-bootstrap widget).
  ///
  /// Replace with a site key from your Cloudflare dashboard, for a widget
  /// whose domain allowlist matches [prodBase].
  static const String turnstileSiteKey = 'YOUR_TURNSTILE_SITE_KEY';

  /// Header the backend expects the PoW token in — matches
  /// `"token_type": "x-pow-token"` in the `/security/pow-token` response.
  static const String powTokenHeader = 'x-pow-token';

  /// Header the backend expects the device ID in; sent alongside
  /// [powTokenHeader] on every `/public-transport/` request.
  static const String deviceIdHeader = 'x-device-id';

  /// Relative PoW token exchange endpoint. Lives under [securityBase] and must
  /// NOT receive the `/public-transport/` prefix.
  static const String powTokenEndpoint = 'pow-token';

  /// Backwards-compatible alias for existing callers; resolves to the
  /// public-transport base.
  static const String baseUrl = publicTransportBase;
}
