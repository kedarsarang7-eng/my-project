import 'package:flutter/material.dart';

class NeoGradientCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;

  const NeoGradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.borderRadius,
    this.padding,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        boxShadow:
            shadows ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }
}
