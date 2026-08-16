import 'package:flutter/material.dart';

/// App-wide theme mode.
///
/// A thin [ValueNotifier<ThemeMode>] shared by `RapidTransitApp` (which
/// rebuilds the [MaterialApp] theme on change) and the Profile screen's theme
/// picker. Session-only: no persistence, so the choice resets to
/// [ThemeMode.system] on restart.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light);

  void setMode(ThemeMode mode) {
    if (value == mode) return;
    value = mode;
  }
}
