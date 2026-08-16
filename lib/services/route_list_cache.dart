import 'dart:convert';

import '../models/transit_route.dart';
import '../utils/api_envelope.dart';
import 'api_service.dart';

/// In-memory cache of each provider's route list, shared across the Map,
/// Routes, and Timetable flows so `{provider_id}/routes` isn't refetched on
/// every tab switch.
///
/// Only static route metadata is cached — never live ETA or vehicle positions.
/// Errors are not cached, so a retry (which re-calls [routesFor]) refetches.
class RouteListCache {
  RouteListCache._({ApiService? apiService})
      : _api = apiService ?? ApiService();

  /// App-wide singleton so all screens share one cache.
  static final RouteListCache instance = RouteListCache._();

  final ApiService _api;
  final Map<int, List<TransitRoute>> _cache = {};
  final Map<int, Future<List<TransitRoute>>> _inflight = {};

  /// Returns the provider's route list, fetching it once per session and
  /// deduplicating concurrent requests for the same provider.
  Future<List<TransitRoute>> routesFor(int providerId) async {
    final cached = _cache[providerId];
    if (cached != null) return cached;

    final inflight = _inflight[providerId];
    if (inflight != null) return inflight;

    final future = _fetch(providerId);
    _inflight[providerId] = future;
    try {
      final routes = await future;
      _cache[providerId] = routes;
      return routes;
    } finally {
      _inflight.remove(providerId);
    }
  }

  Future<List<TransitRoute>> _fetch(int providerId) async {
    final response = await _api.get('$providerId/routes');
    if (response.statusCode != 200) {
      throw Exception('Server responded with ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = extractItems(decoded);
    return data
        .map((item) => TransitRoute.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
