import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/stop.dart';
import '../models/transit_route.dart';
import '../services/api_service.dart';

/// Fetches and holds the nearest bus stops for the currently selected provider.
///
/// The GPS coordinates are supplied by the caller (the app already fetches the
/// user position via `geolocator` on the live map screen) and the provider id
/// comes from the existing provider toggle, so this controller does not
/// duplicate GPS or provider-selection logic.
class StopController extends ChangeNotifier {
  StopController({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  List<Stop> _stops = [];
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;

  // Cache keys used to skip unnecessary repeat calls.
  int? _lastProviderId;
  LatLng? _lastOrigin;

  // Per-provider/stop route cache and fetch state.
  final Map<String, List<TransitRoute>> _routesByStop = {};
  final Map<String, bool> _routesLoading = {};
  final Map<String, String?> _routesError = {};
  final Map<String, Future<List<TransitRoute>>> _routesInFlight = {};

  List<Stop> get stops => List.unmodifiable(_stops);
  bool get isLoading => _isLoading;
  bool get hasStops => _stops.isNotEmpty;
  String? get errorMessage => _errorMessage;

  /// Loads the nearest stops for [providerId] around [origin].
  ///
  /// Avoids repeated calls: a request already in flight, or an identical
  /// provider/origin that already produced results, is skipped.
  Future<void> loadNearestStops({
    required int providerId,
    required LatLng origin,
  }) async {
    if (_isFetching) return;

    final unchanged =
        _lastProviderId == providerId && _lastOrigin == origin && hasStops;
    if (unchanged) return;

    _isFetching = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        '$providerId/nearest_stations',
        body: {
          'lat': origin.latitude,
          'lon': origin.longitude
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? const [];
      _stops = data
          .map((item) => Stop.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      _lastProviderId = providerId;
      _lastOrigin = origin;
    } catch (_) {
      // Drop stale results from the UI when the fetch fails.
      _stops = [];
      _lastProviderId = null;
      _lastOrigin = null;
      _errorMessage = 'Could not load nearby stops.';
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  String _routeKey(int providerId, String stopId) => '$providerId/$stopId';

  /// Routes already fetched for a provider/stop pair, or `null` if not loaded.
  List<TransitRoute>? routesForStop({
    required int providerId,
    required String stopId,
  }) =>
      _routesByStop[_routeKey(providerId, stopId)];

  bool isLoadingRoutesFor({
    required int providerId,
    required String stopId,
  }) =>
      _routesLoading[_routeKey(providerId, stopId)] ?? false;

  String? routesErrorFor({
    required int providerId,
    required String stopId,
  }) =>
      _routesError[_routeKey(providerId, stopId)];

  /// Loads (or returns the cached) routes serving [stopId] for [providerId].
  ///
  /// Only called when a stop is expanded; results are cached per provider/stop
  /// so re-expanding the same stop never re-fetches, and duplicate in-flight
  /// requests are coalesced.
  Future<List<TransitRoute>> loadRoutesForStop({
    required int providerId,
    required String stopId,
  }) async {
    final key = _routeKey(providerId, stopId);
    final cached = _routesByStop[key];
    if (cached != null) return cached;

    final inFlight = _routesInFlight[key];
    if (inFlight != null) return inFlight;

    final future = _fetchRoutes(key, providerId, stopId);
    _routesInFlight[key] = future;
    try {
      return await future;
    } finally {
      _routesInFlight.remove(key);
    }
  }

  Future<List<TransitRoute>> _fetchRoutes(
    String key,
    int providerId,
    String stopId,
  ) async {
    _routesLoading[key] = true;
    _routesError[key] = null;
    notifyListeners();
    try {
      final response = await _api.get('$providerId/$stopId/routes');
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? const [];
      final routes = data
          .map((item) => TransitRoute.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      _routesByStop[key] = routes;
      return routes;
    } catch (_) {
      _routesError[key] = 'Could not load routes.';
      return const [];
    } finally {
      _routesLoading[key] = false;
      notifyListeners();
    }
  }

  void clear() {
    _stops = [];
    _lastProviderId = null;
    _lastOrigin = null;
    _errorMessage = null;
    _routesByStop.clear();
    _routesLoading.clear();
    _routesError.clear();
    _routesInFlight.clear();
    notifyListeners();
  }
}
