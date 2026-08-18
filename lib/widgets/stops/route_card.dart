import 'package:flutter/material.dart';
import '../../models/transit_route.dart';
import '../../theme/app_theme.dart';
import 'route_color_badge.dart';

/// Flat, tappable route list row: provider badge + long name.
class RouteCard extends StatelessWidget {
  final TransitRoute route;
  final ProviderTheme theme;
  final VoidCallback onTap;

  const RouteCard({
    super.key,
    required this.route,
    this.theme = ProviderTheme.defaultTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              RouteColorBadge(
                  shortName: route.routeShortName, theme: theme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.routeLongName,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (route.routeType.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _routeTypeLabel(route.routeType),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _routeTypeLabel(String type) {
    switch (type) {
      case '3':
        return 'Bus';
      case '1':
        return 'MRT';
      case '0':
        return 'LRT';
      case '2':
        return 'Monorail';
      default:
        return 'Transit';
    }
  }
}
