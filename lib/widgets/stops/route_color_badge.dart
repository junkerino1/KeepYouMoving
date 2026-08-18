import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Compact route badge colored by the provider theme (no per-route API
/// colors), so every route looks consistent within a provider.
///
/// The route number is capped to a fixed 4-character width (longer names are
/// truncated with an ellipsis) and paired with a bus icon, keeping badges
/// uniform across the app (route lists, ETA rows, headers).
class RouteColorBadge extends StatelessWidget {
  final String shortName;
  final double fontSize;
  final double iconSize;
  final ProviderTheme theme;

  const RouteColorBadge({
    super.key,
    required this.shortName,
    this.fontSize = 13,
    this.iconSize = 14,
    this.theme = ProviderTheme.defaultTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed 4-char width so every badge is uniform; longer names are
          // truncated with an ellipsis.
          SizedBox(
            width: _fourCharWidth(fontSize),
            child: Text(
              shortName,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: theme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Icon(Icons.directions_bus_rounded,
              size: iconSize, color: theme.onPrimary),
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
