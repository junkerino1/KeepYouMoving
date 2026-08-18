import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/eta_departure.dart';
import '../../models/vehicle_progress.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../stops/route_color_badge.dart';

/// Single ETA departure card: route badge + status (carplate + speed +
/// distance when live, "Scheduled" otherwise) + bold countdown.
///
/// When [onTap] is provided and the departure has a live vehicle, the card
/// becomes tappable — tapping highlights the bus on the map and shows
/// stops-away info.
class EtaItem extends StatelessWidget {
  final EtaDeparture departure;
  final ProviderTheme theme;
  final LatLng stopPosition;
  final VoidCallback? onTap;
  final VehicleProgress? vehicleProgress;
  final bool isLoadingProgress;
  final bool isHighlighted;

  const EtaItem({
    super.key,
    required this.departure,
    required this.theme,
    required this.stopPosition,
    this.onTap,
    this.vehicleProgress,
    this.isLoadingProgress = false,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final live = departure.firstValidVehicle;
    final minutes = departure.countdownMinutes();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasLive = live != null;
    final canTap = hasLive && onTap != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isHighlighted
            ? scheme.primaryContainer.withValues(alpha: 0.3)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? scheme.primary : scheme.outlineVariant,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: canTap ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Route badge (route code + bus icon).
                RouteColorBadge(
                  shortName: departure.routeShortName,
                  theme: theme,
                  fontSize: 12,
                  iconSize: 12,
                ),
                const SizedBox(width: 12),
                // Status: live trips write carplate + speed; scheduled-only
                // write "Scheduled". Shows stops-away when available.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasLive)
                        _buildLiveStatus(context, live)
                      else
                        Text('Scheduled', style: textTheme.bodyMedium),
                      if (departure.isApproximate) ...[
                        const SizedBox(height: 2),
                        Text('Approximate', style: textTheme.labelMedium),
                      ],
                      // Stops-away indicator
                      if (hasLive) ...[
                        const SizedBox(height: 4),
                        _buildStopsAway(context),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Countdown: the primary real-time signal.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _countdownLabel(minutes),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: _countdownColor(context, minutes),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _countdownUnit(minutes),
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Carplate on top, speed + distance below.
  Widget _buildLiveStatus(BuildContext context, VehiclePosition live) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final plate = departure.liveVehicleId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plate?.isNotEmpty == true ? plate! : 'Bus',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.speed_rounded, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '${formatSpeedKmh(live.speedKmh)} km/h',
              style: textTheme.bodySmall,
            ),
            const SizedBox(width: 10),
            Icon(Icons.near_me_rounded,
                size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                formatDistance(_distanceToStop(live)),
                style: textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Stops-away indicator: shows the progress data or a loading state.
  Widget _buildStopsAway(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = vehicleProgress;

    if (isLoadingProgress) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Checking stops...',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    if (progress == null) return const SizedBox.shrink();

    final departed = progress.hasDeparted;
    final arrived = progress.hasArrived;
    final statusColor = departed
        ? scheme.error
        : arrived
            ? AppColors.emeraldDark
            : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: departed
            ? scheme.errorContainer.withValues(alpha: 0.45)
            : arrived
                ? AppColors.emeraldDark.withValues(alpha: 0.15)
                : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            departed
                ? Icons.flag_outlined
                : arrived
                    ? Icons.check_circle_outline_rounded
                    : Icons.directions_bus_outlined,
            size: 12,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            arrived ? 'Arriving' : progress.label,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  double _distanceToStop(VehiclePosition position) {
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(position.latitude, position.longitude),
      stopPosition,
    );
  }
}

String _countdownLabel(int? minutes) {
  if (minutes == null) return '--';
  if (minutes <= 0) return 'Due';
  return '$minutes';
}

String _countdownUnit(int? minutes) {
  if (minutes == null) return 'min';
  if (minutes <= 0) return 'now';
  return 'min';
}

Color _countdownColor(BuildContext context, int? minutes) {
  final scheme = Theme.of(context).colorScheme;
  if (minutes == null) return scheme.onSurfaceVariant;
  if (minutes <= 5) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.emerald
        : AppColors.emeraldDark;
  }
  if (minutes > 5 && minutes < 20) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.amber
        : AppColors.amberDark;
  }
  if (minutes >= 20) return AppColors.red;
  return scheme.onSurface;
}
