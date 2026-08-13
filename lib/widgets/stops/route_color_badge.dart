import 'package:flutter/material.dart';
import '../../models/transit_route.dart';
import '../../utils/format.dart';

/// Route badge colored by the route's API colors: background =
/// `route_color`, text/icon = `route_text_color` (with a [fallbackColor] for
/// invalid/missing values).
class RouteColorBadge extends StatelessWidget {
  final TransitRoute route;
  final double fontSize;
  final double iconSize;
  final Color fallbackColor;

  const RouteColorBadge({
    super.key,
    required this.route,
    this.fontSize = 13,
    this.iconSize = 14,
    this.fallbackColor = const Color(0xFF0F172A),
  });

  @override
  Widget build(BuildContext context) {
    final background = colorFromHex(route.routeColor, fallback: fallbackColor);
    final foreground =
        colorFromHex(route.routeTextColor, fallback: Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed 4-char width so every badge is uniform; longer names are
          // truncated with an ellipsis.
          SizedBox(
            width: _fourCharWidth(fontSize),
            child: Text(
              route.routeShortName,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.directions_bus, size: iconSize, color: foreground),
        ],
      ),
    );
  }

  /// Width of exactly 4 monospace characters (incl. letter spacing) in the
  /// badge's text style.
  double _fourCharWidth(double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: '0000',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }
}
