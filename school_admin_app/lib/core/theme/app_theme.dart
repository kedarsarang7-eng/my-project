import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Admin App palette — Deep Navy/Slate authoritative tone
  static const Color primary = Color(0xFF1E40AF);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color secondary = Color(0xFF7C3AED);
  static const Color accent = Color(0xFF0891B2);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color surface = Color(0xFFF1F5F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color navBg = Color(0xFF0F172A);

  // Dark mode surface colors
  static const Color darkSurface    = Color(0xFF0F172A);
  static const Color darkCard       = Color(0xFF1E293B);
  static const Color darkDivider    = Color(0xFF334155);
  static const Color darkTextPrimary   = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light, primary: primary, secondary: secondary, surface: surface, error: error));
    return base.copyWith(
      scaffoldBackgroundColor: surface,
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg, foregroundColor: textPrimary, elevation: 0,
        shadowColor: Colors.transparent, surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      cardTheme: CardThemeData(color: cardBg, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: divider)), margin: EdgeInsets.zero),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 2)),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark, primary: primary, secondary: secondary, surface: darkSurface, error: error));
    return base.copyWith(
      scaffoldBackgroundColor: darkSurface,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: darkTextPrimary, displayColor: darkTextPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: darkCard, foregroundColor: darkTextPrimary, elevation: 0,
        shadowColor: Colors.transparent, surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(color: darkCard, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: darkDivider)), margin: EdgeInsets.zero),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFF1E293B), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: darkDivider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: darkDivider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 2)),
      ),
      dividerColor: darkDivider,
      drawerTheme: const DrawerThemeData(backgroundColor: darkCard),
      navigationRailTheme: const NavigationRailThemeData(backgroundColor: darkSurface),
    );
  }
}
