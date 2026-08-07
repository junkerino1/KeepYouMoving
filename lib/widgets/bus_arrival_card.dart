import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'route_badge.dart';

/// A card showing a live bus arrival with route badge, vehicle info, speed, distance and ETA.
class BusArrivalCard extends StatelessWidget {
  final String routeId;
  final String vehicleId;
  final String speed;
  final String distance;
  final int etaMinutes;

  const BusArrivalCard({
    super.key,
    required this.routeId,
    required this.vehicleId,
    required this.speed,
    required this.distance,
    required this.etaMinutes,
  });

  Color get _etaColor {
    if (etaMinutes <= 5) return AppColors.emerald;
    if (etaMinutes >= 15) return AppColors.red;
    return AppColors.navyTextPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        children: [
          // Route badge with pulse dot
          Stack(
            children: [
              RouteBadge(routeId: routeId),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emerald,
                    border: Border.all(color: AppColors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Vehicle info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.navyVeryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    vehicleId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navyTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      speed,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(fontSize: 11, color: AppColors.navyTextHint),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$distance km',
                      style: const TextStyle(fontSize: 11, color: AppColors.navyTextSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ETA
          Column(
            children: [
              Text(
                '$etaMinutes',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _etaColor,
                ),
              ),
              const Text(
                'min',
                style: TextStyle(
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
}
