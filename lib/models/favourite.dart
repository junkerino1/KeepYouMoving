/// Models for the favourites API.
library;

import 'transit_provider.dart';

class Favourite {
  final String id;
  final int providerId;
  final String type; // 'stop' or 'route'
  final String? routeId;
  final String? stopId;
  final String label;
  final int sortOrder;
  final bool isStale;
  final TransitProvider? provider;
  final FavouriteEntity? entity;

  const Favourite({
    required this.id,
    required this.providerId,
    required this.type,
    this.routeId,
    this.stopId,
    required this.label,
    required this.sortOrder,
    required this.isStale,
    this.provider,
    this.entity,
  });

  factory Favourite.fromJson(Map<String, dynamic> json) {
    return Favourite(
      id: json['id'] as String? ?? '',
      providerId: (json['provider_id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      routeId: json['route_id'] as String?,
      stopId: json['stop_id'] as String?,
      label: json['label'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isStale: json['is_stale'] as bool? ?? false,
      provider: json['provider'] is Map<String, dynamic>
          ? TransitProvider.fromJson(json['provider'] as Map<String, dynamic>)
          : null,
      entity: json['entity'] is Map<String, dynamic>
          ? FavouriteEntity.fromJson(json['entity'] as Map<String, dynamic>)
          : null,
    );
  }

  String get displayName {
    if (entity?.route != null) return entity!.route!.routeShortName;
    if (entity?.stop != null) return entity!.stop!.stopName;
    return label;
  }

  String get subtitle {
    if (entity?.route != null) return entity!.route!.routeLongName;
    if (entity?.stop != null) return entity!.stop!.stopCode;
    return '';
  }
}

class FavouriteEntity {
  final FavouriteRouteInfo? route;
  final FavouriteStopInfo? stop;

  const FavouriteEntity({this.route, this.stop});

  factory FavouriteEntity.fromJson(Map<String, dynamic> json) {
    return FavouriteEntity(
      route: json['route'] is Map<String, dynamic>
          ? FavouriteRouteInfo.fromJson(json['route'] as Map<String, dynamic>)
          : null,
      stop: json['stop'] is Map<String, dynamic>
          ? FavouriteStopInfo.fromJson(json['stop'] as Map<String, dynamic>)
          : null,
    );
  }
}

class FavouriteRouteInfo {
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final String routeType;

  const FavouriteRouteInfo({
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
  });

  factory FavouriteRouteInfo.fromJson(Map<String, dynamic> json) {
    return FavouriteRouteInfo(
      routeId: json['route_id'] as String? ?? '',
      routeShortName: json['route_short_name'] as String? ?? '',
      routeLongName: json['route_long_name'] as String? ?? '',
      routeType: json['route_type'] as String? ?? '',
    );
  }
}

class FavouriteStopInfo {
  final String stopId;
  final String stopCode;
  final String stopName;

  const FavouriteStopInfo({
    required this.stopId,
    required this.stopCode,
    required this.stopName,
  });

  factory FavouriteStopInfo.fromJson(Map<String, dynamic> json) {
    return FavouriteStopInfo(
      stopId: json['stop_id'] as String? ?? '',
      stopCode: json['stop_code'] as String? ?? '',
      stopName: json['stop_name'] as String? ?? '',
    );
  }
}
