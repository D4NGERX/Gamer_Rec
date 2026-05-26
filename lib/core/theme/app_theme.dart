// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';

abstract class AppColors {
  // Dark theme colors
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF242424);
  static const Color accent = Color(0xFFE8003A);
  static const Color accentSecondary = Color(0xFFFF6B35);
  static const Color onSurface = Color(0xFFE0E0E0);
  static const Color onSurfaceMuted = Color(0xFF757575);
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFD600);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFEEEEEE);
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  static const Color lightOnSurfaceMuted = Color(0xFF757575);
}

/// Creates theme data based on brightness
ThemeData createAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final background = isDark ? AppColors.background : AppColors.lightBackground;
  final surface = isDark ? AppColors.surface : AppColors.lightSurface;
  final surfaceElevated = isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated;
  final onSurface = isDark ? AppColors.onSurface : AppColors.lightOnSurface;
  final onSurfaceMuted = isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: isDark
        ? ColorScheme.dark(
            surface: surface,
            primary: AppColors.accent,
            secondary: AppColors.accentSecondary,
            onPrimary: Colors.white,
            onSurface: onSurface,
          )
        : ColorScheme.light(
            surface: surface,
            primary: AppColors.accent,
            secondary: AppColors.accentSecondary,
            onPrimary: Colors.white,
            onSurface: onSurface,
          ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    iconTheme: IconThemeData(color: onSurface),
    textTheme: TextTheme(
      displayLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w600, fontSize: 20),
      titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w500, fontSize: 16),
      bodyLarge: TextStyle(color: onSurface, fontSize: 14),
      bodyMedium: TextStyle(color: onSurfaceMuted, fontSize: 13),
      labelSmall: TextStyle(color: onSurfaceMuted, fontSize: 11, letterSpacing: 0.8),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.accent,
      thumbColor: AppColors.accent,
      inactiveTrackColor: surfaceElevated,
      overlayColor: const Color(0x33E8003A),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.accent
              : onSurfaceMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.accent.withValues(alpha: 0.4)
              : surfaceElevated),
    ),
    dividerTheme: DividerThemeData(
      color: surfaceElevated,
      thickness: 1,
      space: 1,
    ),
    useMaterial3: true,
  );
}

// Default dark theme (for backwards compatibility)
final ThemeData appTheme = createAppTheme(Brightness.dark);
