import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';
import '../services/auth_service.dart';
import '../services/bootstrap_service.dart';
import '../services/favourite_service.dart';
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
    required this.authService,
    required this.favouriteService,
  });

  final BootstrapService service;
  final ThemeController themeController;
  final AuthService authService;
  final FavouriteService favouriteService;

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

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        // Restore account session if available.
        await widget.authService.restoreSession();

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => HomeScreen(
              themeController: widget.themeController,
              authService: widget.authService,
              favouriteService: widget.favouriteService,
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedLogo(
            pulseController: _pulseController,
            size: 80,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            service.statusMessage,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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