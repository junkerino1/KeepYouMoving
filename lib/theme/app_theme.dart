import 'package:flutter/material.dart';

class AppColors {
  // Brand primitives.
  static const navy = Color(0xFF0F172A);
  static const navyLight = Color(0xFF1E293B);
  static const sky = Color(0xFF075985);
  static const skyDark = Color(0xFF0369A1);
  static const white = Colors.white;
  static const backgroundLight = Color(0xFFF1F5F9);

  // Legacy tokens retained while widgets migrate to theme roles.
  static const navyVeryLight = Color(0x0D0F172A); // 5% opacity
  static const navyBorder = Color(0x140F172A); // 8% opacity

  // AA-compliant text colors for light surfaces. Prefer theme text styles;
  // these are fallbacks only.
  static const navyTextPrimary = Color(0xFF0F172A);
  static const navyTextSecondary = Color(0xFF475569); // ~7.4:1 on white
  static const navyTextTertiary = Color(0xFF64748B); // ~4.7:1 on white
  static const navyTextHint = Color(0xFF64748B); // ~4.7:1 on white

  // Semantic status colors.
  static const emerald = Color(0xFF10B981); // on-dark "due soon"
  static const emeraldDark = Color(0xFF047857); // on-light "due soon", AA
  static const amber = Color.fromARGB(255, 255, 227, 67); // on-dark "approaching"
  static const amberDark = Color.fromARGB(255, 255, 248, 47); // on-light "approaching", AA
  static const red = Color.fromARGB(255, 198, 73, 73); // Rapid KL brand
  static const error = Color(0xFFB91C1C); // AA error on light surfaces
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

  /// Material type scale for Roboto. Roles map to semantic colors so widgets
  /// reference `Theme.of(context).textTheme.*` instead of hand-picking sizes.
  static TextTheme build(ColorScheme scheme) {
    return TextTheme(
      displaySmall: const TextStyle(
          fontFamily: _fontFamily, fontSize: 36, fontWeight: FontWeight.w700),
      headlineMedium: const TextStyle(
          fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w700),
      headlineSmall: const TextStyle(
          fontFamily: _fontFamily, fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: const TextStyle(
          fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface),
      titleSmall: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface),
      bodyLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface),
      bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface),
      bodySmall: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant),
      labelLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface),
      labelMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant),
      labelSmall: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant),
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData get darkTheme => _build(Brightness.dark);

  /// Material 3 color scheme for the given brightness. The navy brand is
  /// preserved: light surfaces stay white/slate, dark surfaces are built from
  /// the navy family rather than a mechanical invert.
  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    if (!isDark) {
      return const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: AppColors.white,
        primaryContainer: Color(0xFFE2E8F0),
        onPrimaryContainer: AppColors.navy,
        secondary: AppColors.navyLight,
        onSecondary: AppColors.white,
        secondaryContainer: Color(0xFFE2E8F0),
        onSecondaryContainer: AppColors.navy,
        tertiary: AppColors.sky,
        onTertiary: AppColors.white,
        tertiaryContainer: Color(0xFFE0F2FE),
        onTertiaryContainer: AppColors.skyDark,
        error: AppColors.error,
        onError: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.navy,
        surfaceContainerLowest: AppColors.white,
        surfaceContainerLow: Color(0xFFF8FAFC),
        surfaceContainer: AppColors.backgroundLight,
        surfaceContainerHigh: Color(0xFFE2E8F0),
        surfaceContainerHighest: Color(0xFFCBD5E1),
        onSurfaceVariant: AppColors.navyTextSecondary,
        outline: AppColors.navyTextTertiary,
        outlineVariant: Color(0xFFCBD5E1),
        inverseSurface: AppColors.navyLight,
        onInverseSurface: AppColors.backgroundLight,
        inversePrimary: Color(0xFF93C5FD),
      );
    }
    return const ColorScheme.dark(
      primary: Color(0xFF93C5FD),
      onPrimary: Color(0xFF0F172A),
      primaryContainer: Color(0xFF1E3A5F),
      onPrimaryContainer: Color(0xFFBFDBFE),
      secondary: Color(0xFF94A3B8),
      onSecondary: Color(0xFF0F172A),
      secondaryContainer: Color(0xFF1E293B),
      onSecondaryContainer: Color(0xFFCBD5E1),
      tertiary: Color(0xFF7DD3FC),
      onTertiary: Color(0xFF0C4A6E),
      tertiaryContainer: Color(0xFF0C4A6E),
      onTertiaryContainer: Color(0xFFBAE6FD),
      error: Color(0xFFF87171),
      onError: Color(0xFF450A0A),
      surface: Color(0xFF0B1220),
      onSurface: Color(0xFFE2E8F0),
      surfaceContainerLowest: Color(0xFF070D18),
      surfaceContainerLow: Color(0xFF0F172A),
      surfaceContainer: Color(0xFF0F172A),
      surfaceContainerHigh: Color(0xFF1E293B),
      surfaceContainerHighest: Color(0xFF334155),
      onSurfaceVariant: Color(0xFF94A3B8),
      outline: Color(0xFF64748B),
      outlineVariant: Color(0xFF334155),
      inverseSurface: Color(0xFFE2E8F0),
      onInverseSurface: Color(0xFF0F172A),
      inversePrimary: Color(0xFF1D4ED8),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = _scheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: AppTypography.build(scheme),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        selectedLabelTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
