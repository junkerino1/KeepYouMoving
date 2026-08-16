import 'package:flutter/material.dart';
import 'controllers/theme_controller.dart';
import 'screens/bootstrap_screen.dart';
import 'services/bootstrap_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RapidTransitApp());
}

class RapidTransitApp extends StatefulWidget {
  const RapidTransitApp({super.key});

  @override
  State<RapidTransitApp> createState() => _RapidTransitAppState();
}

class _RapidTransitAppState extends State<RapidTransitApp> {
  final ThemeController _themeController = ThemeController();
  final BootstrapService _bootstrapService = BootstrapService();

  @override
  void dispose() {
    _bootstrapService.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'RapidTransit KL',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          // The bootstrap splash renders immediately; the Home screen is only
          // shown after the required startup work succeeds.
          home: BootstrapScreen(
            service: _bootstrapService,
            themeController: _themeController,
          ),
        );
      },
    );
  }
}