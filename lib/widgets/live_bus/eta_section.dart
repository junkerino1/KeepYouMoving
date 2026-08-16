import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/eta_departure.dart';
import '../../models/vehicle_progress.dart';
import '../../theme/app_theme.dart';
import 'eta_item.dart';

/// Real-time countdown header plus the list of upcoming departures.
///
/// Pure presentation: receives already-filtered/sorted [departures] and fetch
/// state from the controller; never performs API calls itself.
///
/// [onDepartureTap] is called when a live departure is tapped — the parent
/// uses this to highlight the bus on the map and fetch stops-away data.
class ETASection extends StatelessWidget {
  final List<EtaDeparture> departures;
  final bool isLoading;
  final bool hasAnyDepartures;
  final String? errorMessage;
  final DateTime? lastFetchedAt;
  final ProviderTheme theme;
  final LatLng stopPosition;

  /// Called when a live departure is tapped (has a tracked vehicle).
  final void Function(EtaDeparture departure)? onDepartureTap;

  /// The public vehicle ID currently highlighted (from a prior tap).
  final String? highlightedVehicleId;

  /// Progress data per vehicle+stop key (e.g. "VG6493/12003284").
  final VehicleProgress? Function(String key)? getVehicleProgress;

  /// Whether progress is loading for a given key.
  final bool Function(String key)? isLoadingVehicleProgress;

  const ETASection({
    super.key,
    required this.departures,
    required this.isLoading,
    required this.hasAnyDepartures,
    required this.errorMessage,
    required this.lastFetchedAt,
    required this.theme,
    required this.stopPosition,
    this.onDepartureTap,
    this.highlightedVehicleId,
    this.getVehicleProgress,
    this.isLoadingVehicleProgress,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final withinHour = departures
        .where((d) => d.countdownMinutes() <= 60)
        .toList();
    final displayed = withinHour.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, displayed),
        const SizedBox(height: 12),
        if (isLoading && !hasAnyDepartures)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          )
        else if (errorMessage != null && !hasAnyDepartures)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                errorMessage!,
                style: textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          )
        else if (withinHour.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('No upcoming buses', style: textTheme.bodySmall),
            ),
          )
        else
          ...displayed.map((departure) {
            final vehicleId = departure.liveVehicleId;
            final progressKey = vehicleId != null
                ? '$vehicleId/${departure.stopId}'
                : null;
            final isHighlighted = vehicleId != null &&
                vehicleId == highlightedVehicleId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EtaItem(
                departure: departure,
                theme: theme,
                stopPosition: stopPosition,
                onTap: departure.firstValidVehicle != null &&
                        onDepartureTap != null
                    ? () => onDepartureTap!(departure)
                    : null,
                vehicleProgress: progressKey != null && getVehicleProgress != null
                    ? getVehicleProgress!(progressKey)
                    : null,
                isLoadingProgress: progressKey != null &&
                        isLoadingVehicleProgress != null
                    ? isLoadingVehicleProgress!(progressKey)
                    : false,
                isHighlighted: isHighlighted,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<EtaDeparture> displayed) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasLive = displayed.any((d) => d.firstValidVehicle != null);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded,
                size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('Bus Countdown', style: textTheme.titleSmall),
          ],
        ),
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasLive ? theme.light : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasLive ? 'Live' : 'Scheduled',
                style: textTheme.labelMedium?.copyWith(
                  color: hasLive ? theme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (lastFetchedAt != null) ...[
              const SizedBox(width: 4),
              Text(_formatTime(lastFetchedAt!),
                  style: textTheme.labelMedium),
            ],
          ],
        ),
      ],
    );
  }
}

String _formatTime(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '($h:$m)';
}
