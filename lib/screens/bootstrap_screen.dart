import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';
import '../services/bootstrap_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Material 3 animated splash shown during app bootstrap.
///
/// Displays the RapidTransit KL branding, initialization progress,
/// animated service status, and a recovery state if bootstrap fails.
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
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => HomeScreen(
              themeController: widget.themeController,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
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

/// Main bootstrap view.
class _RunningView extends StatefulWidget {
  const _RunningView({
    required this.service,
  });

  final BootstrapService service;

  @override
  State<_RunningView> createState() => _RunningViewState();
}

class _RunningViewState extends State<_RunningView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final service = widget.service;
    final currentStep = _stepIndex(service.progress);

    return Stack(
      children: [
        // Decorative background glow - top right.
        Positioned(
          top: -130,
          right: -110,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.055),
            ),
          ),
        ),

        // Decorative background glow - bottom left.
        Positioned(
          bottom: -180,
          left: -140,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.tertiary.withValues(alpha: 0.045),
            ),
          ),
        ),

        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App logo.
                  _AnimatedLogo(
                    pulseController: _pulseController,
                    size: 112,
                  ),

                  const SizedBox(height: 22),

                  // Application name.
                  Text(
                    'RapidTransit KL',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Main initialization title.
                  Text(
                    'Preparing your journey',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // App description.
                  Text(
                    'Setting up live transit data, secure services '
                        'and everything you need before departure.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 34),

                  // Initialization progress card.
                  _InitializationCard(
                    service: service,
                    currentStep: currentStep,
                    shimmerController: _shimmerController,
                  ),

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: scheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'This should only take a moment',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Maps bootstrap progress to the visible initialization stage.
  int _stepIndex(double progress) {
    if (progress < 0.15) return 0;
    if (progress < 0.35) return 1;
    if (progress < 0.60) return 2;
    if (progress < 0.85) return 3;
    return 4;
  }
}

/// Main initialization card.
class _InitializationCard extends StatelessWidget {
  const _InitializationCard({
    required this.service,
    required this.currentStep,
    required this.shimmerController,
  });

  final BootstrapService service;
  final int currentStep;
  final AnimationController shimmerController;

  static const int totalSteps = 5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  size: 21,
                  color: scheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Initialization progress',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Step ${currentStep + 1} of $totalSteps',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Percentage chip.
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  end: service.progress.clamp(0.0, 1.0),
                ),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  final percent = (value * 100).round();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percent%',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Step status.
          _StepIndicators(
            currentStep: currentStep,
            shimmerController: shimmerController,
            statusMessage: service.statusMessage,
          ),

          const SizedBox(height: 22),

          // Main overall progress bar.
          _AnimatedProgressBar(
            progress: service.progress,
            shimmerController: shimmerController,
          ),
        ],
      ),
    );
  }
}

/// Initialization stages and current status.
class _StepIndicators extends StatelessWidget {
  const _StepIndicators({
    required this.currentStep,
    required this.shimmerController,
    required this.statusMessage,
  });

  final int currentStep;
  final AnimationController shimmerController;
  final String statusMessage;

  static const List<_StepData> _steps = [
    _StepData(
      Icons.tune_rounded,
      'Configuration',
      'Loading application settings',
    ),
    _StepData(
      Icons.smartphone_rounded,
      'Device',
      'Preparing this device',
    ),
    _StepData(
      Icons.shield_rounded,
      'Security',
      'Starting secure services',
    ),
    _StepData(
      Icons.wifi_rounded,
      'Network',
      'Connecting to transit services',
    ),
    _StepData(
      Icons.directions_transit_rounded,
      'Transit',
      'Loading live transit information',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final safeIndex = currentStep.clamp(
      0,
      _steps.length - 1,
    );

    final step = _steps[safeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segmented progress indicator.
        Row(
          children: List.generate(
            _steps.length,
                (index) {
              final isCompleted = index < safeIndex;
              final isCurrent = index == safeIndex;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _steps.length - 1 ? 0 : 5,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: isCurrent ? 5 : 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Current initialization stage.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CurrentStepIcon(
              icon: step.icon,
              shimmerController: shimmerController,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: ValueKey<int>(safeIndex),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      step.description,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Live service status.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _LoadingDot(
                shimmerController: shimmerController,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: Text(
                    statusMessage,
                    key: ValueKey<String>(statusMessage),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Data describing one initialization stage.
class _StepData {
  const _StepData(
      this.icon,
      this.label,
      this.description,
      );

  final IconData icon;
  final String label;
  final String description;
}

/// Animated icon representing the currently-running step.
class _CurrentStepIcon extends StatelessWidget {
  const _CurrentStepIcon({
    required this.icon,
    required this.shimmerController,
  });

  final IconData icon;
  final AnimationController shimmerController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final pulse = 0.5 +
            (0.5 *
                (1 -
                    (2 * shimmerController.value - 1).abs()));

        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(
                  alpha: 0.05 + (pulse * 0.10),
                ),
                blurRadius: 10 + (pulse * 6),
                spreadRadius: pulse,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 24,
            color: scheme.onPrimaryContainer,
          ),
        );
      },
    );
  }
}

/// Small animated dot used beside the live status message.
class _LoadingDot extends StatelessWidget {
  const _LoadingDot({
    required this.shimmerController,
  });

  final AnimationController shimmerController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, _) {
        final value = shimmerController.value;

        final pulse =
            0.6 + (0.4 * (1 - (2 * value - 1).abs()));

        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(
                  alpha: 0.15 + (pulse * 0.25),
                ),
                blurRadius: 5 + (pulse * 5),
                spreadRadius: pulse,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Smooth animated overall bootstrap progress bar.
class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({
    required this.progress,
    required this.shimmerController,
  });

  final double progress;
  final AnimationController shimmerController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        end: progress.clamp(0.0, 1.0),
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: double.infinity,
            height: 8,
            child: Stack(
              children: [
                // Background.
                Positioned.fill(
                  child: Container(
                    color: scheme.surfaceContainerHighest,
                  ),
                ),

                // Filled progress.
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary,
                              scheme.tertiary,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Moving shimmer.
                if (value > 0 && value < 1)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: shimmerController,
                      builder: (context, _) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: value.clamp(0.0, 1.0),
                            heightFactor: 1,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final shimmerWidth = 55.0;

                                final available =
                                    constraints.maxWidth +
                                        shimmerWidth;

                                final x =
                                    (available *
                                        shimmerController.value) -
                                        shimmerWidth;

                                return Stack(
                                  clipBehavior: Clip.hardEdge,
                                  children: [
                                    Positioned(
                                      left: x,
                                      top: 0,
                                      bottom: 0,
                                      width: shimmerWidth,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.white.withValues(
                                                alpha: 0.38,
                                              ),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Logo with a subtle breathing glow.
class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo({
    required this.pulseController,
    required this.size,
  });

  final AnimationController pulseController;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final t = pulseController.value;

        final glowOpacity = 0.06 + (0.10 * t);
        final glowScale = 1.0 + (0.12 * t);

        return SizedBox(
          width: size + 50,
          height: size + 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: glowScale,
                child: Container(
                  width: size + 24,
                  height: size + 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(
                      alpha: glowOpacity,
                    ),
                  ),
                ),
              ),

              SplashLogo(
                size: size,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Recovery state shown if initialization fails.
class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.service,
  });

  final BootstrapService service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 32,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 38,
                  color: scheme.onErrorContainer,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'We couldn\'t get things ready',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                'RapidTransit KL ran into a problem while '
                    'preparing the app.',
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 20,
                          color: scheme.error,
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            service.errorMessage ??
                                'An unexpected initialization '
                                    'error occurred.',
                            style: textTheme.bodySmall?.copyWith(
                              height: 1.45,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (service.failedStep != null) ...[
                      const SizedBox(height: 14),

                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Text(
                            'Failed during',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),

                          const Spacer(),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              service.failedStep!.label,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 26),

              FilledButton.icon(
                onPressed: service.retry,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                ),
                label: const Text(
                  'Try again',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    52,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'If the problem continues, close and reopen the app.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App logo.
///
/// Uses `assets/logo.png` when available, otherwise falls back to
/// the built-in RapidTransit KL brand mark.
class SplashLogo extends StatelessWidget {
  const SplashLogo({
    super.key,
    this.size = 128,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return _BrandMark(
          size: size,
        );
      },
    );
  }
}

/// Fallback logo shown when assets/logo.png cannot be loaded.
class _BrandMark extends StatelessWidget {
  const _BrandMark({
    this.size = 128,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

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
              border: Border.all(
                color: primary,
                width: size * 0.04,
              ),
            ),
          ),

          Icon(
            Icons.directions_bus_rounded,
            size: size * 0.45,
            color: primary,
          ),

          Positioned(
            top: size * 0.02,
            child: Icon(
              Icons.location_on_rounded,
              size: size * 0.30,
              color: AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}