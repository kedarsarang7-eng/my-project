import 'package:flutter/material.dart';
import '../models/particle.dart';

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      if (particle.opacity <= 0) continue;

      // Draw trails
      if (particle.trail.isNotEmpty) {
        for (int i = 0; i < particle.trail.length; i++) {
          final trailPos = particle.trail[i];
          final factor = (i + 1) / particle.trail.length;
          final trailOpacity = particle.opacity * (0.5 * factor);
          if (trailOpacity <= 0) continue;
          
          final trailPaint = Paint()..color = particle.color.withOpacity(trailOpacity);
          canvas.drawCircle(trailPos, particle.radius * 0.6, trailPaint);
        }
      }

      canvas.save();
      canvas.translate(particle.position.dx, particle.position.dy);
      
      // Draw glow
      canvas.drawCircle(Offset.zero, particle.radius * 2.5, particle.glowPaint);
      
      // Draw core
      canvas.drawCircle(Offset.zero, particle.radius, particle.centerPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return true; // We repaint every frame since it's driven by an AnimationController ticker
  }
}
