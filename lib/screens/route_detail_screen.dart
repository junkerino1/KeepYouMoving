import 'package:flutter/material.dart';
import '../controllers/route_controller.dart';
import '../models/route_stop.dart';
import '../models/transit_route.dart';
import '../theme/app_theme.dart';
import '../widgets/stops/provider_switcher.dart' show providerShortLabelForKey;
import '../widgets/stops/route_color_badge.dart';

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
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              size: 20, color: AppColors.navyTextTertiary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            RouteColorBadge(route: widget.route),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.route.routeLongName,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navyTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.providerKey != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navyVeryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  providerShortLabelForKey(widget.providerKey!),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navyTextSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _routeController,
        builder: (context, _) {
          // No provider context (e.g. a route without a provider id).
          if (widget.providerId == null || _displayStops.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: _buildEmptyStops(),
            );
          }
          if (_routeController.isLoadingStops &&
              _routeController.stops.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.navy),
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
    final stops = _displayStops;
    final origin = stops.isNotEmpty ? stops.first.stopName : '';
    final destination = stops.isNotEmpty ? stops.last.stopName : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_routeController.isBidirectional)
          GestureDetector(
            onTap: _onDirectionToggle,
            child: const Row(
              children: [
                Icon(Icons.swap_horiz_rounded,
                    size: 14, color: AppColors.navyTextHint),
                SizedBox(width: 4),
                Text(
                  'Change Direction',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navyTextSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          const Text(
            'One direction',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.navyTextHint,
            ),
          ),
        Flexible(
          child: Text(
            origin.isEmpty
                ? widget.route.routeLongName
                : '$origin ⇄ $destination',
            style: const TextStyle(
                fontSize: 11, color: AppColors.navyTextSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 28, color: AppColors.red),
            const SizedBox(height: 8),
            Text(
              _routeController.stopsError ?? 'Could not load route stops.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.navyTextSecondary),
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
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStops() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.route_rounded,
              size: 24, color: AppColors.navyTextHint),
          const SizedBox(height: 8),
          const Text(
            'Stops for this route are not available yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.navyTextSecondary),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: 2, color: AppColors.navyBorder),
                  )
                else
                  const Expanded(child: SizedBox()),
                Container(
                  width: isFirst || isLast ? 22 : 14,
                  height: isFirst || isLast ? 22 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst || isLast ? AppColors.navy : AppColors.white,
                    border: Border.all(
                      color: isFirst || isLast
                          ? AppColors.navy
                          : AppColors.navyBorder,
                      width: 2,
                    ),
                  ),
                  child: isFirst || isLast
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.white,
                            ),
                          ),
                        )
                      : Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.navyBorder,
                            ),
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.navyBorder),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Stop card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.navyBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  if (stop.stopDesc.isNotEmpty) ...[
                                    TextSpan(
                                      text: stop.stopDesc,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navyTextSecondary,
                                      ),
                                    ),
                                    const TextSpan(text: '  '),
                                  ],
                                  TextSpan(
                                    text: stop.stopName,
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.navyTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map_rounded,
                                    size: 10, color: AppColors.white),
                                SizedBox(width: 3),
                                Text(
                                  'Map',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.navyTextHint,
                          ),
                        ],
                      ),
                      if (isExpanded) ...[
                        const Divider(height: 20),
                        const Text(
                          'UPCOMING ARRIVALS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.navyTextTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildArrivals(stop),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Upcoming departures for the expanded stop (selected direction).
  Widget _buildArrivals(RouteStop stop) {
    if (_routeController.isLoadingEta) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.navy),
          ),
        ),
      );
    }
    final departures = _routeController.selectedDirectionDepartures;
    if (departures.isEmpty) {
      return Text(
        _routeController.etaError ?? 'No upcoming departures.',
        style:
            const TextStyle(fontSize: 12, color: AppColors.navyTextSecondary),
      );
    }
    return Column(
      children: [
        for (final departure in departures.take(3))
          _buildArrivalRow(
            vehicle: departure.tripId,
            eta: _formatCountdown(departure.countdownMinutes()),
          ),
      ],
    );
  }

  String _formatCountdown(int minutes) {
    if (minutes <= 0) return 'Due';
    return '$minutes min';
  }

  Widget _buildArrivalRow({required String vehicle, required String eta}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.navyBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navyTextSecondary,
                  ),
                ),
              ],
            ),
            Text(
              eta,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.navyTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
