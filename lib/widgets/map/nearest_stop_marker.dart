import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Bus-stop marker used on the live map (provider-colored bus icon).
///
/// [onTap] is invoked when the marker is pressed.
class NearestStopMarker extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;

  const NearestStopMarker({super.key, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.directions_bus_rounded,
          size: 22,
          color: AppColors.white,
        ),
      ),
    );
  }
}
