import 'package:flutter/material.dart';
import '../../models/transit_route.dart';
import '../../theme/app_theme.dart';
import 'route_color_badge.dart';

/// Tappable route list card: colored badge (API colors) + route long name.
class RouteCard extends StatelessWidget {
  final TransitRoute route;
  final Color fallbackBadgeColor;
  final VoidCallback onTap;

  const RouteCard({
    super.key,
    required this.route,
    this.fallbackBadgeColor = const Color(0xFF0F172A),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.navyBorder),
          ),
          child: Row(
            children: [
              RouteColorBadge(route: route, fallbackColor: fallbackBadgeColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  route.routeLongName,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navyTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.navyTextHint),
            ],
          ),
        ),
      ),
    );
  }
}
