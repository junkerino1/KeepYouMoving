import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/eta_departure.dart';
import '../models/route_live_vehicle.dart';
import '../models/route_stop.dart';
import '../models/vehicle_progress.dart';
import '../services/api_service.dart';
import '../utils/api_envelope.dart';

/// Loads the stops of a route (grouped by direction) and the GTFS shape
/// polyline for each direction, caching both so direction switches never
/// re-fetch data.
class RouteController extends ChangeNotifier {
  RouteController({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  String _routeId = '';
  List<RouteStop> _stops = [];
  bool _isLoadingStops = false;
  bool _stopsLoaded = false;
  String? _stopsError;
  int? _selectedDirection;

  final Map<String, List<LatLng>> _geometryCache = {};
  final Set<String> _geometryLoading = {};
  final Map<String, String?> _geometryError = {};

  // Real-time ETA / live vehicle data (refreshed periodically).
  List<EtaDeparture> _departures = [];
  bool _isLoadingEta = false;
  String? _etaError;
  DateTime? _lastEtaFetchedAt;

  // Live buses for the whole route (dedicated live-location endpoint).
  List<RouteLiveVehicle> _routeVehicles = [];
  bool _isLoadingRouteVehicles = false;
  String? _routeVehiclesError;

  // Vehicle progress (stops-away) per public vehicle ID.
  final Map<String, VehicleProgress> _vehicleProgress = {};
  final Map<String, bool> _vehicleProgressLoading = {};

  // Highlighted vehicle (tapped from ETA list).
  String? _highlightedVehicleId;

  List<RouteStop> get stops => List.unmodifiable(_stops);
  bool get isLoadingStops => _isLoadingStops;
  bool get hasLoadedStops => _stopsLoaded;
  String? get stopsError => _stopsError;
  int? get selectedDirection => _selectedDirection;

  /// Unique direction ids present in the stops, sorted ascending.
  List<int> get directions {
    final set = <int>{for (final s in _stops) s.directionId};
    final list = set.toList()..sort();
    return list;
  }

  /// Whether the route runs in both directions (0 and 1 present).
  bool get isBidirectional => directions.length > 1;

  /// Stops for the selected direction, ordered by `stop_sequence` ascending.
  List<RouteStop> get selectedDirectionStops {
    final dir = _selectedDirection;
    if (dir == null) return const [];
    final list = _stops.where((s) => s.directionId == dir).toList()
      ..sort((a, b) => a.stopSequence.compareTo(b.stopSequence));
    return list;
  }

  /// The direction (0 or 1) that serves [stopId], or `null` when the stop is
  /// not part of this route's stops.
  int? directionForStop(String stopId) {
    for (final stop in _stops) {
      if (stop.stopId == stopId) return stop.directionId;
    }
    return null;
  }

  String _geometryKey(int direction) => '$_routeId/$direction';

  /// Cached road geometry for the selected direction (null if not loaded).
  List<LatLng>? get selectedGeometry {
    final dir = _selectedDirection;
    return dir == null ? null : _geometryCache[_geometryKey(dir)];
  }

  bool get isLoadingGeometry {
    final dir = _selectedDirection;
    return dir != null && _geometryLoading.contains(_geometryKey(dir));
  }

  String? get geometryError {
    final dir = _selectedDirection;
    return dir == null ? null : _geometryError[_geometryKey(dir)];
  }

  /// Resets all cached state so a new route can be loaded. Must be called
  /// before loading a different route to clear stale data from the previous
  /// route.
  void resetForNewRoute() {
    _stops = [];
    _stopsLoaded = false;
    _stopsError = null;
    _selectedDirection = null;
    _geometryCache.clear();
    _geometryLoading.clear();
    _geometryError.clear();
    _departures = [];
    _etaError = null;
    _lastEtaFetchedAt = null;
    _routeVehicles = [];
    _routeVehiclesError = null;
    _vehicleProgress.clear();
    _vehicleProgressLoading.clear();
    _highlightedVehicleId = null;
    notifyListeners();
  }

  /// Loads the route's stops and selects the lowest present direction
  /// (0 if available, otherwise 1 — never assumed). Resets cached data
  /// if a different route is being loaded.
  Future<void> loadRouteStops({
    required int providerId,
    required String routeId,
  }) async {
    // If switching to a different route, reset cached state first.
    if (_routeId != routeId) {
      resetForNewRoute();
    }
    _routeId = routeId;
    if (_isLoadingStops || (_stopsLoaded && _stops.isNotEmpty)) return;

    _isLoadingStops = true;
    _stopsError = null;
    notifyListeners();
    try {
      final response = await _api.get('$providerId/$routeId/stops');
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = extractItems(decoded);
      _stops = data
          .map((e) => RouteStop.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      _stopsLoaded = true;
      _selectedDirection = directions.isEmpty ? null : directions.first;
    } catch (_) {
      _stops = [];
      _stopsLoaded = true;
      _selectedDirection = null;
      _stopsError = 'Could not load route stops.';
    } finally {
      _isLoadingStops = false;
      notifyListeners();
    }
  }

  void selectDirection(int direction) {
    if (_selectedDirection == direction) return;
    _selectedDirection = direction;
    notifyListeners();
  }

  /// Ensures the shape polyline for the selected direction is available,
  /// cached per route + direction. Safe to call on every direction switch.
  Future<void> ensureGeometry({required int providerId}) async {
    final dir = _selectedDirection;
    if (dir == null) return;
    final key = _geometryKey(dir);
    if (_geometryCache.containsKey(key) || _geometryLoading.contains(key)) {
      return;
    }

    _geometryLoading.add(key);
    _geometryError.remove(key);
    notifyListeners();
    try {
      final response = await _api.get('$providerId/$_routeId/$dir/shapes');
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final shapes = extractItems(decoded);
      // Merge every returned shape, ordered by point sequence.
      final geometry = <LatLng>[];
      for (final shape in shapes) {
        final shapeMap = shape as Map<String, dynamic>;
        final rawPoints = shapeMap['points'] as List<dynamic>? ?? const [];
        final entries = <(int, LatLng)>[];
        for (final p in rawPoints) {
          final m = p as Map<String, dynamic>;
          entries.add((
            int.parse(m['shape_pt_sequence'] as String),
            LatLng(
              double.parse(m['shape_pt_lat'] as String),
              double.parse(m['shape_pt_lon'] as String),
            ),
          ));
        }
        entries.sort((a, b) => a.$1.compareTo(b.$1));
        geometry.addAll(entries.map((e) => e.$2));
      }
      _geometryCache[key] = geometry;
    } catch (_) {
      // Fallback: stop markers remain visible, the polyline is just omitted.
      _geometryError[key] = 'Could not load route geometry.';
    } finally {
      _geometryLoading.remove(key);
      notifyListeners();
    }
  }

  // --- Real-time ETA / live vehicles ---

  List<EtaDeparture> get departures => List.unmodifiable(_departures);
  bool get isLoadingEta => _isLoadingEta;
  String? get etaError => _etaError;
  DateTime? get lastEtaFetchedAt => _lastEtaFetchedAt;

  /// Upcoming departures for the selected direction, sorted by time. Departed
  /// trips (more than a minute ago) are excluded.
  List<EtaDeparture> get selectedDirectionDepartures {
    final dir = _selectedDirection;
    final now = DateTime.now().toUtc();
    final list = _departures.where((d) {
      if (dir != null && int.tryParse(d.directionId) != dir) return false;
      final scheduled = d.scheduledAtLocal.toUtc();
      return !scheduled.isBefore(now.subtract(const Duration(minutes: 1)));
    }).toList()
      ..sort((a, b) => a.scheduledAtLocal.compareTo(b.scheduledAtLocal));
    return list;
  }

  /// Valid live vehicles (position + public plate) for the selected direction.
  List<({VehiclePosition position, String? plate})> get liveVehicleInfo {
    final dir = _selectedDirection;
    final result = <({VehiclePosition position, String? plate})>[];
    for (final d in _departures) {
      if (dir != null && int.tryParse(d.directionId) != dir) continue;
      final vehicle = d.firstValidVehicle;
      if (vehicle != null) {
        result.add((position: vehicle, plate: d.liveVehicleId));
      }
    }
    return result;
  }

  /// Fetches the ETA departures for a route + stop. Safe to call repeatedly;
  /// only the real-time data is refreshed (stops/geometry stay cached).
  Future<void> loadEta({
    required int providerId,
    required String routeId,
    required String stopId,
  }) async {
    if (_isLoadingEta) return;

    _isLoadingEta = true;
    _etaError = null;
    notifyListeners();
    try {
      final response = await _api.get('$providerId/eta/$routeId/$stopId');
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      // Departures are wrapped under `data` in the ETA response envelope.
      final payload = unwrapData(decoded);
      final data = payload['departures'] as List<dynamic>? ?? const [];
      _departures = data
          .map((e) => EtaDeparture.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      _lastEtaFetchedAt = DateTime.now();
    } catch (_) {
      // Keep previous departures; the UI shows a non-blocking error state.
      _etaError = 'Could not load live departures.';
    } finally {
      _isLoadingEta = false;
      notifyListeners();
    }
  }

  // --- Live buses for the route (dedicated live-location endpoint) ---

  List<RouteLiveVehicle> get routeVehicles => List.unmodifiable(_routeVehicles);
  bool get isLoadingRouteVehicles => _isLoadingRouteVehicles;
  String? get routeVehiclesError => _routeVehiclesError;

  /// Live buses for the selected direction, from the route live-location
  /// endpoint (used to plot buses on the map).
  List<RouteLiveVehicle> get selectedDirectionRouteVehicles {
    final dir = _selectedDirection;
    if (dir == null) return List.unmodifiable(_routeVehicles);
    return _routeVehicles.where((v) => v.directionId == dir).toList();
  }

  /// Fetches live bus locations for the whole route via the dedicated
  /// live-location endpoint. Only the real-time positions are refreshed —
  /// never cached. Safe to call repeatedly.
  Future<void> loadRouteLiveVehicles({
    required int providerId,
    required String routeId,
  }) async {
    if (_isLoadingRouteVehicles) return;
    _isLoadingRouteVehicles = true;
    _routeVehiclesError = null;
    notifyListeners();
    try {
      final response =
          await _api.get('$providerId/live_location/route/$routeId');
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = extractItems(decoded);
      _routeVehicles = data
          .map((item) =>
              RouteLiveVehicle.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      // Keep previous vehicles; the UI shows a non-blocking error state.
      _routeVehiclesError = 'Could not load live buses.';
    } finally {
      _isLoadingRouteVehicles = false;
      notifyListeners();
    }
  }

  // --- Vehicle progress (stops-away) ---

  /// Progress for a specific vehicle, or null if not loaded.
  VehicleProgress? vehicleProgress(String publicVehicleId) =>
      _vehicleProgress[publicVehicleId];

  /// Whether progress is loading for a specific vehicle.
  bool isLoadingProgress(String publicVehicleId) =>
      _vehicleProgressLoading[publicVehicleId] ?? false;

  /// The vehicle ID currently highlighted on the map (from ETA tap).
  String? get highlightedVehicleId => _highlightedVehicleId;

  /// Sets the highlighted vehicle (tapped from the ETA list). Pass null to
  /// clear the highlight.
  void setHighlightedVehicle(String? publicVehicleId) {
    if (_highlightedVehicleId == publicVehicleId) return;
    _highlightedVehicleId = publicVehicleId;
    notifyListeners();
  }

  /// Fetches the stops-away progress for a specific vehicle approaching a
  /// target stop. Results are cached per vehicle+stop combination.
  Future<void> loadVehicleProgress({
    required int providerId,
    required String publicVehicleId,
    required String targetStopId,
  }) async {
    final cacheKey = '$publicVehicleId/$targetStopId';
    if (_vehicleProgressLoading[cacheKey] == true) return;

    _vehicleProgressLoading[cacheKey] = true;
    notifyListeners();
    try {
      final response = await _api.get(
        '$providerId/live_location/vehicle/$publicVehicleId/progress'
        '?target_stop_id=$targetStopId',
      );
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      _vehicleProgress[cacheKey] = VehicleProgress.fromJson(data);
    } catch (_) {
      // Silently fail; the UI just won't show stops-away.
    } finally {
      _vehicleProgressLoading[cacheKey] = false;
      notifyListeners();
    }
  }
}
