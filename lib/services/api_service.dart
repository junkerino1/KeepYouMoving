import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Thin HTTP client for the RapidTransit KL backend.
///
/// Centralises base-path construction: transit endpoints use
/// [ApiConfig.publicTransportBase] (i.e. `{{prod_base}}/public-transport/`)
/// while the PoW exchange uses [ApiConfig.securityBase] and deliberately does
/// NOT receive that prefix. Every transit request carries the device-bound
/// headers `x-pow-token` + `x-device-id`; neither value is ever logged.
class ApiService {
  /// App-wide PoW token, shared by every [ApiService] instance so any
  /// controller/screen benefits once the bootstrap has configured it.
  static String? _powToken;

  /// App-wide device ID, shared the same way as [_powToken].
  static String? _deviceId;

  /// App-wide account access token for authenticated user endpoints.
  static String? _accountToken;

  /// Configures the PoW token used to authorise transit requests. Called by
  /// the bootstrap coordinator once a valid token has been obtained.
  static void setPowToken(String? token) => _powToken = token;

  /// Configures the device ID sent with every transit request. Called by the
  /// bootstrap coordinator as soon as the device identity is known.
  static void setDeviceId(String? deviceId) => _deviceId = deviceId;

  /// Configures the account bearer token for authenticated user endpoints.
  static void setAccountToken(String? token) => _accountToken = token;

  /// True once a non-empty PoW token has been configured.
  static bool get hasPowToken => _powToken != null && _powToken!.isNotEmpty;

  /// Request headers shared by [get] and [post]: the PoW token and the device
  /// ID. They are never attached to security endpoints like the PoW exchange.
  Map<String, String> _authHeaders() => {
        if (_powToken != null && _powToken!.isNotEmpty)
          ApiConfig.powTokenHeader: _powToken!,
        if (_deviceId != null && _deviceId!.isNotEmpty)
          ApiConfig.deviceIdHeader: _deviceId!,
        if (_accountToken != null && _accountToken!.isNotEmpty)
          'Authorization': 'Bearer $_accountToken',
      };

  /// Debug breadcrumb for every transit request: shows the URL and whether
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

  /// Sends a JSON `POST` to `[ApiConfig.securityBase][endpoint]` (e.g. the PoW
  /// token exchange). Deliberately does NOT attach the PoW token.
  Future<http.Response> postSecurity(String endpoint, {Object? body}) async {
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