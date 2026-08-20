import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../controllers/journey_controller.dart';
import '../models/eta_departure.dart';
import '../models/journey_option.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/api_envelope.dart';
import '../utils/format.dart';
import '../widgets/live_bus/eta_item.dart';
import '../widgets/sheets/sheet_snap.dart';
import '../widgets/stops/route_color_badge.dart';

/// Detail view for a planned journey: the map on top with the walking + transit
/// routes, and a draggable bottom sheet showing the journey info and live ETA.
class JourneyDetailScreen extends StatefulWidget {
  final JourneyOption option;
  final LatLng? origin;
  final LatLng? destination;
  final String? originLabel;
  final String? destinationLabel;
  final int providerId;
  final String? providerKey;

  const JourneyDetailScreen({
    super.key,
    required this.option,
    this.origin,
    this.destination,
    this.originLabel,
    this.destinationLabel,
    required this.providerId,
    this.providerKey,
  });

  @override
  State<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends State<JourneyDetailScreen> {
  final MapController _mapController = MapController();
  final JourneyController _controller = JourneyController();
  final ApiService _api = ApiService();

  List<LatLng> _originWalkPolyline = [];
  List<LatLng> _destWalkPolyline = [];
  List<LatLng> _transitPolyline = [];
  bool _isLoadingWalkRoutes = false;
  bool _isLoadingTransitRoute = false;

  // Bottom sheet drag state.
  double _sheetHeight = 0; // 0 = auto (snap to default)
  bool _isSheetDragging = false;
  double _dragStartY = 0;
  double _dragStartHeight = 0;
  bool _sheetMinimized = false;

  ProviderTheme get _providerTheme => ProviderTheme.of(widget.providerKey);

  LatLng get _boarding => LatLng(
        widget.option.boardingStop.stopLat,
        widget.option.boardingStop.stopLon,
      );

  LatLng get _alighting => LatLng(
        widget.option.targetStop.stopLat,
        widget.option.targetStop.stopLon,
      );

  @override
  void initState() {
    super.initState();
    _loadJourney();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fetches the walking legs + transit geometry and the boarding ETA, then
  /// fits the map to the whole journey.
  Future<void> _loadJourney() async {
    setState(() {
      _isLoadingWalkRoutes = true;
      _isLoadingTransitRoute = true;
    });
    final origin = widget.origin;
    final dest = widget.destination;

    final futures = <Future<List<LatLng>>>[
      origin != null
          ? _fetchWalkingRoute(origin, _boarding)
          : Future.value(<LatLng>[]),
      dest != null
          ? _fetchWalkingRoute(_alighting, dest)
          : Future.value(<LatLng>[]),
      _fetchTransitGeometry(
        widget.providerId,
        widget.option.routeId,
        widget.option.directionId,
        _boarding,
        _alighting,
      ),
    ];

    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _originWalkPolyline = results[0];
      _destWalkPolyline = results[1];
      _transitPolyline = results[2];
      _isLoadingWalkRoutes = false;
      _isLoadingTransitRoute = false;
    });

    _fitMapToJourney();

    _controller.loadBoardingEta(
      providerId: widget.providerId,
      routeId: widget.option.routeId,
      stopId: widget.option.boardingStop.stopId,
    );
  }

  Future<List<LatLng>> _fetchWalkingRoute(LatLng from, LatLng to) async {
    try {
      // External routing service; do not send first-party auth headers.
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

  /// Fits the camera to the whole journey (origin, walks, transit, destination).
  void _fitMapToJourney() {
    final points = <LatLng>[
      if (widget.origin != null) widget.origin!,
      ..._originWalkPolyline,
      _boarding,
      ..._transitPolyline,
      _alighting,
      ..._destWalkPolyline,
      if (widget.destination != null) widget.destination!,
    ];
    if (points.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } catch (_) {
      _mapController.move(_boarding, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _buildMap(),
            // Floating header.
            Positioned(top: 12, left: 12, right: 12, child: _buildHeader()),
            // Loading indicator while walk/transit legs are fetched.
            if (_isLoadingWalkRoutes || _isLoadingTransitRoute)
              Positioned(top: 76, left: 12, child: _buildLoadingChip()),
            // Draggable bottom sheet with journey info.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomSheet(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _boarding,
        initialZoom: 14.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: isDark
              ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
              : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.example.gtfs_rapid_flutter',
        ),
        if (widget.origin != null)
          MarkerLayer(markers: [
            Marker(
              point: widget.origin!,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.trip_origin,
                  size: 32, color: AppColors.emeraldDark),
            ),
          ]),
        if (widget.destination != null)
          MarkerLayer(markers: [
            Marker(
              point: widget.destination!,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_on_rounded,
                  size: 36, color: AppColors.red),
            ),
          ]),
        // Walk to boarding.
        if (_originWalkPolyline.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
              points: _originWalkPolyline,
              strokeWidth: 4,
              color: AppColors.emeraldDark,
              pattern: StrokePattern.dashed(segments: const [8, 6]),
            ),
          ]),
        // Walk from alighting.
        if (_destWalkPolyline.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
              points: _destWalkPolyline,
              strokeWidth: 4,
              color: AppColors.red,
              pattern: StrokePattern.dashed(segments: const [8, 6]),
            ),
          ]),
        // Transit route (GTFS shape).
        if (_transitPolyline.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: _transitPolyline,
              strokeWidth: 6,
              color: _providerTheme.primary.withValues(alpha: 0.8),
            ),
          ]),
        // Boarding marker.
        MarkerLayer(markers: [
          Marker(
            point: _boarding,
            width: 50,
            height: 50,
            alignment: Alignment.topCenter,
            child: const _JourneyMarker(
              label: 'Board',
              color: AppColors.emeraldDark,
            ),
          ),
        ]),
        // Alighting marker.
        MarkerLayer(markers: [
          Marker(
            point: _alighting,
            width: 50,
            height: 50,
            alignment: Alignment.topCenter,
            child: const _JourneyMarker(
              label: 'Alight',
              color: AppColors.red,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final origin =
        widget.originLabel ?? (widget.origin != null ? 'Origin' : '');
    final dest = widget.destinationLabel ??
        (widget.destination != null ? 'Destination' : '');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.chevron_left_rounded,
                size: 24, color: scheme.onSurface),
          ),
          const SizedBox(width: 4),
          // Leading column: origin dot, grip handle, destination pin — mirrors
          // the journey planner form's left column.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trip_origin, size: 18, color: AppColors.emeraldDark),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _buildGripDots(),
              ),
              Icon(Icons.location_on_rounded, size: 18, color: AppColors.red),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFromToRow(label: 'From', value: origin),
                const SizedBox(height: 4),
                _buildFromToRow(label: 'To', value: dest),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Three small dots, mirroring the journey planner's grip handle.
  Widget _buildGripDots() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// "FROM source" / "TO destination" block: small uppercase label above the
  /// stop name below, mirroring [RouteSelector]'s field structure.
  Widget _buildFromToRow({required String label, required String value}) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '…' : value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLoadingChip() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: scheme.primary),
          ),
          const SizedBox(width: 8),
          Text('Loading route...', style: textTheme.labelMedium),
        ],
      ),
    );
  }

  // --- Draggable bottom sheet ---

  Widget _buildBottomSheet() {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;
    final height = _sheetMinimized
        ? 100.0
        : (_sheetHeight > 0
            ? _sheetHeight.clamp(kSheetMinHeight, maxHeight)
            : kSheetDefaultHeight.clamp(kSheetMinHeight, maxHeight));

    return AnimatedContainer(
      duration:
          _isSheetDragging ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0F172A), blurRadius: 32, offset: Offset(0, -8)),
        ],
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _sheetMinimized
                  ? _buildMinimizedBar()
                  : ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => _buildJourneyInfo(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        setState(() {
          _isSheetDragging = true;
          _dragStartY = details.globalPosition.dy;
          _dragStartHeight = _sheetHeight > 0
              ? _sheetHeight
              : kSheetDefaultHeight.clamp(
                  kSheetMinHeight, MediaQuery.sizeOf(context).height * 0.55);
        });
      },
      onVerticalDragUpdate: (details) {
        final deltaY = details.globalPosition.dy - _dragStartY;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.55;
        if (_dragStartHeight - deltaY < kSheetMinHeight) {
          // Dragged below the minimum — minimize.
          setState(() {
            _sheetMinimized = true;
            _isSheetDragging = false;
            _sheetHeight = 0;
          });
        } else {
          setState(() {
            _sheetMinimized = false;
            _sheetHeight =
                (_dragStartHeight - deltaY).clamp(kSheetMinHeight, maxHeight);
          });
        }
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _isSheetDragging = false;
          if (!_sheetMinimized) {
            // Snap to the nearest standard height that fits the screen.
            final maxHeight = MediaQuery.sizeOf(context).height * 0.55;
            final current =
                _sheetHeight > 0 ? _sheetHeight : kSheetDefaultHeight;
            final snapOptions =
                kSheetSnapHeights.where((h) => h <= maxHeight).toList();
            final snap = snapOptions.isEmpty
                ? maxHeight
                : snapOptions.reduce((a, b) =>
                    (a - current).abs() < (b - current).abs() ? a : b);
            _sheetHeight = snap;
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
    );
  }

  Widget _buildMinimizedBar() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => setState(() => _sheetMinimized = false),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(Icons.directions_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.option.routeShortName} — tap to expand',
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
    );
  }

  Widget _buildJourneyInfo() {
    final option = widget.option;
    final departures = _controller.boardingDepartures;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Route identity + metadata.
        Row(
          children: [
            RouteColorBadge(
              shortName: option.routeShortName,
              theme: _providerTheme,
              fontSize: 14,
              iconSize: 14,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                option.routeShortName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (option.transferCount > 0) ...[
              const SizedBox(width: 10),
              Text(
                '${option.transferCount} '
                'transfer${option.transferCount > 1 ? 's' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Board / alight stops.
        _buildStopRow(
          icon: Icons.login_rounded,
          label: 'Board at',
          stopName: option.boardingStop.stopName,
          stopCode: option.boardingStop.stopCode,
          distance: option.boardingStop.distanceM,
          color: AppColors.emeraldDark,
        ),
        const SizedBox(height: 12),
        _buildStopRow(
          icon: Icons.logout_rounded,
          label: 'Get off at',
          stopName: option.targetStop.stopName,
          stopCode: option.targetStop.stopCode,
          distance: option.targetStop.distanceM,
          color: AppColors.red,
        ),
        const SizedBox(height: 20),
        _buildEtaSection(departures),
      ],
    );
  }

  /// Bus countdown section, mirroring the stop-detail ETA container: a
  /// "Bus Countdown" header with a Live/Scheduled badge and a list of
  /// [EtaItem] countdown cards.
  Widget _buildEtaSection(List<EtaDeparture> departures) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final theme = _providerTheme;
    final withinHour =
        departures.where((d) => d.countdownMinutes() <= 60).toList();
    final displayed = withinHour.take(4).toList();
    final hasLive = displayed.any((d) => d.firstValidVehicle != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Bus Countdown', style: textTheme.titleSmall),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasLive ? theme.light : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasLive ? 'Live' : 'Scheduled',
                style: textTheme.labelMedium?.copyWith(
                  color: hasLive ? theme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_controller.isLoadingEta)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            ),
          )
        else if (displayed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('No upcoming buses', style: textTheme.bodySmall),
            ),
          )
        else
          ...displayed.map((departure) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EtaItem(
                  departure: departure,
                  theme: theme,
                  stopPosition: _boarding,
                ),
              )),
      ],
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
