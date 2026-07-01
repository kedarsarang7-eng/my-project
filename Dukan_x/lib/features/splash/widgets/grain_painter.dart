import 'package:flutter/material.dart';

class GrainPainter extends CustomPainter {
  final List<Offset> points;
  final List<double> opacities;
  final List<double> radii;
  final double globalOpacity;

  GrainPainter({
    required this.points,
    required this.opacities,
    required this.radii,
    required this.globalOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (globalOpacity <= 0) return;
    
    final paint = Paint();
    for (int i = 0; i < points.length; i++) {
      paint.color = Colors.white.withOpacity(opacities[i] * globalOpacity);
      canvas.drawCircle(points[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant GrainPainter oldDelegate) {
    return oldDelegate.globalOpacity != globalOpacity;
  }
}
