import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Live bus marker: a provider-themed badge with a bus icon, rotated by the
/// vehicle's bearing when explicitly provided. [onTap] reports a press.
class LiveBusMarker extends StatelessWidget {
  final Color color;
  final double bearing;
  final bool bearingIsExplicit;
  final VoidCallback? onTap;

  const LiveBusMarker({
    super.key,
    required this.color,
    required this.bearing,
    required this.bearingIsExplicit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: bearingIsExplicit ? bearing * math.pi / 180 : 0,
          child: const Icon(Icons.directions_bus,
              size: 24, color: AppColors.white),
        ),
      ),
    );
  }
}
