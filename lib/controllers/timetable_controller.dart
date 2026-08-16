import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/route_schedule.dart';
import '../models/route_stop.dart';
import '../models/transit_provider.dart';
import '../models/transit_route.dart';
import '../services/api_service.dart';
import '../services/provider_repository.dart';
import '../services/route_list_cache.dart';
import '../utils/api_envelope.dart';

/// Loads the provider → routes → stops → schedule chain for the Timetable
/// screen and exposes the state reactively through [ChangeNotifier], so the
/// screen stays free of API / parsing logic.
class TimetableController extends ChangeNotifier {
  TimetableController({ApiService? apiService})
      : _api = apiService ?? ApiService();

  final ApiService _api;
  final ProviderRepository _providerRepository = ProviderRepository();

  // Provider selection (dev phase: Rapid KL & MRT Feeder). Rapid KL default.
  List<TransitProvider> _providers = [];
  TransitProvider? _selectedProvider;

  // Routes / stops / schedule for the current selection chain.
  List<TransitRoute> _routes = [];
  List<RouteStop> _stops = [];
  RouteSchedule? _schedule;

  String? _selectedRouteId;
  String? _selectedStopId;

  bool _isLoadingRoutes = false;
  bool _isLoadingStops = false;
  bool _isLoadingSchedule = false;
  String? _errorMessage;

  // --- Getters ---

  List<TransitProvider> get providers => List.unmodifiable(_providers);
  TransitProvider? get selectedProvider => _selectedProvider;

  List<TransitRoute> get routes => List.unmodifiable(_routes);
  List<RouteStop> get stops => List.unmodifiable(_stops);
  RouteSchedule? get schedule => _schedule;

  String? get selectedRouteId => _selectedRouteId;
  String? get selectedStopId => _selectedStopId;

  bool get isLoadingRoutes => _isLoadingRoutes;
  bool get isLoadingStops => _isLoadingStops;
  bool get isLoadingSchedule => _isLoadingSchedule;
  String? get errorMessage => _errorMessage;

  /// Any of the load stages (routes / stops / schedule) is in flight.
  bool get isLoading =>
      _isLoadingRoutes || _isLoadingStops || _isLoadingSchedule;

  /// Label of the currently selected route (short name), if any.
  String? get currentRouteLabel {
    final id = _selectedRouteId;
    if (id == null) return null;
    for (final r in _routes) {
      if (r.routeId == id) return r.routeShortName;
    }
    return null;
  }

  /// Label of the currently selected stop (name), if any.
  String? get currentStopLabel {
    final id = _selectedStopId;
    if (id == null) return null;
    for (final s in _stops) {
      if (s.stopId == id) return s.stopName;
    }
    return null;
  }

  /// Finds a provider by key, falling back to the known dev providers when
  /// the bundled metadata is unavailable.
  TransitProvider providerByKey(String providerKey) {
    for (final provider in _providers) {
      if (provider.providerKey == providerKey) return provider;
    }
    return providerKey == 'rapid_bus_mrtfeeder' ? _mrtFeeder : _rapidKl;
  }

  // --- Lifecycle ---

  /// Resolves the dev providers from the bundled metadata (Rapid KL default),
  /// then kicks off the step-by-step route → stops → schedule chain.
  ///
  /// When [initialRouteId] and [initialStopId] are provided (deep-link from a
  /// stop), it jumps straight to that stop's timetable, loading the whole
  /// chain instead of waiting for each picker.
  Future<void> init({
    String? initialProviderKey,
    int? initialProviderId,
    String? initialRouteId,
    String? initialStopId,
  }) async {
    try {
      final all = await _providerRepository.loadProviders();
      const devKeys = {'rapid_bus_kl', 'rapid_bus_mrtfeeder'};
      final dev = all.where((p) => devKeys.contains(p.providerKey)).toList();
      _providers = dev;
      _selectedProvider = _pickInitialProvider(
        dev,
        initialProviderKey: initialProviderKey,
        initialProviderId: initialProviderId,
      );
    } catch (_) {
      // Fall back to known dev provider ids if the bundled metadata is
      // unavailable (Rapid KL = 5, MRT Feeder = 3).
      _providers = [_rapidKl, _mrtFeeder];
      _selectedProvider =
          initialProviderKey == 'rapid_bus_mrtfeeder' ? _mrtFeeder : _rapidKl;
    }

    final hasDeepLink = initialRouteId != null && initialStopId != null;
    notifyListeners();
    if (hasDeepLink) {
      await _runDeepLink(initialRouteId, initialStopId);
    } else {
      await loadRoutes();
    }
  }

  /// Selects the provider matching the deep-link (by key, then by id),
  /// falling back to the Rapid KL default.
  TransitProvider _pickInitialProvider(
    List<TransitProvider> dev, {
    String? initialProviderKey,
    int? initialProviderId,
  }) {
    if (initialProviderKey != null) {
      for (final p in dev) {
        if (p.providerKey == initialProviderKey) return p;
      }
    }
    if (initialProviderId != null) {
      for (final p in dev) {
        if (p.id == initialProviderId) return p;
      }
    }
    return dev.firstWhere(
      (p) => p.providerKey == 'rapid_bus_kl',
      orElse: () => dev.first,
    );
  }

  /// Deep-link entry: loads routes → stops → schedule end-to-end for the given
  /// route/stop, selecting them without waiting for the step-by-step pickers.
  Future<void> _runDeepLink(String initialRouteId, String initialStopId) async {
    await loadRoutes();
    if (_errorMessage != null || _routes.isEmpty) return;

    // Prefer the requested route, otherwise fall back to the first one.
    _selectedRouteId = _routes.any((r) => r.routeId == initialRouteId)
        ? initialRouteId
        : _routes.first.routeId;
    notifyListeners();

    await loadStops(_selectedRouteId!);
    if (_errorMessage != null || _stops.isEmpty) return;

    // Prefer the requested stop, otherwise fall back to the first one.
    _selectedStopId = _stops.any((s) => s.stopId == initialStopId)
        ? initialStopId
        : _stops.first.stopId;
    notifyListeners();

    await loadSchedule(_selectedStopId!);
  }

  // --- Provider ---

  void selectProvider(TransitProvider provider) {
    if (_selectedProvider?.id == provider.id) return;
    _selectedProvider = provider;
    _routes = [];
    _stops = [];
    _schedule = null;
    _selectedRouteId = null;
    _selectedStopId = null;
    _errorMessage = null;
    notifyListeners();
    loadRoutes();
  }

  // --- Selection (from the pickers) ---

  void selectRoute(String? routeId) {
    if (routeId == null || routeId == _selectedRouteId) return;
    _selectedRouteId = routeId;
    _selectedStopId = null;
    _stops = [];
    _schedule = null;
    _errorMessage = null;
    notifyListeners();
    loadStops(routeId);
  }

  void selectStop(String? stopId) {
    if (stopId == null || stopId == _selectedStopId) return;
    _selectedStopId = stopId;
    _schedule = null;
    _errorMessage = null;
    notifyListeners();
    loadSchedule(stopId);
  }

  void retry() => loadRoutes();

  // --- Load chain ---

  /// Fetches routes for the selected provider, selects the first route and
  /// continues down the chain to stops → schedule.
  Future<void> loadRoutes() async {
    final provider = _selectedProvider;
    if (provider == null) return;
    _isLoadingRoutes = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final routes = await RouteListCache.instance.routesFor(provider.id);
      // Ignore a stale response if the provider changed mid-fetch.
      if (_selectedProvider?.id != provider.id) return;
      _routes = routes;
      _isLoadingRoutes = false;
      // Step-by-step: never auto-select a route; the user picks one next.
      _selectedRouteId = null;
      _selectedStopId = null;
      _stops = [];
      _schedule = null;
      notifyListeners();
    } catch (_) {
      // Ignore a stale failure if the provider changed mid-fetch.
      if (_selectedProvider?.id != provider.id) return;
      _routes = [];
      _isLoadingRoutes = false;
      _errorMessage = 'Could not load routes.';
      notifyListeners();
    }
  }

  Future<void> loadStops(String routeId) async {
    final provider = _selectedProvider;
    if (provider == null) return;
    _isLoadingStops = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.get('${provider.id}/$routeId/stops');
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = extractItems(decoded);
      final stops = data
          .map((e) => RouteStop.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      // Use the first direction's stops for the dropdown.
      final dir0 = stops.where((s) => s.directionId == 0).toList();
      final usable = dir0.isNotEmpty ? dir0 : stops;
      // Ignore a stale response if the route/provider changed mid-fetch.
      if (_selectedProvider?.id != provider.id ||
          _selectedRouteId != routeId) {
        return;
      }
      _stops = usable;
      _isLoadingStops = false;
      // Step-by-step: never auto-select a stop; the user picks one next.
      _selectedStopId = null;
      _schedule = null;
      notifyListeners();
    } catch (_) {
      if (_selectedProvider?.id != provider.id ||
          _selectedRouteId != routeId) {
        return;
      }
      _stops = [];
      _isLoadingStops = false;
      _errorMessage = 'Could not load stops for this route.';
      notifyListeners();
    }
  }

  Future<void> loadSchedule(String stopId) async {
    final provider = _selectedProvider;
    final routeId = _selectedRouteId;
    if (provider == null || routeId == null) return;
    _isLoadingSchedule = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response =
          await _api.get('${provider.id}/schedule/$routeId/$stopId');
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final schedule = RouteSchedule.fromJson(unwrapData(decoded));
      if (_selectedProvider?.id != provider.id ||
          _selectedRouteId != routeId ||
          _selectedStopId != stopId) {
        return;
      }
      _schedule = schedule;
      _isLoadingSchedule = false;
      notifyListeners();
    } catch (_) {
      if (_selectedProvider?.id != provider.id ||
          _selectedRouteId != routeId ||
          _selectedStopId != stopId) {
        return;
      }
      _schedule = null;
      _isLoadingSchedule = false;
      _errorMessage = 'Could not load the schedule.';
      notifyListeners();
    }
  }

  // --- Dev fallback providers ---

  /// Rapid KL Bus (id 5) — the default provider.
  static final _rapidKl = TransitProvider(
    id: 5,
    providerKey: 'rapid_bus_kl',
    providerName: 'Rapid KL Bus',
    category: 'rapid_bus',
    descShort: 'Rapid KL Bus',
    descLong: 'Rapid KL Bus',
    gtfsUrl: '',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  /// Rapid KL MRT Feeder (id 3).
  static final _mrtFeeder = TransitProvider(
    id: 3,
    providerKey: 'rapid_bus_mrtfeeder',
    providerName: 'MRT Feeder',
    category: 'rapid_bus',
    descShort: 'MRT Feeder',
    descLong: 'MRT Feeder',
    gtfsUrl: '',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );
}
