import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/eta_departure.dart';
import '../../theme/app_theme.dart';
import 'eta_item.dart';

/// Real-time countdown header plus the list of upcoming departures.
///
/// Pure presentation: receives already-filtered/sorted [departures] and fetch
/// state from the controller; never performs API calls itself.
class ETASection extends StatelessWidget {
  final List<EtaDeparture> departures;
  final bool isLoading;
  final bool hasAnyDepartures;
  final String? errorMessage;
  final DateTime? lastFetchedAt;
  final ProviderTheme theme;
  final LatLng stopPosition;

  const ETASection({
    super.key,
    required this.departures,
    required this.isLoading,
    required this.hasAnyDepartures,
    required this.errorMessage,
    required this.lastFetchedAt,
    required this.theme,
    required this.stopPosition,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Only show departures within the next hour.
    final withinHour = departures
        .where((d) => d.countdownMinutes() <= 60)
        .toList();
    // Departures actually rendered (capped at 4).
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
          ...displayed.map((departure) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EtaItem(
                  departure: departure,
                  theme: theme,
                  stopPosition: stopPosition,
                ),
              )),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<EtaDeparture> displayed) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // "Live" only when at least one displayed departure is a tracked vehicle;
    // otherwise the arrivals are timetable-based.
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

/// e.g. `(14:30)`.
String _formatTime(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '($h:$m)';
}
