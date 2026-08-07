import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  String _selectedRouteId = '250';
  String _selectedStopId = 'stop_250_1';

  // Placeholder routes for the dropdown
  static const _routeOptions = ['250', 'T801', '506', 'T757'];

  // Placeholder stops
  static const _stops = {
    '250': ['LRT Wangsa Maju', 'Tar Villa', 'Taman Bunga Raya', 'UTAR Pintu 4', 'Setapak Sentral'],
    'T801': ['MRT Kwasa Sentral Entrance A', 'Seksyen 8 Flat', 'SMK Seksyen 10', 'Seksyen 9 Hub', 'Selangor Science Park'],
    '506': ['Bandar Utama Bus Hub', 'LRT Kelana Jaya', 'Sunway Lagoon', 'IOI Mall Puchong', 'Putrajaya Sentral'],
    'T757': ['LRT Alam Megah', 'Taman Alam Megah', 'Flat Proton', 'SK Seksyen 27'],
  };

  // Placeholder stop IDs
  static const _stopIds = {
    '250': ['stop_250_1', 'stop_250_2', 'stop_250_3', 'stop_250_4', 'stop_250_5'],
    'T801': ['stop_t801_1', 'stop_t801_2', 'stop_t801_3', 'stop_t801_4', 'stop_t801_5'],
    '506': ['stop_506_1', 'stop_506_2', 'stop_506_3', 'stop_506_4', 'stop_506_5'],
    'T757': ['stop_t757_1', 'stop_t757_2', 'stop_t757_3', 'stop_t757_4'],
  };

  List<String> get _currentStopNames => _stops[_selectedRouteId] ?? [];
  List<String> get _currentStopIds => _stopIds[_selectedRouteId] ?? [];

  // Placeholder timetable times
  List<String> _getTimes() {
    final base = _selectedStopId.hashCode % 10 + 6;
    return [
      '${base.toString().padLeft(2, '0')}:00 AM',
      '${(base + 1).toString().padLeft(2, '0')}:15 AM',
      '${(base + 2).toString().padLeft(2, '0')}:30 AM',
      '${(base + 3).toString().padLeft(2, '0')}:45 AM',
      '${(base + 4).toString().padLeft(2, '0')}:00 AM',
      '${(base + 5).toString().padLeft(2, '0')}:15 AM',
      '${(base + 6).toString().padLeft(2, '0')}:30 AM',
      '${(base + 7).toString().padLeft(2, '0')}:45 AM',
      '${(base + 8).toString().padLeft(2, '0')}:00 AM',
      '${(base + 9).toString().padLeft(2, '0')}:15 AM',
      '${(base + 10).toString().padLeft(2, '0')}:30 AM',
      '${(base + 11).toString().padLeft(2, '0')}:00 AM',
      '${(base + 12).toString().padLeft(2, '0')}:00 PM',
      '${(base + 13).toString().padLeft(2, '0')}:00 PM',
      '${(base + 14).toString().padLeft(2, '0')}:00 PM',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final times = _getTimes();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(bottom: BorderSide(color: AppColors.navyBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCHEDULE',
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
                'Departures',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyTextPrimary,
                ),
              ),
            ],
          ),
        ),
        // Selectors
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(bottom: BorderSide(color: AppColors.navyBorder)),
          ),
          child: Column(
            children: [
              // Route selector
              _buildDropdown(
                label: 'Route',
                value: _selectedRouteId,
                items: _routeOptions.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text('Line $r', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedRouteId = v;
                      _selectedStopId = _currentStopIds.isNotEmpty ? _currentStopIds.first : '';
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              // Stop selector
              _buildDropdown(
                label: 'Stop',
                value: _selectedStopId,
                items: List.generate(_currentStopIds.length, (i) {
                  return DropdownMenuItem(
                    value: _currentStopIds[i],
                    child: Text(
                      _currentStopNames[i],
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedStopId = v);
                },
              ),
            ],
          ),
        ),
        // Info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(bottom: BorderSide(color: AppColors.navyBorder)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 14, color: AppColors.navyTextHint),
              const SizedBox(width: 6),
              Text(
                'Every 12 mins',
                style: TextStyle(fontSize: 12, color: AppColors.navyTextSecondary),
              ),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.navyTextHint),
              const SizedBox(width: 6),
              Text(
                'Daily service',
                style: TextStyle(fontSize: 12, color: AppColors.navyTextSecondary),
              ),
            ],
          ),
        ),
        // Times list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: times.length,
            separatorBuilder: (_, _2) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final isNext = index == 3;
              final isPast = index < 3;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: isNext ? AppColors.navyVeryLight : Colors.transparent,
                child: Row(
                  children: [
                    // Time dot indicator
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isNext
                            ? AppColors.navy
                            : isPast
                                ? AppColors.navyBorder
                                : AppColors.navyTextHint,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Time
                    Text(
                      times[index],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: isNext ? 18 : isPast ? 13 : 15,
                        color: isNext
                            ? AppColors.navyTextPrimary
                            : isPast
                                ? AppColors.navyTextHint
                                : AppColors.navyTextSecondary,
                      ),
                    ),
                    const Spacer(),
                    // Status badge
                    if (isNext)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else if (isPast)
                      const Text(
                        'Departed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navyTextHint,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.navyTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.navyVeryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.navyBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.navyTextHint),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navyTextPrimary,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
