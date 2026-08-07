/// A transit route serving a stop, returned by the
/// `{provider_id}/{stop_id}/routes` endpoint.
///
/// Color fields arrive as hex strings (e.g. `006CFF`) and are kept as strings
/// so the UI can format them as needed.
class TransitRoute {
  final String routeId;
  final String agencyId;
  final String routeShortName;
  final String routeLongName;
  final String routeType;
  final String routeColor;
  final String routeTextColor;

  const TransitRoute({
    required this.routeId,
    required this.agencyId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
    required this.routeColor,
    required this.routeTextColor,
  });

  factory TransitRoute.fromJson(Map<String, dynamic> json) {
    return TransitRoute(
      routeId: json['route_id'] as String,
      agencyId: json['agency_id'] as String,
      routeShortName: json['route_short_name'] as String,
      routeLongName: json['route_long_name'] as String,
      routeType: json['route_type'] as String,
      routeColor: json['route_color'] as String,
      routeTextColor: json['route_text_color'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'agency_id': agencyId,
      'route_short_name': routeShortName,
      'route_long_name': routeLongName,
      'route_type': routeType,
      'route_color': routeColor,
      'route_text_color': routeTextColor,
    };
  }

  @override
  String toString() => 'TransitRoute($routeId: $routeShortName)';
}
