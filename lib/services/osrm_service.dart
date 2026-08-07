import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches road-following geometry between waypoints using the public OSRM
/// routing service (backed by OpenStreetMap data). No API key is required.
///
/// Because the GTFS stop feed only provides stop coordinates (no road
/// geometry), this service is used to obtain a polyline that follows the
/// actual road network between the stops.
class OsrmService {
  static const String baseUrl = 'https://router.project-osrm.org';

  /// Kept well under OSRM's 100-coordinate limit so one request stays valid.
  static const int _maxCoordsPerRequest = 50;

  /// Returns a polyline (ordered [LatLng]s) following roads through
  /// [waypoints]. If there are fewer than 2 waypoints, returns them unchanged.
  ///
  /// When the waypoint count exceeds the per-request limit, the waypoints are
  /// split into overlapping chunks (sharing a boundary waypoint) and the
  /// resulting geometries are merged into one continuous polyline.
  Future<List<LatLng>> fetchRouteGeometry(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return waypoints;

    final chunks = <List<LatLng>>[];
    for (var i = 0; i < waypoints.length; i += _maxCoordsPerRequest - 1) {
      final end = (i + _maxCoordsPerRequest <= waypoints.length)
          ? i + _maxCoordsPerRequest
          : waypoints.length;
      chunks.add(waypoints.sublist(i, end));
    }

    final merged = <LatLng>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final coords = chunk.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse(
        '$baseUrl/route/v1/driving/$coords?overview=full&geometries=geojson',
      );

      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Routing request failed (${response.statusCode})');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['code'] != 'Ok') {
        throw Exception('Routing request failed: ${decoded['code']}');
      }
      final routes = decoded['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) {
        throw Exception('Routing request returned no routes');
      }

      final geometry = (routes.first as Map<String, dynamic>)['geometry']
          as Map<String, dynamic>;
      final coordsList = geometry['coordinates'] as List<dynamic>? ?? const [];
      var points = coordsList
          .map((c) => LatLng(
                ((c as List)[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      // Consecutive chunks share their boundary waypoint; drop the duplicate
      // so the merged polyline stays continuous.
      if (i > 0 && points.isNotEmpty) {
        points = points.sublist(1);
      }
      merged.addAll(points);
    }

    return merged;
  }
}
