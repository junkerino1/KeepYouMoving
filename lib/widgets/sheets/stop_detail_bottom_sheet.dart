import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/route_controller.dart';
import '../../theme/app_theme.dart';
import '../live_bus/eta_section.dart';
import '../stops/direction_selector.dart';
import '../stops/route_selector.dart';

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
    required this.displayLine,
    required this.originLabel,
    required this.destinationLabel,
    required this.onDirectionToggle,
  });

  final RouteController controller;
  final ProviderTheme theme;
  final LatLng stopPosition;
  final String displayLine;
  final String originLabel;
  final String destinationLabel;
  final VoidCallback onDirectionToggle;

  @override
  State<StopDetailBottomSheet> createState() => _StopDetailBottomSheetState();
}

class _StopDetailBottomSheetState extends State<StopDetailBottomSheet> {
  double _sheetHeight = 340;
  bool _isDragging = false;
  double _dragStartY = 0;
  double _dragStartHeight = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: const Cubic(0.16, 1, 0.3, 1),
      height: _sheetHeight,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.navyBorder),
                    ),
                    child: Column(
                      children: [
                        RouteSelector(
                          displayLine: widget.displayLine,
                          originLabel: widget.originLabel,
                          destinationLabel: widget.destinationLabel,
                        ),
                        DirectionSelector(
                          isLoading: widget.controller.isLoadingStops,
                          hasLoaded: widget.controller.hasLoadedStops,
                          errorMessage: widget.controller.stopsError,
                          selectedDirection:
                              widget.controller.selectedDirection,
                          stopCount:
                              widget.controller.selectedDirectionStops.length,
                          isBidirectional: widget.controller.isBidirectional,
                          onSwapDirection: widget.onDirectionToggle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ETASection(
                    departures:
                        widget.controller.selectedDirectionDepartures,
                    isLoading: widget.controller.isLoadingEta,
                    hasAnyDepartures: widget.controller.departures.isNotEmpty,
                    errorMessage: widget.controller.etaError,
                    lastFetchedAt: widget.controller.lastEtaFetchedAt,
                    theme: widget.theme,
                    stopPosition: widget.stopPosition,
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
          _sheetHeight = (_dragStartHeight - deltaY).clamp(140.0, 560.0);
        });
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _isDragging = false;
          const snaps = [140.0, 340.0, 500.0];
          _sheetHeight = snaps.reduce((a, b) =>
              (a - _sheetHeight).abs() < (b - _sheetHeight).abs() ? a : b);
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
}
