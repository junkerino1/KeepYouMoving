import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/route_controller.dart';
import '../models/eta_departure.dart';
import '../models/route_stop.dart';
import '../models/transit_route.dart';
import '../services/app_location_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/map/live_bus_marker.dart';
import '../widgets/map/live_map.dart';
import '../widgets/map/stop_dot.dart';
import '../widgets/map/user_location_marker.dart';
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

  /// The user's real GPS position, shown when they are near this stop
  /// (mirrors the live map's streaming-location marker).
  LatLng? _userPosition;
  bool _isFetchingUserLocation = false;

  /// Stop whose name bubble is currently shown above its marker.
  RouteStop? _tappedStop;

  /// Live vehicle whose info bubble (plate + speed) is shown above its marker.
  ({VehiclePosition position, String? plate})? _tappedVehicle;

  /// Line/route shown in the header badge: prefers the selected route's short
  /// name, falling back to the passed [StopDetailScreen.stopLine].
  String get _displayLine => widget.route?.routeShortName ?? widget.stopLine;

  /// Provider theme for all provider-related accents on this screen.
  ProviderTheme get _providerTheme => ProviderTheme.of(widget.providerKey);

  /// Whether the entered stop's pin should be shown: yes while the stop
  /// belongs to the currently selected direction, so inverting to a direction
  /// that doesn't serve it hides the pin. With no route data (no direction to
  /// consider) it's always shown.
  bool get _showEnteredStopMarker {
    if (!_routeController.hasLoadedStops) return true;
    return _routeController.selectedDirectionStops
        .any((stop) => stop.stopId == widget.stopId);
  }

  @override
  void initState() {
    super.initState();
    _initRoute();
    _startEtaRefresh();
    _fetchUserLocation();
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

    // Default the direction to whichever one serves the entered stop (0 or 1)
    // so opening a stop on the inbound side doesn't show the outbound view.
    final stopDirection = _routeController.directionForStop(widget.stopId);
    if (stopDirection != null) {
      _routeController.selectDirection(stopDirection);
    }

    _focusOnStation();
    await _routeController.ensureGeometry(providerId: providerId);

    await _routeController.loadEta(
      providerId: providerId,
      routeId: routeId,
      stopId: widget.stopId,
    );
    // Plot live buses for the whole route on the map.
    await _routeController.loadRouteLiveVehicles(
      providerId: providerId,
      routeId: routeId,
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
      _routeController.loadRouteLiveVehicles(
        providerId: widget.providerId,
        routeId: routeId,
      );
    });
  }

  /// Fetches the user's real GPS position via the shared location service
  /// (permission already granted by the live map screen).
  Future<void> _fetchUserLocation() async {
    if (_isFetchingUserLocation) return;
    _isFetchingUserLocation = true;
    try {
      final pos = await AppLocationService.instance.getInitialLatLng();
      if (!mounted) return;
      if (pos != null) {
        setState(() => _userPosition = pos);
      }
    } catch (_) {
      // Not shown — the user marker is simply omitted.
    } finally {
      _isFetchingUserLocation = false;
    }
  }

  /// Whether [position] is close enough to this stop to show the user marker.
  bool _isNearStop(LatLng position) {
    const thresholdM = 1000;
    final distance = const Distance().as(
      LengthUnit.Meter,
      position,
      LatLng(widget.latitude, widget.longitude),
    );
    return distance <= thresholdM;
  }

  /// Centers the map on the selected station so it sits near the top of the
  /// screen (~30% from the top) instead of dead-center, keeping it clear of
  /// the draggable bottom sheet, at the same zoom as the live map.
  void _focusOnStation() {
    final target = LatLng(widget.latitude, widget.longitude);
    try {
      final camera = _mapController.camera;
      final height = camera.nonRotatedSize.y;
      // A negative vertical offset shifts the point UP the screen. Fall back
      // to the screen height when the map isn't laid out yet (size is 0).
      final mapHeight =
          height > 0 ? height : MediaQuery.sizeOf(context).height;
      _mapController.move(
        target,
        16.0,
        offset: Offset(0, -(mapHeight * 0.20)),
      );
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

  /// Highlights a bus on the map and fetches its stops-away progress.
  void _onDepartureTap(EtaDeparture departure) {
    final vehicleId = departure.liveVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    // Toggle highlight: tap again to deselect.
    final currentHighlight = _routeController.highlightedVehicleId;
    if (currentHighlight == vehicleId) {
      _routeController.setHighlightedVehicle(null);
      return;
    }

    _routeController.setHighlightedVehicle(vehicleId);

    // Fetch stops-away progress for this vehicle.
    _routeController.loadVehicleProgress(
      providerId: widget.providerId,
      publicVehicleId: vehicleId,
      targetStopId: widget.stopId,
    );

    // Pan the map to center on the live bus position.
    final vehiclePos = departure.firstValidVehicle;
    if (vehiclePos != null && vehiclePos.positionValid) {
      final busLatLng = LatLng(vehiclePos.latitude, vehiclePos.longitude);
      try {
        final camera = _mapController.camera;
        final height = camera.nonRotatedSize.y;
        final mapHeight =
            height > 0 ? height : MediaQuery.sizeOf(context).height;
        _mapController.move(
          busLatLng,
          camera.zoom,
          offset: Offset(0, -(mapHeight * 0.20)),
        );
      } catch (_) {
        _mapController.move(busLatLng, 16.0);
      }
    }
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
              // Stops for the selected direction (excluding the entered stop,
              // which is drawn as a pinpoint below).
              if (_routeController.hasLoadedStops &&
                  _routeController.selectedDirectionStops.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final stop in _routeController.selectedDirectionStops)
                      if (stop.stopId != widget.stopId)
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
                ),
              // The entered stop's round marker + pinpoint — shown only while
              // the stop belongs to the currently selected direction.
              if (_showEnteredStopMarker) ...[
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.latitude, widget.longitude),
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      child: StopDot(color: _providerTheme.primary),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.latitude, widget.longitude),
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _onMarkerTap(RouteStop(
                          stopId: widget.stopId,
                          stopName: widget.stopName,
                          stopLat: widget.latitude,
                          stopLon: widget.longitude,
                        )),
                        child: _StopPin(theme: _providerTheme),
                      ),
                    ),
                  ],
                ),
              ],
              // The user's real location, only when they are near this stop
              // (mirrors the live map's streaming-location marker).
              if (_userPosition != null && _isNearStop(_userPosition!))
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userPosition!,
                      width: 64,
                      height: 64,
                      child: const UserLocationMarker(),
                    ),
                  ],
                ),
              // Live buses plotted from the route live-location endpoint,
              // filtered to the selected direction (tap shows plate+speed).
              if (_routeController.selectedDirectionRouteVehicles.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final bus
                        in _routeController.selectedDirectionRouteVehicles)
                      Marker(
                        point: LatLng(
                          bus.position.latitude,
                          bus.position.longitude,
                        ),
                        width: bus.publicVehicleId ==
                                _routeController.highlightedVehicleId
                            ? 64
                            : 48,
                        height: bus.publicVehicleId ==
                                _routeController.highlightedVehicleId
                            ? 64
                            : 48,
                        alignment: Alignment.center,
                        child: LiveBusMarker(
                          color: _providerTheme.primary,
                          bearing: bus.position.bearing,
                          bearingIsExplicit: bus.position.bearingIsExplicit,
                          isHighlighted: bus.publicVehicleId ==
                              _routeController.highlightedVehicleId,
                          onTap: () => _onVehicleTap((
                            position: bus.position,
                            plate: bus.publicVehicleId,
                          )),
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
                    onDepartureTap: _onDepartureTap,
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

/// A location-pin marker for the entered stop, whose tail points at the
/// stop's exact location.
class _StopPin extends StatelessWidget {
  final ProviderTheme theme;

  const _StopPin({required this.theme});

  /// Material's pin glyph keeps a little empty padding below its tip, so the
  /// icon is nudged down by this much (logical px at the rendered size) to
  /// make the tail land exactly on the stop's location.
  static const double _tipPadding = 4;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, _tipPadding),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Slightly larger white glyph behind the colored one creates a white
          // outline around the pin.
          const Icon(Icons.location_on_rounded,
              size: 44, color: AppColors.white),
          Icon(Icons.location_on_rounded, size: 34, color: theme.primary),
        ],
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
