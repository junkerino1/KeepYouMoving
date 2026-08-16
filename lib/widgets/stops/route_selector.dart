import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// From → To input panel: two labeled station rows and, for bidirectional
/// routes, a circular swap button on the right. Single-direction routes show a
/// compact "One way" badge instead.
class RouteSelector extends StatelessWidget {
  final String originLabel;
  final String destinationLabel;
  final ProviderTheme theme;
  final bool isBidirectional;
  final VoidCallback? onSwap;

  const RouteSelector({
    super.key,
    required this.originLabel,
    required this.destinationLabel,
    required this.theme,
    required this.isBidirectional,
    this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, 12, isBidirectional ? 68 : 88, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField(context, 'From', originLabel),
              const SizedBox(height: 12),
              _buildField(context, 'To', destinationLabel),
            ],
          ),
        ),
        // Right-edge control: swap button (bidirectional) or One-way badge.
        Positioned(
          right: 14,
          top: 0,
          bottom: 0,
          child: Center(
            child: isBidirectional
                ? _buildSwapButton(context)
                : _buildOneWayBadge(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSwapButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: theme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onSwap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child:
              Icon(Icons.swap_vert_rounded, size: 22, color: theme.onPrimary),
        ),
      ),
    );
  }

  Widget _buildOneWayBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_rounded,
              size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('One way', style: textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelMedium?.copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
