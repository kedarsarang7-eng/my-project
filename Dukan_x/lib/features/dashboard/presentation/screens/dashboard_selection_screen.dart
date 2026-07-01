import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/auth/auth_intent_service.dart';

/// Dashboard Selection Screen - Matches reference design
/// Space theme with glowing circular logo and glass cards
class DashboardSelectionScreen extends StatefulWidget {
  const DashboardSelectionScreen({super.key});

  @override
  State<DashboardSelectionScreen> createState() =>
      _DashboardSelectionScreenState();
}

class _DashboardSelectionScreenState extends State<DashboardSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Glow animation for circular logo
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
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
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // Menu icon
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        Icons.menu,
                        color: Colors.white.withOpacity(0.7),
                        size: 28,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Glowing circular logo
                  _GlowingLogo(controller: _glowController),

                  const SizedBox(height: 30),

                  // Title
                  Text(
                    "Select Dashboard",
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Log in or create an account to continue",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),

                  const Spacer(),

                  // Dashboard Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Vendor Dashboard Card
                        _DashboardCard(
                          icon: Icons.storefront_rounded,
                          iconColor: const Color(0xFF00D4FF),
                          title: "Vendor Dashboard",
                          subtitle: "Log in to manage your vendor account",
                          onTap: () async {
                            await authIntent.setVendorIntent();
                            if (context.mounted) {
                              context.push('/login');
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // OR Divider
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                "OR",
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Customer Dashboard Card
                        _DashboardCard(
                          icon: Icons.person_rounded,
                          iconColor: const Color(0xFFAB5CF6),
                          title: "Customer Dashboard",
                          subtitle: "Log in to access your customer portal",
                          onTap: () async {
                            await authIntent.setCustomerIntent();
                            if (context.mounted) {
                              context.push('/customer_auth');
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Bottom glow effect
                  _BottomGlow(),

                  const SizedBox(height: 40),
                ],
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
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: const Color(0xFFAB5CF6).withOpacity(0.3),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _GlowRingPainter(progress: controller.value),
            child: Center(
              child: Container(
                width: 110,
                height: 110,
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
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
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
    final radius = size.width / 2 - 5;

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
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Dashboard selection card
class _DashboardCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(_isHovered ? 0.08 : 0.05),
            border: Border.all(
              color: widget.iconColor.withOpacity(_isHovered ? 0.6 : 0.3),
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.iconColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.iconColor.withOpacity(0.15),
                  border: Border.all(color: widget.iconColor.withOpacity(0.3)),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 24),
              ),
              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
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
          ...List.generate(50, (index) {
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
                    random.nextDouble() * 0.5 + 0.2,
                  ),
                ),
              ),
            );
          }),

          // Blue nebula glow
          Positioned(
            right: -100,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E3A8A).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Purple nebula glow
          Positioned(
            left: -80,
            bottom: MediaQuery.of(context).size.height * 0.2,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF581C87).withOpacity(0.2),
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
            const Color(0xFF00D4FF).withOpacity(0.15),
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
