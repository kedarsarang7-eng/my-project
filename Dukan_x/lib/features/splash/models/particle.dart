import 'package:flutter/material.dart';

enum ParticlePhase { drifting, converging, dispersing, orbiting, dead }

class Particle {
  Offset position;
  Offset velocity;
  double radius;
  Color color;
  double opacity;
  double trailOpacity;
  List<Offset> trail;
  ParticlePhase phase;
  double birthDelay;
  double orbitAngle;
  double orbitRadius;
  double orbitSpeed;
  
  // Pre-created paint objects for performance (Rule 11)
  late Paint glowPaint;
  late Paint centerPaint;

  Particle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.color,
    required this.opacity,
    required this.trailOpacity,
    required this.trail,
    required this.phase,
    required this.birthDelay,
    required this.orbitAngle,
    required this.orbitRadius,
    required this.orbitSpeed,
  }) {
    _updatePaints();
  }

  void _updatePaints() {
    glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(opacity),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 2.5));
      
    centerPaint = Paint()..color = color.withOpacity(opacity);
  }

  void updateOpacity(double newOpacity) {
    if (opacity != newOpacity) {
      opacity = newOpacity;
      _updatePaints();
    }
  }
}
