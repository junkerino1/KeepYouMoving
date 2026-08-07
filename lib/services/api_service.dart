import 'dart:convert';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}$endpoint',
    );

    return await http.get(url);
  }

  /// Sends a JSON `POST` request to `[ApiConfig.baseUrl][endpoint]`.
  Future<http.Response> post(String endpoint, {Object? body}) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}$endpoint',
    );

    return await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }
}