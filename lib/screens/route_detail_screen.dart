import 'package:flutter/material.dart';
import '../controllers/route_controller.dart';
import '../models/route_stop.dart';
import '../models/transit_route.dart';
import '../theme/app_theme.dart';
import '../widgets/stops/route_color_badge.dart';
import 'stop_detail_screen.dart';

/// Detail view for a route: identity header (colored badge + long name) and a
/// stop timeline. Opened from [RoutesScreen]; receives the API route object.
class RouteDetailScreen extends StatefulWidget {
  final TransitRoute route;
  final int? providerId;
  final String? providerKey;

  const RouteDetailScreen({
    super.key,
    required this.route,
    this.providerId,
    this.providerKey,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final RouteController _routeController = RouteController();
  String? _expandedStopId;

  @override
  void initState() {
    super.initState();
    final providerId = widget.providerId;
    if (providerId != null) {
      _routeController.loadRouteStops(
        providerId: providerId,
        routeId: widget.route.routeId,
      );
    }
  }

  @override
  void dispose() {
    _routeController.dispose();
    super.dispose();
  }

  /// Stops for the selected direction, ordered by stop sequence.
  List<RouteStop> get _displayStops => _routeController.selectedDirectionStops;

  void _onDirectionToggle() {
    final dirs = _routeController.directions;
    if (dirs.length < 2) return;
    final current = _routeController.selectedDirection ?? dirs.first;
    final next = dirs.firstWhere((d) => d != current, orElse: () => current);
    _routeController.selectDirection(next);
  }

  void _toggleStop(String stopId) {
    final wasExpanded = _expandedStopId == stopId;
    setState(() {
      _expandedStopId = wasExpanded ? null : stopId;
    });
    final providerId = widget.providerId;
    if (providerId != null && !wasExpanded) {
      _routeController.loadEta(
        providerId: providerId,
        routeId: widget.route.routeId,
        stopId: stopId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              size: 22, color: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
          child: Row(
            children: [
              RouteColorBadge(
                shortName: widget.route.routeShortName,
                theme: ProviderTheme.of(widget.providerKey),
                fontSize: 16,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.route.routeLongName,
                    maxLines: 1,
                    style: textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _routeController,
        builder: (context, _) {
          // No provider context (e.g. a route without a provider id).
          if (widget.providerId == null || _displayStops.isEmpty) {
            return _buildEmptyStops();
          }
          if (_routeController.isLoadingStops &&
              _routeController.stops.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            );
          }
          if (_routeController.stopsError != null &&
              _routeController.stops.isEmpty) {
            return _buildErrorState();
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDirectionRow(),
                const SizedBox(height: 16),
                ...List.generate(_displayStops.length, (index) {
                  final stop = _displayStops[index];
                  final isFirst = index == 0;
                  final isLast = index == _displayStops.length - 1;
                  final isExpanded = _expandedStopId == stop.stopId;

                  return _buildTimelineItem(
                    stop: stop,
                    isFirst: isFirst,
                    isLast: isLast,
                    isExpanded: isExpanded,
                    onTap: () => _toggleStop(stop.stopId),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDirectionRow() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_routeController.isBidirectional) {
      return Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: _onDirectionToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz_rounded,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('Change Direction', style: textTheme.labelMedium),
              ],
            ),
          ),
        ),
      );
    }
    return Text('One direction', style: textTheme.labelMedium);
  }

  Widget _buildErrorState() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 28, color: scheme.error),
            const SizedBox(height: 8),
            Text(
              _routeController.stopsError ?? 'Could not load route stops.',
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final providerId = widget.providerId;
                if (providerId != null) {
                  _routeController.loadRouteStops(
                    providerId: providerId,
                    routeId: widget.route.routeId,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStops() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_rounded, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Stops for this route are not available yet.',
            textAlign: TextAlign.center,
            style:
                textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required RouteStop stop,
    required bool isFirst,
    required bool isLast,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        // Timeline connector: painted line + marker, fills the row height
        // (avoids an intrinsic measurement pass per stop so long routes
        // scroll smoothly).
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 32,
          child: CustomPaint(
            painter: _TimelineConnectorPainter(
              lineColor: scheme.outlineVariant,
              dotColor: isFirst || isLast ? scheme.primary : scheme.surface,
              dotBorderColor:
                  isFirst || isLast ? scheme.primary : scheme.outlineVariant,
              innerColor:
                  isFirst || isLast ? scheme.onPrimary : scheme.outlineVariant,
              isFirst: isFirst,
              isLast: isLast,
              dotSize: isFirst || isLast ? 22 : 14,
            ),
          ),
        ),
        // Stop card (non-positioned → defines the row height).
        Padding(
          padding: EdgeInsets.fromLTRB(40, 0, 0, isLast ? 0 : 8),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.stopName,
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const Divider(height: 20),
                    Text(
                      'UPCOMING ARRIVALS',
                      style:
                          textTheme.labelMedium?.copyWith(letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    _buildArrivals(stop),
                    const SizedBox(height: 12),
                    _buildViewLiveMapButton(stop),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Upcoming departures for the expanded stop (selected direction).
  Widget _buildArrivals(RouteStop stop) {
    if (_routeController.isLoadingEta) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }
    final departures = _routeController.selectedDirectionDepartures
        .where((d) => d.countdownMinutes() <= 60)
        .toList();
    if (departures.isEmpty) {
      return Text(
        _routeController.etaError ?? 'No upcoming departures.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      children: [
        for (final departure in departures.take(3))
          _buildArrivalRow(
            vehicle: departure.liveVehicleId ??
                departure.scheduledVehicleId ??
                departure.tripId,
            eta: _formatCountdown(departure.countdownMinutes()),
            isLive: departure.firstValidVehicle != null,
          ),
      ],
    );
  }

  /// Opens the full stop detail (live map + live countdown) for [stop].
  void _openStopDetail(RouteStop stop) {
    final providerId = widget.providerId;
    if (providerId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopDetailScreen(
          stopName: stop.stopName,
          stopLine: widget.route.routeShortName,
          latitude: stop.stopLat,
          longitude: stop.stopLon,
          stopId: stop.stopId,
          providerId: providerId,
          providerKey: widget.providerKey,
          route: widget.route,
        ),
      ),
    );
  }

  /// Full-width "View live map" action colored by the provider theme.
  Widget _buildViewLiveMapButton(RouteStop stop) {
    final theme = ProviderTheme.of(widget.providerKey);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _openStopDetail(stop),
        style: FilledButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: theme.onPrimary,
        ),
        icon: const Icon(Icons.map_rounded),
        label: const Text('View live map'),
      ),
    );
  }

  String _formatCountdown(int minutes) {
    if (minutes <= 0) return 'Due';
    return '$minutes min';
  }

  Widget _buildArrivalRow({
    required String vehicle,
    required String eta,
    required bool isLive,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isLive)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.emerald,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vehicle,
                    style: textTheme.labelMedium
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 12, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Scheduled service',
                    style: textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            Text(
              eta,
              style:
                  textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the timeline connector (vertical line + marker dot) for a stop row.
///
/// Replaces the per-row `IntrinsicHeight` layout with a single paint pass so
/// long routes avoid an extra measurement round per stop. The [CustomPaint]
/// fills the row height via [Positioned], and the marker is centered on the
/// row, matching the previous layout.
class _TimelineConnectorPainter extends CustomPainter {
  _TimelineConnectorPainter({
    required this.lineColor,
    required this.dotColor,
    required this.dotBorderColor,
    required this.innerColor,
    required this.isFirst,
    required this.isLast,
    required this.dotSize,
  });

  final Color lineColor;
  final Color dotColor;
  final Color dotBorderColor;
  final Color innerColor;
  final bool isFirst;
  final bool isLast;
  final double dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = dotSize / 2;

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2;

    // Line from the previous stop down to the marker.
    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, centerY - radius),
        line,
      );
    }
    // Line from the marker down to the next stop.
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, centerY + radius),
        Offset(centerX, size.height),
        line,
      );
    }

    // Marker dot: fill + border.
    canvas.drawCircle(
        Offset(centerX, centerY), radius, Paint()..color = dotColor);
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      Paint()
        ..color = dotBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Inner dot.
    canvas.drawCircle(Offset(centerX, centerY), 3, Paint()..color = innerColor);
  }

  @override
  bool shouldRepaint(covariant _TimelineConnectorPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.dotBorderColor != dotBorderColor ||
        oldDelegate.innerColor != innerColor ||
        oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast ||
        oldDelegate.dotSize != dotSize;
  }
}
