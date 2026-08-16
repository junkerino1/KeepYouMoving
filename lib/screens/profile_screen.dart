import 'package:flutter/material.dart';
import '../controllers/theme_controller.dart';

/// Profile & settings screen.
///
/// Presentation-only for now: shows static app information and honest
/// placeholders for features that aren't wired up yet (saving favorites). The
/// theme picker is live (session-only, no persistence).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.themeController});

  /// App-wide theme mode (owned by `RapidTransitApp`); the picker below
  /// updates it live.
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.directions_bus_rounded,
                  size: 28, color: scheme.onPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RapidTransit KL', style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text('Your transit companion', style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const _SectionHeader('Appearance'),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.brightness_auto_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Theme', style: textTheme.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Changes apply instantly and reset to System on restart.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeController,
                  builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selection) =>
                        themeController.setMode(selection.first),
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const _SectionHeader('Saved'),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              children: [
                Icon(Icons.bookmark_border_rounded,
                    size: 28, color: scheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text('No saved stops or routes yet',
                    style: textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  'Saving favorites is coming soon.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const _SectionHeader('About'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: scheme.primary),
                title: const Text('Version'),
                trailing: Text('1.0.0', style: textTheme.labelMedium),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.hub_outlined, color: scheme.primary),
                title: const Text('Transit data'),
                subtitle: const Text('data.gov.my GTFS & real-time feeds'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: textTheme.labelMedium?.copyWith(letterSpacing: 0.8),
      ),
    );
  }
}
