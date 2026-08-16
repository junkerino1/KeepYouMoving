/// A stop along a route, returned by the `{provider_id}/{route_id}/stops`
/// endpoint.
///
/// `stop_lat`, `stop_lon` and `stop_sequence` are returned as strings by the
/// API, so they are parsed to their proper types here. Responses vary by
/// provider (some omit `stop_desc` and send `stop_code` instead), so optional
/// fields are handled defensively.
class RouteStop {
  final String stopId;
  final String stopCode;
  final String stopName;
  final String stopDesc;
  final double stopLat;
  final double stopLon;
  final int stopSequence;
  final int directionId;

  const RouteStop({
    required this.stopId,
    this.stopCode = '',
    required this.stopName,
    this.stopDesc = '',
    required this.stopLat,
    required this.stopLon,
    this.stopSequence = 0,
    this.directionId = 0,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      stopId: json['stop_id'] as String,
      stopCode: (json['stop_code'] as String?) ?? '',
      stopName: json['stop_name'] as String,
      stopDesc: (json['stop_desc'] as String?) ?? '',
      stopLat: double.parse(json['stop_lat'] as String),
      stopLon: double.parse(json['stop_lon'] as String),
      stopSequence:
          int.tryParse(json['stop_sequence'] as String? ?? '') ?? 0,
      directionId: int.tryParse(json['direction_id'] as String? ?? '') ?? 0,
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
      'stop_sequence': stopSequence.toString(),
      'direction_id': directionId.toString(),
    };
  }

  @override
  String toString() => 'RouteStop($stopId: $stopName)';
}
