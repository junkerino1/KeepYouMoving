import 'package:flutter/material.dart';

/// Compact loading / error / info pill shown over the map.
class MapStatusChip extends StatelessWidget {
  final bool loading;
  final String? message;
  final IconData? icon;
  final bool isError;

  const MapStatusChip.loading({super.key})
      : loading = true,
        message = null,
        icon = null,
        isError = false;

  const MapStatusChip.error(this.message, {super.key})
      : loading = false,
        icon = Icons.error_outline_rounded,
        isError = true;

  /// Neutral informational chip (e.g. location unavailable).
  const MapStatusChip.info(this.message, {super.key})
      : loading = false,
        icon = Icons.location_off_outlined,
        isError = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isError
              ? scheme.error.withValues(alpha: 0.3)
              : scheme.outlineVariant,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else if (icon != null)
            Icon(icon,
                size: 14,
                color: isError ? scheme.error : scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            loading ? 'Loading stops...' : (message ?? ''),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isError ? scheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
