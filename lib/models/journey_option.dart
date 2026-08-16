/// Models for the journey planning endpoint:
/// `POST {base}/journeys/plan`.
library;

/// A single journey option returned by the planner.
class JourneyOption {
  final String routeId;
  final String routeShortName;
  final String routeType;
  final String stopSequence;
  final String directionId;
  final JourneyStop boardingStop;
  final JourneyStop targetStop;
  final int transferCount;
  final String predictionType;

  const JourneyOption({
    required this.routeId,
    required this.routeShortName,
    required this.routeType,
    required this.stopSequence,
    required this.directionId,
    required this.boardingStop,
    required this.targetStop,
    required this.transferCount,
    required this.predictionType,
  });

  factory JourneyOption.fromJson(Map<String, dynamic> json) {
    final route = json['route'] as Map<String, dynamic>? ?? {};
    final boarding = json['boarding_stop'] as Map<String, dynamic>? ?? {};
    final target = json['target_stop'] as Map<String, dynamic>? ?? {};
    return JourneyOption(
      routeId: route['route_id'] as String? ?? '',
      routeShortName: route['route_short_name'] as String? ?? '',
      routeType: route['route_type'] as String? ?? '',
      stopSequence: route['stop_sequence'] as String? ?? '',
      directionId: route['direction_id'] as String? ?? '',
      boardingStop: JourneyStop.fromJson(boarding),
      targetStop: JourneyStop.fromJson(target),
      transferCount: (json['transfer_count'] as num?)?.toInt() ?? 0,
      predictionType: json['prediction_type'] as String? ?? '',
    );
  }

  /// Route type as a human-readable label.
  String get routeTypeLabel {
    switch (routeType) {
      case '3':
        return 'Bus';
      case '1':
        return 'MRT';
      case '0':
        return 'LRT';
      case '2':
        return 'Monorail';
      default:
        return 'Transit';
    }
  }
}

/// A stop in a journey (boarding or target).
class JourneyStop {
  final String stopId;
  final String stopCode;
  final String stopName;
  final double stopLat;
  final double stopLon;
  final double distanceM;

  const JourneyStop({
    required this.stopId,
    required this.stopCode,
    required this.stopName,
    required this.stopLat,
    required this.stopLon,
    required this.distanceM,
  });

  factory JourneyStop.fromJson(Map<String, dynamic> json) {
    return JourneyStop(
      stopId: json['stop_id'] as String? ?? '',
      stopCode: json['stop_code'] as String? ?? '',
      stopName: json['stop_name'] as String? ?? '',
      stopLat: double.tryParse(json['stop_lat'] as String? ?? '') ?? 0,
      stopLon: double.tryParse(json['stop_lon'] as String? ?? '') ?? 0,
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0,
    );
  }
}
