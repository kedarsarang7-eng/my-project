import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand palette (aligned with DukanX enterprise system) ──────────────
  static const Color _electricBlue   = Color(0xFF3B82F6); // Blue 500
  static const Color _cyan           = Color(0xFF06B6D4); // Cyan 500
  static const Color _violet         = Color(0xFF8B5CF6); // Violet 500
  static const Color _error          = Color(0xFFEF4444); // Red 500

  // ── Light surface palette ───────────────────────────────────────────────
  static const Color _lightBg        = Color(0xFFF8FAFC); // Slate 50
  static const Color _lightSurface   = Color(0xFFFFFFFF);
  static const Color _lightBorder    = Color(0xFFE2E8F0); // Slate 200
  static const Color _lightText      = Color(0xFF0F172A); // Slate 900
  static const Color _lightSubtext   = Color(0xFF64748B); // Slate 500

  // ── Dark surface palette ────────────────────────────────────────────────
  static const Color _darkBg         = Color(0xFF0F172A); // Slate 900
  static const Color _darkSurface    = Color(0xFF1E293B); // Slate 800
  static const Color _darkBorder     = Color(0xFF334155); // Slate 700
  static const Color _darkSubtext    = Color(0xFF94A3B8); // Slate 400

  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: _electricBlue,
      brightness: Brightness.light,
      primary:          _electricBlue,
      secondary:        _cyan,
      tertiary:         _violet,
      surface:          _lightSurface,
      error:            _error,
    ).copyWith(
      surfaceContainerHighest: const Color(0xFFF1F5F9),
      onSurface:               _lightText,
      onSurfaceVariant:        _lightSubtext,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: _lightBg,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: _lightText,
        displayColor: _lightText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: _lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: _electricBlue.withValues(alpha: 0.08),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _lightText,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _lightText),
        actionsIconTheme: IconThemeData(color: _lightSubtext),
        shape: const Border(
          bottom: BorderSide(color: _lightBorder, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: _electricBlue.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _electricBlue : _lightSubtext,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _electricBlue : _lightSubtext,
            size: 22,
          );
        }),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        overlayColor: WidgetStateProperty.all(
          _electricBlue.withValues(alpha: 0.06),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _electricBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _electricBlue,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: _electricBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        hintStyle: const TextStyle(color: _lightSubtext, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _electricBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.focused) ? _electricBlue : _lightSubtext),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: _electricBlue.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.inter(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: _lightBorder),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: _electricBlue,
      brightness: Brightness.dark,
      primary:          _electricBlue,
      secondary:        _cyan,
      tertiary:         _violet,
      surface:          _darkSurface,
      error:            _error,
    ).copyWith(
      surfaceContainerHighest: const Color(0xFF334155),
      onSurface:               Colors.white,
      onSurfaceVariant:        _darkSubtext,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: _darkBg,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: _electricBlue.withValues(alpha: 0.12),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: _darkSubtext),
        shape: Border(
          bottom: BorderSide(
            color: _electricBlue.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: _electricBlue.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        indicatorColor: _electricBlue.withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _electricBlue : _darkSubtext,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _electricBlue : _darkSubtext,
            size: 22,
          );
        }),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        overlayColor: WidgetStateProperty.all(
          _electricBlue.withValues(alpha: 0.08),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _electricBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _electricBlue,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: _electricBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF334155),
        hintStyle: const TextStyle(color: _darkSubtext, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _electricBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.focused) ? _electricBlue : _darkSubtext),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF334155),
        selectedColor: _electricBlue.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(
            fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: _darkBorder),
      ),
      dividerTheme: DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
