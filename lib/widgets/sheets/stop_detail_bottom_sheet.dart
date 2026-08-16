import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/route_controller.dart';
import '../../models/eta_departure.dart';
import '../../theme/app_theme.dart';
import '../live_bus/eta_section.dart';
import '../stops/direction_selector.dart';
import '../stops/route_selector.dart';
import 'sheet_snap.dart';

/// Draggable bottom sheet on the stop-detail screen.
///
/// Owns its own height/drag state and composes the route selector, direction
/// selector and real-time ETA section. Reads data from [RouteController] and
/// reports user actions back through callbacks.
class StopDetailBottomSheet extends StatefulWidget {
  const StopDetailBottomSheet({
    super.key,
    required this.controller,
    required this.theme,
    required this.stopPosition,
    required this.originLabel,
    required this.destinationLabel,
    required this.onDirectionToggle,
    this.onStopsList,
    this.onSchedule,
    this.onDepartureTap,
  });

  final RouteController controller;
  final ProviderTheme theme;
  final LatLng stopPosition;
  final String originLabel;
  final String destinationLabel;
  final VoidCallback onDirectionToggle;
  final VoidCallback? onStopsList;
  final VoidCallback? onSchedule;
  final void Function(EtaDeparture departure)? onDepartureTap;

  @override
  State<StopDetailBottomSheet> createState() => _StopDetailBottomSheetState();
}

class _StopDetailBottomSheetState extends State<StopDetailBottomSheet> {
  double _sheetHeight = kSheetDefaultHeight;
  bool _isDragging = false;
  double _dragStartY = 0;
  double _dragStartHeight = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: const Cubic(0.16, 1, 0.3, 1),
      height: _sheetHeight,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From → To panel with swap button on the right edge.
                  RouteSelector(
                    originLabel: widget.originLabel,
                    destinationLabel: widget.destinationLabel,
                    theme: widget.theme,
                    isBidirectional: widget.controller.isBidirectional,
                    onSwap: widget.onDirectionToggle,
                  ),
                  const SizedBox(height: 16),
                  // Stops List / Schedule action buttons.
                  DirectionSelector(
                    isLoading: widget.controller.isLoadingStops,
                    hasLoaded: widget.controller.hasLoadedStops,
                    errorMessage: widget.controller.stopsError,
                    stopCount:
                        widget.controller.selectedDirectionStops.length,
                    theme: widget.theme,
                    onStopsList: widget.onStopsList,
                    onSchedule: widget.onSchedule,
                  ),
                  const SizedBox(height: 20),
                  ETASection(
                    departures:
                        widget.controller.selectedDirectionDepartures,
                    isLoading: widget.controller.isLoadingEta,
                    hasAnyDepartures: widget.controller.departures.isNotEmpty,
                    errorMessage: widget.controller.etaError,
                    lastFetchedAt: widget.controller.lastEtaFetchedAt,
                    theme: widget.theme,
                    stopPosition: widget.stopPosition,
                    onDepartureTap: widget.onDepartureTap,
                    highlightedVehicleId:
                        widget.controller.highlightedVehicleId,
                    getVehicleProgress: (key) =>
                        widget.controller.vehicleProgress(key),
                    isLoadingVehicleProgress: (key) =>
                        widget.controller.isLoadingProgress(key),
                  ),
                ],
              ),
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
          _dragStartHeight = _sheetHeight;
        });
      },
      onVerticalDragUpdate: (details) {
        setState(() {
          final deltaY = details.globalPosition.dy - _dragStartY;
          _sheetHeight = (_dragStartHeight - deltaY)
              .clamp(kSheetMinHeight, kSheetExpandedHeight);
        });
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _isDragging = false;
          _sheetHeight = kSheetSnapHeights.reduce((a, b) =>
              (a - _sheetHeight).abs() < (b - _sheetHeight).abs() ? a : b);
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
}
