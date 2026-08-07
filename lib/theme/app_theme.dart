import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0F172A);
  static const navyLight = Color(0xFF1E293B);
  static const navyVeryLight = Color(0x0D0F172A); // 5% opacity
  static const navyBorder = Color(0x140F172A); // 8% opacity
  static const navyTextPrimary = Color(0xFF0F172A);
  static const navyTextSecondary = Color(0x800F172A); // 50% opacity
  static const navyTextTertiary = Color(0x660F172A); // 40% opacity
  static const navyTextHint = Color(0x4D0F172A); // 30% opacity
  static const skyDark = Color(0xFF0369A1);
  static const sky = Color(0xFF075985);
  static const white = Colors.white;
  static const backgroundLight = Color(0xFFF1F5F9);
  static const emerald = Color(0xFF10B981);
  static const red = Color.fromARGB(255, 198, 73, 73);
}

/// Per-provider color themes for provider-related buttons, icons and markers.
///
/// Kept deliberately distinct from the app's default navy theme
/// (`AppColors.navy`) so provider colors never collide with the base UI.
class ProviderTheme {
  const ProviderTheme({
    required this.primary,
    required this.onPrimary,
    required this.light,
    required this.border,
  });

  /// Solid fill color for buttons, badges and markers.
  final Color primary;

  /// Foreground (icon/label) color placed on [primary].
  final Color onPrimary;

  /// Subtle tint used for selected/active backgrounds.
  final Color light;

  /// Border / outline color.
  final Color border;

  /// Rapid KL Bus → red theme.
  static const rapidKl = ProviderTheme(
    primary: AppColors.red,
    onPrimary: AppColors.white,
    light: Color(0x1AC64949), // ~10% red tint
    border: Color(0x33C64949), // ~20% red tint
  );

  /// Rapid KL MRT Feeder → sky theme.
  static const mrtFeeder = ProviderTheme(
    primary: AppColors.sky,
    onPrimary: AppColors.white,
    light: Color(0x1A075985), // ~10% sky tint
    border: Color(0x33075985), // ~20% sky tint
  );

  /// App-default theme (navy), used when no provider theme applies.
  static const defaultTheme = ProviderTheme(
    primary: AppColors.navy,
    onPrimary: AppColors.white,
    light: AppColors.navyVeryLight,
    border: AppColors.navyBorder,
  );

  /// Resolves the theme for a provider key, falling back to [defaultTheme].
  static ProviderTheme of(String? providerKey) {
    switch (providerKey) {
      case 'rapid_bus_kl':
        return rapidKl;
      case 'rapid_bus_mrtfeeder':
        return mrtFeeder;
      default:
        return defaultTheme;
    }
  }
}

class AppTypography {
  static const _fontFamily = 'Roboto';

  static const textXs = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.05,
  );

  static const textXsSemibold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.05,
  );

  static const textSm = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const textSmSemibold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const textBase = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const textBaseSemibold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const textLg = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const textXl = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static const fontMono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const fontMonoSm = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: AppColors.white,
        secondary: AppColors.navyLight,
        surface: AppColors.white,
        onSurface: AppColors.navyTextPrimary,
        outline: AppColors.navyBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.navyTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.navyTextPrimary,
            );
          }
          return const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.navyTextTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.navyTextPrimary,
              size: 20,
            );
          }
          return const IconThemeData(
            color: AppColors.navyTextTertiary,
            size: 20,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.navyTextPrimary,
        unselectedItemColor: AppColors.navyTextTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.navyBorder,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.navyBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navyVeryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navyBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navyBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navyTextSecondary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          color: AppColors.navyTextHint,
        ),
      ),
    );
  }
}
