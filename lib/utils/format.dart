/// Shared formatting helpers used across widgets.
library;

/// Formats a distance in meters as a compact label (`52 m`, `1.2 km`).
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Converts speed in m/s to km/h formatted with one decimal (e.g. `38.9`).
String formatSpeedKmh(double speedMps) => (speedMps * 3.6).toStringAsFixed(1);
