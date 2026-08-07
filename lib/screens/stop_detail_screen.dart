import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/route_controller.dart';
import '../models/transit_route.dart';
import '../theme/app_theme.dart';
import '../widgets/map/live_bus_marker.dart';
import '../widgets/map/live_map.dart';
import '../widgets/map/stop_dot.dart';
import '../widgets/sheets/stop_detail_bottom_sheet.dart';

class StopDetailScreen extends StatefulWidget {
  final String stopName;
  final String stopLine;
  final double latitude;
  final double longitude;
  final String? stopId;
  final int? providerId;
  final String? providerKey;
  final TransitRoute? route;

  const StopDetailScreen({
    super.key,
    required this.stopName,
    required this.stopLine,
    required this.latitude,
    required this.longitude,
    this.stopId,
    this.providerId,
    this.providerKey,
    this.route,
  });

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  final MapController _mapController = MapController();
  final RouteController _routeController = RouteController();
  Timer? _etaTimer;

  /// Line/route shown in the header badge: prefers the selected route's short
  /// name, falling back to the passed [StopDetailScreen.stopLine].
  String get _displayLine => widget.route?.routeShortName ?? widget.stopLine;

  /// Provider theme for all provider-related accents on this screen.
  ProviderTheme get _providerTheme => ProviderTheme.of(widget.providerKey);

  @override
  void initState() {
    super.initState();
    _initRoute();
    _startEtaRefresh();
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    _routeController.dispose();
    super.dispose();
  }

  Future<void> _initRoute() async {
    final providerId = widget.providerId;
    final routeId = widget.route?.routeId;
    if (providerId == null || routeId == null) return;

    await _routeController.loadRouteStops(
      providerId: providerId,
      routeId: routeId,
    );
    if (!mounted) return;

    _fitToRoute();
    await _routeController.ensureGeometry();

    final stopId = widget.stopId;
    if (stopId != null) {
      await _routeController.loadEta(
        providerId: providerId,
        routeId: routeId,
        stopId: stopId,
      );
    }
  }

  /// Periodically refreshes ETA / live vehicle data without touching the
  /// cached route stops or geometry.
  void _startEtaRefresh() {
    final providerId = widget.providerId;
    final routeId = widget.route?.routeId;
    final stopId = widget.stopId;
    if (providerId == null || routeId == null || stopId == null) return;

    _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _routeController.loadEta(
        providerId: providerId,
        routeId: routeId,
        stopId: stopId,
      );
    });
  }

  /// Fits the map to the bounds of the selected direction's stops.
  void _fitToRoute() {
    final stops = _routeController.selectedDirectionStops;
    if (stops.length < 2) return;
    final bounds = LatLngBounds.fromPoints(
      [for (final s in stops) LatLng(s.stopLat, s.stopLon)],
    );
    try {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    } catch (_) {
      // The map may not be laid out yet; the initial center still applies.
    }
  }

  void _onDirectionToggle() {
    final dirs = _routeController.directions;
    if (dirs.length < 2) return;
    final current = _routeController.selectedDirection ?? dirs.first;
    final next = dirs.firstWhere((d) => d != current, orElse: () => current);
    _routeController.selectDirection(next);
    _fitToRoute();
    _routeController.ensureGeometry();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _routeController,
          builder: (context, _) {
            final selectedGeometry = _routeController.selectedGeometry;
            final polylines =
                (selectedGeometry != null && selectedGeometry.isNotEmpty)
                    ? [
                        Polyline(
                          points: selectedGeometry,
                          strokeWidth: 4,
                          color: _providerTheme.primary,
                        ),
                      ]
                    : <Polyline>[];

            final markerLayers = <MarkerLayer>[
              // Stops for the selected direction, or the single tapped stop
              // when no route data is available.
              if (_routeController.hasLoadedStops &&
                  _routeController.selectedDirectionStops.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final stop in _routeController.selectedDirectionStops)
                      Marker(
                        point: LatLng(stop.stopLat, stop.stopLon),
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        child: StopDot(color: _providerTheme.primary),
                      ),
                  ],
                )
              else
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.latitude, widget.longitude),
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      child: StopDot(color: _providerTheme.primary),
                    ),
                  ],
                ),
              // Live buses on the selected route/direction
              if (_routeController.liveVehicles.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final vehicle in _routeController.liveVehicles)
                      Marker(
                        point: LatLng(vehicle.latitude, vehicle.longitude),
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: LiveBusMarker(
                          color: _providerTheme.primary,
                          bearing: vehicle.bearing,
                          bearingIsExplicit: vehicle.bearingIsExplicit,
                        ),
                      ),
                  ],
                ),
            ];

            return Stack(
              children: [
                // Map Layer
                LiveMap(
                  mapController: _mapController,
                  initialCenter: LatLng(widget.latitude, widget.longitude),
                  initialZoom: 16.0,
                  tileUrlTemplate:
                      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  polylines: polylines,
                  markerLayers: markerLayers,
                ),
                // Floating Header
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _buildHeader(),
                ),
                // Station Radar Badge
                Positioned(
                  top: 80,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.navyBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.navigation_rounded,
                            size: 10, color: AppColors.navyTextTertiary),
                        SizedBox(width: 6),
                        Text(
                          'Station Radar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.navyTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Draggable Bottom Sheet
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: StopDetailBottomSheet(
                    controller: _routeController,
                    theme: _providerTheme,
                    stopPosition: LatLng(widget.latitude, widget.longitude),
                    displayLine: _displayLine,
                    originLabel: _originLabel,
                    destinationLabel: _destinationLabel,
                    onDirectionToggle: _onDirectionToggle,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.chevron_left_rounded,
                  size: 22, color: AppColors.navyTextTertiary),
            ),
          ),
          const SizedBox(width: 8),
          // Line badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _displayLine,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Stop name
          Expanded(
            child: Text(
              widget.stopName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.navyTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Live Station badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.navyVeryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Live Station',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.navyTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// First stop of the selected direction (fallback placeholder when empty).
  String get _originLabel {
    final stops = _routeController.selectedDirectionStops;
    return stops.isEmpty ? 'LRT Wangsa Maju' : stops.first.stopName;
  }

  /// Last stop of the selected direction (fallback placeholder when empty).
  String get _destinationLabel {
    final stops = _routeController.selectedDirectionStops;
    return stops.isEmpty ? 'Lebuh Ampang' : stops.last.stopName;
  }
}
