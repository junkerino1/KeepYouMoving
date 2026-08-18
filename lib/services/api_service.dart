import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Thin HTTP client for the RapidTransit KL backend.
///
/// Centralises base-path construction: transit endpoints use
/// [ApiConfig.publicTransportBase] (i.e. `{{prod_base}}/public-transport/`)
/// while the PoW exchange uses [ApiConfig.securityBase] and deliberately does
/// NOT receive that prefix. Every first-party API request carries the
/// device-bound headers `x-pow-token` + `x-device-id`; neither value is ever
/// logged.
class ApiService {
  /// App-wide PoW token, shared by every [ApiService] instance so any
  /// controller/screen benefits once the bootstrap has configured it.
  static String? _powToken;

  /// App-wide device ID, shared the same way as [_powToken].
  static String? _deviceId;

  /// App-wide account access token for authenticated user endpoints.
  static String? _accountToken;

  /// Completes once bootstrap has configured both device-bound API headers.
  static Completer<void>? _requiredHeadersReady;

  /// Configures the PoW token used to authorise transit requests. Called by
  /// the bootstrap coordinator once a valid token has been obtained.
  static void setPowToken(String? token) {
    _powToken = token;
    _completeRequiredHeadersReady();
  }

  /// Configures the device ID sent with every transit request. Called by the
  /// bootstrap coordinator as soon as the device identity is known.
  static void setDeviceId(String? deviceId) {
    _deviceId = deviceId;
    _completeRequiredHeadersReady();
  }

  /// Configures the account bearer token for authenticated user endpoints.
  static void setAccountToken(String? token) => _accountToken = token;

  /// True once a non-empty PoW token has been configured.
  static bool get hasPowToken => _powToken != null && _powToken!.isNotEmpty;

  /// True once both headers required by first-party API requests are ready.
  static bool get hasRequiredHeaders =>
      _powToken != null &&
      _powToken!.isNotEmpty &&
      _deviceId != null &&
      _deviceId!.isNotEmpty;

  /// Waits for bootstrap to configure the headers required by normal API
  /// requests. This lets cold-start OAuth callbacks safely wait for bootstrap.
  static Future<void> waitForRequiredHeaders({
    Duration timeout = const Duration(seconds: 45),
  }) {
    if (hasRequiredHeaders) return Future<void>.value();
    final completer = _requiredHeadersReady ??= Completer<void>();
    return completer.future.timeout(timeout);
  }

  static void _completeRequiredHeadersReady() {
    if (hasRequiredHeaders &&
        _requiredHeadersReady != null &&
        !_requiredHeadersReady!.isCompleted) {
      _requiredHeadersReady!.complete();
    }
  }

  /// Request headers shared by all normal API methods. The two device-bound
  /// headers are mandatory; fail before making a request rather than silently
  /// sending an unauthorised API call during bootstrap or recovery.
  Map<String, String> _authHeaders() => {
        ApiConfig.powTokenHeader: _requireHeader(
          _powToken,
          ApiConfig.powTokenHeader,
        ),
        ApiConfig.deviceIdHeader: _requireHeader(
          _deviceId,
          ApiConfig.deviceIdHeader,
        ),
        if (_accountToken != null && _accountToken!.isNotEmpty)
          'Authorization': 'Bearer $_accountToken',
      };

  String _requireHeader(String? value, String name) {
    if (value == null || value.isEmpty) {
      throw StateError('Missing required API header: $name');
    }
    return value;
  }

  /// Debug breadcrumb for every first-party request: shows the URL and whether
  /// the PoW token / device ID headers are attached. Token values are never
  /// logged.
  void _logRequest(String method, Uri url, Map<String, String> headers) {
    debugPrint('[api] $method $url'
        ' | ${ApiConfig.powTokenHeader}: '
        '${headers.containsKey(ApiConfig.powTokenHeader) ? 'attached' : 'MISSING'}'
        ' | ${ApiConfig.deviceIdHeader}: '
        '${headers.containsKey(ApiConfig.deviceIdHeader) ? 'attached' : 'MISSING'}');
  }

  void _logResponse(Uri url, int status) {
    debugPrint('[api] ${url.path} → HTTP $status');
  }

  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse(
      '${ApiConfig.publicTransportBase}$endpoint',
    );
    final headers = _authHeaders();
    _logRequest('GET', url, headers);

    final response = await http.get(url, headers: headers);
    _logResponse(url, response.statusCode);
    return response;
  }

  /// Sends a GET request to an account/favourite endpoint at the API root.
  /// These endpoints intentionally do not use the `/public-transport/`
  /// prefix, but retain the configured account/device headers.
  Future<http.Response> getRoot(String endpoint) async {
    final url = Uri.parse('${ApiConfig.prodBase}/$endpoint');
    final headers = _authHeaders();
    _logRequest('GET', url, headers);

    final response = await http.get(url, headers: headers);
    _logResponse(url, response.statusCode);
    return response;
  }

  /// Sends a JSON `POST` request to `[ApiConfig.publicTransportBase][endpoint]`.
  Future<http.Response> post(String endpoint, {Object? body}) async {
    final url = Uri.parse(
      '${ApiConfig.publicTransportBase}$endpoint',
    );
    final headers = {..._authHeaders(), 'Content-Type': 'application/json'};
    _logRequest('POST', url, headers);

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
    _logResponse(url, response.statusCode);
    return response;
  }

  /// Sends a JSON POST request to an account/favourite endpoint at the API
  /// root, without the `/public-transport/` prefix.
  Future<http.Response> postRoot(String endpoint, {Object? body}) async {
    final url = Uri.parse('${ApiConfig.prodBase}/$endpoint');
    final headers = {..._authHeaders(), 'Content-Type': 'application/json'};
    _logRequest('POST', url, headers);

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
    _logResponse(url, response.statusCode);
    return response;
  }

  /// Sends a JSON `POST` to `[ApiConfig.securityBase][endpoint]` (e.g. the PoW
  /// token exchange). Deliberately does NOT attach the PoW token.
  Future<http.Response> postSecurity(String endpoint, {Object? body}) async {
    if (endpoint != ApiConfig.powTokenEndpoint) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'Only the PoW-token endpoint may omit required API headers.',
      );
    }
    final url = Uri.parse(
      '${ApiConfig.securityBase}$endpoint',
    );
    // Security endpoints deliberately carry no auth headers.
    debugPrint('[api] POST $url (security — no auth headers)');

    final response = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _logResponse(url, response.statusCode);
    return response;
  }
}
