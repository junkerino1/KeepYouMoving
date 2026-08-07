import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Compact loading / error pill shown over the map while nearby stops load.
class MapStatusChip extends StatelessWidget {
  final bool loading;
  final String? error;

  const MapStatusChip.loading({super.key})
      : loading = true,
        error = null;

  const MapStatusChip.error(String message, {super.key})
      : loading = false,
        error = message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.navy,
              ),
            )
          else
            const Icon(Icons.error_outline_rounded,
                size: 12, color: AppColors.red),
          const SizedBox(width: 6),
          Text(
            loading ? 'Loading stops…' : error ?? '',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.navyTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
