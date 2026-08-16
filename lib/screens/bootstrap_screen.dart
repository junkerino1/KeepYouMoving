import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';
import '../services/bootstrap_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Branded app-launch splash shown before the Home screen.
///
/// Renders immediately (no pre-`runApp` work), drives [BootstrapService], and
/// shows honest progress copy plus a fake percentage. On failure it shows a
/// recovery state with retry (never an infinite spinner); if Turnstile needs a
/// visible challenge it shows one inline. Android back is blocked while
/// bootstrap runs and only cancels an interactive challenge.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({
    super.key,
    required this.service,
    required this.themeController,
  });

  final BootstrapService service;
  final ThemeController themeController;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onBootstrapChanged);
    widget.service.start();
  }

  @override
  void dispose() {
    widget.service.removeListener(_onBootstrapChanged);
    super.dispose();
  }

  void _onBootstrapChanged() {
    if (widget.service.status == BootstrapStatus.ready && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                HomeScreen(themeController: widget.themeController),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        // PopScope sits inside the builder so `canPop` tracks status changes
        // (block back while running; allow exit once bootstrap has failed).
        return PopScope(
          canPop: service.status == BootstrapStatus.failed,
          child: Scaffold(
            body: SafeArea(
              child: switch (service.status) {
                BootstrapStatus.ready => _RunningView(service: service),
                BootstrapStatus.failed => _FailureView(service: service),
                BootstrapStatus.running => _RunningView(service: service),
              },
            ),
          ),
        );
      },
    );
  }
}

/// The live splash: logo, restrained progress bar, and honest copy.
class _RunningView extends StatelessWidget {
  const _RunningView({required this.service});

  final BootstrapService service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SplashLogo(size: 128),
              const SizedBox(height: 24),
              Text(
                'RapidTransit KL',
                style: textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Kuala Lumpur transit, live',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              _ProgressBar(progress: service.progress),
              const SizedBox(height: 16),
              Text(
                service.statusMessage,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smooth progress bar + fake percentage driven by [BootstrapService.progress].
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final percent = (value * 100).clamp(0, 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$percent%',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }
}

/// Clear recovery state: no spinner, an honest message, and a retry action.
class _FailureView extends StatelessWidget {
  const _FailureView({required this.service});

  final BootstrapService service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 32,
                  color: scheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Couldn’t prepare the app',
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                service.errorMessage ?? 'Please try again.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (service.failedStep != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Failed while: ${service.failedStep!.label}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: service.retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
              const SizedBox(height: 8),
              Text(
                'You can also close and reopen the app.',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App logo. Uses `assets/logo.png` when present; otherwise falls back to a
/// programmatic navy bus-in-ring + red pin mark matching the brand identity.
class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key, this.size = 128});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _BrandMark(size: size),
    );
  }
}

/// Drawn fallback logo: a navy ring around a bus, with a red map pin
/// overlapping the top — a restrained nod to the attached logo.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 128});

  final double size;

  @override
  Widget build(BuildContext context) {
    final navy = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: navy, width: size * 0.045),
            ),
          ),
          Icon(
            Icons.directions_bus_rounded,
            size: size * 0.5,
            color: navy,
          ),
          Positioned(
            top: size * 0.02,
            child: Icon(
              Icons.location_on_rounded,
              size: size * 0.34,
              color: AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}
