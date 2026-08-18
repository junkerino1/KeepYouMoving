/// Model for the vehicle progress / stops-away endpoint:
/// `GET {base}/{provider_id}/live_location/vehicle/{public_vehicle_id}/progress?target_stop_id={stop_id}`.
library;

/// Response from the stops-away progress API.
class VehicleProgress {
  final int stopsAway;
  final String confidence;
  final int? currentStopSequence;
  final int? targetStopSequence;
  final String targetStopId;

  const VehicleProgress({
    required this.stopsAway,
    required this.confidence,
    this.currentStopSequence,
    this.targetStopSequence,
    required this.targetStopId,
  });

  factory VehicleProgress.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] as Map<String, dynamic>? ?? {};
    return VehicleProgress(
      stopsAway: (progress['stops_away'] as num?)?.toInt() ?? 0,
      confidence: progress['confidence'] as String? ?? 'unknown',
      currentStopSequence: (progress['current_stop_sequence'] as num?)?.toInt(),
      targetStopSequence: (progress['target_stop_sequence'] as num?)?.toInt(),
      targetStopId: progress['target_stop_id'] as String? ?? '',
    );
  }

  /// Human-readable label, including the terminal state returned when the
  /// vehicle has already passed the target stop.
  String get label => hasDeparted
      ? 'Departed'
      : '$stopsAway stop${stopsAway == 1 ? '' : 's'} away';

  /// Whether the vehicle is at the target stop (0 stops away).
  bool get hasArrived => stopsAway == 0;

  /// Whether the vehicle has passed the target stop (negative stops away).
  bool get hasDeparted => stopsAway < 0;
}
