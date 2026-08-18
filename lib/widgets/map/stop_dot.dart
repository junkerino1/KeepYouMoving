import 'package:flutter/material.dart';

/// Small circular bus-stop marker on the stop-detail map, colored by the
/// provider theme.
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
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
