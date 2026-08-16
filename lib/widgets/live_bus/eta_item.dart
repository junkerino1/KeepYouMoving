import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/eta_departure.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../stops/route_color_badge.dart';

/// Single ETA departure card: route badge + status (carplate + speed +
/// distance when live, "Scheduled" otherwise) + bold countdown.
class EtaItem extends StatelessWidget {
  final EtaDeparture departure;
  final ProviderTheme theme;
  final LatLng stopPosition;

  const EtaItem({
    super.key,
    required this.departure,
    required this.theme,
    required this.stopPosition,
  });

  @override
  Widget build(BuildContext context) {
    final live = departure.firstValidVehicle;
    final minutes = departure.countdownMinutes();
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
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
          // Status: live trips write carplate + speed; scheduled-only write
          // "Scheduled".
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (live != null)
                  _buildLiveStatus(context, live)
                else
                  Text('Scheduled', style: textTheme.bodyMedium),
                if (departure.isApproximate) ...[
                  const SizedBox(height: 2),
                  Text('Approximate', style: textTheme.labelMedium),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Countdown: the primary real-time signal — intentionally kept as a
          // custom large, extra-bold monospace treatment (type-scale exception).
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
    // AA-compliant "due soon" green per theme.
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.emerald
        : AppColors.emeraldDark;
  }
  // Approaching band: 6–19 min → amber instead of the neutral dark tone.
  if (minutes > 5 && minutes < 20) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.amber
        : AppColors.amberDark;
  }
  if (minutes >= 20) return AppColors.red;
  return scheme.onSurface;
}
