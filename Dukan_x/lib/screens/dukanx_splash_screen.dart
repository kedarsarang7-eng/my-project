import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../../widgets/modern_ui_components.dart';

/// dukanX Splash Screen - Matches reference design
/// Space theme with glowing circular logo
class DukanXSplashScreen extends StatefulWidget {
  const DukanXSplashScreen({super.key});

  @override
  State<DukanXSplashScreen> createState() => _DukanXSplashScreenState();
}

class _DukanXSplashScreenState extends State<DukanXSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    // Glow ring rotation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      lowerBound: 0.98,
      upperBound: 1.02,
    )..repeat(reverse: true);

    _fadeController.forward();

    // Navigate after animation
    Future.delayed(const Duration(seconds: 3), () {
      _navigateToNext();
    });
  }

  void _navigateToNext() {
    if (!mounted) return;
    context.pushReplacement(RoutePaths.authGate);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1F),
      body: Stack(
        children: [
          // Space background
          _SpaceBackground(),

          // Main content
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Glowing Logo
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseController.value,
                            child: child,
                          );
                        },
                        child: _GlowingLogo(controller: _glowController),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Loading indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF00D4FF).withOpacity(0.5),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Footer
                    Text(
                      "Powered by",
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Sarang Technologies",
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Bottom glow
                    _BottomGlow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glowing circular logo with rainbow gradient ring
class _GlowingLogo extends StatelessWidget {
  final AnimationController controller;

  const _GlowingLogo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.5),
                blurRadius: 60,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: const Color(0xFFAB5CF6).withOpacity(0.4),
                blurRadius: 80,
                spreadRadius: 15,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _GlowRingPainter(progress: controller.value),
            child: Center(
              child: Container(
                width: 145,
                height: 145,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0B0D1F),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFFAB5CF6)],
                      ).createShader(bounds),
                      child: Text(
                        "dukanX",
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for the rainbow glow ring
class _GlowRingPainter extends CustomPainter {
  final double progress;

  _GlowRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final gradient = SweepGradient(
      startAngle: progress * 2 * math.pi,
      colors: const [
        Color(0xFF00D4FF),
        Color(0xFF00FF88),
        Color(0xFFFFDD00),
        Color(0xFFFF6B00),
        Color(0xFFFF00FF),
        Color(0xFFAB5CF6),
        Color(0xFF00D4FF),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Space background with stars
class _SpaceBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0D1F), Color(0xFF0F1B3D), Color(0xFF0B0D1F)],
        ),
      ),
      child: Stack(
        children: [
          // Stars
          ...List.generate(80, (index) {
            final random = math.Random(index);
            return Positioned(
              left: random.nextDouble() * MediaQuery.of(context).size.width,
              top: random.nextDouble() * MediaQuery.of(context).size.height,
              child: Container(
                width: random.nextDouble() * 2 + 1,
                height: random.nextDouble() * 2 + 1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(
                    random.nextDouble() * 0.6 + 0.2,
                  ),
                ),
              ),
            );
          }),

          // Blue nebula glow (right)
          Positioned(
            right: -100,
            top: MediaQuery.of(context).size.height * 0.2,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E3A8A).withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Purple nebula glow (left)
          Positioned(
            left: -100,
            bottom: MediaQuery.of(context).size.height * 0.15,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF581C87).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom glow effect (holographic platform)
class _BottomGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.2),
            const Color(0xFFAB5CF6).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 200,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF00D4FF),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
