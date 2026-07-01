import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/futuristic_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.color,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.width,
    this.height,
    this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);

    Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: boxShadow ?? FuturisticColors.glassShadow,
        borderRadius: effectiveBorderRadius,
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (color ?? FuturisticColors.surface).withOpacity(opacity),
              borderRadius: effectiveBorderRadius,
              border:
                  border ??
                  Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              gradient: gradient ?? FuturisticColors.glassGradient,
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: container),
      );
    }

    return container;
  }
}
