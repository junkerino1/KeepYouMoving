/// A stop along a route, returned by the `{provider_id}/{route_id}/stops`
/// endpoint.
///
/// `stop_lat`, `stop_lon` and `stop_sequence` are returned as strings by the
/// API, so they are parsed to their proper types here.
class RouteStop {
  final String stopId;
  final String stopName;
  final String stopDesc;
  final double stopLat;
  final double stopLon;
  final int stopSequence;
  final int directionId;

  const RouteStop({
    required this.stopId,
    required this.stopName,
    required this.stopDesc,
    required this.stopLat,
    required this.stopLon,
    required this.stopSequence,
    required this.directionId,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      stopId: json['stop_id'] as String,
      stopName: json['stop_name'] as String,
      stopDesc: json['stop_desc'] as String,
      stopLat: double.parse(json['stop_lat'] as String),
      stopLon: double.parse(json['stop_lon'] as String),
      stopSequence: int.parse(json['stop_sequence'] as String),
      directionId: int.parse(json['direction_id'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stop_id': stopId,
      'stop_name': stopName,
      'stop_desc': stopDesc,
      'stop_lat': stopLat.toString(),
      'stop_lon': stopLon.toString(),
      'stop_sequence': stopSequence.toString(),
      'direction_id': directionId.toString(),
    };
  }

  @override
  String toString() => 'RouteStop($stopId: $stopName)';
}
