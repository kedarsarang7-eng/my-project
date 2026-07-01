import 'package:flutter/material.dart';
import 'star_field_background.dart';
import '../../core/theme/futuristic_colors.dart';

/// Premium Content Wrapper
/// Wraps content with star field background and premium visual effects.
/// This is a purely visual enhancement - no layout changes.
class PremiumContentWrapper extends StatelessWidget {
  final Widget child;
  final bool showStarField;
  final bool showGradientOverlay;

  const PremiumContentWrapper({
    super.key,
    required this.child,
    this.showStarField = true,
    this.showGradientOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF0A0F1C),
                ],
              )
            : null,
      ),
      child: Stack(
        children: [
          // Star field background layer (subtle, low opacity, only in dark mode)
          if (showStarField && isDark)
            Positioned.fill(
              child: StarFieldBackground(
                starCount: 60,
                starColor: Colors.white.withOpacity(0.6),
                maxStarSize: 1.5,
                animate: true,
                animationDuration: const Duration(seconds: 6),
              ),
            ),

          // Subtle gradient overlay for depth
          if (showGradientOverlay && isDark)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0F172A).withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),

          // Actual content on top
          child,
        ],
      ),
    );
  }
}

/// Premium Card Wrapper
/// Applies premium blue accent glow border to cards.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? accentColor;
  final bool showGlow;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 12,
    this.accentColor,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = accentColor ?? theme.colorScheme.primary;

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? color.withOpacity(0.25) : theme.dividerColor,
          width: 1,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: isDark 
                      ? color.withOpacity(0.1)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}
