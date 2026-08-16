import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Live bus marker: a provider-themed badge with a bus icon, rotated by the
/// vehicle's bearing when explicitly provided. [onTap] reports a press.
///
/// When [isHighlighted] is true, the marker is larger with a glowing border
/// to show it's the selected bus from the ETA list.
class LiveBusMarker extends StatelessWidget {
  final Color color;
  final double bearing;
  final bool bearingIsExplicit;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const LiveBusMarker({
    super.key,
    required this.color,
    required this.bearing,
    required this.bearingIsExplicit,
    this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isHighlighted ? 56.0 : 44.0;
    final iconSize = isHighlighted ? 28.0 : 24.0;
    final borderWidth = isHighlighted ? 4.0 : 3.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isHighlighted ? AppColors.amber : AppColors.white,
            width: borderWidth,
          ),
          boxShadow: [
            if (isHighlighted)
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 2,
              )
            else
              const BoxShadow(
                color: Color(0x55000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Transform.rotate(
          angle: bearingIsExplicit ? bearing * math.pi / 180 : 0,
          child: Icon(Icons.directions_bus,
              size: iconSize, color: AppColors.white),
        ),
      ),
    );
  }
}
