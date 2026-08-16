/// A transit route serving a stop, returned by the
/// `{provider_id}/{stop_id}/routes` endpoint.
///
/// Responses vary by provider (some omit optional fields, e.g. `agency_id`
/// may be null), so parsing is defensive. Route colors are intentionally not
/// kept — the UI styles badges with the app theme.
class TransitRoute {
  final String routeId;
  final String agencyId;
  final String routeShortName;
  final String routeLongName;
  final String routeType;

  const TransitRoute({
    required this.routeId,
    this.agencyId = '',
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
  });

  factory TransitRoute.fromJson(Map<String, dynamic> json) {
    return TransitRoute(
      routeId: json['route_id'] as String,
      agencyId: (json['agency_id'] as String?) ?? '',
      routeShortName: json['route_short_name'] as String,
      routeLongName: json['route_long_name'] as String,
      routeType: json['route_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'agency_id': agencyId,
      'route_short_name': routeShortName,
      'route_long_name': routeLongName,
      'route_type': routeType,
    };
  }

  @override
  String toString() => 'TransitRoute($routeId: $routeShortName)';
}
