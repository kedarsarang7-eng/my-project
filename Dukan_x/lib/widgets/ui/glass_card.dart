import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_providers.dart';

class GlassCard extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeStateProvider);
    final isDark = themeProvider.isDark;
    final palette = themeProvider.palette;

    // Premium styling constants
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]
          : [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.6)],
    );

    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : palette.glassBorder; // Subtle dark border in light mode

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}
