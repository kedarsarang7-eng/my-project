import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/voice_state.dart';

class AiStarBall extends StatefulWidget {
  final VoiceState aiState;

  const AiStarBall({super.key, required this.aiState});

  @override
  State<AiStarBall> createState() => _AiStarBallState();
}

class _AiStarBallState extends State<AiStarBall>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(AiStarBall oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aiState != widget.aiState) {
      if (widget.aiState == VoiceState.processing) {
        // Fast rotation for thinking
        _controller.duration = const Duration(seconds: 1);
        _controller.repeat();
      } else if (widget.aiState == VoiceState.speaking ||
          widget.aiState == VoiceState.listening) {
        // Medium rotation for speaking/listening
        _controller.duration = const Duration(seconds: 2);
        _controller.repeat();
      } else {
        // Slow idle
        _controller.duration = const Duration(seconds: 4);
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _StarBallPainter(
            animationValue: _controller.value,
            state: widget.aiState,
          ),
        );
      },
    );
  }
}

class _StarBallPainter extends CustomPainter {
  final double animationValue;
  final VoiceState state;

  _StarBallPainter({required this.animationValue, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 4;

    // Determine colors and behavior based on state
    Color coreColor;
    Color glowColor;
    double pulseAmplitude = 0;
    int particleCount = 0;

    switch (state) {
      case VoiceState.listening:
        coreColor = const Color(0xFF00E5FF); // Cyan
        glowColor = const Color(0x6600E5FF);
        pulseAmplitude = 10;
        particleCount = 5;
        break;
      case VoiceState.processing:
        coreColor = const Color(0xFFB388FF); // Purple
        glowColor = const Color(0x66B388FF);
        pulseAmplitude = 5;
        particleCount = 15;
        break;
      case VoiceState.speaking:
        coreColor = const Color(0xFF69F0AE); // Green
        glowColor = const Color(0x6669F0AE);
        pulseAmplitude = 20; // High amplitude for speaking
        particleCount = 8;
        break;
      case VoiceState.error:
        coreColor = const Color(0xFFFF5252); // Red
        glowColor = const Color(0x66FF5252);
        break;
      case VoiceState.idle:
        coreColor = const Color(0xFF29B6F6); // Light Blue
        glowColor = const Color(0x6629B6F6);
        pulseAmplitude = 2;
        particleCount = 3;
        break;
    }

    // Sine wave for pulsing
    final pulse = sin(animationValue * 2 * pi) * pulseAmplitude;
    final radius = baseRadius + pulse;

    // Draw Outer Glow
    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30.0);
    canvas.drawCircle(center, radius * 1.5, glowPaint);

    // Draw Inner Glow / Core
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, coreColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawCircle(center, radius, corePaint);

    // Draw Particles/Orbits
    if (particleCount > 0) {
      final particlePaint = Paint()..color = coreColor.withValues(alpha: 0.8);
      for (int i = 0; i < particleCount; i++) {
        // Spread particles around the circle
        final angle = (i / particleCount) * 2 * pi + (animationValue * 2 * pi);
        // Vary distance from center (orbit radius)
        final orbitRadius =
            radius * 1.5 + sin(animationValue * pi * 4 + i) * 10;

        final dx = center.dx + orbitRadius * cos(angle);
        final dy = center.dy + orbitRadius * sin(angle);

        canvas.drawCircle(Offset(dx, dy), 3, particlePaint);
      }
    }

    // Additional wave ripples for speaking
    if (state == VoiceState.speaking) {
      final ripplePaint = Paint()
        ..color = coreColor.withValues(alpha: 1.0 - animationValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius + (animationValue * 40), ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
