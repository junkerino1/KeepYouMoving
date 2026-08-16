import 'package:flutter/material.dart';
import '../../models/transit_route.dart';
import '../../theme/app_theme.dart';
import 'route_color_badge.dart';

/// Flat, tappable route list row (no card chrome): provider badge + long name.
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            RouteColorBadge(
                shortName: route.routeShortName, theme: theme),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                route.routeLongName,
                style: textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
