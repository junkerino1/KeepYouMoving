import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Speed + distance row shown for a live vehicle.
class LiveBusInfo extends StatelessWidget {
  /// e.g. `38.9 km/h`
  final String speedLabel;

  /// e.g. `120 m`
  final String distanceLabel;

  const LiveBusInfo({
    super.key,
    required this.speedLabel,
    required this.distanceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.speed_rounded,
            size: 12, color: AppColors.navyTextTertiary),
        const SizedBox(width: 4),
        Text(
          speedLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.navyTextPrimary,
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.near_me_rounded,
            size: 12, color: AppColors.navyTextTertiary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            distanceLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.navyTextPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
