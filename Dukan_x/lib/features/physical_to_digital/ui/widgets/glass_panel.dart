// Glass Panel Widget
//
// Glassmorphism container with blur effect and subtle border.
// Core widget for the Physical → Digital futuristic UI.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/p2d_theme.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? glowColor;
  final double blur;
  final double opacity;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = kP2DBorderRadiusMedium,
    this.padding,
    this.margin,
    this.glowColor,
    this.blur = 10,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: glowColor != null
            ? [kP2DNeonGlow(glowColor!, blur: 20)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: kP2DGlassBorder, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
