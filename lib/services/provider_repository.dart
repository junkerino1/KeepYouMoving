import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/transit_provider.dart';

/// Reads GTFS provider metadata from the bundled static JSON asset.
///
/// The JSON is a data.gov.my-style envelope:
/// `{"data": [...], "count": 15}`.
///
/// Example:
/// ```dart
/// final repo = ProviderRepository();
/// final providers = await repo.loadProviders();
/// final rapidKl = await repo.getProviderByKey('rapid_bus_kl');
/// ```
class ProviderRepository {
  ProviderRepository({this.assetPath = defaultAssetPath});

  /// Bundle-relative path to the JSON asset (relative to the `assets/` root).
  static const String defaultAssetPath = 'assets/data/providers.json';

  final String assetPath;

  /// In-memory cache so the file is only read/parsed once per app run.
  List<TransitProvider>? _cache;

  /// Loads all providers from the JSON asset (cached after the first call).
  Future<List<TransitProvider>> loadProviders() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>;

    final providers = data
        .map((item) => TransitProvider.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    _cache = providers;
    return providers;
  }

  /// Finds a single provider by its `provider_key` (e.g. `rapid_bus_kl`),
  /// or returns `null` when no match is found.
  Future<TransitProvider?> getProviderByKey(String providerKey) async {
    final providers = await loadProviders();
    for (final provider in providers) {
      if (provider.providerKey == providerKey) return provider;
    }
    return null;
  }

  /// Finds a single provider by its numeric `id`, or `null` if not found.
  Future<TransitProvider?> getProviderById(int id) async {
    final providers = await loadProviders();
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  /// Case-insensitive search over provider name, key and category.
  /// An empty query returns all providers.
  Future<List<TransitProvider>> search(String query) async {
    final providers = await loadProviders();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return providers;

    return providers
        .where((provider) =>
            provider.providerName.toLowerCase().contains(q) ||
            provider.providerKey.toLowerCase().contains(q) ||
            provider.category.toLowerCase().contains(q))
        .toList(growable: false);
  }

  /// Forgets the in-memory cache (e.g. after editing the asset during tests).
  void clearCache() => _cache = null;
}
