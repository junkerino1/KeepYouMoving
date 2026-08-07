/// Models for the real-time ETA endpoint:
/// `GET {base}/{provider_id}/eta/{route_id}/{stop_id}`.
library;

/// A single scheduled/real-time departure returned in the `departures` array.
class EtaDeparture {
  final String tripId;
  final String routeId;
  final String routeShortName;
  final String directionId;
  final String? tripHeadsign;
  final String stopId;
  final int stopSequence;
  final String serviceDate;
  final String gtfsTime;
  final DateTime scheduledAtLocal;
  final DateTime scheduledAtUtc;
  final bool frequencyBased;
  final bool isApproximate;
  final LiveVehicle? liveVehicle;

  const EtaDeparture({
    required this.tripId,
    required this.routeId,
    required this.routeShortName,
    required this.directionId,
    this.tripHeadsign,
    required this.stopId,
    required this.stopSequence,
    required this.serviceDate,
    required this.gtfsTime,
    required this.scheduledAtLocal,
    required this.scheduledAtUtc,
    required this.frequencyBased,
    required this.isApproximate,
    this.liveVehicle,
  });

  factory EtaDeparture.fromJson(Map<String, dynamic> json) {
    final live = json['live_vehicle'];
    return EtaDeparture(
      tripId: json['trip_id'] as String,
      routeId: json['route_id'] as String,
      routeShortName: json['route_short_name'] as String? ?? '',
      directionId: json['direction_id'] as String,
      tripHeadsign: json['trip_headsign'] as String?,
      stopId: json['stop_id'] as String,
      stopSequence: int.parse(json['stop_sequence'] as String),
      serviceDate: json['service_date'] as String,
      gtfsTime: json['gtfs_time'] as String,
      scheduledAtLocal: DateTime.parse(json['scheduled_at_local'] as String),
      scheduledAtUtc: DateTime.parse(json['scheduled_at_utc'] as String),
      frequencyBased: json['frequency_based'] as bool? ?? false,
      isApproximate: json['is_approximate'] as bool? ?? false,
      liveVehicle:
          live is Map<String, dynamic> ? LiveVehicle.fromJson(live) : null,
    );
  }

  /// First valid live vehicle position for this departure, if any.
  VehiclePosition? get firstValidVehicle {
    final live = liveVehicle;
    if (live == null) return null;
    for (final v in live.vehicles) {
      if (v.position.positionValid) return v.position;
    }
    return null;
  }

  /// Minutes until this departure (based on its scheduled local time).
  int countdownMinutes({DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    return scheduledAtLocal.toUtc().difference(current).inMinutes;
  }
}

/// The `live_vehicle` object attached to a departure.
class LiveVehicle {
  final String matchingRule;
  final String tripId;
  final String serviceDate;
  final List<LiveVehiclePosition> vehicles;

  const LiveVehicle({
    required this.matchingRule,
    required this.tripId,
    required this.serviceDate,
    required this.vehicles,
  });

  factory LiveVehicle.fromJson(Map<String, dynamic> json) {
    return LiveVehicle(
      matchingRule: json['matching_rule'] as String,
      tripId: json['trip_id'] as String,
      serviceDate: json['service_date'] as String,
      vehicles: (json['vehicles'] as List<dynamic>? ?? const [])
          .map((e) => LiveVehiclePosition.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// A single matched vehicle (an entry inside `live_vehicle.vehicles`).
class LiveVehiclePosition {
  final String entityId;
  final VehiclePosition position;

  const LiveVehiclePosition({
    required this.entityId,
    required this.position,
  });

  factory LiveVehiclePosition.fromJson(Map<String, dynamic> json) {
    return LiveVehiclePosition(
      entityId: json['entity_id'] as String,
      position:
          VehiclePosition.fromJson(json['position'] as Map<String, dynamic>),
    );
  }
}

/// The real-time position of a vehicle.
class VehiclePosition {
  final double latitude;
  final double longitude;
  final double bearing;
  final bool bearingIsExplicit;
  final double speedMps;
  final bool speedIsExplicit;
  final bool positionValid;

  const VehiclePosition({
    required this.latitude,
    required this.longitude,
    required this.bearing,
    required this.bearingIsExplicit,
    required this.speedMps,
    required this.speedIsExplicit,
    required this.positionValid,
  });

  factory VehiclePosition.fromJson(Map<String, dynamic> json) {
    return VehiclePosition(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      bearing: (json['bearing'] as num?)?.toDouble() ?? 0,
      bearingIsExplicit: json['bearing_is_explicit'] as bool? ?? false,
      speedMps: (json['speed_mps'] as num?)?.toDouble() ?? 0,
      speedIsExplicit: json['speed_is_explicit'] as bool? ?? false,
      positionValid: json['position_valid'] as bool? ?? false,
    );
  }
}
