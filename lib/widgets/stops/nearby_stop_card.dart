import 'package:flutter/material.dart';
import '../../models/stop.dart';
import '../../models/transit_route.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

/// Nearby stop card with an expandable routes dropdown.
///
/// Collapsed appearance is identical to the original stop row; expanding
/// reveals the routes serving the stop (loading / error / empty / list states).
class NearbyStopCard extends StatelessWidget {
  final Stop stop;
  final Color accentColor;
  final bool expanded;
  final bool loadingRoutes;
  final String? routesError;
  final List<TransitRoute>? routes;
  final VoidCallback onTap;
  final ValueChanged<TransitRoute> onRouteTap;

  const NearbyStopCard({
    super.key,
    required this.stop,
    required this.accentColor,
    required this.expanded,
    required this.loadingRoutes,
    required this.routesError,
    required this.routes,
    required this.onTap,
    required this.onRouteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stop header row (unchanged appearance when collapsed)
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_bus_rounded,
                        size: 16, color: AppColors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.stopName,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.navyTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (stop.stopDesc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            stop.stopDesc,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.navyTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDistance(stop.distanceM),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable routes section
          if (expanded) ...[
            const Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: AppColors.navyBorder,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: _buildRoutesSection(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoutesSection() {
    if (loadingRoutes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.navy,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Loading routes…',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.navyTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final error = routesError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          error,
          style: const TextStyle(fontSize: 14, color: AppColors.red),
        ),
      );
    }

    final routes = this.routes;
    if (routes == null || routes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'No routes available',
          style: TextStyle(fontSize: 14, color: AppColors.navyTextHint),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final route in routes)
          InkWell(
            onTap: () => onRouteTap(route),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: route.routeShortName,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navyTextPrimary,
                            ),
                          ),
                          TextSpan(
                            text: '  ${route.routeLongName}',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              color: AppColors.navyTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.navyTextHint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
