import 'dart:async';

import 'package:flutter/material.dart';
import '../../controllers/stop_controller.dart';
import '../../models/stop.dart';
import '../../models/transit_provider.dart';
import '../../models/transit_route.dart';
import '../../theme/app_theme.dart';
import '../stops/nearby_stop_card.dart';
import '../stops/provider_switcher.dart';
import '../stops/route_color_badge.dart';
import 'sheet_snap.dart';

/// Draggable bottom sheet on the live map.
///
/// Owns the drag gesture, search state, and which stop's route dropdown is
/// expanded. Height is controlled by the parent (needed to position the
/// locate button above the sheet) and reported back via [onHeightChanged].
class LiveMapBottomSheet extends StatefulWidget {
  const LiveMapBottomSheet({
    super.key,
    required this.height,
    required this.onHeightChanged,
    required this.controller,
    required this.providers,
    required this.selectedProvider,
    required this.theme,
    required this.routes,
    required this.onProviderSelected,
    required this.onSearchResultTap,
    required this.onRouteTap,
    required this.onRouteSearchSelected,
  });

  final double height;
  final ValueChanged<double> onHeightChanged;
  final StopController controller;
  final List<TransitProvider> providers;
  final TransitProvider? selectedProvider;
  final ProviderTheme theme;

  /// Loaded routes for the selected provider (bus-line search results).
  final List<TransitRoute> routes;

  final ValueChanged<TransitProvider> onProviderSelected;
  final ValueChanged<Stop> onSearchResultTap;
  final void Function(Stop stop, TransitRoute route) onRouteTap;

  /// Called when a bus line is picked from the global search.
  final ValueChanged<TransitRoute> onRouteSearchSelected;

  @override
  State<LiveMapBottomSheet> createState() => _LiveMapBottomSheetState();
}

class _LiveMapBottomSheetState extends State<LiveMapBottomSheet> {
  bool _isDragging = false;
  double _dragStartY = 0;
  double _dragStartHeight = 0;
  String _searchQuery = '';
  bool _showSearchResults = false;
  String? _expandedStopKey;

  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  List<Stop> _stopResults = [];
  List<TransitRoute> _routeResults = [];

  bool get _hasResults => _stopResults.isNotEmpty || _routeResults.isNotEmpty;

  /// Debounced search across the loaded stops and routes. Never navigates
  /// while typing — selection happens only via a tap or submit.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
        _updateResults(value);
        _showSearchResults = value.trim().length > 1;
      });
    });
  }

  void _updateResults(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      _stopResults = const [];
      _routeResults = const [];
      return;
    }
    _stopResults = widget.controller.stops
        .where((s) =>
            s.stopName.toLowerCase().contains(q) ||
            s.stopDesc.toLowerCase().contains(q) ||
            s.stopCode.toLowerCase().contains(q) ||
            s.stopId.toLowerCase().contains(q))
        .toList();
    _routeResults = widget.routes
        .where((r) =>
            r.routeShortName.toLowerCase().contains(q) ||
            r.routeLongName.toLowerCase().contains(q))
        .toList();
  }

  void _selectStop(Stop stop) {
    setState(() => _showSearchResults = false);
    widget.onSearchResultTap(stop);
  }

  void _selectRoute(TransitRoute route) {
    setState(() => _showSearchResults = false);
    widget.onRouteSearchSelected(route);
  }

  /// On submit, navigate directly only when there is exactly one
  /// high-confidence (exact) match; otherwise require a selection.
  void _onSearchSubmitted(String value) {
    final q = value.trim();
    final ql = q.toLowerCase();
    if (q.isEmpty) return;
    if (_stopResults.length + _routeResults.length == 1) {
      if (_stopResults.length == 1) {
        final stop = _stopResults.first;
        final exact = stop.stopId == q ||
            stop.stopName.toLowerCase() == ql ||
            stop.stopCode.toLowerCase() == ql;
        if (exact) {
          _selectStop(stop);
          return;
        }
      } else if (_routeResults.length == 1) {
        final route = _routeResults.first;
        final exact = route.routeShortName.toLowerCase() == ql ||
            route.routeLongName.toLowerCase() == ql;
        if (exact) {
          _selectRoute(route);
          return;
        }
      }
    }
    setState(() => _showSearchResults = true);
  }

  void _toggleStopExpansion(Stop stop) {
    final providerId = widget.selectedProvider?.id;
    if (providerId == null) return;

    final key = '$providerId/${stop.stopId}';
    setState(() {
      _expandedStopKey = _expandedStopKey == key ? null : key;
    });

    if (_expandedStopKey == key) {
      widget.controller.loadRoutesForStop(
        providerId: providerId,
        stopId: stop.stopId,
      );
    }
  }

  void _onProviderSelected(TransitProvider provider) {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _expandedStopKey = null;
      _showSearchResults = false;
      _searchQuery = '';
      _stopResults = const [];
      _routeResults = const [];
    });
    widget.onProviderSelected(provider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: const Cubic(0.16, 1, 0.3, 1),
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // full-width 48dp grab area
      onVerticalDragStart: (details) {
        setState(() {
          _isDragging = true;
          _dragStartY = details.globalPosition.dy;
          _dragStartHeight = widget.height;
        });
      },
      onVerticalDragUpdate: (details) {
        final deltaY = details.globalPosition.dy - _dragStartY;
        widget.onHeightChanged(
          (_dragStartHeight - deltaY)
              .clamp(kSheetMinHeight, kSheetExpandedHeight),
        );
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _isDragging = false;
          widget.onHeightChanged(
            kSheetSnapHeights.reduce((a, b) =>
                (a - widget.height).abs() < (b - widget.height).abs()
                    ? a
                    : b),
          );
        });
      },
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        if (_showSearchResults) ...[
          const SizedBox(height: 12),
          if (_hasResults)
            _buildSearchResults()
          else
            _buildNoResults(),
        ],
        if (widget.providers.length > 1) ...[
          const SizedBox(height: 12),
          ProviderSwitcher(
            providers: widget.providers,
            selectedProvider: widget.selectedProvider,
            onSelected: _onProviderSelected,
          ),
        ],
        const SizedBox(height: 20),
        _buildNearbyHeader(),
        const SizedBox(height: 12),
        _buildNearbyList(),
      ],
    );
  }

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      onTap: () {
        if (_hasResults) {
          setState(() => _showSearchResults = true);
        }
      },
      onSubmitted: _onSearchSubmitted,
      decoration: InputDecoration(
        hintText: 'Search bus line or station (e.g. T250)',
        prefixIcon: Icon(Icons.search_rounded,
            size: 20, color: scheme.onSurfaceVariant),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _debounce?.cancel();
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _showSearchResults = false;
                    _stopResults = const [];
                    _routeResults = const [];
                  });
                },
                icon: Icon(Icons.close_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
              )
            : null,
      ),
    );
  }

  Widget _buildSearchResults() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SEARCH RESULTS', style: textTheme.labelMedium),
                TextButton(
                  onPressed: () =>
                      setState(() => _showSearchResults = false),
                  child: const Text('Hide'),
                ),
              ],
            ),
            const Divider(height: 12),
            if (_stopResults.isNotEmpty) ...[
              _buildGroupHeader(context, 'Stops'),
              ..._stopResults.map((stop) => _buildStopRow(stop)),
              const Divider(height: 12),
            ],
            if (_routeResults.isNotEmpty) ...[
              _buildGroupHeader(context, 'Bus lines'),
              ..._routeResults.map((route) => _buildRouteRow(route)),
            ],
          ],
        ),
      ),
    );
  }

  /// Shown when a search query has no matching stops or routes. The search
  /// field (with its clear button) stays visible above so the user can adjust.
  Widget _buildNoResults() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final query = _searchQuery.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            query.isEmpty ? 'No matches found' : 'No matches for "$query"',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different stop or bus line, or clear the search.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context, String title) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(title, style: textTheme.labelMedium),
    );
  }

  Widget _buildStopRow(Stop stop) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _selectStop(stop),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.theme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on_rounded,
                  size: 14, color: AppColors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stop.stopName, style: textTheme.bodyMedium),
                  Text(
                    stop.stopDesc.isNotEmpty ? stop.stopDesc : stop.stopId,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteRow(TransitRoute route) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _selectRoute(route),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            RouteColorBadge(
              shortName: route.routeShortName,
              theme: widget.theme,
              fontSize: 12,
              iconSize: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(route.routeLongName, style: textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyHeader() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.navigation_rounded,
                size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('NEARBY STOPS', style: textTheme.labelMedium),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${widget.controller.stops.length} stops',
            style: textTheme.labelMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyList() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (widget.controller.isLoading && widget.controller.stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
      );
    }
    // When a provider is toggled and there are no stops nearby (empty/null
    // result), prefer a friendly empty message over a load error.
    if (widget.controller.stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No nearby stops', style: textTheme.bodySmall),
        ),
      );
    }

    return Column(
      children: widget.controller.stops.map((stop) {
        final providerId = widget.selectedProvider?.id;
        final expanded = providerId != null &&
            _expandedStopKey == '$providerId/${stop.stopId}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NearbyStopCard(
            stop: stop,
            theme: widget.theme,
            expanded: expanded,
            loadingRoutes: expanded &&
                widget.controller.isLoadingRoutesFor(
                  providerId: providerId,
                  stopId: stop.stopId,
                ),
            routesError: expanded
                ? widget.controller.routesErrorFor(
                    providerId: providerId,
                    stopId: stop.stopId,
                  )
                : null,
            routes: expanded
                ? widget.controller.routesForStop(
                    providerId: providerId,
                    stopId: stop.stopId,
                  )
                : null,
            onTap: () => _toggleStopExpansion(stop),
            onRouteTap: (route) => widget.onRouteTap(stop, route),
          ),
        );
      }).toList(),
    );
  }
}
