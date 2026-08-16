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
      duration: const Duration(milliseconds: 1800),
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
              // Grows from a small dot to the full box while fading out.
              final size = 24 + 300 * t;
              final alpha = 0.50 * (1 - t);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red.withValues(alpha: alpha),
                ),
              );
            },
          ),
          // Red dot with a white border (streaming-location style).
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.red,
              border: Border.all(color: AppColors.white, width: 3),
            ),
          ),
        ],
      ),
    );
  }
}
