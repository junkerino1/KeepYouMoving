import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device and application values shared by backend requests.
class AppMetadata {
  AppMetadata._();

  static String deviceModel = '';

  /// Mutable app-wide version sent to the backend and shown in the UI.
  /// It can be overridden at build time with `--dart-define=APP_VERSION=...`.
  static String appVersion = const String.fromEnvironment('APP_VERSION');
  static String platform = _resolvePlatform();

  static Future<void>? _initialization;

  static Future<void> initialize() {
    return _initialization ??= _load();
  }

  static Future<void> _load() async {
    platform = _resolvePlatform();
    if (appVersion.trim().isEmpty) {
      appVersion = (await PackageInfo.fromPlatform()).version;
    }

    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      final info = await deviceInfo.webBrowserInfo;
      deviceModel = _joinParts([info.vendor, info.platform]);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final info = await deviceInfo.androidInfo;
      deviceModel = _joinParts([info.manufacturer, info.model]);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final info = await deviceInfo.iosInfo;
      deviceModel = _joinParts(['Apple', info.model]);
      return;
    }

    deviceModel = 'Web';
  }

  static String _resolvePlatform() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }

  static String _joinParts(Iterable<String?> parts) {
    return parts
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
  }
}
