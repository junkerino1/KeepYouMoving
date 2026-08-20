import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../controllers/journey_controller.dart';
import '../models/journey_option.dart';
import '../models/transit_provider.dart';
import '../services/app_location_service.dart';
import '../services/provider_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/stops/provider_switcher.dart';
import '../widgets/stops/route_color_badge.dart';
import 'journey_detail_screen.dart';

/// A place result from OSM Nominatim search.
class _PlaceResult {
  final String displayName;
  final double lat;
  final double lon;

  const _PlaceResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory _PlaceResult.fromJson(Map<String, dynamic> json) {
    return _PlaceResult(
      displayName: json['display_name'] as String? ?? '',
      lat: double.tryParse(json['lat'] as String? ?? '') ?? 0,
      lon: double.tryParse(json['lon'] as String? ?? '') ?? 0,
    );
  }
}

/// Which search field the suggestion dropdown currently belongs to.
enum _SearchField { origin, destination }

/// Journey planner screen: searchable origin/destination, plan routes, view
/// results on a map with walking polylines.
class JourneyPlannerScreen extends StatefulWidget {
  final int? providerId;
  final String? providerKey;

  const JourneyPlannerScreen({
    super.key,
    this.providerId,
    this.providerKey,
  });

  @override
  State<JourneyPlannerScreen> createState() => _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends State<JourneyPlannerScreen> {
  final JourneyController _controller = JourneyController();
  final TextEditingController _originSearchController = TextEditingController();
  final TextEditingController _destSearchController = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  LatLng? _currentPosition;
  bool _isSearchingOrigin = false;
  bool _isSearchingDest = false;

  // Provider selection
  List<TransitProvider> _providers = [];
  TransitProvider? _selectedProvider;

  // Search results
  List<_PlaceResult> _searchResults = [];
  bool _isSearchingPlaces = false;
  bool _hasSearched = false; // true after first search completes
  Timer? _searchDebounce;

  // Guards auto-commit while we programmatically move focus (e.g. when a
  // suggestion is explicitly selected or the panel is collapsed).
  bool _suppressAutoSelect = false;

  // Bumped on every search/dismiss; only the latest request may apply its
  // result, so stale responses never overwrite newer ones.
  int _searchGeneration = 0;

  // Set when a field is dismissed while its search is still pending or in
  // flight; the first result is auto-selected as soon as it arrives, so a fast
  // typer who tapped away before the dropdown appeared still gets their choice.
  _SearchField? _pendingAutoSelectOnDismiss;

  // Keys used to measure the fields for the anchored suggestion dropdown.
  final GlobalKey _originFieldKey = GlobalKey();
  final GlobalKey _destFieldKey = GlobalKey();
  final GlobalKey _suggestionDropdownKey = GlobalKey();

  // Anchored suggestion dropdown — rendered in the root overlay so it always
  // paints above the search panel and is reliably hit-testable.
  final OverlayPortalController _originSuggestionsPortal =
      OverlayPortalController();
  final OverlayPortalController _destSuggestionsPortal =
      OverlayPortalController();
  final LayerLink _originLink = LayerLink();
  final LayerLink _destLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _loadProviders();
    _originFocus.addListener(_onOriginFocusChange);
    _destFocus.addListener(_onDestFocusChange);
  }

  Future<void> _loadProviders() async {
    try {
      final repo = ProviderRepository();
      final all = await repo.loadProviders();
      const devKeys = {'rapid_bus_kl', 'rapid_bus_mrtfeeder'};
      final dev = all.where((p) => devKeys.contains(p.providerKey)).toList();
      if (!mounted) return;
      setState(() {
        _providers = dev;
        _selectedProvider ??= dev.firstWhere(
          (p) => p.providerKey == 'rapid_bus_kl',
          orElse: () => dev.first,
        );
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _originSearchController.dispose();
    _destSearchController.dispose();
    _originFocus.removeListener(_onOriginFocusChange);
    _destFocus.removeListener(_onDestFocusChange);
    _originFocus.dispose();
    _destFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onOriginFocusChange() {
    if (!mounted) return;
    final nowFocused = _originFocus.hasFocus;
    if (nowFocused) {
      // Engaging with this field again — cancel any earlier pending auto-select.
      _pendingAutoSelectOnDismiss = null;
      final wasDest = _isSearchingDest;
      setState(() {
        _isSearchingOrigin = true;
        _isSearchingDest = false;
      });
      // Switching fields must never reuse the previous field's suggestions.
      if (wasDest) _resetTransientSearch();
    } else if (_isSearchingOrigin) {
      // Remember the field before clearing so auto-commit targets it.
      final forField = _activeFieldFor;
      setState(() => _isSearchingOrigin = false);
      // Only commit when the search interaction is dismissed entirely (the
      // destination field did not take over).
      if (!_destFocus.hasFocus && !_suppressAutoSelect) {
        _autoSelectFirst(forField);
      }
    }
    _updateSuggestionsPortals();
  }

  void _onDestFocusChange() {
    if (!mounted) return;
    final nowFocused = _destFocus.hasFocus;
    if (nowFocused) {
      // Engaging with this field again — cancel any earlier pending auto-select.
      _pendingAutoSelectOnDismiss = null;
      final wasOrigin = _isSearchingOrigin;
      setState(() {
        _isSearchingDest = true;
        _isSearchingOrigin = false;
      });
      if (wasOrigin) _resetTransientSearch();
    } else if (_isSearchingDest) {
      final forField = _activeFieldFor;
      setState(() => _isSearchingDest = false);
      if (!_originFocus.hasFocus && !_suppressAutoSelect) {
        _autoSelectFirst(forField);
      }
    }
    _updateSuggestionsPortals();
  }

  Future<void> _fetchCurrentLocation() async {
    final pos = await AppLocationService.instance.getInitialLatLng();
    if (!mounted || pos == null) return;
    setState(() => _currentPosition = pos);
  }

  void _useCurrentLocationAsOrigin() {
    final pos = _currentPosition;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not determine your location.')),
      );
      return;
    }
    _suppressAutoSelect = true;
    _controller.setOrigin(pos, label: 'Current location');
    _originSearchController.text = 'Current location';
    setState(() => _isSearchingOrigin = false);
    _originFocus.unfocus();
    _suppressAutoSelect = false;
    _dismissSuggestions();
  }

  /// Debounced OSM Nominatim search.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    // New input means an active search interaction — drop any stale pending
    // auto-select from a previous dismissal.
    _pendingAutoSelectOnDismiss = null;
    final q = query.trim();
    if (q.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearchingPlaces = false;
        _hasSearched = false;
      });
    }
    // Reflect the typed query in the dropdown immediately.
    _updateSuggestionsPortals();
    if (q.length >= 3) {
      _searchDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _searchPlaces(q);
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isSearchingPlaces = true;
      _searchResults = [];
      _hasSearched = false;
    });
    try {
      // External geocoding service; first-party auth headers do not apply.
      // Bias results towards KL area.
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=6'
        '&countrycodes=my'
        '&viewbox=101.0,2.5,102.0,3.5'
        '&bounded=0',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'RapidTransitKL/1.0 (transit app)',
      }).timeout(const Duration(seconds: 8));

      // Ignore a stale response (field switched or search restarted).
      if (!mounted || generation != _searchGeneration) return;
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _searchResults = data
            .map((e) => _PlaceResult.fromJson(e as Map<String, dynamic>))
            .toList();
        _isSearchingPlaces = false;
        _hasSearched = true;
      });
      // If the field was dismissed before this search finished, commit the
      // first result now so the user's typed text is still resolved.
      final pending = _pendingAutoSelectOnDismiss;
      if (pending != null) {
        _pendingAutoSelectOnDismiss = null;
        if (_textFor(pending).trim().isNotEmpty) {
          _autoSelectFirst(pending);
          return;
        }
      }
      _updateSuggestionsPortals();
    } catch (_) {
      // Ignore a stale failure (field switched or search restarted).
      if (!mounted || generation != _searchGeneration) return;
      _pendingAutoSelectOnDismiss = null;
      setState(() {
        _isSearchingPlaces = false;
        _searchResults = [];
        _hasSearched = true;
      });
      _updateSuggestionsPortals();
    }
  }

  void _selectPlace(_PlaceResult place, {_SearchField? forField}) {
    _pendingAutoSelectOnDismiss = null;
    _suppressAutoSelect = true;
    _applyPlace(place, forField: forField);
    _suppressAutoSelect = false;
    _dismissSuggestions();
  }

  /// Applies [place] to the field identified by [forField] (defaults to the
  /// currently active field), committing the selected location.
  void _applyPlace(_PlaceResult place, {_SearchField? forField}) {
    final target = forField ?? _activeFieldFor;
    final pos = LatLng(place.lat, place.lon);
    final label = _shortenPlaceName(place.displayName);
    switch (target) {
      case _SearchField.origin:
        _controller.setOrigin(pos, label: label);
        _originSearchController.text = label;
        setState(() => _isSearchingOrigin = false);
        _originFocus.unfocus();
      case _SearchField.destination:
        _controller.setDestination(pos, label: label);
        _destSearchController.text = label;
        setState(() => _isSearchingDest = false);
        _destFocus.unfocus();
      case null:
        break;
    }
  }

  /// Commits the first available suggestion when the search interaction is
  /// dismissed without an explicit selection (tapping elsewhere / losing
  /// focus). No-op when there is nothing to select.
  void _autoSelectFirst(_SearchField? forField) {
    if (forField == null) return;
    if (_searchResults.isEmpty || _isSearchingPlaces) return;
    _suppressAutoSelect = true;
    _applyPlace(_searchResults.first, forField: forField);
    _suppressAutoSelect = false;
    _dismissSuggestions();
  }

  /// Closes the suggestion dropdown and resets transient search state.
  void _dismissSuggestions() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _pendingAutoSelectOnDismiss = null;
    setState(() {
      _isSearchingOrigin = false;
      _isSearchingDest = false;
      _searchResults = [];
      _isSearchingPlaces = false;
      _hasSearched = false;
    });
    _updateSuggestionsPortals();
  }

  /// Clears transient search results while keeping the active field.
  void _resetTransientSearch() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _pendingAutoSelectOnDismiss = null;
    setState(() {
      _searchResults = [];
      _isSearchingPlaces = false;
      _hasSearched = false;
    });
    _updateSuggestionsPortals();
  }

  /// Handles taps outside the search fields (via [TextField.onTapOutside]).
  ///
  /// Taps on the suggestion dropdown are ignored so the tapped row can select
  /// the choice while the field keeps focus. Taps on either search field just
  /// move focus (never auto-commit). Any other outside tap dismisses the
  /// search interaction, committing the first suggestion if one is available.
  void _handleFieldTapOutside(PointerDownEvent event) {
    final dropdownBox =
        _suggestionDropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (dropdownBox != null) {
      final local = dropdownBox.globalToLocal(event.position);
      if (dropdownBox.size.contains(local)) return;
    }
    for (final key in [_originFieldKey, _destFieldKey]) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final local = box.globalToLocal(event.position);
        if (box.size.contains(local)) return;
      }
    }
    _dismissSearchOnOutsideTap();
  }

  /// Dismisses the search interaction after a genuine outside tap: commits the
  /// first suggestion if one is available, otherwise drops focus and closes the
  /// dropdown. If the search is still pending or in flight, remembers to commit
  /// the first result once it lands (covers fast typers who tap away before the
  /// dropdown appears).
  void _dismissSearchOnOutsideTap() {
    final forField = _activeFieldFor;
    if (forField == null) {
      _dismissSuggestions();
      return;
    }
    // Search already finished → commit the first result immediately.
    if (_searchResults.isNotEmpty && !_isSearchingPlaces) {
      _autoSelectFirst(forField);
      return;
    }
    // Search still pending or in flight → keep the raw typed text and commit
    // the first result as soon as the search lands.
    if (_isSearchingPlaces || (_searchDebounce?.isActive ?? false)) {
      _pendingAutoSelectOnDismiss = forField;
    }
    if (forField == _SearchField.origin) _originFocus.unfocus();
    if (forField == _SearchField.destination) _destFocus.unfocus();
    if (_pendingAutoSelectOnDismiss == null) {
      _dismissSuggestions();
    }
  }

  String _shortenPlaceName(String fullName) {
    // Take the first 3 comma-separated parts for a shorter label.
    final parts = fullName.split(',').map((s) => s.trim()).toList();
    if (parts.length <= 3) return fullName;
    return parts.take(3).join(', ');
  }

  Future<void> _planJourney() async {
    _originFocus.unfocus();
    _destFocus.unfocus();
    _dismissSuggestions();
    final providerId = _selectedProvider?.id ?? widget.providerId ?? 3;
    await _controller.planJourney(providerId: providerId);
  }

  /// Opens the journey detail screen for the selected result.
  void _onOptionTap(JourneyOption option) {
    _originFocus.unfocus();
    _destFocus.unfocus();
    _dismissSuggestions();
    final providerId = _selectedProvider?.id ?? widget.providerId ?? 3;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JourneyDetailScreen(
          option: option,
          origin: _controller.origin,
          destination: _controller.destination,
          originLabel: _controller.originLabel,
          destinationLabel: _controller.destinationLabel,
          providerId: providerId,
          providerKey: _selectedProvider?.providerKey ?? widget.providerKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Screen header (same height/placement as the other screens).
        _buildScreenHeader(),
        // Search form.
        _buildSearchPanel(),
        const Divider(height: 1),
        // Results list (no map — each result is a tappable container).
        Expanded(child: _buildResults()),
      ],
    );
  }

  /// Renders the journey results (loading / error / empty / list) below the
  /// search panel. Each result is a tappable container.
  Widget _buildResults() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.options.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    strokeWidth: 2, color: scheme.primary),
                const SizedBox(height: 12),
                Text('Finding routes...',
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          );
        }
        if (_controller.errorMessage != null && _controller.options.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 28, color: scheme.error),
                  const SizedBox(height: 8),
                  Text(
                    _controller.errorMessage!,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _planJourney,
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
        if (_controller.options.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_rounded,
                      size: 32, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 10),
                  Text(
                    'Plan a journey to see route options.',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final options = _controller.options;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${options.length} route${options.length == 1 ? '' : 's'} found',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: options.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildJourneyCard(options[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Screen header ---

  /// Standard screen header — same height, alignment and placement as the
  /// other screens (e.g. Routes / Timetable): a bordered container with the
  /// title. No leading icon, no collapse control.
  Widget _buildScreenHeader() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Text('Plan Journey', style: textTheme.titleMedium),
    );
  }

  // --- Search form (static, not collapsible) ---

  Widget _buildSearchPanel() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bus operator toggle.
          if (_providers.length > 1) ...[
            ProviderSwitcher(
              providers: _providers,
              selectedProvider: _selectedProvider,
              onSelected: (p) {
                setState(() => _selectedProvider = p);
                // Results are provider-specific; require a fresh search.
                _controller.clearResults();
              },
            ),
            const SizedBox(height: 20),
          ],
          // Combined origin/destination form (Google Maps style).
          _buildJourneyForm(),
          const SizedBox(height: 12),
          // Find routes.
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return FilledButton.icon(
                onPressed: _controller.canPlan ? _planJourney : null,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Find routes'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.errorMessage == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _controller.errorMessage!,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Google Maps-style combined origin/destination form. The origin dot (O), a
  /// grip handle (⋮) between the rows, and the destination pin sit in a leading
  /// column; each field is a clean, borderless row with an x clear button on
  /// the right; the swap button (↕) floats on the right, vertically centred
  /// between the two fields. No background box — the rows just sit together.
  Widget _buildJourneyForm() {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Column(
          children: [
            // Origin row: marker on the left, borderless field with x clear
            // on the right.
            _buildFormRow(
              marker: Icon(Icons.trip_origin,
                  size: 20, color: AppColors.emeraldDark),
              field: _buildSearchField(
                controller: _originSearchController,
                focusNode: _originFocus,
                fieldKey: _originFieldKey,
                hint: 'Choose starting point',
                isOrigin: true,
                isActive: _isSearchingOrigin,
                onChanged: _onSearchChanged,
              ),
            ),
            // Grip handle between the two fields (no divider line).
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Center(child: _buildGripHandle()),
                ),
                const Spacer(),
                const SizedBox(width: 44),
              ],
            ),
            // Destination row.
            _buildFormRow(
              marker: Icon(Icons.location_on_rounded,
                  size: 20, color: AppColors.red),
              field: _buildSearchField(
                controller: _destSearchController,
                focusNode: _destFocus,
                fieldKey: _destFieldKey,
                hint: 'Choose destination',
                isOrigin: false,
                isActive: _isSearchingDest,
                onChanged: _onSearchChanged,
              ),
            ),
          ],
        ),
        // Swap button floating on the right, centred between the fields. Only
        // shown once both fields have a value.
        ListenableBuilder(
          listenable: Listenable.merge(
            [_originSearchController, _destSearchController],
          ),
          builder: (context, _) {
            final bothFilled = _originSearchController.text.trim().isNotEmpty &&
                _destSearchController.text.trim().isNotEmpty;
            return Positioned(
              right: 40,
              top: 0,
              bottom: 0,
              child: Center(
                child:
                    bothFilled ? _buildSwapButton() : const SizedBox.shrink(),
              ),
            );
          },
        ),
      ],
    );
  }

  /// One row of the journey form: a leading marker icon followed by the field.
  Widget _buildFormRow({required Widget marker, required Widget field}) {
    return Row(
      children: [
        SizedBox(width: 44, child: Center(child: marker)),
        Expanded(child: field),
      ],
    );
  }

  /// Grip handle (3 dots) shown between the two search rows, mimicking the
  /// Google Maps journey planner.
  Widget _buildGripHandle() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Circular swap control between origin and destination. This is a separate
  /// interaction from the panel hide/show chevron.
  Widget _buildSwapButton() {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final enabled = _controller.canPlan;
        final bg = enabled ? scheme.primary : scheme.surfaceContainerHigh;
        final fg = enabled ? scheme.onPrimary : scheme.onSurfaceVariant;
        return Semantics(
          button: true,
          label: 'Swap origin and destination',
          enabled: enabled,
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            elevation: enabled ? 2 : 0,
            child: InkWell(
              onTap: enabled ? _swapJourney : null,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.swap_vert_rounded, size: 20, color: fg),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Swaps origin/destination values and the matching field text.
  void _swapJourney() {
    _controller.swap();
    setState(() {
      final originText = _originSearchController.text;
      _originSearchController.text = _destSearchController.text;
      _destSearchController.text = originText;
    });
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required GlobalKey fieldKey,
    required String hint,
    required bool isOrigin,
    required bool isActive,
    required ValueChanged<String> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final link = isOrigin ? _originLink : _destLink;
    final portal = isOrigin ? _originSuggestionsPortal : _destSuggestionsPortal;
    // Clean, borderless text row (Google Maps style). The marker icon lives in
    // the leading column of the form, not inside the field. An x clear button
    // appears on the right once the field has text.
    //
    // The field is wrapped in a CompositedTransformTarget + OverlayPortal so
    // the suggestion dropdown renders in the ROOT overlay, anchored just below
    // this field — always on top of the search panel and reliably tappable.
    return CompositedTransformTarget(
      link: link,
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (_) => CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: Offset.zero,
          showWhenUnlinked: false,
          // The Overlay lays its entries out with full-screen constraints, and
          // the follower passes those tight constraints straight to its child,
          // which would force the dropdown to fill the whole screen. The
          // UnconstrainedBox breaks that so the dropdown sizes to its natural
          // content (field width x up to 320px tall).
          child: UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width:
                  _activeFieldWidth ?? (MediaQuery.sizeOf(context).width - 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _buildSuggestionDropdown(),
              ),
            ),
          ),
        ),
        child: Container(
          key: fieldKey,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onTapOutside: _handleFieldTapOutside,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
              // A little more left padding so the text/hint doesn't hug the
              // marker column.
              contentPadding: const EdgeInsets.fromLTRB(12, 18, 4, 18),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                        if (isActive) {
                          setState(() {
                            if (isOrigin) {
                              _controller.clearOrigin();
                            } else {
                              _controller.clearDestination();
                            }
                          });
                        }
                      },
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: scheme.onSurfaceVariant),
                      tooltip: 'Clear',
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // --- Suggestion dropdown (anchored below the active field) ---

  /// Whether the suggestion dropdown should be visible right now.
  bool get _shouldShowSuggestions {
    final active = _activeFieldFor;
    if (active == null) return false;
    final query = _activeFieldText.trim();
    // Origin + empty → "Use my current location" option.
    if (active == _SearchField.origin && query.isEmpty) return true;
    // Any field with text → loading / results / empty states.
    return query.isNotEmpty;
  }

  _SearchField? get _activeFieldFor {
    if (_isSearchingOrigin) return _SearchField.origin;
    if (_isSearchingDest) return _SearchField.destination;
    return null;
  }

  String get _activeFieldText => _isSearchingOrigin
      ? _originSearchController.text
      : _destSearchController.text;

  /// Text currently in the given field, regardless of which one is active.
  String _textFor(_SearchField field) => field == _SearchField.origin
      ? _originSearchController.text
      : _destSearchController.text;

  GlobalKey get _activeFieldKey =>
      _isSearchingOrigin ? _originFieldKey : _destFieldKey;

  /// Width of the currently active search field, used to size the anchored
  /// suggestion dropdown so it matches the field.
  double? get _activeFieldWidth {
    final box =
        _activeFieldKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width;
  }

  /// Shows/hides the anchored suggestion dropdowns to match the current search
  /// state. Must be called after any state change that affects
  /// [_shouldShowSuggestions].
  void _updateSuggestionsPortals() {
    if (!mounted) return;
    if (_shouldShowSuggestions) {
      if (_isSearchingOrigin) {
        _originSuggestionsPortal.show();
        _destSuggestionsPortal.hide();
      } else if (_isSearchingDest) {
        _destSuggestionsPortal.show();
        _originSuggestionsPortal.hide();
      } else {
        _originSuggestionsPortal.hide();
        _destSuggestionsPortal.hide();
      }
    } else {
      _originSuggestionsPortal.hide();
      _destSuggestionsPortal.hide();
    }
  }

  Widget _buildSuggestionDropdown() {
    final query = _activeFieldText.trim();
    // The field this dropdown belongs to — captured now so a tapped row always
    // targets it, even if focus state changes before the tap is processed.
    final forField = _activeFieldFor;
    final children = <Widget>[];

    // "Use my current location" — only for the origin field while empty.
    if (_isSearchingOrigin && query.isEmpty) {
      children.add(_buildLocationOption());
    }

    if (query.isNotEmpty) {
      if (_isSearchingPlaces) {
        children.add(_buildSuggestionLoading());
      } else if (_searchResults.isNotEmpty) {
        // Keep the dropdown compact: show at most 3 suggestions.
        for (final place in _searchResults.take(3)) {
          children.add(_buildSuggestionTile(place, forField: forField));
        }
      } else if (_hasSearched) {
        children.add(_buildNoMatches(query));
      } else {
        children.add(_buildKeepTypingHint());
      }
    }

    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: _suggestionDropdownKey,
      elevation: 6,
      shadowColor: const Color(0x330F172A),
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: children,
      ),
    );
  }

  Widget _buildLocationOption() {
    final scheme = Theme.of(context).colorScheme;
    return _buildDropdownRow(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.my_location_rounded, size: 18, color: scheme.primary),
      ),
      title: 'Use my current location',
      subtitle: 'Locate me',
      onTap: _useCurrentLocationAsOrigin,
    );
  }

  Widget _buildSuggestionTile(_PlaceResult place, {_SearchField? forField}) {
    final scheme = Theme.of(context).colorScheme;
    final (title, subtitle) = _splitPlaceName(place.displayName);
    return _buildDropdownRow(
      leading:
          Icon(Icons.location_on_outlined, size: 18, color: scheme.primary),
      title: title,
      subtitle: subtitle,
      onTap: () => _selectPlace(place, forField: forField),
    );
  }

  Widget _buildDropdownRow({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Splits an OSM display name into a primary title and a location subtitle.
  (String, String) _splitPlaceName(String displayName) {
    final parts = displayName
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return (displayName, '');
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.sublist(1).join(', '));
  }

  Widget _buildSuggestionLoading() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Text('Searching places...', style: textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildNoMatches(String query) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No matches for "$query"',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Try a different place or tap the map.',
              style: textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildKeepTypingHint() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined,
              size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('Keep typing to search for a place.',
              style: textTheme.bodyMedium),
        ],
      ),
    );
  }

  /// Compact, tappable journey result shown as a container in the results
  /// list. Tapping it opens the journey detail screen (map + info sheet).
  ///
  /// Card styling follows the live map's route cards: a bordered container
  /// with the provider-colored [RouteColorBadge] for the route number. The
  /// badge color follows the selected provider type (see [ProviderTheme]).
  Widget _buildJourneyCard(JourneyOption option) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final theme =
        ProviderTheme.of(_selectedProvider?.providerKey ?? widget.providerKey);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onOptionTap(option),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route badge + transfers.
                Row(
                  children: [
                    RouteColorBadge(
                      shortName: option.routeShortName,
                      theme: theme,
                      fontSize: 13,
                      iconSize: 14,
                    ),
                    if (option.transferCount > 0) ...[
                      const SizedBox(width: 10),
                      Text(
                        '${option.transferCount} '
                        'transfer${option.transferCount > 1 ? 's' : ''}',
                        style: textTheme.labelMedium
                            ?.copyWith(color: scheme.error),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStopRow(
                  icon: Icons.login_rounded,
                  label: 'Board at',
                  stopName: option.boardingStop.stopName,
                  stopCode: option.boardingStop.stopCode,
                  distance: option.boardingStop.distanceM,
                  color: AppColors.emeraldDark,
                ),
                const SizedBox(height: 8),
                _buildStopRow(
                  icon: Icons.logout_rounded,
                  label: 'Get off at',
                  stopName: option.targetStop.stopName,
                  stopCode: option.targetStop.stopCode,
                  distance: option.targetStop.distanceM,
                  color: AppColors.red,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStopRow({
    required IconData icon,
    required String label,
    required String stopName,
    required String stopCode,
    required double distance,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              Text(
                stopName,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (stopCode.isNotEmpty)
              Text(stopCode,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  )),
            Text(
              formatDistance(distance),
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
