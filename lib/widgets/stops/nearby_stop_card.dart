import 'package:flutter/material.dart';
import '../../models/stop.dart';
import '../../models/transit_route.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'route_color_badge.dart';

/// Nearby stop card with an expandable routes dropdown.
///
/// Collapsed appearance is identical to the original stop row; expanding
/// reveals the routes serving the stop (loading / error / empty / list states).
class NearbyStopCard extends StatelessWidget {
  final Stop stop;
  final ProviderTheme theme;
  final bool expanded;
  final bool loadingRoutes;
  final String? routesError;
  final List<TransitRoute>? routes;
  final VoidCallback onTap;
  final ValueChanged<TransitRoute> onRouteTap;

  const NearbyStopCard({
    super.key,
    required this.stop,
    required this.theme,
    required this.expanded,
    required this.loadingRoutes,
    required this.routesError,
    required this.routes,
    required this.onTap,
    required this.onRouteTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stop header row
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.directions_bus_rounded,
                        size: 16, color: theme.onPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.stopName,
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDistance(stop.distanceM),
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: _buildRoutesSection(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoutesSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (loadingRoutes) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading routes…',
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
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
          style: textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }

    final routes = this.routes;
    if (routes == null || routes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text('No routes available', style: textTheme.bodyMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final route in routes)
          InkWell(
            onTap: () => onRouteTap(route),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          RouteColorBadge(
                            shortName: route.routeShortName,
                            theme: theme,
                            fontSize: 12,
                            iconSize: 12,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              route.routeLongName,
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
