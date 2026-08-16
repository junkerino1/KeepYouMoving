import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Pulsing location marker shown at the user's current position.
///
/// A soft, semi-transparent navy circle pulses outward behind a navy
/// pinpoint icon (with a white outline) to draw the eye without cluttering
/// the map.
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
          // Pinpoint icon with a white outline on the pin itself: a slightly
          // larger white glyph behind the colored one creates the stroke.
          const Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 48,
                color: AppColors.white,
              ),
              Icon(
                Icons.location_on_rounded,
                size: 36,
                color: AppColors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
