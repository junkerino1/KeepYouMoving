import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/stop_controller.dart';
import '../models/stop.dart';
import '../models/transit_provider.dart';
import '../models/transit_route.dart';
import '../services/provider_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common/map_status_chip.dart';
import '../widgets/map/live_map.dart';
import '../widgets/map/nearest_stop_marker.dart';
import '../widgets/map/user_location_marker.dart';
import '../widgets/sheets/live_map_bottom_sheet.dart';
import '../widgets/stops/provider_switcher.dart';
import 'stop_detail_screen.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  static const _defaultCenter = LatLng(3.2066, 101.7317);

  final MapController _mapController = MapController();
  final ProviderRepository _providerRepository = ProviderRepository();
  final StopController _stopController = StopController();
  LatLng? _currentPosition;
  bool _isLocating = false;
  double _bottomSheetHeight = 450;

  // Provider switching (dev phase: Rapid KL Bus & MRT Feeder).
  List<TransitProvider> _providers = [];
  TransitProvider? _selectedProvider;

  /// Theme of the currently selected provider; drives provider-related
  /// buttons, icons and markers.
  ProviderTheme get _providerTheme =>
      ProviderTheme.of(_selectedProvider?.providerKey);

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _loadProviders();
  }

  @override
  void dispose() {
    _stopController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      final all = await _providerRepository.loadProviders();
      // Dev phase: only Rapid KL Bus (5) and MRT Feeder (3).
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
      _refreshStops();
    } catch (_) {
      // Keep the UI working without provider data (e.g. during tests).
    }
  }

  /// Fetches the nearest stops for the selected provider around the user's
  /// current GPS position.
  void _refreshStops() {
    final position = _currentPosition;
    final provider = _selectedProvider;
    if (position == null || provider == null) return;
    _stopController.loadNearestStops(
      providerId: provider.id,
      origin: position,
    );
  }

  /// Fetches the user's live GPS position and centers the map on it.
  Future<void> _fetchCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = latLng;
        _isLocating = false;
      });
      _centerOn(latLng);
      _refreshStops();
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Re-centers the map on the user's current position (fetching it if needed).
  void _centerOnCurrent() {
    final position = _currentPosition;
    if (position == null) {
      _fetchCurrentLocation();
      return;
    }
    _centerOn(position);
  }

  void _centerOn(LatLng point) {
    try {
      _mapController.move(point, _mapController.camera.zoom);
    } catch (_) {
      _mapController.move(point, 15.0);
    }
  }

  void _openStopDetail(Stop stop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopDetailScreen(
          stopName: stop.stopName,
          stopLine: _selectedProvider == null
              ? ''
              : providerShortLabel(_selectedProvider!),
          latitude: stop.stopLat,
          longitude: stop.stopLon,
          stopId: stop.stopId,
          providerId: _selectedProvider?.id,
          providerKey: _selectedProvider?.providerKey,
        ),
      ),
    );
  }

  /// Opens the stop detail screen for a specific route serving [stop].
  void _openRouteDetail(Stop stop, TransitRoute route) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopDetailScreen(
          stopName: stop.stopName,
          stopLine: route.routeShortName,
          latitude: stop.stopLat,
          longitude: stop.stopLon,
          stopId: stop.stopId,
          providerId: _selectedProvider?.id,
          providerKey: _selectedProvider?.providerKey,
          route: route,
        ),
      ),
    );
  }

  void _onProviderSelected(TransitProvider provider) {
    setState(() => _selectedProvider = provider);
    _refreshStops();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _stopController,
      builder: (context, _) {
        final markerLayers = <MarkerLayer>[
          // Marker for the user's live location
          MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition ?? _defaultCenter,
                width: 40,
                height: 40,
                child: const UserLocationMarker(),
              ),
            ],
          ),
          // Nearest stops for the currently selected provider
          if (_stopController.hasStops)
            MarkerLayer(
              markers: [
                for (final stop in _stopController.stops)
                  Marker(
                    point: LatLng(stop.stopLat, stop.stopLon),
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: NearestStopMarker(color: _providerTheme.primary),
                  ),
              ],
            ),
        ];

        return Stack(
          children: [
            // Map Layer
            LiveMap(
              mapController: _mapController,
              initialCenter: _defaultCenter,
              initialZoom: 15.0,
              tileUrlTemplate:
                  'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              markerLayers: markerLayers,
            ),
            // Map Active Badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.navyBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.navigation_rounded,
                        size: 10, color: AppColors.navyTextTertiary),
                    const SizedBox(width: 6),
                    const Text(
                      'Map Active',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navyTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Center-on-location button
            Positioned(
              right: 12,
              bottom: _bottomSheetHeight + 16,
              child: FloatingActionButton.small(
                heroTag: 'locateMe',
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.navy,
                elevation: 2,
                onPressed: _centerOnCurrent,
                child: _isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.navy,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
            // Nearest-stops fetch status
            if (_stopController.isLoading)
              const Positioned(
                top: 12,
                left: 12,
                child: MapStatusChip.loading(),
              )
            else if (_stopController.errorMessage != null)
              Positioned(
                top: 12,
                left: 12,
                child: MapStatusChip.error(_stopController.errorMessage!),
              ),
            // Bottom Sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LiveMapBottomSheet(
                height: _bottomSheetHeight,
                onHeightChanged: (height) =>
                    setState(() => _bottomSheetHeight = height),
                controller: _stopController,
                providers: _providers,
                selectedProvider: _selectedProvider,
                theme: _providerTheme,
                onProviderSelected: _onProviderSelected,
                onSearchResultTap: _openStopDetail,
                onRouteTap: _openRouteDetail,
              ),
            ),
          ],
        );
      },
    );
  }
}
