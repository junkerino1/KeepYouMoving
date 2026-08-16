import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/stop_controller.dart';
import '../models/stop.dart';
import '../models/transit_provider.dart';
import '../models/transit_route.dart';
import '../services/provider_repository.dart';
import '../services/route_list_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/common/map_status_chip.dart';
import '../widgets/map/live_map.dart';
import '../widgets/map/nearest_stop_marker.dart';
import '../widgets/map/user_location_marker.dart';
import '../widgets/sheets/live_map_bottom_sheet.dart';
import '../widgets/sheets/sheet_snap.dart';
import '../widgets/stops/provider_switcher.dart';
import 'stop_detail_screen.dart';

class LiveMapScreen extends StatefulWidget {
  /// Called when the user picks a bus line from the global search. The query
  /// is forwarded to the Routes tab, which filters with its own logic.
  final ValueChanged<String>? onOpenRouteSearch;

  const LiveMapScreen({super.key, this.onOpenRouteSearch});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  static const _defaultCenter = LatLng(3.0797, 101.7741);
  static const _defaultZoom = 16.0;

  /// Rapid KL Bus (id 5) — the default provider.
  static final _rapidKl = TransitProvider(
    id: 5,
    providerKey: 'rapid_bus_kl',
    providerName: 'Rapid KL Bus',
    category: 'rapid_bus',
    descShort: 'Rapid KL Bus',
    descLong: 'Rapid KL Bus',
    gtfsUrl: '',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  /// Rapid KL MRT Feeder (id 3).
  static final _mrtFeeder = TransitProvider(
    id: 3,
    providerKey: 'rapid_bus_mrtfeeder',
    providerName: 'MRT Feeder',
    category: 'rapid_bus',
    descShort: 'MRT Feeder',
    descLong: 'MRT Feeder',
    gtfsUrl: '',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  final MapController _mapController = MapController();
  final ProviderRepository _providerRepository = ProviderRepository();
  final StopController _stopController = StopController();
  LatLng? _currentPosition;
  bool _isLocating = false;
  double _bottomSheetHeight = kSheetDefaultHeight;
  Stop? _tappedStop;

  /// Live GPS stream subscription; updates [_currentPosition] as the user moves.
  StreamSubscription<Position>? _positionSub;

  /// Where nearest stops were last fetched from; used to throttle re-fetches
  /// while the location stream emits frequent updates.
  LatLng? _lastStopsRefreshOrigin;

  /// Honest, human-readable reason the location couldn't be resolved. Shown
  /// as a status chip instead of a fabricated "you are here" marker.
  String? _locationMessage;

  // Provider switching (dev phase: Rapid KL Bus & MRT Feeder).
  List<TransitProvider> _providers = [];
  TransitProvider? _selectedProvider;

  /// Routes for the selected provider, used by the global search (bus lines).
  List<TransitRoute> _routes = [];

  /// Theme of the currently selected provider; drives provider-related
  /// buttons, icons and markers.
  ProviderTheme get _providerTheme =>
      ProviderTheme.of(_selectedProvider?.providerKey);

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _loadProviders();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stopController.dispose();
    super.dispose();
  }

  /// Loads the dev providers (Rapid KL default) and refreshes the nearest
  /// stops for the selected one. Toggling the provider runs this flow again.
  Future<void> _loadProviders() async {
    List<TransitProvider> dev;
    try {
      final all = await _providerRepository.loadProviders();
      // Dev phase: only Rapid KL Bus (5) and MRT Feeder (3).
      const devKeys = {'rapid_bus_kl', 'rapid_bus_mrtfeeder'};
      dev = all.where((p) => devKeys.contains(p.providerKey)).toList();
    } catch (_) {
      dev = const [];
    }
    // Fall back to the known dev providers if the bundle is unavailable.
    if (dev.isEmpty) dev = [_rapidKl, _mrtFeeder];

    if (!mounted) return;
    setState(() {
      _providers = dev;
      // Default to Rapid KL on first load; keep the current selection on
      // later toggles.
      _selectedProvider ??= dev.firstWhere(
        (p) => p.providerKey == 'rapid_bus_kl',
        orElse: () => dev.first,
      );
    });
    _refreshStops();
    _loadRoutes();
  }

  /// Loads the routes for the selected provider so the global search can list
  /// bus lines (shared with the Routes/Timetable flows; cached per provider).
  Future<void> _loadRoutes() async {
    final provider = _selectedProvider;
    if (provider == null) return;
    try {
      final routes = await RouteListCache.instance.routesFor(provider.id);
      if (!mounted || _selectedProvider?.id != provider.id) return;
      setState(() => _routes = routes);
    } catch (_) {
      // Ignore; the search simply shows no bus-line matches.
    }
  }

  /// Forwards a selected bus line to the Routes tab, which filters with its
  /// existing search logic.
  void _onRouteSearchSelected(TransitRoute route) {
    widget.onOpenRouteSearch?.call(route.routeShortName);
  }

  /// Fetches the nearest stops for the selected provider around the user's
  /// current GPS position.
  void _refreshStops() {
    final position = _currentPosition;
    final provider = _selectedProvider;
    if (position == null || provider == null) return;
    _stopController.loadNearestStops(
      providerId: provider.id,
      origin: position,
    );
  }

  /// Requests location permission, then starts streaming the user's live
  /// position so the marker follows the device.
  ///
  /// On permission/service failure sets [_locationMessage] so the UI shows an
  /// honest location-unavailable state instead of a fabricated marker.
  Future<void> _fetchCurrentLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _locationMessage = 'Location services are off';
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _locationMessage = 'Location permission denied';
          });
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _locationMessage = 'Location is disabled in settings';
          });
        }
        return;
      }

      await _startPositionStream();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _locationMessage = 'Could not determine your location';
        });
      }
    }
  }

  /// Subscribes to the live GPS stream so the user marker follows the device.
  ///
  /// The first fix centers the map and refreshes nearby stops; later updates
  /// only move the marker (the map is not re-centered while you pan). Nearby
  /// stops refresh again once the user has moved a meaningful distance.
  Future<void> _startPositionStream() async {
    await _positionSub?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      // 0 = emit every update (no distance filter).
      distanceFilter: 0,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
      (position) {
        if (!mounted) return;
        final latLng = LatLng(position.latitude, position.longitude);
        final isFirstFix = _currentPosition == null;
        setState(() {
          _currentPosition = latLng;
          _isLocating = false;
          _locationMessage = null;
        });
        if (isFirstFix) _centerOn(latLng);
        _refreshStopsIfMoved(latLng, force: isFirstFix);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLocating = false;
          // Keep any last-known position; only surface an error when we never
          // got a fix at all.
          if (_currentPosition == null) {
            _locationMessage = 'Could not determine your location';
          }
        });
      },
    );
  }

  /// Refreshes the nearest stops only when the user has moved at least
  /// [minRefreshDistanceM] from the last refresh, or when [force] is set
  /// (first fix / provider change).
  void _refreshStopsIfMoved(LatLng origin, {required bool force}) {
    const minRefreshDistanceM = 150;
    final last = _lastStopsRefreshOrigin;
    if (!force &&
        last != null &&
        const Distance().as(LengthUnit.Meter, last, origin) <
            minRefreshDistanceM) {
      return;
    }
    _lastStopsRefreshOrigin = origin;
    _refreshStops();
  }

  /// Re-centers the map on the user's current position (fetching it if needed).
  void _centerOnCurrent() {
    final position = _currentPosition;
    if (position == null) {
      _fetchCurrentLocation();
      return;
    }
    _centerOn(position);
  }

  /// Centers the camera so the location marker sits near the top of the map
  /// (~25% from the top) instead of dead-center, keeping it clear of the
  /// bottom sheet that covers the lower part of the screen.
  ///
  /// The zoom is reset to the default level, and rotation is snapped back to
  /// north — only the center follows [point].
  void _centerOn(LatLng point) {
    try {
      final camera = _mapController.camera;
      // Reset to the default zoom level.
      const zoom = _defaultZoom;
      // Snap rotation to north first (rotate-only: never touches zoom/center)
      // so the offset math below runs in a north-up frame and the marker ends
      // up exactly where intended.
      if (camera.rotation != 0) _mapController.rotate(0);

      final height = camera.nonRotatedSize.y;
      // A negative vertical offset shifts the point UP the screen. Fall back
      // to the screen height when the map isn't laid out yet (size is 0).
      final mapHeight = height > 0 ? height : MediaQuery.sizeOf(context).height;
      _mapController.move(
        point,
        zoom,
        offset: Offset(0, -(mapHeight * 0.25)),
      );
    } catch (_) {
      _mapController.move(point, _defaultZoom);
    }
  }

  /// Resets the map rotation so north is up, keeping the current center/zoom.
  void _resetNorth() {
    try {
      _mapController.rotate(0);
    } catch (_) {
      // The map may not be laid out yet; nothing to reset.
    }
  }

  void _openStopDetail(Stop stop) {
    final provider = _selectedProvider;
    if (provider == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopDetailScreen(
          stopName: stop.stopName,
          stopLine: providerShortLabel(provider),
          latitude: stop.stopLat,
          longitude: stop.stopLon,
          stopId: stop.stopId,
          providerId: provider.id,
          providerKey: provider.providerKey,
        ),
      ),
    );
  }

  /// Opens the stop detail screen for a specific route serving [stop].
  void _openRouteDetail(Stop stop, TransitRoute route) {
    final provider = _selectedProvider;
    if (provider == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopDetailScreen(
          stopName: stop.stopName,
          stopLine: route.routeShortName,
          latitude: stop.stopLat,
          longitude: stop.stopLon,
          stopId: stop.stopId,
          providerId: provider.id,
          providerKey: provider.providerKey,
          route: route,
        ),
      ),
    );
  }

  /// Opens the stop detail screen for [stop] with its first route's context
  /// (route stops, polyline, live ETA, "Stops List"/"Schedule"), mirroring a
  /// route tap (see [_openRouteDetail]). Falls back to the plain stop detail
  /// when the stop has no routes. Used for both the marker bubble and stop-name
  /// search results so a stop is always opened with the full stop context.
  Future<void> _openStopDetailResolved(Stop stop) async {
    final provider = _selectedProvider;
    if (provider == null) return;
    final routes = await _stopController.loadRoutesForStop(
      providerId: provider.id,
      stopId: stop.stopId,
    );
    if (!mounted) return;
    if (routes.isNotEmpty) {
      _openRouteDetail(stop, routes.first);
    } else {
      _openStopDetail(stop);
    }
  }

  void _onProviderSelected(TransitProvider provider) {
    setState(() => _selectedProvider = provider);
    _refreshStops();
    _loadRoutes();
  }

  /// Records the tapped stop so a speech bubble can be shown above its marker.
  void _onMarkerTap(Stop stop) {
    setState(() => _tappedStop = stop);
  }

  /// Hides the stop-name bubble (and its dismiss barrier).
  void _dismissStopBubble() {
    if (_tappedStop != null) {
      setState(() => _tappedStop = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _stopController,
      builder: (context, _) {
        final markerLayers = <MarkerLayer>[
          // Marker for the user's live location (only once it's known).
          if (_currentPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition!,
                  width: 64,
                  height: 64,
                  child: const UserLocationMarker(),
                ),
              ],
            ),
          // Nearest stops for the currently selected provider
          if (_stopController.hasStops)
            MarkerLayer(
              markers: [
                for (final stop in _stopController.stops)
                  Marker(
                    point: LatLng(stop.stopLat, stop.stopLon),
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: NearestStopMarker(
                      color: _providerTheme.primary,
                      onTap: () => _onMarkerTap(stop),
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
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              tileUrlTemplate: Theme.of(context).brightness == Brightness.dark
                  ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              markerLayers: markerLayers,
            ),
            // Map controls: reset-north + center-on-location buttons
            Positioned(
              right: 12,
              bottom: _bottomSheetHeight + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'resetNorth',
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.navy,
                    elevation: 2,
                    tooltip: 'Reset north',
                    onPressed: _resetNorth,
                    child: const Icon(Icons.explore_rounded),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'locateMe',
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.navy,
                    elevation: 2,
                    tooltip: 'Center on my location',
                    onPressed: _centerOnCurrent,
                    child: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.navy,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ],
              ),
            ),
            // Nearest-stops fetch status
            if (_stopController.isLoading)
              const Positioned(
                top: 12,
                left: 12,
                child: MapStatusChip.loading(),
              )
            else if (_stopController.errorMessage != null)
              Positioned(
                top: 12,
                left: 12,
                child: MapStatusChip.error(_stopController.errorMessage!),
              ),
            // Location-unavailable / permission state (honest, no fake marker)
            if (_locationMessage != null)
              Positioned(
                top: 12,
                left: 12,
                child: MapStatusChip.info(_locationMessage!),
              ),
            // Bottom Sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LiveMapBottomSheet(
                height: _bottomSheetHeight,
                onHeightChanged: (height) =>
                    setState(() => _bottomSheetHeight = height),
                controller: _stopController,
                providers: _providers,
                selectedProvider: _selectedProvider,
                theme: _providerTheme,
                routes: _routes,
                onProviderSelected: _onProviderSelected,
                onSearchResultTap: _openStopDetailResolved,
                onRouteTap: _openRouteDetail,
                onRouteSearchSelected: _onRouteSearchSelected,
              ),
            ),
            // Stop-name bubble overlay (dismiss on outside tap); follows the
            // marker as the map is dragged.
            if (_tappedStop != null)
              _StopBubbleOverlay(
                key: ValueKey(_tappedStop!.stopId),
                stop: _tappedStop!,
                mapController: _mapController,
                onDismiss: _dismissStopBubble,
                onOpen: () {
                  final stop = _tappedStop;
                  // Capture the stop before dismissing (dismiss clears it).
                  _dismissStopBubble();
                  if (stop != null) _openStopDetailResolved(stop);
                },
              ),
          ],
        );
      },
    );
  }
}

/// Stop-name bubble that stays tied to its marker while the map moves.
///
/// Repositions itself on every map movement event, so the bubble follows the
/// bus icon even while dragging. Tapping anywhere outside dismisses it.
class _StopBubbleOverlay extends StatefulWidget {
  final Stop stop;
  final MapController mapController;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  const _StopBubbleOverlay({
    super.key,
    required this.stop,
    required this.mapController,
    required this.onDismiss,
    required this.onOpen,
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
    _position = _computePosition(widget.stop);
    // Follow the marker as the map pans or flings.
    _mapSub = widget.mapController.mapEventStream.listen((event) {
      if (!mounted) return;
      if (event is MapEventMove || event is MapEventFlingAnimation) {
        setState(() => _position = _computePosition(widget.stop));
      }
    });
  }

  @override
  void dispose() {
    _mapSub?.cancel();
    super.dispose();
  }

  /// Top-left corner for the bubble: centered above the marker.
  Offset _computePosition(Stop stop) {
    try {
      final point = widget.mapController.camera.latLngToScreenPoint(
        LatLng(stop.stopLat, stop.stopLon),
      );
      return Offset(point.x, point.y - 22 - 8 - 36);
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
                child: _StopBubble(
                  stopName: widget.stop.stopName,
                  onTap: widget.onOpen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stop-name bubble locked above a tapped marker. A native `Material`/`InkWell`
/// (the whole bubble is tappable) styled like a tooltip; text uses the theme
/// color and the chevron hints at navigation.
class _StopBubble extends StatelessWidget {
  final String stopName;
  final VoidCallback onTap;

  const _StopBubble({required this.stopName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      shadowColor: const Color(0x330F172A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  stopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
