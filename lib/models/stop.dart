/// A bus stop returned by the `nearest_stations` endpoint.
///
/// The API returns `stop_lat` / `stop_lon` as strings, so they are parsed
/// into [double] here rather than passed around as raw JSON. Responses vary by
/// provider: some omit `stop_desc` and include `stop_code` instead, so both
/// optional fields are handled defensively.
class Stop {
  final String stopId;
  final String stopCode;
  final String stopName;
  final String stopDesc;
  final double stopLat;
  final double stopLon;
  final double distanceM;

  const Stop({
    required this.stopId,
    this.stopCode = '',
    required this.stopName,
    this.stopDesc = '',
    required this.stopLat,
    required this.stopLon,
    this.distanceM = 0,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      stopId: json['stop_id'] as String,
      stopCode: (json['stop_code'] as String?) ?? '',
      stopName: json['stop_name'] as String,
      stopDesc: (json['stop_desc'] as String?) ?? '',
      stopLat: double.parse(json['stop_lat'] as String),
      stopLon: double.parse(json['stop_lon'] as String),
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stop_id': stopId,
      'stop_code': stopCode,
      'stop_name': stopName,
      'stop_desc': stopDesc,
      'stop_lat': stopLat.toString(),
      'stop_lon': stopLon.toString(),
      'distance_m': distanceM,
    };
  }

  /// Returns a copy whose [stopName] includes the [stopCode] (used to
  /// disambiguate Rapid KL stops). Unchanged when there is no code.
  Stop withStopCodeInName() {
    if (stopCode.isEmpty) return this;
    return Stop(
      stopId: stopId,
      stopCode: stopCode,
      stopName: '$stopName ($stopCode)',
      stopDesc: stopDesc,
      stopLat: stopLat,
      stopLon: stopLon,
      distanceM: distanceM,
    );
  }

  @override
  String toString() => 'Stop($stopId: $stopName)';
}
