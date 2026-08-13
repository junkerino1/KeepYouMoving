import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/transit_provider.dart';
import '../models/transit_route.dart';
import '../services/api_service.dart';
import '../services/provider_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/stops/route_card.dart';
import 'route_detail_screen.dart';

// --- Routes Screen ---

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final ApiService _api = ApiService();
  final ProviderRepository _providerRepository = ProviderRepository();

  // Provider selection (dev phase: Rapid KL & MRT Feeder). Rapid KL default.
  List<TransitProvider> _providers = [];
  TransitProvider? _selectedProvider;

  // Routes for the selected provider (GET {base}/{provider_id}/routes).
  List<TransitRoute> _routes = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Resolves the dev providers from the bundled metadata (Rapid KL default).
  Future<void> _init() async {
    try {
      final all = await _providerRepository.loadProviders();
      const devKeys = {'rapid_bus_kl', 'rapid_bus_mrtfeeder'};
      final dev = all.where((p) => devKeys.contains(p.providerKey)).toList();
      if (!mounted) return;
      setState(() {
        _providers = dev;
        _selectedProvider = dev.firstWhere(
          (p) => p.providerKey == 'rapid_bus_kl',
          orElse: () => dev.first,
        );
      });
    } catch (_) {
      // Fall back to known dev provider ids if the bundled metadata is
      // unavailable (Rapid KL = 5, MRT Feeder = 3).
      if (!mounted) return;
      setState(() {
        _providers = [_rapidKl, _mrtFeeder];
        _selectedProvider = _rapidKl;
      });
    }
    _loadRoutes();
  }

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

  TransitProvider? _providerByKey(String providerKey) {
    for (final provider in _providers) {
      if (provider.providerKey == providerKey) return provider;
    }
    return null;
  }

  void _selectProvider(TransitProvider provider) {
    if (_selectedProvider?.id == provider.id) return;
    setState(() {
      _selectedProvider = provider;
      _routes = [];
      _errorMessage = null;
    });
    _loadRoutes();
  }

  /// Fetches the routes for the currently selected provider.
  Future<void> _loadRoutes() async {
    final provider = _selectedProvider;
    if (provider == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _api.get('${provider.id}/routes');
      if (response.statusCode != 200) {
        throw Exception('Server responded with ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? const [];
      final routes = data
          .map((item) => TransitRoute.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routes = [];
        _isLoading = false;
        _errorMessage = 'Could not load routes.';
      });
    }
  }

  /// Routes for the selected provider, filtered by the search query.
  List<TransitRoute> get _filteredRoutes {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _routes;
    return _routes
        .where((r) =>
            r.routeShortName.toLowerCase().contains(q) ||
            r.routeLongName.toLowerCase().contains(q))
        .toList();
  }

  void _openRouteDetail(TransitRoute route) {
    final provider = _selectedProvider;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          route: route,
          providerId: provider?.id,
          providerKey: provider?.providerKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildControls(),
        const Divider(height: 1, color: AppColors.navyBorder),
        Expanded(child: _buildContent()),
      ],
    );
  }

  /// Always-visible controls: provider toggle + search bar. These stay
  /// present regardless of the API state; only [_buildContent] changes.
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProviderFilters(),
          const SizedBox(height: 10),
          _buildSearchBar(),
        ],
      ),
    );
  }

  /// Route content area; reacts to the API state (loading / error / empty /
  /// list). The header, provider toggle and search bar stay visible above.
  Widget _buildContent() {
    if (_isLoading && _routes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
            SizedBox(height: 12),
            Text(
              'Loading routes...',
              style:
                  TextStyle(fontSize: 13, color: AppColors.navyTextSecondary),
            ),
          ],
        ),
      );
    }
    if (_errorMessage != null && _routes.isEmpty) {
      return _buildErrorState();
    }
    if (_routes.isEmpty) {
      return const Center(
        child: Text(
          'No routes available',
          style: TextStyle(fontSize: 14, color: AppColors.navyTextHint),
        ),
      );
    }
    return _buildRouteList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 28, color: AppColors.red),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.navyTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadRoutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.navyBorder)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROUTES',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: AppColors.navyTextTertiary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'All Lines',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navyTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Route List View ---

  Widget _buildRouteList() {
    // No matches: show the empty state filling the whole content area
    // (full width + height), outside the scroll view so it can expand.
    if (_filteredRoutes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: _buildEmptySearch(),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredRoutes.length} Routes',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.navyTextTertiary,
                  ),
                ),
                const Text(
                  'Tap to expand',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 9,
                    color: AppColors.navyTextHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Route Cards (API data: badge colors + route_long_name)
          ..._filteredRoutes.map((route) {
            final providerKey = _selectedProvider?.providerKey;
            return RouteCard(
              route: route,
              fallbackBadgeColor: ProviderTheme.of(providerKey).primary,
              onTap: () => _openRouteDetail(route),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyVeryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 13, color: AppColors.navyTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search bus line or station',
          hintStyle: const TextStyle(color: AppColors.navyTextHint),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.navyTextHint),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() => _searchQuery = ''),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Clear',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.navyTextSecondary)),
                  ),
                )
              : null,
          border: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildProviderFilters() {
    final rapidKlTheme = ProviderTheme.of('rapid_bus_kl');
    final feederTheme = ProviderTheme.of('rapid_bus_mrtfeeder');
    return Row(
      children: [
        Expanded(
          child: _buildFilterChip(
            label: 'Rapid KL',
            isSelected: _selectedProvider?.providerKey == 'rapid_bus_kl',
            selectedColor: rapidKlTheme.primary,
            dotColor: rapidKlTheme.primary,
            onTap: () =>
                _selectProvider(_providerByKey('rapid_bus_kl') ?? _rapidKl),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterChip(
            label: 'MRT Feeder',
            isSelected: _selectedProvider?.providerKey == 'rapid_bus_mrtfeeder',
            selectedColor: feederTheme.primary,
            dotColor: feederTheme.primary,
            onTap: () => _selectProvider(
                _providerByKey('rapid_bus_mrtfeeder') ?? _mrtFeeder),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required Color dotColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.navyBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.white : dotColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color:
                    isSelected ? AppColors.white : AppColors.navyTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.help_outline_rounded,
              size: 24, color: AppColors.navyTextHint),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'No routes found'
                : 'No routes match "$_searchQuery"',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.navyTextPrimary),
          ),
        ],
      ),
    );
  }
}
