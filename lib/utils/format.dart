/// Shared formatting helpers used across widgets.
library;

import 'package:flutter/material.dart';

/// Parses an API timestamp as UTC and converts it to the user's local time.
/// Account/session endpoints return UTC; public transport payloads have their
/// own local-time fields and should not use this helper.
DateTime? parseUtcToLocal(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  final utc = parsed.isUtc
      ? parsed
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
  return utc.toLocal();
}

String formatLocalDateTime(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

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
