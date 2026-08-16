import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/route_controller.dart';
import '../models/eta_departure.dart';
import '../models/route_stop.dart';
import '../models/transit_route.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/map/live_bus_marker.dart';
import '../widgets/map/live_map.dart';
import '../widgets/map/stop_dot.dart';
import '../widgets/sheets/stop_detail_bottom_sheet.dart';
import '../widgets/stops/route_color_badge.dart';
import 'route_detail_screen.dart';
import 'timetable_screen.dart';

class StopDetailScreen extends StatefulWidget {
  final String stopName;
  final String stopLine;
  final double latitude;
  final double longitude;
  final String stopId;
  final int providerId;
  final String? providerKey;
  final TransitRoute? route;

  const StopDetailScreen({
    super.key,
    required this.stopName,
    required this.stopLine,
    required this.latitude,
    required this.longitude,
    required this.stopId,
    required this.providerId,
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

  /// Stop whose name bubble is currently shown above its marker.
  RouteStop? _tappedStop;

  /// Live vehicle whose info bubble (plate + speed) is shown above its marker.
  ({VehiclePosition position, String? plate})? _tappedVehicle;

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
    if (routeId == null) return;

    await _routeController.loadRouteStops(
      providerId: providerId,
      routeId: routeId,
    );
    if (!mounted) return;

    _focusOnStation();
    await _routeController.ensureGeometry(providerId: providerId);

    await _routeController.loadEta(
      providerId: providerId,
      routeId: routeId,
      stopId: widget.stopId,
    );
  }

  /// Periodically refreshes ETA / live vehicle data without touching the
  /// cached route stops or geometry.
  void _startEtaRefresh() {
    final routeId = widget.route?.routeId;
    if (routeId == null) return;

    _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _routeController.loadEta(
        providerId: widget.providerId,
        routeId: routeId,
        stopId: widget.stopId,
      );
    });
  }

  /// Centers the map on the selected station at a fixed zoom (~14.0), keeping
  /// the same look as the live map instead of fitting the whole route.
  void _focusOnStation() {
    final target = LatLng(widget.latitude, widget.longitude);
    try {
      _mapController.move(target, 16.0);
    } catch (_) {
      // The map may not be laid out yet; the initial center still applies.
    }
  }

  /// Shows the tapped stop's name above its marker, like the live map.
  void _onMarkerTap(RouteStop stop) {
    setState(() {
      _tappedStop = stop;
      _tappedVehicle = null;
    });
  }

  /// Shows a live bus's plate + speed above its marker.
  void _onVehicleTap(({VehiclePosition position, String? plate}) info) {
    setState(() {
      _tappedVehicle = info;
      _tappedStop = null;
    });
  }

  /// Hides the live-bus info bubble.
  void _dismissVehicleBubble() {
    if (_tappedVehicle != null) {
      setState(() => _tappedVehicle = null);
    }
  }

  /// Hides the stop-name bubble (and its dismiss barrier).
  void _dismissStopBubble() {
    if (_tappedStop != null) {
      setState(() => _tappedStop = null);
    }
  }

  void _onDirectionToggle() {
    final providerId = widget.providerId;
    final dirs = _routeController.directions;
    if (dirs.length < 2) return;
    final current = _routeController.selectedDirection ?? dirs.first;
    final next = dirs.firstWhere((d) => d != current, orElse: () => current);
    _routeController.selectDirection(next);
    _focusOnStation();
    _routeController.ensureGeometry(providerId: providerId);
  }

  /// Opens the route-detail screen for the route serving this stop, so the
  /// user can browse its full stop list. Only available with a route context.
  void _openStopsList() {
    final route = widget.route;
    if (route == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          route: route,
          providerId: widget.providerId,
          providerKey: widget.providerKey,
        ),
      ),
    );
  }

  /// Opens the timetable screen deep-linked to this stop's schedule. Only
  /// available with a route context (needed to resolve the timetable).
  void _openSchedule() {
    final route = widget.route;
    if (route == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(widget.stopName)),
          body: TimetableScreen(
            initialProviderKey: widget.providerKey,
            initialProviderId: widget.providerId,
            initialRouteId: route.routeId,
            initialStopId: widget.stopId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          strokeWidth: 8,
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
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => _onMarkerTap(stop),
                          child: StopDot(color: _providerTheme.primary),
                        ),
                      ),
                  ],
                )
              else
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.latitude, widget.longitude),
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => _onMarkerTap(RouteStop(
                          stopId: widget.stopId,
                          stopName: widget.stopName,
                          stopLat: widget.latitude,
                          stopLon: widget.longitude,
                        )),
                        child: StopDot(color: _providerTheme.primary),
                      ),
                    ),
                  ],
                ),
              // Live buses on the selected route/direction (tap shows plate+speed)
              if (_routeController.liveVehicleInfo.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final info in _routeController.liveVehicleInfo)
                      Marker(
                        point: LatLng(
                          info.position.latitude,
                          info.position.longitude,
                        ),
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: LiveBusMarker(
                          color: _providerTheme.primary,
                          bearing: info.position.bearing,
                          bearingIsExplicit: info.position.bearingIsExplicit,
                          onTap: () => _onVehicleTap(info),
                        ),
                      ),
                  ],
                ),
            ];

            return Stack(
              children: [
                // Map Layer (dark-aware tile set)
                LiveMap(
                  mapController: _mapController,
                  initialCenter: LatLng(widget.latitude, widget.longitude),
                  initialZoom: 20.0,
                  tileUrlTemplate: Theme.of(context).brightness == Brightness.dark
                      ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  polylines: polylines,
                  markerLayers: markerLayers,
                ),
                // "You are here!" label above the selected stop
                _YouAreHereLabel(
                  mapController: _mapController,
                  position: LatLng(widget.latitude, widget.longitude),
                ),
                // Floating Header
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _buildHeader(),
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
                    originLabel: _originLabel,
                    destinationLabel: _destinationLabel,
                    onDirectionToggle: _onDirectionToggle,
                    onStopsList:
                        widget.route != null ? _openStopsList : null,
                    onSchedule: widget.route != null ? _openSchedule : null,
                  ),
                ),
                // Stop-name bubble for the tapped marker (dismiss on outside
                // tap), mirroring the live map.
                if (_tappedStop != null)
                  _StopBubbleOverlay(
                    key: ValueKey(_tappedStop!.stopId),
                    stop: _tappedStop!,
                    mapController: _mapController,
                    onDismiss: _dismissStopBubble,
                  ),
                // Live-bus info bubble (plate + speed) for the tapped bus.
                if (_tappedVehicle != null)
                  _VehicleBubbleOverlay(
                    key: ValueKey(
                      'bus-${_tappedVehicle!.position.latitude}-'
                      '${_tappedVehicle!.position.longitude}',
                    ),
                    point: LatLng(
                      _tappedVehicle!.position.latitude,
                      _tappedVehicle!.position.longitude,
                    ),
                    plate: _tappedVehicle!.plate,
                    speedKmh: _tappedVehicle!.position.speedKmh,
                    mapController: _mapController,
                    onDismiss: _dismissVehicleBubble,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.chevron_left_rounded,
                size: 24, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          // Route number badge (provider theme, max 4 chars with ellipsis)
          RouteColorBadge(
            shortName: _displayLine,
            theme: _providerTheme,
            fontSize: 12,
            iconSize: 12,
          ),
          const SizedBox(width: 8),
          // Stop name
          Expanded(
            child: Text(
              widget.stopName,
              style: textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// First stop of the selected direction, or a loading label while the stops
  /// haven't been returned yet.
  String get _originLabel {
    final stops = _routeController.selectedDirectionStops;
    return stops.isEmpty ? 'Loading...' : stops.first.stopName;
  }

  /// Last stop of the selected direction, or a loading label while the stops
  /// haven't been returned yet.
  String get _destinationLabel {
    final stops = _routeController.selectedDirectionStops;
    return stops.isEmpty ? 'Loading...' : stops.last.stopName;
  }
}

/// Stop-name bubble that stays tied to a tapped stop marker while the map
/// moves, mirroring the live map. Tapping outside dismisses it.
class _StopBubbleOverlay extends StatefulWidget {
  final RouteStop stop;
  final MapController mapController;
  final VoidCallback onDismiss;

  const _StopBubbleOverlay({
    super.key,
    required this.stop,
    required this.mapController,
    required this.onDismiss,
  });

  @override
  State<_StopBubbleOverlay> createState() => _StopBubbleOverlayState();
}

class _StopBubbleOverlayState extends State<_StopBubbleOverlay> {
  StreamSubscription<MapEvent>? _mapSub;
  Offset _position = Offset.zero;

  @override
  void initState() {
    super.initState();
    _position = _computePosition();
    // Follow the tapped marker as the map pans or flings.
    _mapSub = widget.mapController.mapEventStream.listen((event) {
      if (!mounted) return;
      if (event is MapEventMove || event is MapEventFlingAnimation) {
        setState(() => _position = _computePosition());
      }
    });
  }

  @override
  void dispose() {
    _mapSub?.cancel();
    super.dispose();
  }

  /// Top-left corner for the bubble: centered above the 24px marker.
  Offset _computePosition() {
    try {
      final point = widget.mapController.camera.latLngToScreenPoint(
        LatLng(widget.stop.stopLat, widget.stop.stopLon),
      );
      return Offset(point.x, point.y - 12 - 8 - 36);
    } catch (_) {
      return Offset(MediaQuery.sizeOf(context).width / 2, 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onDismiss,
        child: Stack(
          children: [
            Positioned(
              left: _position.dx,
              top: _position.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: _StopBubble(stopName: widget.stop.stopName),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tooltip-style bubble showing a stop's name.
class _StopBubble extends StatelessWidget {
  final String stopName;

  const _StopBubble({required this.stopName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      shadowColor: const Color(0x330F172A),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          stopName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// "You are here!" label that stays tied to the selected stop marker while the
/// map moves.
class _YouAreHereLabel extends StatefulWidget {
  final MapController mapController;
  final LatLng position;

  const _YouAreHereLabel({
    required this.mapController,
    required this.position,
  });

  @override
  State<_YouAreHereLabel> createState() => _YouAreHereLabelState();
}

class _YouAreHereLabelState extends State<_YouAreHereLabel> {
  StreamSubscription<MapEvent>? _mapSub;
  Offset _position = Offset.zero;

  @override
  void initState() {
    super.initState();
    _position = _computePosition();
    // Follow the selected stop marker as the map pans or flings.
    _mapSub = widget.mapController.mapEventStream.listen((event) {
      if (!mounted) return;
      if (event is MapEventMove || event is MapEventFlingAnimation) {
        setState(() => _position = _computePosition());
      }
    });
  }

  @override
  void dispose() {
    _mapSub?.cancel();
    super.dispose();
  }

  /// Top-left corner for the label: centered above the selected stop marker.
  Offset _computePosition() {
    try {
      final point =
          widget.mapController.camera.latLngToScreenPoint(widget.position);
      // Above the 24px marker (half = 12) with a small gap and the label.
      return Offset(point.x, point.y - 12 - 8 - 30);
    } catch (_) {
      return Offset(MediaQuery.sizeOf(context).width / 2, 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: const FractionalTranslation(
        translation: Offset(-0.5, 0),
        child: _YouAreHereBubble(),
      ),
    );
  }
}

/// Small white rectangle with a shadow, a red location pin and black text.
class _YouAreHereBubble extends StatelessWidget {
  const _YouAreHereBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 3,
      shadowColor: const Color(0x330F172A),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded, size: 12, color: scheme.error),
            const SizedBox(width: 4),
            Text(
              'You are here!',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live-bus info bubble that stays tied to a tapped bus marker while the map
/// moves. Tapping outside dismisses it.
class _VehicleBubbleOverlay extends StatefulWidget {
  final LatLng point;
  final String? plate;
  final double speedKmh;
  final MapController mapController;
  final VoidCallback onDismiss;

  const _VehicleBubbleOverlay({
    super.key,
    required this.point,
    required this.plate,
    required this.speedKmh,
    required this.mapController,
    required this.onDismiss,
  });

  @override
  State<_VehicleBubbleOverlay> createState() => _VehicleBubbleOverlayState();
}

class _VehicleBubbleOverlayState extends State<_VehicleBubbleOverlay> {
  StreamSubscription<MapEvent>? _mapSub;
  Offset _position = Offset.zero;

  @override
  void initState() {
    super.initState();
    _position = _computePosition();
    _mapSub = widget.mapController.mapEventStream.listen((event) {
      if (!mounted) return;
      if (event is MapEventMove || event is MapEventFlingAnimation) {
        setState(() => _position = _computePosition());
      }
    });
  }

  @override
  void dispose() {
    _mapSub?.cancel();
    super.dispose();
  }

  /// Top-left corner for the bubble: centered above the 48px bus marker.
  Offset _computePosition() {
    try {
      final point =
          widget.mapController.camera.latLngToScreenPoint(widget.point);
      return Offset(point.x, point.y - 24 - 8 - 46);
    } catch (_) {
      return Offset(MediaQuery.sizeOf(context).width / 2, 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onDismiss,
        child: Stack(
          children: [
            Positioned(
              left: _position.dx,
              top: _position.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: _VehicleBubble(
                  plate: widget.plate,
                  speedKmh: widget.speedKmh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tooltip-style bubble showing a live bus's plate (carplate) and speed.
class _VehicleBubble extends StatelessWidget {
  final String? plate;
  final double speedKmh;

  const _VehicleBubble({required this.plate, required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      shadowColor: const Color(0x330F172A),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_bus_rounded,
                    size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  plate?.isNotEmpty == true ? plate! : 'Bus',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed_rounded,
                    size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${formatSpeedKmh(speedKmh)} km/h',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
