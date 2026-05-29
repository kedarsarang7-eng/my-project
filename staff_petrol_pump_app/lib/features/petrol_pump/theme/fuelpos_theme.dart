import 'package:flutter/material.dart';

/// FuelPOS Dark Theme - Professional POS aesthetic
/// Based on the reference image with dark navy background and vibrant accent colors
class FuelPOSTheme {
  // Primary colors
  static const Color primaryBlue = Color(0xFF4A90D9);
  static const Color primaryOrange = Color(0xFFFFA726);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryRed = Color(0xFFEF5350);
  static const Color primaryYellow = Color(0xFFFFC107);

  // Dark theme background colors
  static const Color backgroundDark = Color(0xFF0F1419);
  static const Color surfaceDark = Color(0xFF1A1F2E);
  static const Color cardDark = Color(0xFF252B3D);
  static const Color sidebarDark = Color(0xFF161B28);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8C4);
  static const Color textMuted = Color(0xFF6B7280);

  // Accent colors for charts and indicators
  static const Color petrolBlue = Color(0xFF4A90D9);
  static const Color dieselOrange = Color(0xFFFFA726);
  static const Color lubricantGreen = Color(0xFF66BB6A);
  static const Color shopGray = Color(0xFF78909C);

  // Status colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningYellow = Color(0xFFFFC107);
  static const Color errorRed = Color(0xFFEF5350);
  static const Color infoBlue = Color(0xFF2196F3);

  // Border and divider colors
  static const Color borderDark = Color(0xFF2D3548);
  static const Color dividerDark = Color(0xFF2D3548);

  // Sidebar active item
  static const Color sidebarActiveBg = Color(0xFF252B3D);
  static const Color sidebarActiveBorder = Color(0xFF4A90D9);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: primaryOrange,
        surface: surfaceDark,
        onSurface: textPrimary,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderDark),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerDark,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return primaryBlue.withAlpha(0x1A);
          }
          return null;
        }),
        headingRowColor: WidgetStateProperty.all(surfaceDark),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 16,
        dataTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
        ),
        headingTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardDark,
        selectedColor: primaryBlue.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: primaryBlue, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderDark),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // Helper method for KPI card gradients
  static LinearGradient getKpiGradient(Color color) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: 0.15),
        color.withValues(alpha: 0.05),
      ],
    );
  }

  // Status badge styles
  static BoxDecoration successBadge = BoxDecoration(
    color: successGreen.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(4),
  );

  static BoxDecoration warningBadge = BoxDecoration(
    color: warningYellow.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(4),
  );

  static BoxDecoration errorBadge = BoxDecoration(
    color: errorRed.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(4),
  );

  static BoxDecoration neutralBadge = BoxDecoration(
    color: textMuted.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(4),
  );
}
