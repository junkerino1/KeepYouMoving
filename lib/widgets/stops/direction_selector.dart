import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// "Stops List" / "Schedule" action buttons plus a slim status row.
///
/// Pure presentation: fetch state is passed in, and button actions are
/// reported back through [onStopsList] / [onSchedule]. A `null` callback
/// disables its button (used when there's no route context to navigate to).
class DirectionSelector extends StatelessWidget {
  final bool isLoading;
  final bool hasLoaded;
  final String? errorMessage;
  final int stopCount;
  final ProviderTheme theme;
  final VoidCallback? onStopsList;
  final VoidCallback? onSchedule;

  const DirectionSelector({
    super.key,
    required this.isLoading,
    required this.hasLoaded,
    required this.errorMessage,
    required this.stopCount,
    required this.theme,
    this.onStopsList,
    this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hasLoaded || isLoading) ...[
          const SizedBox(height: 12),
          _buildStatus(context),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAction(
                context,
                label: 'Stops List',
                icon: Icons.list_rounded,
                primary: true,
                onTap: onStopsList,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAction(
                context,
                label: 'Schedule',
                icon: Icons.schedule_rounded,
                primary: false,
                onTap: onSchedule,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool primary,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final background = enabled
        ? (primary ? theme.primary : scheme.surfaceContainerHigh)
        : scheme.surfaceContainerHigh;
    final foreground = enabled
        ? (primary ? theme.onPrimary : scheme.onSurfaceVariant)
        : scheme.outline;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: scheme.primary),
          ),
          const SizedBox(width: 8),
          Text('Loading route stops…', style: textTheme.bodySmall),
        ],
      );
    }

    final error = errorMessage;
    if (error != null) {
      return Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 14, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        ],
      );
    }

    if (stopCount == 0) {
      return Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No stops available for this route.',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.route_rounded,
            size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$stopCount stops in this direction',
            style: textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
