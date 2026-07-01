import 'dart:math';
import 'package:flutter/material.dart';

class SakuraBackground extends StatefulWidget {
  final Widget child;
  const SakuraBackground({super.key, required this.child});

  @override
  State<SakuraBackground> createState() => _SakuraBackgroundState();
}

class _SakuraBackgroundState extends State<SakuraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<SakuraPetal> _petals = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Initialize petals
    for (int i = 0; i < 30; i++) {
      _petals.add(_generatePetal());
    }
  }

  SakuraPetal _generatePetal() {
    return SakuraPetal(
      x: _random.nextDouble(),
      y: _random.nextDouble() - 1.0, // Start above screen
      size: _random.nextDouble() * 10 + 5,
      speed: _random.nextDouble() * 0.002 + 0.001,
      rotation: _random.nextDouble() * 2 * pi,
      rotationSpeed: _random.nextDouble() * 0.02 - 0.01,
    );
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
        // Gradient Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFCE4EC), // Light Pink
                Color(0xFFF8BBD0), // Pink
              ],
            ),
          ),
        ),
        // Animated Petals
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: SakuraPainter(_petals, _random),
              size: Size.infinite,
            );
          },
        ),
        // Content
        widget.child,
      ],
    );
  }
}

class SakuraPetal {
  double x;
  double y;
  double size;
  double speed;
  double rotation;
  double rotationSpeed;

  SakuraPetal({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class SakuraPainter extends CustomPainter {
  final List<SakuraPetal> petals;
  final Random random;

  SakuraPainter(this.petals, this.random);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.pinkAccent.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (var petal in petals) {
      // Update position
      petal.y += petal.speed;
      petal.rotation += petal.rotationSpeed;
      petal.x += sin(petal.y * 10) * 0.001; // Swaying motion

      // Reset if out of bounds
      if (petal.y > 1.0) {
        petal.y = -0.1;
        petal.x = random.nextDouble();
      }

      // Draw petal
      canvas.save();
      canvas.translate(petal.x * size.width, petal.y * size.height);
      canvas.rotate(petal.rotation);

      // Draw a simple petal shape (oval)
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: petal.size,
          height: petal.size * 0.6,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
