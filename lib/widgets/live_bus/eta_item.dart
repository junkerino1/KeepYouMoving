import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/eta_departure.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'live_bus_info.dart';

/// Single ETA departure card: route badge + live speed/distance + countdown.
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          // Route badge (provider theme)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  departure.routeShortName,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.directions_bus,
                    size: 12, color: AppColors.white),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Speed & distance (supporting info)
          Expanded(
            child: live != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LiveBusInfo(
                        speedLabel: '${formatSpeedKmh(live.speedMps)} km/h',
                        distanceLabel:
                            formatDistance(_distanceToStop(live)),
                      ),
                      if (departure.isApproximate) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Approximate',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.navyTextHint),
                        ),
                      ],
                    ],
                  )
                : const Text(
                    'Scheduled service',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.navyTextSecondary),
                  ),
          ),
          const SizedBox(width: 8),
          // Countdown (most prominent)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _countdownLabel(minutes),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _countdownColor(minutes),
                ),
              ),
              Text(
                _countdownUnit(minutes),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navyTextTertiary,
                ),
              ),
            ],
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

Color _countdownColor(int? minutes) {
  if (minutes == null) return AppColors.navyTextTertiary;
  if (minutes <= 5) return AppColors.emerald;
  if (minutes >= 15) return AppColors.red;
  return AppColors.navyTextPrimary;
}
