import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// --- Placeholder Data ---

class _RouteData {
  final String id;
  final String name;
  final String start;
  final String end;
  final String frequency;
  final int stopCount;
  final bool isRapidKL;

  const _RouteData({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.frequency,
    required this.stopCount,
    required this.isRapidKL,
  });
}

const _routes = [
  _RouteData(
    id: '250',
    name: 'LRT Wangsa Maju ⇄ Lebuh Ampang',
    start: 'LRT Wangsa Maju',
    end: 'Lebuh Ampang',
    frequency: '12 mins',
    stopCount: 32,
    isRapidKL: true,
  ),
  _RouteData(
    id: 'T801',
    name: 'MRT Kwasa Sentral ↺ Seksyen 9',
    start: 'MRT Kwasa Sentral',
    end: 'Seksyen 9',
    frequency: '15 mins',
    stopCount: 5,
    isRapidKL: false,
  ),
  _RouteData(
    id: '506',
    name: 'Bandar Utama ⇄ Putrajaya Sentral',
    start: 'Bandar Utama',
    end: 'Putrajaya Sentral',
    frequency: '30 mins',
    stopCount: 5,
    isRapidKL: true,
  ),
  _RouteData(
    id: 'T757',
    name: 'LRT Alam Megah ↺ Seksyen 27',
    start: 'LRT Alam Megah',
    end: 'Seksyen 27',
    frequency: '15 mins',
    stopCount: 5,
    isRapidKL: true,
  ),
];

class _StopData {
  final String id;
  final String name;
  final String stopNumber;

  const _StopData({
    required this.id,
    required this.name,
    required this.stopNumber,
  });
}

// Placeholder stops for each route
final _routeStops = <String, List<_StopData>>{
  '250': [
    const _StopData(id: 'stop_250_1', name: 'LRT Wangsa Maju', stopNumber: 'KL251'),
    const _StopData(id: 'stop_250_2', name: 'Tar Villa', stopNumber: 'KL252'),
    const _StopData(id: 'stop_250_3', name: 'Taman Bunga Raya', stopNumber: 'KL253'),
    const _StopData(id: 'stop_250_4', name: 'Surau Tmn Bunga Raya', stopNumber: 'KL254'),
    const _StopData(id: 'stop_250_5', name: 'UTAR Pintu 4', stopNumber: 'KL255'),
  ],
  'T801': [
    const _StopData(id: 'stop_t801_1', name: 'MRT Kwasa Sentral Entrance A', stopNumber: 'MR801'),
    const _StopData(id: 'stop_t801_2', name: 'Seksyen 8 Kota Damansara Flat', stopNumber: 'MR802'),
    const _StopData(id: 'stop_t801_3', name: 'SMK Seksyen 10 Kota Damansara', stopNumber: 'MR803'),
    const _StopData(id: 'stop_t801_4', name: 'Seksyen 9 commercial hub', stopNumber: 'MR804'),
    const _StopData(id: 'stop_t801_5', name: 'Selangor Science Park', stopNumber: 'MR805'),
  ],
  '506': [
    const _StopData(id: 'stop_506_1', name: 'Bandar Utama Bus Hub', stopNumber: 'KL501'),
    const _StopData(id: 'stop_506_2', name: 'LRT Kelana Jaya Station', stopNumber: 'KL502'),
    const _StopData(id: 'stop_506_3', name: 'Sunway Lagoon Toll Plaza', stopNumber: 'KL503'),
    const _StopData(id: 'stop_506_4', name: 'IOI Mall Puchong LDP', stopNumber: 'KL504'),
    const _StopData(id: 'stop_506_5', name: 'Putrajaya Sentral Terminal', stopNumber: 'KL505'),
  ],
  'T757': [
    const _StopData(id: 'stop_t757_1', name: 'LRT Alam Megah', stopNumber: 'SA751'),
    const _StopData(id: 'stop_t757_2', name: 'Taman Alam Megah Seksyen 27', stopNumber: 'SA752'),
    const _StopData(id: 'stop_t757_3', name: 'Flat Proton Shah Alam', stopNumber: 'SA753'),
    const _StopData(id: 'stop_t757_4', name: 'SK Seksyen 27 Shah Alam', stopNumber: 'SA754'),
  ],
};

// --- Routes Screen ---

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'rapid-bus-kl', 'rapid-bus-mrtfeeder'
  String? _selectedRouteId;
  bool _isReversed = false;
  String? _expandedStopId;

  List<_RouteData> get _filteredRoutes {
    return _routes.where((r) {
      final matchesSearch = _searchQuery.isEmpty ||
          r.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'all' ||
          (_selectedCategory == 'rapid-bus-kl' && r.isRapidKL) ||
          (_selectedCategory == 'rapid-bus-mrtfeeder' && !r.isRapidKL);
      return matchesSearch && matchesCategory;
    }).toList();
  }

  _RouteData? get _selectedRoute {
    if (_selectedRouteId == null) return null;
    return _routes.where((r) => r.id == _selectedRouteId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        _buildHeader(),
        // Content
        Expanded(
          child: _selectedRouteId != null ? _buildRouteDetail() : _buildRouteList(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.navyBorder)),
      ),
      child: _selectedRouteId != null
          ? Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRouteId = null;
                      _isReversed = false;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.navyTextTertiary),
                  ),
                ),
                const SizedBox(width: 8),
                _buildRouteBadge(_selectedRoute!),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _cleanRouteName(_selectedRoute!.name),
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navyTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : Column(
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
                const SizedBox(height: 4),
                const Text(
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

  Widget _buildRouteBadge(_RouteData route) {
    final bgColor = route.isRapidKL ? AppColors.navy : AppColors.skyDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            route.id,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.directions_bus, size: 14, color: AppColors.white),
        ],
      ),
    );
  }

  String _cleanRouteName(String name) {
    return name
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll('-', ' ')
        .replaceAll('⇄', ' ')
        .replaceAll('↺', ' ')
        .replaceAll(RegExp(r'\d+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // --- Route List View ---

  Widget _buildRouteList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          _buildSearchBar(),
          const SizedBox(height: 12),
          // Category Filters
          _buildCategoryFilters(),
          const SizedBox(height: 8),
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
          // Route Cards
          if (_filteredRoutes.isNotEmpty)
            ..._filteredRoutes.map((route) => _buildRouteCard(route))
          else
            _buildEmptySearch(),
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
          hintText: 'Search bus line or station (e.g. T250)',
          hintStyle: const TextStyle(color: AppColors.navyTextHint),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.navyTextHint),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() => _searchQuery = ''),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.navyTextSecondary)),
                  ),
                )
              : null,
          border: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterChip(
            label: 'Rapid KL',
            isSelected: _selectedCategory == 'rapid-bus-kl',
            selectedColor: AppColors.navy,
            dotColor: AppColors.navy,
            onTap: () {
              setState(() {
                _selectedCategory = _selectedCategory == 'rapid-bus-kl' ? 'all' : 'rapid-bus-kl';
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterChip(
            label: 'MRT Feeder',
            isSelected: _selectedCategory == 'rapid-bus-mrtfeeder',
            selectedColor: AppColors.skyDark,
            dotColor: AppColors.skyDark,
            onTap: () {
              setState(() {
                _selectedCategory = _selectedCategory == 'rapid-bus-mrtfeeder' ? 'all' : 'rapid-bus-mrtfeeder';
              });
            },
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
                color: isSelected ? AppColors.white : AppColors.navyTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(_RouteData route) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedRouteId = route.id),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.navyBorder),
          ),
          child: Row(
            children: [
              // Route badge
              _buildRouteBadge(route),
              const SizedBox(width: 12),
              // Route info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            route.start,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.navyTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('→', style: TextStyle(fontSize: 11, color: AppColors.navyTextHint)),
                        ),
                        Flexible(
                          child: Text(
                            route.end,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.navyTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 10, color: AppColors.navyTextHint),
                        const SizedBox(width: 4),
                        Text(
                          'Every ${route.frequency}',
                          style: const TextStyle(fontSize: 10, color: AppColors.navyTextSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(fontSize: 10, color: AppColors.navyTextHint),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${route.stopCount} stops',
                          style: const TextStyle(fontSize: 10, color: AppColors.navyTextSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.navyTextHint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.help_outline_rounded, size: 24, color: AppColors.navyTextHint),
          const SizedBox(height: 8),
          Text(
            'No routes match "$_searchQuery"',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.navyTextPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try searching for "T250", "T801", or "506".',
            style: TextStyle(fontSize: 12, color: AppColors.navyTextSecondary),
          ),
        ],
      ),
    );
  }

  // --- Route Detail View ---

  Widget _buildRouteDetail() {
    final route = _selectedRoute!;
    final stops = _routeStops[route.id] ?? [];
    final displayStops = _isReversed ? stops.reversed.toList() : stops;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Direction Changer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isReversed = !_isReversed),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.navyTextHint),
                    const SizedBox(width: 4),
                    const Text(
                      'Change Direction',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navyTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  '${displayStarts.firstOrNull?.name ?? ''} ⇄ ${displayStarts.lastOrNull?.name ?? ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.navyTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Timeline
          ...List.generate(displayStops.length, (index) {
            final stop = displayStops[index];
            final isFirst = index == 0;
            final isLast = index == displayStops.length - 1;
            final isExpanded = _expandedStopId == stop.id;

            return _buildTimelineItem(
              stop: stop,
              isFirst: isFirst,
              isLast: isLast,
              isExpanded: isExpanded,
              onTap: () {
                setState(() {
                  _expandedStopId = isExpanded ? null : stop.id;
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required _StopData stop,
    required bool isFirst,
    required bool isLast,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.navyBorder,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                Container(
                  width: isFirst || isLast ? 22 : 14,
                  height: isFirst || isLast ? 22 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst || isLast ? AppColors.navy : AppColors.white,
                    border: Border.all(
                      color: isFirst || isLast ? AppColors.navy : AppColors.navyBorder,
                      width: 2,
                    ),
                  ),
                  child: isFirst || isLast
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.white,
                            ),
                          ),
                        )
                      : Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.navyBorder,
                            ),
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.navyBorder,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Stop card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.navyBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: stop.stopNumber,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navyTextSecondary,
                                    ),
                                  ),
                                  const TextSpan(text: '  '),
                                  TextSpan(
                                    text: stop.name,
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.navyTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map_rounded, size: 10, color: AppColors.white),
                                SizedBox(width: 3),
                                Text(
                                  'Map',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.navyTextHint,
                          ),
                        ],
                      ),
                      if (isExpanded) ...[
                        const Divider(height: 20),
                        const Text(
                          'UPCOMING ARRIVALS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.navyTextTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildArrivalRow('W250-211', '3 min'),
                        const SizedBox(height: 4),
                        _buildArrivalRow('W250-322', '15 min'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalRow(String vehicle, String eta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                vehicle,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navyTextSecondary,
                ),
              ),
            ],
          ),
          Text(
            eta,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.navyTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  List<_StopData> get displayStarts {
    final route = _selectedRoute;
    if (route == null) return [];
    final stops = _routeStops[route.id] ?? [];
    return _isReversed ? stops.reversed.toList() : stops;
  }
}
