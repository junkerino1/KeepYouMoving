import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Shared location service that owns the single permission request and
/// position fetch for the entire app. Prevents the Android "Can request
/// only one set of permissions at a time" race condition by coalescing
/// all callers into one Future.
class AppLocationService {
  AppLocationService._();

  static final AppLocationService instance = AppLocationService._();

  Future<Position?>? _initializationFuture;

  /// Returns the initial position, requesting permission if needed.
  /// Multiple callers receive the same Future — only one permission
  /// request is ever active.
  Future<Position?> getInitialPosition() {
    return _initializationFuture ??= _initializeLocation();
  }

  /// Convenience: returns a LatLng or null.
  Future<LatLng?> getInitialLatLng() async {
    final pos = await getInitialPosition();
    if (pos == null) return null;
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<Position?> _initializeLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[location] Location services disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      debugPrint('[location] Current permission: $permission');

      if (permission == LocationPermission.denied) {
        debugPrint('[location] Requesting permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('[location] Permission result: $permission');
      }

      if (permission == LocationPermission.denied) {
        debugPrint('[location] Permission denied');
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[location] Permission permanently denied');
        return null;
      }

      // Try cached location first for a fast map center.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        debugPrint(
          '[location] Cached: ${cached.latitude}, ${cached.longitude}',
        );
      }

      // Request fresh position with a timeout so the UI never hangs.
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));

        debugPrint(
          '[location] Fresh: ${position.latitude}, ${position.longitude}',
        );
        return position;
      } on TimeoutException {
        debugPrint('[location] Fresh position timed out; using cached');
        return cached;
      }
    } catch (e, st) {
      debugPrint('[location] Failed: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Starts a live position stream. Only call this AFTER
  /// [getInitialPosition] has succeeded (permission is already granted).
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
  }) {
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Allows a manual retry (e.g. after user enables location in settings).
  void reset() {
    _initializationFuture = null;
  }
}
