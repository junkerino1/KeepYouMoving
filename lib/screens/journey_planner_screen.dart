import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../controllers/journey_controller.dart';
import '../models/journey_option.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sheets/sheet_snap.dart';

/// Journey planner screen: set origin/destination, plan routes, view results.
///
/// Users can set origin (current location or map tap) and destination (map
/// tap), then see route options with boarding/alighting stops and walking
/// distances. Tapping a result plots the full journey on the map.
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
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _isSelectingOrigin = false;
  bool _isSelectingDestination = false;
  double _sheetHeight = kSheetDefaultHeight;
  bool _isDragging = false;
  double _dragStartY = 0;
  double _dragStartHeight = 0;

  // Journey plot state
  JourneyOption? _selectedOption;
  List<LatLng> _originWalkPolyline = [];
  List<LatLng> _destWalkPolyline = [];
  bool _isLoadingWalkRoutes = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // Silently ignore; user can set origin manually.
    }
  }

  void _useCurrentLocationAsOrigin() {
    final pos = _currentPosition;
    if (pos == null) return;
    _controller.setOrigin(pos, label: 'Current location');
    _mapController.move(pos, 15.0);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_isSelectingOrigin) {
      _controller.setOrigin(point, label: _formatLatLng(point));
      setState(() => _isSelectingOrigin = false);
    } else if (_isSelectingDestination) {
      _controller.setDestination(point, label: _formatLatLng(point));
      setState(() => _isSelectingDestination = false);
    }
  }

  String _formatLatLng(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  Future<void> _planJourney() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedOption = null;
      _originWalkPolyline = [];
      _destWalkPolyline = [];
    });
    await _controller.planJourney(providerId: widget.providerId ?? 3);
    _fitMapToJourney();
    // Expand the sheet to show results.
    if (_controller.options.isNotEmpty) {
      setState(() => _sheetHeight = kSheetExpandedHeight);
    }
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
    } catch (_) {
      // Map may not be laid out yet.
    }
  }

  /// Tapping a journey result: plot it on the map with walking routes.
  Future<void> _onOptionTap(JourneyOption option) async {
    setState(() {
      _selectedOption = option;
      _originWalkPolyline = [];
      _destWalkPolyline = [];
      _isLoadingWalkRoutes = true;
    });

    // Fetch walking routes in parallel.
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

    final futures = <Future<List<LatLng>>>[];
    if (origin != null) {
      futures.add(_fetchWalkingRoute(origin, boarding));
    } else {
      futures.add(Future.value([]));
    }
    if (dest != null) {
      futures.add(_fetchWalkingRoute(alighting, dest));
    } else {
      futures.add(Future.value([]));
    }

    final results = await Future.wait(futures);
    if (!mounted) return;

    setState(() {
      _originWalkPolyline = results[0];
      _destWalkPolyline = results[1];
      _isLoadingWalkRoutes = false;
    });

    // Fit the map to show the full journey.
    _fitMapToFullJourney(option);
  }

  /// Fetches a walking route polyline from OSRM.
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
      // Fallback: straight line.
      return [from, to];
    }
  }

  void _fitMapToFullJourney(JourneyOption option) {
    final points = <LatLng>[
      if (_controller.origin != null) _controller.origin!,
      ..._originWalkPolyline,
      LatLng(option.boardingStop.stopLat, option.boardingStop.stopLon),
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
        _buildSearchPanel(),
        Expanded(
          child: Stack(
            children: [
              // Map
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
                    urlTemplate:
                        Theme.of(context).brightness == Brightness.dark
                            ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                            : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    userAgentPackageName: 'com.example.gtfs_rapid_flutter',
                  ),
                  // Origin marker
                  if (_controller.origin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _controller.origin!,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.trip_origin,
                              size: 32, color: AppColors.emeraldDark),
                        ),
                      ],
                    ),
                  // Destination marker
                  if (_controller.destination != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _controller.destination!,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on_rounded,
                              size: 36, color: AppColors.red),
                        ),
                      ],
                    ),
                  // Walking route: origin → boarding
                  if (_originWalkPolyline.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _originWalkPolyline,
                          strokeWidth: 4,
                          color: AppColors.emeraldDark,
                          pattern: StrokePattern.dashed(segments: [8, 6]),
                        ),
                      ],
                    ),
                  // Walking route: alighting → destination
                  if (_destWalkPolyline.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _destWalkPolyline,
                          strokeWidth: 4,
                          color: AppColors.red,
                          pattern: StrokePattern.dashed(segments: [8, 6]),
                        ),
                      ],
                    ),
                  // Boarding stop marker
                  if (_selectedOption != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _selectedOption!.boardingStop.stopLat,
                            _selectedOption!.boardingStop.stopLon,
                          ),
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.emeraldDark,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Board',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const Icon(Icons.circle,
                                  size: 14, color: AppColors.emeraldDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  // Alighting stop marker
                  if (_selectedOption != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _selectedOption!.targetStop.stopLat,
                            _selectedOption!.targetStop.stopLon,
                          ),
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Alight',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const Icon(Icons.circle,
                                  size: 14, color: AppColors.red),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // Selection mode hint
              if (_isSelectingOrigin || _isSelectingDestination)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _buildSelectionHint(),
                ),
              // Loading indicator for walk routes
              if (_isLoadingWalkRoutes)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading walking routes...',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              // Results bottom sheet (positioned, not DraggableScrollableSheet)
              if (_controller.options.isNotEmpty || _controller.isLoading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildResultsSheet(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionHint() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              _isSelectingOrigin
                  ? Icons.trip_origin
                  : Icons.location_on_rounded,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isSelectingOrigin
                    ? 'Tap the map to set origin'
                    : 'Tap the map to set destination',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isSelectingOrigin = false;
                _isSelectingDestination = false;
              }),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan Journey', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildLocationField(
                icon: Icons.trip_origin,
                iconColor: AppColors.emeraldDark,
                label: 'From',
                value: _controller.originLabel,
                placeholder: 'Set origin',
                onTap: () => setState(() => _isSelectingOrigin = true),
                onUseCurrentLocation: _useCurrentLocationAsOrigin,
              ),
              const SizedBox(height: 8),
              _buildLocationField(
                icon: Icons.location_on_rounded,
                iconColor: AppColors.red,
                label: 'To',
                value: _controller.destinationLabel,
                placeholder: 'Set destination',
                onTap: () => setState(() => _isSelectingDestination = true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _controller.canPlan ? _controller.swap : null,
                    icon: const Icon(Icons.swap_vert_rounded),
                    tooltip: 'Swap origin and destination',
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _controller.canPlan ? _planJourney : null,
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text('Find routes'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_controller.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _controller.errorMessage!,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    VoidCallback? onUseCurrentLocation,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 1),
                  Text(
                    value ?? placeholder,
                    style: value != null
                        ? textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)
                        : textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (label == 'From' && onUseCurrentLocation != null)
              IconButton(
                onPressed: onUseCurrentLocation,
                icon: Icon(Icons.my_location_rounded,
                    size: 18, color: scheme.primary),
                tooltip: 'Use current location',
                visualDensity: VisualDensity.compact,
              ),
            Icon(Icons.edit_outlined,
                size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Draggable results sheet positioned at the bottom.
  Widget _buildResultsSheet() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: const Cubic(0.16, 1, 0.3, 1),
      height: _sheetHeight,
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
      child: Column(
        children: [
          // Drag handle
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (details) {
              setState(() {
                _isDragging = true;
                _dragStartY = details.globalPosition.dy;
                _dragStartHeight = _sheetHeight;
              });
            },
            onVerticalDragUpdate: (details) {
              setState(() {
                final deltaY = details.globalPosition.dy - _dragStartY;
                _sheetHeight = (_dragStartHeight - deltaY)
                    .clamp(kSheetMinHeight, kSheetExpandedHeight);
              });
            },
            onVerticalDragEnd: (_) {
              setState(() {
                _isDragging = false;
                _sheetHeight = kSheetSnapHeights.reduce((a, b) =>
                    (a - _sheetHeight).abs() < (b - _sheetHeight).abs()
                        ? a
                        : b);
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
                Icon(Icons.directions_rounded,
                    size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  _controller.isLoading
                      ? 'Searching...'
                      : '${_controller.options.length} route${_controller.options.length == 1 ? '' : 's'} found',
                  style: textTheme.titleSmall,
                ),
              ],
            ),
          ),
          // Results list
          Expanded(
            child: _controller.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: scheme.primary))
                : _controller.options.isEmpty
                    ? Center(
                        child: Text(
                          _controller.errorMessage ?? 'No routes found',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _controller.options.length,
                        itemBuilder: (context, index) {
                          final option = _controller.options[index];
                          return _buildJourneyCard(option);
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.2)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onOptionTap(option),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route badge + type
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      option.routeShortName,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(option.routeTypeLabel,
                        style: textTheme.labelSmall),
                  ),
                  if (option.transferCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${option.transferCount} transfer${option.transferCount > 1 ? 's' : ''}',
                      style:
                          textTheme.labelSmall?.copyWith(color: scheme.error),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Boarding stop
              _buildStopRow(
                icon: Icons.login_rounded,
                label: 'Board at',
                stopName: option.boardingStop.stopName,
                stopCode: option.boardingStop.stopCode,
                distance: option.boardingStop.distanceM,
                color: AppColors.emeraldDark,
              ),
              const SizedBox(height: 8),
              // Alighting stop
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
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              Text(
                stopName,
                style:
                    textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
              Text(
                stopCode,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
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
