import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Map shell used by both the live map and the stop-detail screens.
///
/// Owns the `FlutterMap`, tile layer, optional route polyline layer, and any
/// marker layers supplied by the caller. It never performs API calls; it only
/// renders data passed down from the screen/controller.
class LiveMap extends StatelessWidget {
  const LiveMap({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.initialZoom,
    required this.tileUrlTemplate,
    this.polylines = const [],
    this.markerLayers = const [],
  });

  final MapController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final String tileUrlTemplate;
  final List<Polyline> polylines;
  final List<MarkerLayer> markerLayers;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrlTemplate,
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.example.gtfs_rapid_flutter',
          additionalOptions: const {
            'attribution':
                '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
          },
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        ...markerLayers,
      ],
    );
  }
}
