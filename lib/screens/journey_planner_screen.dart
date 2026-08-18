import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../controllers/journey_controller.dart';
import '../models/journey_option.dart';
import '../models/transit_provider.dart';
import '../services/app_location_service.dart';
import '../services/api_service.dart';
import '../services/provider_repository.dart';
import '../theme/app_theme.dart';
import '../utils/api_envelope.dart';
import '../utils/format.dart';
import '../widgets/stops/provider_switcher.dart';

/// A place result from OSM Nominatim search.
class _PlaceResult {
  final String displayName;
  final double lat;
  final double lon;

  const _PlaceResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory _PlaceResult.fromJson(Map<String, dynamic> json) {
    return _PlaceResult(
      displayName: json['display_name'] as String? ?? '',
      lat: double.tryParse(json['lat'] as String? ?? '') ?? 0,
      lon: double.tryParse(json['lon'] as String? ?? '') ?? 0,
    );
  }
}

/// Journey planner screen: searchable origin/destination, plan routes, view
/// results on a map with walking polylines.
class JourneyPlannerScreen extends StatefulWidget {
  final int? providerId;
  final String? providerKey;

  const JourneyPlannerScreen({
    super.key,
    this.providerId,
    this.providerKey,
  });

  @override
  State<JourneyPlannerScreen> createState() => _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends State<JourneyPlannerScreen> {
  final JourneyController _controller = JourneyController();
  final ApiService _api = ApiService();
  final MapController _mapController = MapController();
  final TextEditingController _originSearchController = TextEditingController();
  final TextEditingController _destSearchController = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  LatLng? _currentPosition;
  bool _isSearchingOrigin = false;
  bool _isSearchingDest = false;

  // Provider selection
  List<TransitProvider> _providers = [];
  TransitProvider? _selectedProvider;

  // Search results
  List<_PlaceResult> _searchResults = [];
  bool _isSearchingPlaces = false;
  bool _hasSearched = false; // true after first search completes
  Timer? _searchDebounce;

  // Journey plot state
  JourneyOption? _selectedOption;
  List<LatLng> _originWalkPolyline = [];
  List<LatLng> _destWalkPolyline = [];
  bool _isLoadingWalkRoutes = false;

  // Transit route polyline (GTFS shape between boarding and alighting)
  List<LatLng> _transitPolyline = [];
  bool _isLoadingTransitRoute = false;

  // Results sheet drag state
  double _sheetHeight = 0; // 0 = auto, >0 = explicit height
  bool _isSheetDragging = false;
  double _dragStartY = 0;
  double _dragStartHeight = 0;
  bool _sheetMinimized = false;

  // The journey form collapses after a route is selected so the map and the
  // selected route details have the available screen space.
  bool _searchPanelMinimized = false;

  // Map-tap mode: 'origin' or 'destination'
  String? _mapTapMode;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _loadProviders();
    _originFocus.addListener(_onOriginFocusChange);
    _destFocus.addListener(_onDestFocusChange);
  }

  Future<void> _loadProviders() async {
    try {
      final repo = ProviderRepository();
      final all = await repo.loadProviders();
      const devKeys = {'rapid_bus_kl', 'rapid_bus_mrtfeeder'};
      final dev = all.where((p) => devKeys.contains(p.providerKey)).toList();
      if (!mounted) return;
      setState(() {
        _providers = dev;
        _selectedProvider ??= dev.firstWhere(
          (p) => p.providerKey == 'rapid_bus_kl',
          orElse: () => dev.first,
        );
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _originSearchController.dispose();
    _destSearchController.dispose();
    _originFocus.removeListener(_onOriginFocusChange);
    _destFocus.removeListener(_onDestFocusChange);
    _originFocus.dispose();
    _destFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onOriginFocusChange() {
    if (_originFocus.hasFocus) {
      setState(() {
        _isSearchingOrigin = true;
        _isSearchingDest = false;
      });
    }
  }

  void _onDestFocusChange() {
    if (_destFocus.hasFocus) {
      setState(() {
        _isSearchingDest = true;
        _isSearchingOrigin = false;
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    final pos = await AppLocationService.instance.getInitialLatLng();
    if (!mounted || pos == null) return;
    setState(() => _currentPosition = pos);
  }

  void _useCurrentLocationAsOrigin() {
    final pos = _currentPosition;
    if (pos == null) return;
    _controller.setOrigin(pos, label: 'Current location');
    _originSearchController.text = 'Current location';
    _clearSearch();
    _mapController.move(pos, 15.0);
  }

  /// Debounced OSM Nominatim search.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query.trim());
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isSearchingPlaces = true;
      _searchResults = [];
      _hasSearched = false;
    });
    try {
      // Bias results towards KL area.
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=6'
        '&countrycodes=my'
        '&viewbox=101.0,2.5,102.0,3.5'
        '&bounded=0',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'RapidTransitKL/1.0 (transit app)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _searchResults = data
            .map((e) => _PlaceResult.fromJson(e as Map<String, dynamic>))
            .toList();
        _isSearchingPlaces = false;
        _hasSearched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearchingPlaces = false;
        _searchResults = [];
        _hasSearched = true;
      });
    }
  }

  void _selectPlace(_PlaceResult place) {
    final pos = LatLng(place.lat, place.lon);
    // Shorten the display name for the label.
    final label = _shortenPlaceName(place.displayName);

    if (_isSearchingOrigin) {
      _controller.setOrigin(pos, label: label);
      _originSearchController.text = label;
      _originFocus.unfocus();
      setState(() => _isSearchingOrigin = false);
    } else if (_isSearchingDest) {
      _controller.setDestination(pos, label: label);
      _destSearchController.text = label;
      _destFocus.unfocus();
      setState(() => _isSearchingDest = false);
    }

    _clearSearch();
    _mapController.move(pos, 15.0);
  }

  String _shortenPlaceName(String fullName) {
    // Take the first 3 comma-separated parts for a shorter label.
    final parts = fullName.split(',').map((s) => s.trim()).toList();
    if (parts.length <= 3) return fullName;
    return parts.take(3).join(', ');
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchResults = [];
      _isSearchingPlaces = false;
      _hasSearched = false;
    });
  }

  String _formatLatLng(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    _clearSearch();
    _originFocus.unfocus();
    _destFocus.unfocus();

    // If in map-tap mode, set the tapped point as origin or destination.
    if (_mapTapMode == 'origin') {
      _controller.setOrigin(point, label: _formatLatLng(point));
      _originSearchController.text = _formatLatLng(point);
      setState(() {
        _mapTapMode = null;
        _isSearchingOrigin = false;
        _isSearchingDest = false;
      });
      return;
    }
    if (_mapTapMode == 'destination') {
      _controller.setDestination(point, label: _formatLatLng(point));
      _destSearchController.text = _formatLatLng(point);
      setState(() {
        _mapTapMode = null;
        _isSearchingOrigin = false;
        _isSearchingDest = false;
      });
      return;
    }

    setState(() {
      _isSearchingOrigin = false;
      _isSearchingDest = false;
      _mapTapMode = null;
    });
  }

  Future<void> _planJourney() async {
    _originFocus.unfocus();
    _destFocus.unfocus();
    _clearSearch();
    setState(() {
      _selectedOption = null;
      _originWalkPolyline = [];
      _destWalkPolyline = [];
      _transitPolyline = [];
      _searchPanelMinimized = false;
      _sheetMinimized = false;
      _sheetHeight = 0;
    });
    final providerId = _selectedProvider?.id ?? widget.providerId ?? 3;
    await _controller.planJourney(providerId: providerId);
    _fitMapToJourney();
  }

  void _fitMapToJourney() {
    final origin = _controller.origin;
    final dest = _controller.destination;
    if (origin == null || dest == null) return;
    try {
      final bounds = LatLngBounds.fromPoints([origin, dest]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (_) {}
  }

  /// Tapping a journey result: plot it on the map with walking + transit routes.
  Future<void> _onOptionTap(JourneyOption option) async {
    setState(() {
      _selectedOption = option;
      _originWalkPolyline = [];
      _destWalkPolyline = [];
      _transitPolyline = [];
      _isLoadingWalkRoutes = true;
      _isLoadingTransitRoute = true;
      _searchPanelMinimized = true;
      _sheetMinimized = false;
      _sheetHeight = 0;
    });

    final origin = _controller.origin;
    final boarding = LatLng(
      option.boardingStop.stopLat,
      option.boardingStop.stopLon,
    );
    final alighting = LatLng(
      option.targetStop.stopLat,
      option.targetStop.stopLon,
    );
    final dest = _controller.destination;
    final providerId = _selectedProvider?.id ?? widget.providerId ?? 3;

    final futures = <Future<List<LatLng>>>[];
    futures.add(origin != null
        ? _fetchWalkingRoute(origin, boarding)
        : Future.value(<LatLng>[]));
    futures.add(dest != null
        ? _fetchWalkingRoute(alighting, dest)
        : Future.value(<LatLng>[]));
    futures.add(_fetchTransitGeometry(
      providerId,
      option.routeId,
      option.directionId,
      boarding,
      alighting,
    ));

    final results = await Future.wait(futures);
    if (!mounted) return;

    setState(() {
      _originWalkPolyline = results[0];
      _destWalkPolyline = results[1];
      _transitPolyline = results[2];
      _isLoadingWalkRoutes = false;
      _isLoadingTransitRoute = false;
    });

    _fitMapToFullJourney(option);

    _controller.loadBoardingEta(
      providerId: providerId,
      routeId: option.routeId,
      stopId: option.boardingStop.stopId,
    );
  }

  Future<List<LatLng>> _fetchWalkingRoute(LatLng from, LatLng to) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(
            const Duration(seconds: 8),
          );
      if (response.statusCode != 200) return [from, to];

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [from, to];

      final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) return [from, to];

      return coords
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return [from, to];
    }
  }

  int _findNearestIndex(List<LatLng> points, LatLng target) {
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final dx = points[i].latitude - target.latitude;
      final dy = points[i].longitude - target.longitude;
      final d = dx * dx + dy * dy;
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  List<LatLng> _sliceGeometry(List<LatLng> shape, LatLng board, LatLng alight) {
    if (shape.isEmpty) return [];
    final boardIdx = _findNearestIndex(shape, board);
    final alightIdx = _findNearestIndex(shape, alight);
    final start = boardIdx < alightIdx ? boardIdx : alightIdx;
    final end = boardIdx < alightIdx ? alightIdx : boardIdx;
    return shape.sublist(start, end + 1);
  }

  Future<List<LatLng>> _fetchTransitGeometry(
    int providerId,
    String routeId,
    String directionId,
    LatLng boarding,
    LatLng alighting,
  ) async {
    try {
      final response =
          await _api.get('$providerId/$routeId/$directionId/shapes');
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final shapes = extractItems(decoded);
      final allPoints = <LatLng>[];
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
        allPoints.addAll(entries.map((e) => e.$2));
      }
      return _sliceGeometry(allPoints, boarding, alighting);
    } catch (_) {
      return [];
    }
  }

  void _fitMapToFullJourney(JourneyOption option) {
    final points = <LatLng>[
      if (_controller.origin != null) _controller.origin!,
      ..._originWalkPolyline,
      LatLng(option.boardingStop.stopLat, option.boardingStop.stopLon),
      ..._transitPolyline,
      LatLng(option.targetStop.stopLat, option.targetStop.stopLon),
      ..._destWalkPolyline,
      if (_controller.destination != null) _controller.destination!,
    ];
    if (points.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search panel (automatically compact after selecting a route)
        _buildSearchPanel(),
        // Map + overlays
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _currentPosition ?? const LatLng(3.0797, 101.7741),
                  initialZoom: 14.0,
                  onTap: _onMapTap,
                ),
                children: [
                  TileLayer(
                    urlTemplate: Theme.of(context).brightness == Brightness.dark
                        ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.example.gtfs_rapid_flutter',
                  ),
                  if (_controller.origin != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _controller.origin!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.trip_origin,
                            size: 32, color: AppColors.emeraldDark),
                      ),
                    ]),
                  if (_controller.destination != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _controller.destination!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on_rounded,
                            size: 36, color: AppColors.red),
                      ),
                    ]),
                  // Walk to boarding
                  if (_originWalkPolyline.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: _originWalkPolyline,
                        strokeWidth: 4,
                        color: AppColors.emeraldDark,
                        pattern: StrokePattern.dashed(segments: [8, 6]),
                      ),
                    ]),
                  // Walk from alighting
                  if (_destWalkPolyline.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: _destWalkPolyline,
                        strokeWidth: 4,
                        color: AppColors.red,
                        pattern: StrokePattern.dashed(segments: [8, 6]),
                      ),
                    ]),
                  // Transit route (GTFS shape)
                  if (_transitPolyline.length >= 2)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: _transitPolyline,
                        strokeWidth: 6,
                        color: ProviderTheme.of(widget.providerKey)
                            .primary
                            .withValues(alpha: 0.8),
                      ),
                    ]),
                  // Boarding marker
                  if (_selectedOption != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(
                          _selectedOption!.boardingStop.stopLat,
                          _selectedOption!.boardingStop.stopLon,
                        ),
                        width: 50,
                        height: 50,
                        alignment: Alignment.topCenter,
                        child: _JourneyMarker(
                          label: 'Board',
                          color: AppColors.emeraldDark,
                        ),
                      ),
                    ]),
                  // Alighting marker
                  if (_selectedOption != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(
                          _selectedOption!.targetStop.stopLat,
                          _selectedOption!.targetStop.stopLon,
                        ),
                        width: 50,
                        height: 50,
                        alignment: Alignment.topCenter,
                        child: _JourneyMarker(
                          label: 'Alight',
                          color: AppColors.red,
                        ),
                      ),
                    ]),
                ],
              ),
              // Map-tap mode hint
              if (_mapTapMode != null)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Material(
                    color: _mapTapMode == 'origin'
                        ? AppColors.emeraldDark
                        : AppColors.red,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded,
                              size: 18, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _mapTapMode == 'origin'
                                  ? 'Tap the map to set origin'
                                  : 'Tap the map to set destination',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _mapTapMode = null),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Walk route loading indicator
              if (_isLoadingWalkRoutes)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildChip(
                    icon: Icons.directions_walk,
                    text: 'Loading walk route...',
                    showSpinner: true,
                  ),
                ),
              // Transit route loading indicator
              if (_isLoadingTransitRoute && !_isLoadingWalkRoutes)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildChip(
                    icon: Icons.directions_bus,
                    text: 'Loading transit route...',
                    showSpinner: true,
                  ),
                ),
              // Search results overlay (when a field is focused)
              if ((_isSearchingOrigin || _isSearchingDest) &&
                  (_searchResults.isNotEmpty ||
                      _isSearchingPlaces ||
                      _hasSearched))
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildSearchResultsOverlay(),
                ),
              // Results bottom sheet (doesn't cover search panel)
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.isLoading) {
                    return Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildLoadingSheet(),
                    );
                  }
                  if (_controller.options.isNotEmpty) {
                    return Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildResultsSheet(),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String text,
    bool showSpinner = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  // --- Search panel ---

  Widget _buildSearchPanel() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_searchPanelMinimized && _selectedOption != null) {
      final origin = _controller.originLabel ?? 'Origin';
      final destination = _controller.destinationLabel ?? 'Destination';
      return Material(
        color: scheme.surface,
        child: InkWell(
          onTap: () => setState(() => _searchPanelMinimized = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(Icons.route_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Plan Journey',
                        style: textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$origin -> $destination',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Plan Journey', style: textTheme.titleMedium),
              const Spacer(),
              if (_selectedOption != null)
                IconButton(
                  onPressed: () => setState(() => _searchPanelMinimized = true),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                  tooltip: 'Collapse journey form',
                  visualDensity: VisualDensity.compact,
                ),
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (!_controller.canPlan) return const SizedBox.shrink();
                  return IconButton(
                    onPressed: _controller.swap,
                    icon: const Icon(Icons.swap_vert_rounded, size: 20),
                    tooltip: 'Swap origin and destination',
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                },
              ),
            ],
          ),
          // Provider selector
          if (_providers.length > 1) ...[
            const SizedBox(height: 10),
            ProviderSwitcher(
              providers: _providers,
              selectedProvider: _selectedProvider,
              onSelected: (p) => setState(() => _selectedProvider = p),
            ),
          ],
          const SizedBox(height: 10),
          // Origin field
          _buildSearchField(
            controller: _originSearchController,
            focusNode: _originFocus,
            icon: Icons.trip_origin,
            iconColor: AppColors.emeraldDark,
            hint: 'Search origin...',
            isActive: _isSearchingOrigin,
            onChanged: _onSearchChanged,
            onUseCurrentLocation: _useCurrentLocationAsOrigin,
          ),
          const SizedBox(height: 8),
          // Destination field
          _buildSearchField(
            controller: _destSearchController,
            focusNode: _destFocus,
            icon: Icons.location_on_rounded,
            iconColor: AppColors.red,
            hint: 'Search destination...',
            isActive: _isSearchingDest,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 8),
          // Map-tap mode buttons
          Row(
            children: [
              Expanded(
                child: _buildMapTapButton(
                  label: 'Tap map: Origin',
                  icon: Icons.touch_app_rounded,
                  mode: 'origin',
                  color: AppColors.emeraldDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMapTapButton(
                  label: 'Tap map: Dest',
                  icon: Icons.touch_app_rounded,
                  mode: 'destination',
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Plan button
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _controller.canPlan ? _planJourney : null,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Find routes'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.errorMessage == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _controller.errorMessage!,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required Color iconColor,
    required String hint,
    required bool isActive,
    required ValueChanged<String> onChanged,
    VoidCallback? onUseCurrentLocation,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? scheme.primary : scheme.outlineVariant,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                isDense: true,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (onUseCurrentLocation != null)
            IconButton(
              onPressed: onUseCurrentLocation,
              icon: Icon(Icons.my_location_rounded,
                  size: 18, color: scheme.primary),
              tooltip: 'Use current location',
              visualDensity: VisualDensity.compact,
            ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                controller.clear();
                onChanged('');
                if (isActive) {
                  setState(() {
                    if (isActive && icon == Icons.trip_origin) {
                      _controller.setOrigin(LatLng(0, 0), label: null);
                    } else {
                      _controller.setDestination(LatLng(0, 0), label: null);
                    }
                  });
                }
              },
              icon: Icon(Icons.close_rounded,
                  size: 16, color: scheme.onSurfaceVariant),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildMapTapButton({
    required String label,
    required IconData icon,
    required String mode,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isActive = _mapTapMode == mode;
    return Material(
      color: isActive ? color : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          _originFocus.unfocus();
          _destFocus.unfocus();
          _clearSearch();
          setState(() {
            _mapTapMode = isActive ? null : mode;
            _isSearchingOrigin = false;
            _isSearchingDest = false;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isActive ? Colors.white : scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Search results overlay ---

  Widget _buildSearchResultsOverlay() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16)),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: _isSearchingPlaces
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Text('Searching places...', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              )
            : _searchResults.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text('No places found',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: scheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final place = _searchResults[index];
                      return InkWell(
                        onTap: () => _selectPlace(place),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 18, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  place.displayName,
                                  style: textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  // --- Loading sheet ---

  Widget _buildLoadingSheet() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
          ],
        ),
      ),
    );
  }

  // --- Results sheet (draggable, doesn't cover search panel) ---

  Widget _buildResultsSheet() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final options = _controller.options;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.45;
    final minHeight = 60.0; // Just the handle + header

    // Once a route is selected, collapse the route picker and retain only the
    // selected route card over the map.
    final selectedOption = _selectedOption;
    if (selectedOption != null) {
      return Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _buildJourneyCard(selectedOption),
        ),
      );
    }

    // When minimized, show only the header bar.
    if (_sheetMinimized) {
      return GestureDetector(
        onTap: () => setState(() => _sheetMinimized = false),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 16,
                  offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.directions_rounded,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${options.length} route${options.length == 1 ? '' : 's'} — tap to expand',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration:
          _isSheetDragging ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: _sheetHeight > 0
          ? _sheetHeight.clamp(minHeight, maxHeight)
          : maxHeight,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // Drag handle (draggable down to minimize)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (details) {
              setState(() {
                _isSheetDragging = true;
                _dragStartY = details.globalPosition.dy;
                _dragStartHeight = _sheetHeight > 0 ? _sheetHeight : maxHeight;
              });
            },
            onVerticalDragUpdate: (details) {
              final deltaY = details.globalPosition.dy - _dragStartY;
              final newHeight = _dragStartHeight - deltaY;
              if (newHeight < minHeight) {
                // Dragged below minimum — minimize.
                setState(() {
                  _sheetMinimized = true;
                  _isSheetDragging = false;
                  _sheetHeight = 0;
                });
              } else {
                setState(() => _sheetHeight = newHeight);
              }
            },
            onVerticalDragEnd: (_) {
              setState(() {
                _isSheetDragging = false;
                if (!_sheetMinimized) {
                  _sheetHeight = 0; // Reset to auto (maxHeight)
                }
              });
            },
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Icon(Icons.directions_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${options.length} route${options.length == 1 ? '' : 's'} found',
                  style: textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _sheetMinimized = true),
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: scheme.onSurfaceVariant),
                  tooltip: 'Minimize',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Scrollable list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: options.length,
              itemBuilder: (context, index) {
                return _buildJourneyCard(options[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(JourneyOption option) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final theme = ProviderTheme.of(widget.providerKey);
    final isSelected = _selectedOption == option;
    final departures = isSelected ? _controller.boardingDepartures : const [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.2)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onOptionTap(option),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route badge and metadata
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      option.routeShortName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.onPrimary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(option.routeTypeLabel,
                        style: textTheme.labelMedium),
                  ),
                  if (option.transferCount > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '${option.transferCount} transfer${option.transferCount > 1 ? 's' : ''}',
                      style:
                          textTheme.labelMedium?.copyWith(color: scheme.error),
                    ),
                  ],
                ],
              ),
              // Transit details and ETA
              if (isSelected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.route_rounded, size: 18, color: theme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${option.boardingStop.stopName} → ${option.targetStop.stopName}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatDistance(option.boardingStop.distanceM)} walk to stop',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // ETA display
                      if (_controller.isLoadingEta)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      else if (departures.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${departures.first.countdownMinutes()}',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.primary,
                                height: 1,
                              ),
                            ),
                            Text(
                              'min',
                              style: textTheme.labelSmall?.copyWith(
                                color: theme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Next departures row
                if (departures.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Next: ',
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      ...departures.skip(1).map((d) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '${d.countdownMinutes()} min',
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          )),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 12),
              // Stop rows
              _buildStopRow(
                icon: Icons.login_rounded,
                label: 'Board at',
                stopName: option.boardingStop.stopName,
                stopCode: option.boardingStop.stopCode,
                distance: option.boardingStop.distanceM,
                color: AppColors.emeraldDark,
              ),
              const SizedBox(height: 8),
              _buildStopRow(
                icon: Icons.logout_rounded,
                label: 'Get off at',
                stopName: option.targetStop.stopName,
                stopCode: option.targetStop.stopCode,
                distance: option.targetStop.distanceM,
                color: AppColors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopRow({
    required IconData icon,
    required String label,
    required String stopName,
    required String stopCode,
    required double distance,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              Text(
                stopName,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (stopCode.isNotEmpty)
              Text(stopCode,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  )),
            Text(
              formatDistance(distance),
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Map marker for boarding/alighting with a label badge.
class _JourneyMarker extends StatelessWidget {
  final String label;
  final Color color;

  const _JourneyMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
          ),
        ),
        Icon(Icons.circle, size: 12, color: color),
      ],
    );
  }
}
