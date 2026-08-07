import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable route badge showing route ID and a bus icon.
/// Used in route cards, stop cards, and headers.
class RouteBadge extends StatelessWidget {
  final String routeId;
  final double fontSize;
  final double iconSize;
  final double height;
  final EdgeInsets padding;
  final Color? backgroundColor;

  const RouteBadge({
    super.key,
    required this.routeId,
    this.fontSize = 13,
    this.iconSize = 14,
    this.height = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.backgroundColor,
  });

  Color get _bgColor => backgroundColor ??
      (routeId.startsWith('T') ? AppColors.skyDark : AppColors.navy);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            routeId,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.directions_bus, size: iconSize, color: AppColors.white.withOpacity(0.7)),
        ],
      ),
    );
  }
}
