import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Small circular bus-stop marker (provider-themed dot), clearly distinct
/// from the route polyline and the larger live-bus marker.
class StopDot extends StatelessWidget {
  final Color color;

  const StopDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(Icons.directions_bus, size: 9, color: AppColors.white),
    );
  }
}
