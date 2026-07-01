import 'package:flutter/material.dart';

/// A dynamic theme-aware color that can be constructed as a const but resolves its value at runtime.
class DynamicThemeColor extends Color {
  final int darkValue;
  final int lightValue;

  const DynamicThemeColor(this.darkValue, this.lightValue) : super(darkValue);

  @override
  int get value => FuturisticColors.isDark ? darkValue : lightValue;
}

/// Futuristic Color Palette for DukanX Desktop Redesign
class FuturisticColors {
  static bool _isDark = false;
  static bool get isDark => _isDark;

  static void sync(bool isDark) {
    _isDark = isDark;
  }

  // Backgrounds - Deep Space Enterprise
  static const Color background = DynamicThemeColor(0xFF0F172A, 0xFFF8FAFC); // Slate 900 vs Slate 50
  static const Color surface = DynamicThemeColor(0xFF1E293B, 0xFFFFFFFF); // Slate 800 vs White
  static const Color surfaceGlass = DynamicThemeColor(0xCC1E293B, 0xCCFFFFFF); // Translucent Slate 800 vs White

  // Primary Actions - Neon Cyan/Blue
  static const Color primary = Color(0xFF3B82F6); // Blue 500
  static const Color primaryDark = Color(0xFF1D4ED8); // Blue 700
  static const Color accent1 = Color(0xFF06B6D4); // Cyan 500
  static const Color accent2 = Color(0xFF8B5CF6); // Violet 500

  // Status Colors (Vibrant but legible)
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF3B82F6); // Blue 500

  // Text
  static const Color textPrimary = DynamicThemeColor(0xFFF8FAFC, 0xFF0F172A); // Slate 50 vs Slate 900
  static const Color textSecondary = DynamicThemeColor(0xFF94A3B8, 0xFF475569); // Slate 400 vs Slate 600
  static const Color textDisabled = DynamicThemeColor(0xFF64748B, 0xFF94A3B8); // Slate 500 vs Slate 400

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get glassGradient => LinearGradient(
    colors: [
      (_isDark ? const Color(0xFF38BDF8) : const Color(0xFF3B82F6)).withOpacity(_isDark ? 0.1 : 0.05),
      (_isDark ? const Color(0xFF38BDF8) : const Color(0xFF3B82F6)).withOpacity(0.02),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get darkBackgroundGradient => LinearGradient(
    colors: _isDark 
        ? [const Color(0xFF0F172A), const Color(0xFF020617)] 
        : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows/Glows
  static List<BoxShadow> neonShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(_isDark ? 0.2 : 0.05),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // ===========================================================================
  // LEGACY COMPATIBILITY LAYER (To fix existing lints)
  // ===========================================================================
  static const Color secondary = accent1;
  static const Color accent = accent2;
  static const Color textMuted = textSecondary;
  static const Color darkBackground = DynamicThemeColor(0xFF0F172A, 0xFFF8FAFC);
  static const Color darkSurface = DynamicThemeColor(0xFF1E293B, 0xFFFFFFFF);
  static const Color darkTextPrimary = DynamicThemeColor(0xFFF8FAFC, 0xFF0F172A);
  static const Color darkTextSecondary = DynamicThemeColor(0xFF94A3B8, 0xFF475569);
  static const Color darkDivider = DynamicThemeColor(0x1AFFFFFF, 0x13000000);
  static const Color divider = DynamicThemeColor(0x1AFFFFFF, 0x13000000);
  static const Color onSurface = DynamicThemeColor(0xFFFFFFFF, 0xFF0F172A);
  static const Color dividerColor = divider;

  static LinearGradient get lightBackgroundGradient => darkBackgroundGradient;

  static const LinearGradient errorGradient = LinearGradient(
    colors: [error, Color(0xFF991B1B)], // Red 500 -> Red 800
  );

  static const Color neonBlue = accent1;
  static const Color backgroundDark = DynamicThemeColor(0xFF0F172A, 0xFFF1F5F9);
  static const Color paidBackground = DynamicThemeColor(0xFF064E3B, 0xFFD1FAE5); // Emerald 900 vs Emerald 100
  static const Color unpaidBackground = DynamicThemeColor(0xFF7F1D1D, 0xFFFEE2E2); // Red 900 vs Red 100

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF065F46)], // Emerald 500 -> Emerald 800
  );

  static const Color paid = success;
  static const Color unpaid = error;
  static const Color primaryLight = primary;
  static const Color darkSurfaceVariant = surface;
  static const Color surfaceVariant = surface;
  static const Color textHint = textDisabled;
  static const Color darkTextMuted = textSecondary;
  static const Color darkSurfaceElevated = surface;
  static const Color surfaceElevated = DynamicThemeColor(0xFF334155, 0xFFF1F5F9);
  static const Color white = Colors.white;
  static const Color glassBorder = DynamicThemeColor(0x1AFFFFFF, 0x1A000000);
  static const Color glassBorderDark = DynamicThemeColor(0x1AFFFFFF, 0x1A000000);

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, Color(0xFF92400E)], // Amber 500 -> Amber 800
  );

  static const Color successDark = Color(0xFF064E3B);
  static const Color errorDark = Color(0xFF7F1D1D);
  static const Color warningDark = Color(0xFF78350F);
  static const Color accent3 = accent2;
  static const Color secondaryLight = accent1;
  static const Color primaryLight2 = primary; // Fallback

  // Modern UI Aliases
  static const Color surfaceHighlight = Color(0xFF334155); // Slate 700
  static const Color cardBackground = surface;
  static const Color border = DynamicThemeColor(0xFF334155, 0xFFCBD5E1); // Slate 700 vs Slate 300
  static const Color iconPrimary = textPrimary;

  // ===========================================================================
  // PREMIUM UI ENHANCEMENT - Futuristic Accents
  // ===========================================================================

  /// Premium blue accent for futuristic UI (matches reference image)
  static const Color premiumBlue = Color(0xFF00D4FF);
  static const Color premiumBlueDark = Color(0xFF0099CC);
  static const Color premiumBlueGlow = Color(0xFF00D4FF);

  /// Generate premium glow box shadow for cards and buttons
  static List<BoxShadow> premiumGlow({
    Color? color,
    double blurRadius = 12,
    double spreadRadius = 0,
    double opacity = 0.3,
  }) => [
    BoxShadow(
      color: (color ?? premiumBlue).withOpacity(_isDark ? opacity : opacity * 0.5),
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
    ),
  ];

  /// Premium card border with glow effect
  static BoxDecoration premiumCardDecoration({
    Color? borderColor,
    double borderWidth = 1,
    double borderRadius = 12,
    Color? backgroundColor,
  }) => BoxDecoration(
    color: backgroundColor ?? surface,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: (borderColor ?? premiumBlue).withOpacity(_isDark ? 0.3 : 0.15),
      width: borderWidth,
    ),
    boxShadow: [
      BoxShadow(
        color: (borderColor ?? premiumBlue).withOpacity(_isDark ? 0.1 : 0.05),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ],
  );

  /// Starfield overlay gradient for background texture
  static LinearGradient get starfieldOverlay => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(_isDark ? 0.05 : 0.01),
      Colors.white.withOpacity(_isDark ? 0.02 : 0.00),
      Colors.white.withOpacity(_isDark ? 0.05 : 0.01),
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  /// Premium top bar gradient with subtle blue accent
  static LinearGradient get premiumTopBarGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: _isDark 
        ? [const Color(0xFF0F172A), const Color(0xFF0D1526)] 
        : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
  );

  /// Icon glow decoration for sidebar icons with blue accent
  static BoxDecoration iconGlowDecoration({
    Color? accentColor,
    bool isActive = false,
  }) => BoxDecoration(
    color: (accentColor ?? premiumBlue).withOpacity(isActive ? 0.2 : 0.1),
    borderRadius: BorderRadius.circular(10),
    boxShadow: isActive
        ? [
            BoxShadow(
              color: (accentColor ?? premiumBlue).withOpacity(_isDark ? 0.4 : 0.2),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ]
        : null,
  );

  /// Premium content area background decoration with star effect support
  static BoxDecoration premiumContentBackground({Color? backgroundColor}) =>
      BoxDecoration(
        color: backgroundColor ?? background,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDark 
              ? [const Color(0xFF0F172A), const Color(0xFF0A0F1C)] 
              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
        ),
      );

  /// Top bar glow border for premium effect
  static Border topBarGlowBorder() =>
      Border(bottom: BorderSide(color: premiumBlue.withOpacity(_isDark ? 0.2 : 0.1), width: 1));

  static const Color surfaceHigh = Color(0xFF475569); // Slate 600
  static const Color hoverTint = Color(0x1A00D4FF); // Premium blue with 10% opacity
}
