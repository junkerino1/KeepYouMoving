import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'route_badge.dart';

/// A card displaying a stop with its route badge, name, and optional distance.
class StopCard extends StatelessWidget {
  final String stopName;
  final String routeId;
  final String? distance;
  final bool isSelected;
  final VoidCallback onTap;

  const StopCard({
    super.key,
    required this.stopName,
    required this.routeId,
    this.distance,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyVeryLight : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.navyBorder : AppColors.navyBorder,
          ),
        ),
        child: Row(
          children: [
            RouteBadge(routeId: routeId),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                stopName,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navyTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: 8),
              Text(
                distance!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navyTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
