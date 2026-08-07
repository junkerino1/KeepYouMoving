import 'package:flutter/material.dart';
import '../../controllers/stop_controller.dart';
import '../../models/stop.dart';
import '../../models/transit_provider.dart';
import '../../models/transit_route.dart';
import '../../theme/app_theme.dart';
import '../stops/nearby_stop_card.dart';
import '../stops/provider_switcher.dart';

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
    required this.onProviderSelected,
    required this.onSearchResultTap,
    required this.onRouteTap,
  });

  final double height;
  final ValueChanged<double> onHeightChanged;
  final StopController controller;
  final List<TransitProvider> providers;
  final TransitProvider? selectedProvider;
  final ProviderTheme theme;
  final ValueChanged<TransitProvider> onProviderSelected;
  final ValueChanged<Stop> onSearchResultTap;
  final void Function(Stop stop, TransitRoute route) onRouteTap;

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

  List<Stop> get _searchResults {
    if (_searchQuery.trim().isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return widget.controller.stops
        .where((s) =>
            s.stopName.toLowerCase().contains(q) ||
            s.stopId.toLowerCase().contains(q))
        .toList();
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
    setState(() => _expandedStopKey = null);
    widget.onProviderSelected(provider);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: const Cubic(0.16, 1, 0.3, 1),
      height: widget.height,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
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
      behavior: HitTestBehavior.opaque, // enlarge the touch area
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
          (_dragStartHeight - deltaY).clamp(140.0, 600.0),
        );
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _isDragging = false;
          const snaps = [140.0, 450.0, 600.0];
          widget.onHeightChanged(
            snaps.reduce((a, b) =>
                (a - widget.height).abs() < (b - widget.height).abs()
                    ? a
                    : b),
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.navyBorder,
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
        if (_showSearchResults && _searchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSearchResults(),
        ],
        if (widget.providers.length > 1) ...[
          const SizedBox(height: 12),
          ProviderSwitcher(
            providers: widget.providers,
            selectedProvider: widget.selectedProvider,
            onSelected: _onProviderSelected,
          ),
        ],
        const SizedBox(width: double.infinity, height: 60),
        _buildNearbyHeader(),
        const SizedBox(height: 12),
        _buildNearbyList(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navyVeryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.navyBorder),
        ),
        child: TextField(
          onChanged: (v) {
            setState(() {
              _searchQuery = v;
              _showSearchResults = v.trim().length > 1;
            });
          },
          onTap: () {
            if (_searchResults.isNotEmpty) {
              setState(() => _showSearchResults = true);
            }
          },
          style: const TextStyle(fontSize: 13, color: AppColors.navyTextPrimary),
          decoration: InputDecoration(
            hintText: 'Search bus line or station (e.g. T250)',
            hintStyle: const TextStyle(color: AppColors.navyTextHint),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: AppColors.navyTextHint),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => setState(() {
                      _searchQuery = '';
                      _showSearchResults = false;
                    }),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Clear',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.navyTextSecondary)),
                    ),
                  )
                : null,
            border: InputBorder.none,
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SEARCH RESULTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.navyTextTertiary,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showSearchResults = false),
                child: const Text('Hide',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.navyTextSecondary)),
              ),
            ],
          ),
          const Divider(height: 12),
          ..._searchResults.map((stop) => GestureDetector(
                onTap: () => widget.onSearchResultTap(stop),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.stopName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.navyTextPrimary,
                              ),
                            ),
                            Text(
                              stop.stopDesc.isNotEmpty
                                  ? stop.stopDesc
                                  : stop.stopId,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.navyTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.navyTextHint),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildNearbyHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.navigation_rounded,
                size: 14, color: AppColors.navyTextTertiary),
            const SizedBox(width: 6),
            const Text(
              'NEARBY STOPS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.navyTextTertiary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.navyVeryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${widget.controller.stops.length} stops',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.navyTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyList() {
    if (widget.controller.isLoading && widget.controller.stops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.navy,
          ),
        ),
      );
    }
    if (widget.controller.errorMessage != null &&
        widget.controller.stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            widget.controller.errorMessage!,
            style: const TextStyle(fontSize: 12, color: AppColors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (widget.controller.stops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No stops nearby',
            style: TextStyle(fontSize: 12, color: AppColors.navyTextHint),
          ),
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
            accentColor: widget.theme.primary,
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
