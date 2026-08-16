/// Shared formatting helpers used across widgets.
library;

import 'package:flutter/material.dart';

/// Formats a distance in meters as a compact label (`52 m`, `1.2 km`).
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Formats a speed (already in km/h) with one decimal (e.g. `38.9`).
String formatSpeedKmh(double speedKmh) => speedKmh.toStringAsFixed(1);

/// Parses a 6-digit hex color string (e.g. `006CFF`) into a [Color], returning
/// [fallback] for missing/invalid values.
Color colorFromHex(String? hex, {required Color fallback}) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
