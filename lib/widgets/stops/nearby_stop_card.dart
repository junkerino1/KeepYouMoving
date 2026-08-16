import 'package:flutter/material.dart';
import '../../models/stop.dart';
import '../../models/transit_route.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'route_color_badge.dart';

/// Nearby stop card with an expandable routes dropdown.
///
/// Collapsed: bus icon + stop name + distance. Expanding reveals the routes
/// serving the stop (loading / error / empty / list states).
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: expanded
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded
              ? theme.border
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stop header row
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.directions_bus_rounded,
                        size: 20, color: theme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.stopName,
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        if (stop.stopCode.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            stop.stopCode,
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDistance(stop.distanceM),
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expandable routes section
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: expanded
                ? Column(
                    children: [
                      Divider(
                        height: 1,
                        indent: 12,
                        endIndent: 12,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        child: _buildRoutesSection(context),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
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
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading routes...',
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
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                size: 16, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      );
    }

    final routes = this.routes;
    if (routes == null || routes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text('No routes available', style: textTheme.bodySmall),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${routes.length} route${routes.length == 1 ? '' : 's'}',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        for (final route in routes)
          InkWell(
            onTap: () => onRouteTap(route),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
