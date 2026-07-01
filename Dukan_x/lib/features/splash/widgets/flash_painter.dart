import 'package:flutter/material.dart';

class FlashPainter extends CustomPainter {
  final double flashRadius;
  final double flashOpacity;

  FlashPainter({
    required this.flashRadius,
    required this.flashOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (flashOpacity <= 0 || flashRadius <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFE2E8F0).withOpacity(flashOpacity),
          const Color(0xFFF97316).withOpacity(flashOpacity * 0.5),
          const Color(0xFFF97316).withOpacity(0.0),
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: flashRadius));

    canvas.drawCircle(center, flashRadius, paint);
  }

  @override
  bool shouldRepaint(covariant FlashPainter oldDelegate) {
    return oldDelegate.flashRadius != flashRadius ||
           oldDelegate.flashOpacity != flashOpacity;
  }
}
