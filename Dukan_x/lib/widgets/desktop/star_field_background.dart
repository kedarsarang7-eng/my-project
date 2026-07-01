import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium Star Field Background Widget
/// Creates a subtle animated starfield effect for futuristic UI
class StarFieldBackground extends StatefulWidget {
  final Widget? child;
  final int starCount;
  final Color starColor;
  final double maxStarSize;
  final bool animate;
  final Duration animationDuration;

  const StarFieldBackground({
    super.key,
    this.child,
    this.starCount = 80,
    this.starColor = Colors.white,
    this.maxStarSize = 2.0,
    this.animate = true,
    this.animationDuration = const Duration(seconds: 4),
  });

  @override
  State<StarFieldBackground> createState() => _StarFieldBackgroundState();
}

class _StarFieldBackgroundState extends State<StarFieldBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Star> _stars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    if (widget.animate) {
      _controller.repeat();
    }

    _generateStars();
  }

  void _generateStars() {
    final random = math.Random(42); // Fixed seed for consistent star pattern
    _stars = List.generate(widget.starCount, (index) {
      return Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * widget.maxStarSize + 0.5,
        opacity: random.nextDouble() * 0.5 + 0.2,
        twinkleOffset: random.nextDouble() * math.pi * 2,
        twinkleSpeed: random.nextDouble() * 0.5 + 0.5,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Star field layer
        Positioned.fill(
          child: widget.animate
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: StarFieldPainter(
                        stars: _stars,
                        starColor: widget.starColor,
                        animationValue: _controller.value,
                      ),
                    );
                  },
                )
              : CustomPaint(
                  painter: StarFieldPainter(
                    stars: _stars,
                    starColor: widget.starColor,
                    animationValue: 0,
                  ),
                ),
        ),
        // Child content
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// Star data model
class Star {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double twinkleOffset;
  final double twinkleSpeed;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.twinkleOffset,
    required this.twinkleSpeed,
  });
}

/// Custom painter for star field
class StarFieldPainter extends CustomPainter {
  final List<Star> stars;
  final Color starColor;
  final double animationValue;

  StarFieldPainter({
    required this.stars,
    required this.starColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      // Calculate twinkle effect
      final twinkle = math.sin(
        (animationValue * math.pi * 2 * star.twinkleSpeed) + star.twinkleOffset,
      );
      final currentOpacity = (star.opacity + twinkle * 0.15).clamp(0.1, 0.7);

      final paint = Paint()
        ..color = starColor.withOpacity(currentOpacity)
        ..style = PaintingStyle.fill;

      // Draw star with subtle glow
      final x = star.x * size.width;
      final y = star.y * size.height;

      // Outer glow
      final glowPaint = Paint()
        ..color = starColor.withOpacity(currentOpacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), star.size * 1.5, glowPaint);

      // Core star
      canvas.drawCircle(Offset(x, y), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(StarFieldPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
