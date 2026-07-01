// Physical → Digital Theme
//
// Futuristic dark theme with glassmorphism and neon accents.
// Designed for a premium scanner experience.

import 'package:flutter/material.dart';

/// Primary background color (near black)
const Color kP2DBackground = Color(0xFF0B0F14);

/// Secondary background (slightly lighter)
const Color kP2DBackgroundSecondary = Color(0xFF111827);

/// Accent colors - Neon Cyan/Blue
const Color kP2DAccentCyan = Color(0xFF00E5FF);
const Color kP2DAccentBlue = Color(0xFF2979FF);
const Color kP2DAccentPurple = Color(0xFF7C3AED);

/// Glow colors
const Color kP2DGlowCyan = Color(0xFF00BCD4);
const Color kP2DGlowSuccess = Color(0xFF00E676);
const Color kP2DGlowWarning = Color(0xFFFFAB00);

/// Surface colors for glassmorphism
const Color kP2DGlassSurface = Color(0x1AFFFFFF);
const Color kP2DGlassBorder = Color(0x33FFFFFF);

/// Text colors
const Color kP2DTextPrimary = Color(0xFFFFFFFF);
const Color kP2DTextSecondary = Color(0xB3FFFFFF);
const Color kP2DTextMuted = Color(0x80FFFFFF);

/// Gradient presets
const LinearGradient kP2DBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B0F14), Color(0xFF111827), Color(0xFF0F172A)],
);

const LinearGradient kP2DAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kP2DAccentCyan, kP2DAccentBlue],
);

/// Shadow/glow presets
BoxShadow kP2DNeonGlow(Color color, {double blur = 20, double spread = 0}) {
  return BoxShadow(
    color: color.withOpacity(0.5),
    blurRadius: blur,
    spreadRadius: spread,
  );
}

/// Border radius
const double kP2DBorderRadiusSmall = 8.0;
const double kP2DBorderRadiusMedium = 12.0;
const double kP2DBorderRadiusLarge = 20.0;

/// Animation durations
const Duration kP2DAnimationFast = Duration(milliseconds: 150);
const Duration kP2DAnimationNormal = Duration(milliseconds: 300);
const Duration kP2DAnimationSlow = Duration(milliseconds: 500);

/// Glassmorphism decoration factory
BoxDecoration kP2DGlassDecoration({
  double borderRadius = kP2DBorderRadiusMedium,
  Color? glowColor,
}) {
  return BoxDecoration(
    color: kP2DGlassSurface,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: kP2DGlassBorder, width: 1),
    boxShadow: glowColor != null ? [kP2DNeonGlow(glowColor, blur: 15)] : null,
  );
}
