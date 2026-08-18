import 'package:flutter/material.dart';
import 'controllers/theme_controller.dart';
import 'screens/bootstrap_screen.dart';
import 'services/auth_service.dart';
import 'services/bootstrap_service.dart';
import 'services/favourite_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common/app_services.dart';

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
  final AuthService _authService = AuthService();
  final FavouriteService _favouriteService = FavouriteService();

  @override
  void initState() {
    super.initState();
    _authService.listenForOAuthCallback();
    _authService.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_authService.isLoggedIn) {
      _favouriteService.loadFavourites();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _bootstrapService.dispose();
    _authService.dispose();
    _favouriteService.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, themeMode, _) {
        return AppServices(
          authService: _authService,
          favouriteService: _favouriteService,
          child: MaterialApp(
            title: 'RapidTransit KL',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: BootstrapScreen(
              service: _bootstrapService,
              themeController: _themeController,
              authService: _authService,
              favouriteService: _favouriteService,
            ),
          ),
        );
      },
    );
  }
}