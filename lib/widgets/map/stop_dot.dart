import 'package:flutter/material.dart';

/// Small circular bus-stop marker on the stop-detail map, colored by the
/// provider theme.
class StopDot extends StatelessWidget {
  final Color color;

  const StopDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
