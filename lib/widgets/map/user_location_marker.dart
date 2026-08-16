import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Pulsing live-location marker shown at the user's current position.
///
/// A soft, semi-transparent red circle pulses outward behind a solid red dot
/// with a white border — the standard "streaming location" look.
class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({super.key});

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing semi-transparent circle behind the pinpoint.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final size = 20 + 350 * t;
              final alpha = 0.45 * (1 - t);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sky.withValues(alpha: alpha),
                ),
              );
            },
          ),
          // White outer ring
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.sky.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // Blue inner dot (matches M3 location marker style).
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sky,
              border: Border.all(color: AppColors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}
