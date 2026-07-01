import 'package:flutter/material.dart';
import 'futuristic_colors.dart';

/// Premium Desktop Theme for DukanX
/// Enterprise-grade, futuristic design with high contrast and premium controls
class DesktopTheme {
  DesktopTheme._();

  // ════════════════════════════════════════════════════════════════════════════
  // MAIN DARK THEME
  // ════════════════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FuturisticColors.background,
      primaryColor: FuturisticColors.primary,
      fontFamily: 'Inter',

      // ══════════════════════════════════════════════════════════════════════
      // COLOR SCHEME
      // ══════════════════════════════════════════════════════════════════════
      colorScheme: const ColorScheme.dark(
        primary: FuturisticColors.primary,
        secondary: FuturisticColors.accent1,
        tertiary: FuturisticColors.accent2,
        surface: FuturisticColors.surface,
        error: FuturisticColors.error,
        onSurface: FuturisticColors.textPrimary,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ELEVATED BUTTON THEME - Primary Actions (Save, Submit, Create, Pay)
      // ══════════════════════════════════════════════════════════════════════
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.grey.shade700;
            }
            if (states.contains(WidgetState.pressed)) {
              return FuturisticColors.primaryDark;
            }
            if (states.contains(WidgetState.hovered)) {
              return FuturisticColors.primary.withOpacity(0.9);
            }
            return FuturisticColors.primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 2;
            if (states.contains(WidgetState.hovered)) return 8;
            return 4;
          }),
          shadowColor: WidgetStateProperty.all(
            FuturisticColors.primary.withOpacity(0.4),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          minimumSize: WidgetStateProperty.all(const Size(120, 48)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          animationDuration: const Duration(milliseconds: 200),
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // TEXT BUTTON THEME - Secondary/Tertiary Actions (Cancel, Skip, Learn More)
      // ══════════════════════════════════════════════════════════════════════
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return FuturisticColors.textDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return FuturisticColors.accent1;
            }
            if (states.contains(WidgetState.hovered)) {
              return FuturisticColors.primary;
            }
            return FuturisticColors.textPrimary;
          }),
          overlayColor: WidgetStateProperty.all(
            FuturisticColors.primary.withOpacity(0.1),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // OUTLINED BUTTON THEME - Alternative Actions with Glow on Hover
      // ══════════════════════════════════════════════════════════════════════
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return FuturisticColors.textDisabled;
            }
            if (states.contains(WidgetState.hovered)) {
              return FuturisticColors.accent1;
            }
            return FuturisticColors.textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return FuturisticColors.primary.withOpacity(0.08);
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: Colors.grey.shade600, width: 1.5);
            }
            if (states.contains(WidgetState.hovered)) {
              return const BorderSide(
                color: FuturisticColors.accent1,
                width: 2,
              );
            }
            if (states.contains(WidgetState.pressed)) {
              return const BorderSide(
                color: FuturisticColors.primary,
                width: 2,
              );
            }
            return BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5);
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          minimumSize: WidgetStateProperty.all(const Size(100, 44)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // ICON BUTTON THEME
      // ══════════════════════════════════════════════════════════════════════
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return FuturisticColors.textDisabled;
            }
            if (states.contains(WidgetState.hovered)) {
              return FuturisticColors.accent1;
            }
            return FuturisticColors.textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withOpacity(0.1);
            }
            return Colors.transparent;
          }),
          iconSize: WidgetStateProperty.all(24),
          padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // FLOATING ACTION BUTTON THEME - Premium Glow Effect
      // ══════════════════════════════════════════════════════════════════════
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FuturisticColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        focusElevation: 12,
        hoverElevation: 12,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // TAB BAR THEME - High Contrast Selected/Unselected States
      // ══════════════════════════════════════════════════════════════════════
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: FuturisticColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: FuturisticColors.primary.withOpacity(0.2),
          border: const Border(
            bottom: BorderSide(color: FuturisticColors.accent1, width: 3),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(
          FuturisticColors.primary.withOpacity(0.1),
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // CHIP THEME - Premium Filters & Tags
      // ══════════════════════════════════════════════════════════════════════
      chipTheme: ChipThemeData(
        backgroundColor: FuturisticColors.surface,
        selectedColor: FuturisticColors.primary.withOpacity(0.2),
        disabledColor: Colors.grey.shade800,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: FuturisticColors.textSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
        checkmarkColor: FuturisticColors.accent1,
        deleteIconColor: FuturisticColors.textSecondary,
        elevation: 0,
        pressElevation: 2,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // TOGGLE / SWITCH THEME
      // ══════════════════════════════════════════════════════════════════════
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return FuturisticColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FuturisticColors.primary;
          }
          return Colors.white.withOpacity(0.2);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        overlayColor: WidgetStateProperty.all(
          FuturisticColors.primary.withOpacity(0.2),
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // CARD THEME - Premium Futuristic Style with Blue Accent
      // ══════════════════════════════════════════════════════════════════════
      cardTheme: CardThemeData(
        color: FuturisticColors.surface,
        elevation: 0,
        shadowColor: FuturisticColors.premiumBlue.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: FuturisticColors.premiumBlue.withOpacity(0.2),
          ),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // TEXT THEME - Crystal Clear Typography
      // ══════════════════════════════════════════════════════════════════════
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: FuturisticColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: FuturisticColors.textPrimary,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: FuturisticColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: FuturisticColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: FuturisticColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: FuturisticColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: FuturisticColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // INPUT DECORATION THEME
      // ══════════════════════════════════════════════════════════════════════
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FuturisticColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: FuturisticColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: FuturisticColors.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FuturisticColors.error, width: 2),
        ),
        labelStyle: const TextStyle(
          color: FuturisticColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: FuturisticColors.textSecondary.withOpacity(0.7),
          fontSize: 14,
        ),
        prefixIconColor: FuturisticColors.textSecondary,
        suffixIconColor: FuturisticColors.textSecondary,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // DIALOG THEME
      // ══════════════════════════════════════════════════════════════════════
      dialogTheme: DialogThemeData(
        backgroundColor: FuturisticColors.surface,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: FuturisticColors.textPrimary,
        ),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // BOTTOM SHEET THEME
      // ══════════════════════════════════════════════════════════════════════
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FuturisticColors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: FuturisticColors.textSecondary,
        dragHandleSize: Size(40, 4),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // SNACKBAR THEME
      // ══════════════════════════════════════════════════════════════════════
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FuturisticColors.surface,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: FuturisticColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // DIVIDER THEME
      // ══════════════════════════════════════════════════════════════════════
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.1),
        thickness: 1,
        space: 1,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // APPBAR THEME
      // ══════════════════════════════════════════════════════════════════════
      appBarTheme: const AppBarTheme(
        backgroundColor: FuturisticColors.background,
        foregroundColor: FuturisticColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: FuturisticColors.textPrimary, size: 24),
      ),

      // ══════════════════════════════════════════════════════════════════════
      // PROGRESS INDICATOR THEME
      // ══════════════════════════════════════════════════════════════════════
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FuturisticColors.primary,
        linearTrackColor: FuturisticColors.surface,
        circularTrackColor: FuturisticColors.surface,
      ),

      // ══════════════════════════════════════════════════════════════════════
      // TOOLTIP THEME
      // ══════════════════════════════════════════════════════════════════════
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: FuturisticColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          color: FuturisticColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
