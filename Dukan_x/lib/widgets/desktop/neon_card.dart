import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

class NeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FuturisticColors.surface,
            FuturisticColors.surface.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: Colors.white.withOpacity(0.02),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
