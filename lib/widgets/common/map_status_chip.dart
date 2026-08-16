import 'package:flutter/material.dart';

/// Compact loading / error pill shown over the map while nearby stops load.
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

  /// Neutral informational chip (e.g. location unavailable). Muted icon
  /// instead of the error red.
  const MapStatusChip.info(this.message, {super.key})
      : loading = false,
        icon = Icons.location_off_outlined,
        isError = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else if (icon != null)
            Icon(icon,
                size: 12,
                color: isError ? scheme.error : scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            loading ? 'Loading stops…' : (message ?? ''),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
