import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

class FavouriteService extends ChangeNotifier {
  FavouriteService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  List<dynamic> _favourites = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get favourites => List.unmodifiable(_favourites);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFavourites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.get('favourite/retrieve');
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      _favourites = data['items'] as List<dynamic>? ?? const [];
    } catch (_) {
      _error = 'Could not load favourites.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createFavourite({
    required int providerId,
    required String type,
    String? routeId,
    String? stopId,
    required String label,
  }) async {
    try {
      final body = <String, dynamic>{
        'provider_id': providerId.toString(),
        'type': type,
        'label': label,
        'sort_order': 0,
      };
      if (routeId != null) body['route_id'] = routeId;
      if (stopId != null) body['stop_id'] = stopId;
      final response = await _api.post('favourite/create', body: body);
      if (response.statusCode == 201) {
        await loadFavourites();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateFavourite({
    required String id,
    required String label,
    int? sortOrder,
  }) async {
    try {
      final body = <String, dynamic>{'id': id, 'label': label};
      if (sortOrder != null) body['sort_order'] = sortOrder;
      final response = await _api.post('favourite/update', body: body);
      if (response.statusCode == 200) {
        await loadFavourites();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFavourite(String id) async {
    try {
      final response = await _api.post('favourite/delete', body: {'id': id});
      if (response.statusCode == 200) {
        _favourites.removeWhere((f) => f['id'] == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool isFavourited({String? routeId, String? stopId}) {
    for (final f in _favourites) {
      final map = f as Map<String, dynamic>;
      if (routeId != null && map['route_id'] == routeId) return true;
      if (stopId != null && map['stop_id'] == stopId) return true;
    }
    return false;
  }

  String? favouriteIdFor({String? routeId, String? stopId}) {
    for (final f in _favourites) {
      final map = f as Map<String, dynamic>;
      if (routeId != null && map['route_id'] == routeId) {
        return map['id'] as String?;
      }
      if (stopId != null && map['stop_id'] == stopId) {
        return map['id'] as String?;
      }
    }
    return null;
  }
}
