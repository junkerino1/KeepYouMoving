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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        if (isLoading && !hasAnyDepartures)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.navy,
              ),
            ),
          )
        else if (errorMessage != null && !hasAnyDepartures)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                errorMessage!,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.red),
              ),
            ),
          )
        else if (departures.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No upcoming buses',
                style: TextStyle(
                    fontSize: 12, color: AppColors.navyTextHint),
              ),
            ),
          )
        else
          ...departures.take(4).map((departure) => Padding(
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 14, color: AppColors.navyTextTertiary),
            const SizedBox(width: 6),
            const Text(
              'REAL-TIME BUS COUNTDOWNS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.navyTextTertiary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.light,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Live',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: theme.primary,
                ),
              ),
            ),
            if (lastFetchedAt != null) ...[
              const SizedBox(width: 4),
              Text(
                _formatTime(lastFetchedAt!),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navyTextTertiary,
                ),
              ),
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
