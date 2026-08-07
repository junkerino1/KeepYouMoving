/// A bus stop returned by the `nearest_stations` endpoint.
///
/// The API returns `stop_lat` / `stop_lon` as strings, so they are parsed
/// into [double] here rather than passed around as raw JSON.
class Stop {
  final String stopId;
  final String stopName;
  final String stopDesc;
  final double stopLat;
  final double stopLon;
  final double distanceM;

  const Stop({
    required this.stopId,
    required this.stopName,
    required this.stopDesc,
    required this.stopLat,
    required this.stopLon,
    required this.distanceM,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      stopId: json['stop_id'] as String,
      stopName: json['stop_name'] as String,
      stopDesc: json['stop_desc'] as String,
      stopLat: double.parse(json['stop_lat'] as String),
      stopLon: double.parse(json['stop_lon'] as String),
      distanceM: (json['distance_m'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stop_id': stopId,
      'stop_name': stopName,
      'stop_desc': stopDesc,
      'stop_lat': stopLat.toString(),
      'stop_lon': stopLon.toString(),
      'distance_m': distanceM,
    };
  }

  @override
  String toString() => 'Stop($stopId: $stopName)';
}
