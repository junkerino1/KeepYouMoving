import 'eta_departure.dart';

/// A live bus location returned by the route live-location endpoint:
/// `GET {base}/{provider_id}/live_location/route/{route_id}`.
///
/// Used to plot moving buses on the map for a route. The API returns lat/lon
/// and bearing as doubles; only the fields the map needs are modelled.
class RouteLiveVehicle {
  final String entityId;
  final VehiclePosition position;
  final int? directionId;
  final String? publicVehicleId;

  const RouteLiveVehicle({
    required this.entityId,
    required this.position,
    this.directionId,
    this.publicVehicleId,
  });

  factory RouteLiveVehicle.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'] as Map<String, dynamic>?;
    final vehicle = json['vehicle'] as Map<String, dynamic>?;
    return RouteLiveVehicle(
      entityId: json['entity_id'] as String,
      position:
          VehiclePosition.fromJson(json['position'] as Map<String, dynamic>),
      directionId: (trip?['direction_id'] as num?)?.toInt(),
      publicVehicleId: vehicle?['public_vehicle_id'] as String?,
    );
  }
}
