import 'dart:async';

import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'device_identity.dart';
import 'pow_token_service.dart';
import 'provider_repository.dart';
import 'secure_token_store.dart';

/// High-level bootstrap state.
enum BootstrapStatus {
  /// Bootstrap is running (or about to). Show the splash/progress.
  running,

  /// All required work succeeded; safe to show the Home screen.
  ready,

  /// Bootstrap failed; show a recovery state with retry.
  failed,
}

/// The discrete work items performed during bootstrap. Tracked so progress
/// copy is honest and so a failure can report exactly which part of init broke.
enum BootstrapStep {
  config('app configuration'),
  device('device setup'),
  token('secure access'),
  api('transit connection'),
  data('transit data');

  const BootstrapStep(this.label);

  /// Human-readable label shown when this step fails.
  final String label;
}

/// Orchestrates app-launch bootstrap.
///
/// Sequence (per launch):
/// 1. Load app configuration (static env constants).
/// 2. Generate/persist a stable device ID.
/// 3. (No parent auth exists in this app — PoW is the only auth.)
/// 4. Restore a valid cached PoW token if it is still usable.
/// 5. Otherwise run Turnstile in invisible (headless) mode and exchange the
///    token for a PoW token at `{{prod_base}}/security/pow-token`.
/// 6. Configure authenticated API access (`x-pow-token` header).
/// 7. Initialise only the essential static transit data (bundled providers).
///
/// UI state ([progress], [statusMessage], [errorMessage]) is deliberately
/// separate from the token/network logic. [start] is single-flight so
/// duplicate concurrent bootstrap runs cannot happen.
class BootstrapService extends ChangeNotifier {
  BootstrapService({
    DeviceIdentity? identity,
    PowTokenService? powToken,
    ProviderRepository? providers,
  })  : _identity = identity ?? DeviceIdentity(SecureTokenStore()),
        _powToken = powToken ?? PowTokenService(),
        _providers = providers ?? ProviderRepository();

  final DeviceIdentity _identity;
  final PowTokenService _powToken;
  final ProviderRepository _providers;

  BootstrapStatus _status = BootstrapStatus.running;
  double _progress = 0;
  String _statusMessage = 'Preparing transit information…';
  String? _errorMessage;
  Future<void>? _inFlight;
  BootstrapStep? _currentStep;
  BootstrapStep? _failedStep;

  BootstrapStatus get status => _status;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  /// The bootstrap step that failed, or `null` when bootstrap never failed.
  /// Lets the UI (and logs) pinpoint exactly which part of init broke.
  BootstrapStep? get failedStep => _failedStep;

  /// Starts bootstrap. Returns the same future for concurrent callers.
  Future<void> start() {
    return _inFlight ??= _run();
  }

  /// Re-runs bootstrap after a failure.
  Future<void> retry() {
    _status = BootstrapStatus.running;
    _errorMessage = null;
    _failedStep = null;
    _progress = 0;
    _statusMessage = 'Preparing transit information…';
    notifyListeners();
    _inFlight = _run();
    return _inFlight!;
  }

  Future<void> _run() async {
    try {
      // 1. Configuration (static env constants — stage kept for honest copy).
      _beginStep(BootstrapStep.config, 0.05, 'Loading app configuration…');

      // 2. Device identity.
      _beginStep(BootstrapStep.device, 0.20, 'Preparing your device…');
      final deviceId = await _identity.ensureDeviceId();
      // Make the device ID available to every transit request header.
      ApiService.setDeviceId(deviceId);
      _completeStep(BootstrapStep.device);

      // 3–5. PoW token: reuse a valid cached one, else Turnstile + exchange.
      _beginStep(BootstrapStep.token, 0.45, 'Verifying secure access…');
      final powToken = await _obtainPowToken(deviceId);
      _completeStep(BootstrapStep.token);

      // 6. Configure authenticated API access.
      _beginStep(BootstrapStep.api, 0.75, 'Connecting to transit services…');
      ApiService.setPowToken(powToken.token);
      _completeStep(BootstrapStep.api);

      // 7. Essential static transit data (bundled providers — cheap).
      _beginStep(BootstrapStep.data, 0.90, 'Loading transit information…');
      await _providers.loadProviders();
      _completeStep(BootstrapStep.data);

      _progress = 1;
      _statusMessage = 'Ready';
      _status = BootstrapStatus.ready;
      notifyListeners();
    } catch (e, st) {
      final failed = _currentStep;
      _failedStep = failed;
      // Debug breadcrumb: exactly which step of init broke and why.
      debugPrint('[bootstrap] FAILED at ${failed?.name ?? 'unknown'}'
          ' (${failed?.label ?? 'unknown'}): $e');
      debugPrint('[bootstrap] $st');
      _status = BootstrapStatus.failed;
      _statusMessage = 'Could not finish preparing the app.';
      _errorMessage = _friendlyError(e);
      notifyListeners();
    } finally {
      _inFlight = null;
    }
  }

  Future<PowToken> _obtainPowToken(String deviceId) async {
    final cached = await _powToken.cachedIfUsable();
    if (cached != null) return cached;
    // Turnstile always runs in invisible (headless) mode — no challenge UI is
    // ever shown. If the challenge can't complete, this throws and bootstrap
    // surfaces a retry-able failure.
    return _powToken.getOrRefresh(deviceId);
  }

  void _beginStep(BootstrapStep step, double value, String message) {
    _currentStep = step;
    _failedStep = null;
    debugPrint('[bootstrap] → ${step.name} (${step.label})');
    _setProgress(value, message);
  }

  void _completeStep(BootstrapStep step) {
    debugPrint('[bootstrap] ✓ ${step.name} (${step.label})');
  }

  void _setProgress(double value, String message) {
    _progress = value;
    _statusMessage = message;
    notifyListeners();
  }

  static String _friendlyError(Object error) {
    if (error is TurnstileException) {
      return 'The security check could not be completed. '
          'Check your connection and try again.';
    }
    if (error is PowTokenException) {
      return 'Could not verify this device with the transit service. '
          'Please try again.';
    }
    if (error is TimeoutException) {
      return 'The app took too long to respond. Please try again.';
    }
    return 'Something went wrong while preparing the app. Please try again.';
  }
}
