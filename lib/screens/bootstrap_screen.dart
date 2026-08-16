import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';
import '../services/bootstrap_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Material 3 animated splash shown during app bootstrap.
///
/// Displays a branded logo with a subtle pulse, step-by-step progress
/// indicators with animated checkmarks, and a smooth progress bar.
/// On failure shows a recovery state with retry.
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
            pageBuilder: (_, __, ___) =>
                HomeScreen(themeController: widget.themeController),
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

/// Animated splash: logo pulse, step indicators, smooth progress bar.
class _RunningView extends StatefulWidget {
  const _RunningView({required this.service});

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
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated logo with pulse glow
              _AnimatedLogo(
                pulseController: _pulseController,
                size: 120,
              ),
              const SizedBox(height: 28),
              Text(
                'RapidTransit KL',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kuala Lumpur transit, live',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              // Step indicators
              _StepIndicators(
                currentStep: currentStep,
                shimmerController: _shimmerController,
                statusMessage: service.statusMessage,
              ),
              const SizedBox(height: 28),
              // Smooth progress bar
              _AnimatedProgressBar(
                progress: service.progress,
                shimmerController: _shimmerController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Maps progress (0.0–1.0) to the current step index (0–4).
  int _stepIndex(double progress) {
    if (progress < 0.15) return 0;
    if (progress < 0.35) return 1;
    if (progress < 0.60) return 2;
    if (progress < 0.85) return 3;
    return 4;
  }
}

/// Logo with a subtle breathing pulse glow behind it.
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
        final glowOpacity = 0.08 + 0.12 * t;
        final glowScale = 1.0 + 0.15 * t;
        return SizedBox(
          width: size + 40,
          height: size + 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft glow ring
              Transform.scale(
                scale: glowScale,
                child: Container(
                  width: size + 20,
                  height: size + 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: glowOpacity),
                  ),
                ),
              ),
              // Logo
              SplashLogo(size: size),
            ],
          ),
        );
      },
    );
  }
}

/// Step indicators with animated transitions and labels.
class _StepIndicators extends StatelessWidget {
  const _StepIndicators({
    required this.currentStep,
    required this.shimmerController,
    required this.statusMessage,
  });

  final int currentStep;
  final AnimationController shimmerController;
  final String statusMessage;

  static const _steps = [
    _StepData(Icons.settings_outlined, 'Config'),
    _StepData(Icons.phone_android_outlined, 'Device'),
    _StepData(Icons.verified_user_outlined, 'Security'),
    _StepData(Icons.wifi_outlined, 'Connect'),
    _StepData(Icons.directions_bus_outlined, 'Transit'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Step dots row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_steps.length, (index) {
            final isCompleted = index < currentStep;
            final isCurrent = index == currentStep;
            final isPending = index > currentStep;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index > 0)
                  _StepConnector(
                    active: index <= currentStep,
                  ),
                _StepDot(
                  step: _steps[index],
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isPending: isPending,
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 16),
        // Current step label with animated transition
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            statusMessage,
            key: ValueKey(statusMessage),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepData {
  const _StepData(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Single step dot: completed (checkmark), current (animated), or pending.
class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.isPending,
  });

  final _StepData step;
  final bool isCompleted;
  final bool isCurrent;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = isCurrent ? 36.0 : 28.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? scheme.primary
            : isCurrent
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
        border: isCurrent
            ? Border.all(color: scheme.primary, width: 2)
            : null,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: isCompleted
            ? Icon(
                Icons.check_rounded,
                key: const ValueKey('check'),
                size: isCurrent ? 18 : 14,
                color: scheme.onPrimary,
              )
            : Icon(
                step.icon,
                key: ValueKey(step.icon),
                size: isCurrent ? 18 : 14,
                color: isCurrent
                    ? scheme.primary
                    : isPending
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                        : scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

/// Animated connector line between step dots.
class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 20,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        color: active ? scheme.primary : scheme.surfaceContainerHighest,
      ),
    );
  }
}

/// Smooth progress bar with shimmer effect and percentage.
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
    final textTheme = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final percent = (value * 100).clamp(0, 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      color: scheme.surfaceContainerHighest,
                    ),
                    // Progress fill
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary,
                              scheme.primary.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Shimmer overlay
                    if (value < 1.0)
                      AnimatedBuilder(
                        animation: shimmerController,
                        builder: (context, _) {
                          return FractionallySizedBox(
                            widthFactor: value,
                            child: Align(
                              alignment: Alignment(
                                2.0 * shimmerController.value - 1.0,
                                0,
                              ),
                              child: Container(
                                width: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$percent%',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Recovery state: honest error message with retry action.
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color: scheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Couldn\'t prepare the app',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                service.errorMessage ?? 'Please try again.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (service.failedStep != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Failed at: ${service.failedStep!.label}',
                    style: textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: service.retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can also close and reopen the app.',
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

/// App logo. Uses `assets/logo.png` when present; otherwise falls back to a
/// programmatic bus-in-ring mark.
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

/// Drawn fallback logo: a ring around a bus icon.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 128});

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
              border: Border.all(color: primary, width: size * 0.04),
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
              size: size * 0.3,
              color: AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}
