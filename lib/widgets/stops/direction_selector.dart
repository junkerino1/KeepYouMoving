import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Direction status + Swap Direction / Full List action buttons.
///
/// The direction toggle is only shown for bidirectional routes (when
/// [isBidirectional] is true). Actions are reported through callbacks so all
/// business logic stays in the controller/screen.
class DirectionSelector extends StatelessWidget {
  final bool isLoading;
  final bool hasLoaded;
  final String? errorMessage;
  final int? selectedDirection;
  final int stopCount;
  final bool isBidirectional;
  final VoidCallback onSwapDirection;

  const DirectionSelector({
    super.key,
    required this.isLoading,
    required this.hasLoaded,
    required this.errorMessage,
    required this.selectedDirection,
    required this.stopCount,
    required this.isBidirectional,
    required this.onSwapDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hasLoaded || isLoading) ...[
          const SizedBox(height: 12),
          _buildStatus(),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            if (isBidirectional) ...[
              Expanded(
                child: GestureDetector(
                  onTap: onSwapDirection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Swap Direction',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text('⇄',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.navyBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_rounded,
                        size: 14, color: AppColors.navyTextSecondary),
                    SizedBox(width: 4),
                    Text(
                      'Full List',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatus() {
    if (isLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
          ),
          SizedBox(width: 8),
          Text(
            'Loading route stops…',
            style: TextStyle(fontSize: 12, color: AppColors.navyTextSecondary),
          ),
        ],
      );
    }

    final error = errorMessage;
    if (error != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 14, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 12, color: AppColors.red),
            ),
          ),
        ],
      );
    }

    if (stopCount == 0) {
      return const Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.navyTextHint),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No stops available for this route.',
              style: TextStyle(fontSize: 12, color: AppColors.navyTextHint),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.swap_vert_rounded,
            size: 14, color: AppColors.navyTextTertiary),
        const SizedBox(width: 6),
        Text(
          'Direction $selectedDirection',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.navyTextPrimary,
          ),
        ),
        const Spacer(),
        Text(
          '$stopCount stops',
          style:
              const TextStyle(fontSize: 11, color: AppColors.navyTextSecondary),
        ),
      ],
    );
  }
}
