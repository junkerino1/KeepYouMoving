import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/journey_option.dart';
import '../services/api_service.dart';

/// Manages journey planning: origin/destination selection and API calls.
class JourneyController extends ChangeNotifier {
  JourneyController({ApiService? apiService})
      : _api = apiService ?? ApiService();

  final ApiService _api;

  LatLng? _origin;
  LatLng? _destination;
  String? _originLabel;
  String? _destinationLabel;
  int? _selectedProviderId;

  List<JourneyOption> _options = [];
  bool _isLoading = false;
  String? _errorMessage;

  LatLng? get origin => _origin;
  LatLng? get destination => _destination;
  String? get originLabel => _originLabel;
  String? get destinationLabel => _destinationLabel;
  List<JourneyOption> get options => List.unmodifiable(_options);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get canPlan => _origin != null && _destination != null;

  /// Sets the origin location. Clears results when changed.
  void setOrigin(LatLng position, {String? label}) {
    _origin = position;
    _originLabel = label;
    _options = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets the destination location. Clears results when changed.
  void setDestination(LatLng position, {String? label}) {
    _destination = position;
    _destinationLabel = label;
    _options = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Swaps origin and destination.
  void swap() {
    final tempPos = _origin;
    final tempLabel = _originLabel;
    _origin = _destination;
    _originLabel = _destinationLabel;
    _destination = tempPos;
    _destinationLabel = tempLabel;
    _options = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets the provider ID for the journey search.
  void setProviderId(int? providerId) {
    _selectedProviderId = providerId;
  }

  /// Plans the journey using the API.
  Future<void> planJourney({int? providerId}) async {
    final origin = _origin;
    final dest = _destination;
    if (origin == null || dest == null) return;

    final pid = providerId ?? _selectedProviderId ?? 3; // Default MRT Feeder

    _isLoading = true;
    _errorMessage = null;
    _options = [];
    notifyListeners();

    try {
      final response = await _api.post(
        'journeys/plan',
        body: {
          'provider_id': pid,
          'origin_lat': origin.latitude,
          'origin_lon': origin.longitude,
          'target_lat': dest.latitude,
          'target_lon': dest.longitude,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      final items = data['items'] as List<dynamic>? ?? const [];
      _options = items
          .map((e) => JourneyOption.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

      if (_options.isEmpty) {
        _errorMessage = 'No routes found for this journey.';
      }
    } catch (_) {
      _errorMessage = 'Could not plan journey. Please try again.';
      _options = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears all journey data.
  void clear() {
    _origin = null;
    _destination = null;
    _originLabel = null;
    _destinationLabel = null;
    _options = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
