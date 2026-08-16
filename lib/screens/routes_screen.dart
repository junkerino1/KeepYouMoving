import 'package:flutter/material.dart';

import '../models/transit_provider.dart';
import '../models/transit_route.dart';
import '../services/provider_repository.dart';
import '../services/route_list_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/stops/route_card.dart';
import 'route_detail_screen.dart';

// --- Routes Screen ---

class RoutesScreen extends StatefulWidget {
  /// Optional external search query pushed from elsewhere (e.g. the global
  /// search on the map). When set, this screen switches to it and keeps using
  /// its existing filter logic.
  final ValueNotifier<String>? externalQuery;

  const RoutesScreen({super.key, this.externalQuery});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final ProviderRepository _providerRepository = ProviderRepository();
  final TextEditingController _searchController = TextEditingController();

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
    widget.externalQuery?.addListener(_onExternalQuery);
    _init();
  }

  @override
  void dispose() {
    widget.externalQuery?.removeListener(_onExternalQuery);
    _searchController.dispose();
    super.dispose();
  }

  /// Applies an externally-supplied search query (keeps the existing filter).
  void _onExternalQuery() {
    final q = widget.externalQuery?.value ?? '';
    if (_searchController.text != q) _searchController.text = q;
    if (mounted) setState(() => _searchQuery = q);
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
      final routes = await RouteListCache.instance.routesFor(provider.id);
      // Ignore a stale response if the provider changed mid-fetch.
      if (!mounted || _selectedProvider?.id != provider.id) return;
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (_) {
      // Ignore a stale failure if the provider changed mid-fetch.
      if (!mounted || _selectedProvider?.id != provider.id) return;
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
        const Divider(height: 1),
        Expanded(child: _buildContent()),
      ],
    );
  }

  /// Always-visible controls: provider toggle + search bar. These stay
  /// present regardless of the API state; only [_buildContent] changes.
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProviderFilters(),
          const SizedBox(height: 12),
          _buildSearchBar(),
        ],
      ),
    );
  }

  /// Route content area; reacts to the API state (loading / error / empty /
  /// list). The header, provider toggle and search bar stay visible above.
  Widget _buildContent() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_isLoading && _routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Loading routes...',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (_errorMessage != null && _routes.isEmpty) {
      return _buildErrorState();
    }
    if (_routes.isEmpty) {
      return Center(
        child: Text(
          'No routes available',
          style: textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return _buildRouteList();
  }

  Widget _buildErrorState() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 28, color: scheme.error),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadRoutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Lines', style: textTheme.titleMedium),
        ],
      ),
    );
  }

  // --- Route List View ---

  Widget _buildRouteList() {
    // No matches: show the empty state filling the whole content area.
    if (_filteredRoutes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildEmptySearch(),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${_filteredRoutes.length} Routes',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _filteredRoutes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final route = _filteredRoutes[index];
              return RouteCard(
                route: route,
                theme: ProviderTheme.of(_selectedProvider?.providerKey),
                onTap: () => _openRouteDetail(route),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search bus line or station',
        prefixIcon: Icon(Icons.search_rounded,
            size: 20, color: scheme.onSurfaceVariant),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: Icon(Icons.close_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
              )
            : null,
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? selectedColor : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white
                      : dotColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_outline_rounded,
              size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'No routes found'
                : 'No routes match "$_searchQuery"',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
