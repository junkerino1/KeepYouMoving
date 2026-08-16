import 'package:flutter/material.dart';

import '../controllers/timetable_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/stops/route_color_badge.dart';

/// One selectable entry in the searchable route/stop picker.
class _SearchOption {
  final String value;
  final String label;
  final String? subtitle;
  final String? routeBadge;
  final String searchText;

  const _SearchOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.routeBadge,
    required this.searchText,
  });
}

class TimetableScreen extends StatefulWidget {
  /// Deep-link target: when set together with [initialStopId], the screen
  /// loads straight to that stop's timetable instead of the step-by-step
  /// picker flow.
  final String? initialProviderKey;
  final int? initialProviderId;
  final String? initialRouteId;
  final String? initialStopId;

  const TimetableScreen({
    super.key,
    this.initialProviderKey,
    this.initialProviderId,
    this.initialRouteId,
    this.initialStopId,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final TimetableController _controller = TimetableController();

  @override
  void initState() {
    super.initState();
    _controller.init(
      initialProviderKey: widget.initialProviderKey,
      initialProviderId: widget.initialProviderId,
      initialRouteId: widget.initialRouteId,
      initialStopId: widget.initialStopId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Departures', style: textTheme.titleMedium),
            ],
          ),
        ),
        // Selectors
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Column(
            children: [
              _buildProviderFilters(),
              const SizedBox(height: 12),
              _buildDropdown(
                label: 'Route',
                value: _controller.selectedRouteId,
                currentLabel: _controller.currentRouteLabel,
                options: [
                  for (final r in _controller.routes)
                    _SearchOption(
                      value: r.routeId,
                      label: r.routeLongName,
                      routeBadge: r.routeShortName,
                      searchText: '${r.routeShortName} ${r.routeLongName}',
                    ),
                ],
                onChanged: _controller.selectRoute,
              ),
              const SizedBox(height: 10),
              _buildDropdown(
                label: 'Stop',
                value: _controller.selectedStopId,
                currentLabel: _controller.currentStopLabel,
                options: [
                  for (final s in _controller.stops)
                    _SearchOption(
                      value: s.stopId,
                      label: s.stopName,
                      subtitle: s.stopId,
                      searchText: '${s.stopName} ${s.stopId}',
                    ),
                ],
                onChanged: _controller.selectStop,
              ),
            ],
          ),
        ),
        // Info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(_frequencyLabel(), style: textTheme.bodySmall),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today_rounded,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(_serviceLabel(), style: textTheme.bodySmall),
              ),
            ],
          ),
        ),
        // Times list
        Expanded(child: _buildTimes()),
      ],
    );
  }

  String _frequencyLabel() {
    final schedule = _controller.schedule;
    if (schedule == null) return '—';
    if (schedule.currentFrequencyMinutes != null) {
      return 'Every ${schedule.currentFrequencyMinutes} mins';
    }
    if (schedule.headwayMedian != null) {
      return 'Every ~${schedule.headwayMedian} mins';
    }
    return '—';
  }

  String _serviceLabel() {
    final schedule = _controller.schedule;
    if (schedule == null || schedule.operatingDays.isEmpty) return '—';
    if (schedule.operatingDays.length >= 7) return 'Daily service';
    return schedule.operatingDays
        .map((d) => d.isEmpty ? d : d[0].toUpperCase() + d.substring(1, 3))
        .join(', ');
  }

  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Today's weekday name, e.g. `Saturday` (`DateTime.weekday` is 1–7).
  String get _todayWeekdayName => _weekdayNames[DateTime.now().weekday - 1];

  /// Whether the schedule's operating calendar includes today
  /// (case-insensitive). An empty list means the calendar is unknown and is
  /// treated as operating.
  bool _operatesToday(List<String> operatingDays) {
    if (operatingDays.isEmpty) return true;
    final today = _todayWeekdayName.toLowerCase();
    return operatingDays.any((d) => d.toLowerCase() == today);
  }

  /// Step-specific hint shown when the timetable isn't loaded yet.
  String _emptyMessage() {
    if (_controller.routes.isEmpty) {
      return 'Choose a route to get started.';
    }
    if (_controller.stops.isEmpty) {
      return 'Choose a stop to view its timetable.';
    }
    return 'Select a route and stop to view its timetable.';
  }

  Widget _buildTimes() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final schedule = _controller.schedule;

    if (_controller.errorMessage != null) {
      return _buildErrorState(scheme, textTheme);
    }
    if (_controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: scheme.primary),
      );
    }
    if (schedule == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _emptyMessage(),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final times = schedule.allTimes;

    // Explicit "not in service" state when the route doesn't run today, so
    // the list never looks like a valid timetable on an off day.
    if (!_operatesToday(schedule.operatingDays)) {
      return _buildNotInService(scheme, textTheme);
    }

    if (times.isEmpty) {
      return Center(
        child: Text(
          'No scheduled departures for this stop.',
          style:
              textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    // Highlight "next" and "departed" only when the schedule is for today.
    int? nextIndex;
    final isToday = _isScheduleToday(schedule.serviceDate);
    if (isToday) {
      final nowMinutes =
          DateTime.now().hour * 60 + DateTime.now().minute;
      for (var i = 0; i < times.length; i++) {
        if (_minutesOfDay(times[i]) >= nowMinutes) {
          nextIndex = i;
          break;
        }
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: times.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final isNext = index == nextIndex;
        final isPast = isToday &&
            nextIndex != null &&
            index < nextIndex;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: isNext ? scheme.surfaceContainerLow : Colors.transparent,
          child: Row(
            children: [
              // Time dot indicator
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNext
                      ? scheme.primary
                      : isPast
                          ? scheme.outlineVariant
                          : scheme.outline,
                ),
              ),
              const SizedBox(width: 16),
              // Time — monospace numerals for scannability; size varies for
              // hierarchy (next larger, past smaller). Type-scale exception.
              Text(
                _formatTime(times[index]),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  fontSize: isNext ? 18 : isPast ? 13 : 15,
                  color: isNext
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // Status badge
              if (isNext)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Next',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else if (isPast)
                Text('Departed', style: textTheme.labelMedium),
            ],
          ),
        );
      },
    );
  }

  /// Shown when the selected route doesn't operate on the current day.
  Widget _buildNotInService(ColorScheme scheme, TextTheme textTheme) {
    final days = _serviceLabel();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 28, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('Not in service today', style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Operates $days — no departures today ($_todayWeekdayName).',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Pick another stop or route to keep browsing.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme scheme, TextTheme textTheme) {
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
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _controller.retry,
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

  /// Provider toggle, matching the Routes screen's filter chips exactly.
  Widget _buildProviderFilters() {
    final rapidKlTheme = ProviderTheme.of('rapid_bus_kl');
    final feederTheme = ProviderTheme.of('rapid_bus_mrtfeeder');
    return Row(
      children: [
        Expanded(
          child: _buildFilterChip(
            label: 'Rapid KL',
            isSelected:
                _controller.selectedProvider?.providerKey == 'rapid_bus_kl',
            selectedColor: rapidKlTheme.primary,
            dotColor: rapidKlTheme.primary,
            onTap: () => _controller
                .selectProvider(_controller.providerByKey('rapid_bus_kl')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterChip(
            label: 'MRT Feeder',
            isSelected: _controller.selectedProvider?.providerKey ==
                'rapid_bus_mrtfeeder',
            selectedColor: feederTheme.primary,
            dotColor: feederTheme.primary,
            onTap: () => _controller.selectProvider(
                _controller.providerByKey('rapid_bus_mrtfeeder')),
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
                  color: isSelected ? Colors.white : dotColor,
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

  /// Tappable field that opens a searchable bottom-sheet picker.
  Widget _buildDropdown({
    required String label,
    required String? value,
    required String? currentLabel,
    required List<_SearchOption> options,
    required ValueChanged<String?> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        const SizedBox(height: 6),
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: options.isEmpty
                ? null
                : () => _openSearchablePicker(
                      title: 'Select $label',
                      options: options,
                      selectedValue: value,
                      onSelected: onChanged,
                    ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      currentLabel ?? 'Select $label',
                      style: currentLabel == null
                          ? textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)
                          : textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.search_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shows a modal with a search box + filtered list; returns the picked
  /// option through [onSelected] (only when one is chosen).
  Future<void> _openSearchablePicker({
    required String title,
    required List<_SearchOption> options,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final result = await showModalBottomSheet<_SearchOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      builder: (sheetContext) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final q = controller.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? options
                : options
                    .where((o) => o.searchText.toLowerCase().contains(q))
                    .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search $title',
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 20, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text('No matches',
                                    style: textTheme.bodySmall),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final selected =
                                    option.value == selectedValue;
                                return ListTile(
                                  title: option.routeBadge != null
                                      ? Row(
                                          children: [
                                            RouteColorBadge(
                                              shortName: option.routeBadge!,
                                              theme: ProviderTheme.of(_controller
                                                  .selectedProvider
                                                  ?.providerKey),
                                              fontSize: 12,
                                              iconSize: 12,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                option.label,
                                                style: textTheme.bodyMedium,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(option.label,
                                          style: textTheme.bodyMedium),
                                  subtitle: option.subtitle == null
                                      ? null
                                      : Text(option.subtitle!,
                                          style: textTheme.bodySmall),
                                  trailing: selected
                                      ? Icon(Icons.check_rounded,
                                          size: 18, color: scheme.primary)
                                      : null,
                                  onTap: () => Navigator.of(sheetContext)
                                      .pop(option),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      onSelected(result.value);
    }
  }

  /// `HH:mm:ss` → minutes of the day.
  int _minutesOfDay(String hhmmss) {
    final parts = hhmmss.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return h * 60 + m;
  }

  /// `HH:mm:ss` → e.g. `5:22 AM`.
  String _formatTime(String hhmmss) {
    final parts = hhmmss.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    final ampm = h < 12 ? 'AM' : 'PM';
    return '$hour12:${m.toString().padLeft(2, '0')} $ampm';
  }

  /// `20260729` vs today's `yyyyMMdd`.
  bool _isScheduleToday(String serviceDate) {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return serviceDate == today;
  }
}
