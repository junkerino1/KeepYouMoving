/// Parsed response of `{provider_id}/schedule/{route_id}/{stop_id}`.
///
/// Only the fields the timetable UI renders are modelled; unknown fields are
/// ignored defensively.
class RouteSchedule {
  final int providerId;
  final String routeId;
  final String stopId;
  final String serviceDate;
  final String timezone;
  final int? currentFrequencyMinutes;
  final List<String> activeServiceIds;
  final List<String> operatingDays;
  final int? headwayMin;
  final int? headwayMedian;
  final int? headwayMax;
  final List<DirectionTimes> timesByDirection;
  final String predictionType;
  final int count;
  final bool truncated;

  const RouteSchedule({
    required this.providerId,
    required this.routeId,
    required this.stopId,
    required this.serviceDate,
    required this.timezone,
    required this.currentFrequencyMinutes,
    required this.activeServiceIds,
    required this.operatingDays,
    required this.headwayMin,
    required this.headwayMedian,
    required this.headwayMax,
    required this.timesByDirection,
    required this.predictionType,
    required this.count,
    required this.truncated,
  });

  factory RouteSchedule.fromJson(Map<String, dynamic> json) {
    final calendar = json['service_calendar'] as Map<String, dynamic>?;
    final headway = json['scheduled_headway_minutes'] as Map<String, dynamic>?;
    return RouteSchedule(
      providerId: (json['provider_id'] as num?)?.toInt() ?? 0,
      routeId: (json['route_id'] as String?) ?? '',
      stopId: (json['stop_id'] as String?) ?? '',
      serviceDate: (json['service_date'] as String?) ?? '',
      timezone: (json['schedule_timezone'] as String?) ?? '',
      currentFrequencyMinutes:
          (json['current_frequency_minutes'] as num?)?.toInt(),
      activeServiceIds: [
        for (final id in (calendar?['active_service_ids'] as List? ?? const []))
          id as String,
      ],
      operatingDays: [
        for (final day in (calendar?['operating_days'] as List? ?? const []))
          day as String,
      ],
      headwayMin: (headway?['minimum'] as num?)?.toInt(),
      headwayMedian: (headway?['median'] as num?)?.toInt(),
      headwayMax: (headway?['maximum'] as num?)?.toInt(),
      timesByDirection: [
        for (final entry
            in (json['available_times_by_direction'] as List? ?? const []))
          DirectionTimes.fromJson(entry as Map<String, dynamic>),
      ],
      predictionType: (json['prediction_type'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      truncated: (json['truncated'] as bool?) ?? false,
    );
  }

  /// All available departure times (HH:mm:ss), across every direction.
  List<String> get allTimes =>
      [for (final direction in timesByDirection) ...direction.times];
}

/// One `available_times_by_direction` entry: the times for a direction.
class DirectionTimes {
  final String directionId;
  final List<String> times;

  const DirectionTimes({required this.directionId, required this.times});

  factory DirectionTimes.fromJson(Map<String, dynamic> json) {
    return DirectionTimes(
      directionId: (json['direction_id'] as String?) ?? '',
      times: [
        for (final t in (json['times'] as List? ?? const [])) t as String,
      ],
    );
  }
}
