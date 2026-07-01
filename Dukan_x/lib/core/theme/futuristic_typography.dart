// ============================================================================
// MODERN TYPOGRAPHY THEME
// ============================================================================
// Premium typography for DukanX:
// - Uses Google Fonts (Inter, Poppins-like system fonts)
// - Defines text styles for all UI elements
// - Supports light and dark modes
// ============================================================================

import 'package:flutter/material.dart';

import 'futuristic_colors.dart';

/// Modern text theme for DukanX app
class FuturisticTypography {
  FuturisticTypography._();

  /// Primary font family (uses system font with custom weights)
  static const String fontFamily = 'Inter';

  /// Display text - Large headlines (28-34pt)
  static TextStyle display({bool isDark = false}) => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: isDark ? Colors.white : FuturisticColors.textPrimary,
  );

  /// Headline text - Section titles (22-24pt)
  static TextStyle headline({bool isDark = false}) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.3,
    color: isDark ? Colors.white : FuturisticColors.textPrimary,
  );

  /// Title text - Card titles (18-20pt)
  static TextStyle title({bool isDark = false}) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
    color: isDark ? Colors.white : FuturisticColors.textPrimary,
  );

  /// Subtitle text - Secondary headings (16pt)
  static TextStyle subtitle({bool isDark = false}) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: isDark ? Colors.white70 : FuturisticColors.textSecondary,
  );

  /// Body text - Main content (14-15pt)
  static TextStyle body({bool isDark = false}) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
    color: isDark ? Colors.white70 : FuturisticColors.textPrimary,
  );

  /// Body small text - Secondary content (13pt)
  static TextStyle bodySmall({bool isDark = false}) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.5,
    color: isDark ? Colors.white60 : FuturisticColors.textSecondary,
  );

  /// Label text - Buttons, chips (13-14pt)
  static TextStyle label({bool isDark = false}) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
    color: isDark ? Colors.white : FuturisticColors.textPrimary,
  );

  /// Caption text - Small labels (11-12pt)
  static TextStyle caption({bool isDark = false}) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.4,
    color: isDark ? Colors.white54 : FuturisticColors.textMuted,
  );

  /// Number display - Large numbers (24-28pt)
  static TextStyle number({bool isDark = false, Color? color}) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? (isDark ? Colors.white : FuturisticColors.textPrimary),
  );

  /// Currency display - Money amounts
  static TextStyle currency({bool isDark = false, Color? color}) => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? (isDark ? Colors.white : FuturisticColors.textPrimary),
  );

  /// Build complete TextTheme for MaterialApp
  static TextTheme buildTextTheme({bool isDark = false}) {
    return TextTheme(
      displayLarge: display(isDark: isDark),
      displayMedium: headline(isDark: isDark),
      displaySmall: title(isDark: isDark),
      headlineLarge: headline(isDark: isDark),
      headlineMedium: title(isDark: isDark),
      headlineSmall: subtitle(isDark: isDark),
      titleLarge: title(isDark: isDark),
      titleMedium: subtitle(isDark: isDark),
      titleSmall: label(isDark: isDark),
      bodyLarge: body(isDark: isDark),
      bodyMedium: bodySmall(isDark: isDark),
      bodySmall: caption(isDark: isDark),
      labelLarge: label(isDark: isDark),
      labelMedium: caption(isDark: isDark),
      labelSmall: caption(isDark: isDark),
    );
  }
}

/// Extension to easily apply typography
extension FuturisticTextStyles on BuildContext {
  /// Access typography based on current theme
  FuturisticTypography get typography => FuturisticTypography._();

  /// Check if dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Display text style
  TextStyle get displayStyle =>
      FuturisticTypography.display(isDark: isDarkMode);

  /// Headline text style
  TextStyle get headlineStyle =>
      FuturisticTypography.headline(isDark: isDarkMode);

  /// Title text style
  TextStyle get titleStyle => FuturisticTypography.title(isDark: isDarkMode);

  /// Body text style
  TextStyle get bodyStyle => FuturisticTypography.body(isDark: isDarkMode);

  /// Label text style
  TextStyle get labelStyle => FuturisticTypography.label(isDark: isDarkMode);

  /// Caption text style
  TextStyle get captionStyle =>
      FuturisticTypography.caption(isDark: isDarkMode);
}
