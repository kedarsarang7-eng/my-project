import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'splash_controller.dart';
import 'splash_audio_controller.dart';
import 'models/particle.dart';
import 'widgets/particle_painter.dart';
import 'widgets/grain_painter.dart';
import 'widgets/flash_painter.dart';
import 'widgets/logo_widget.dart';
import 'widgets/wordmark_widget.dart';
import 'widgets/tagline_widget.dart';
import 'widgets/progress_bar_widget.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final SplashController _controller;
  late final AnimationController _masterController;
  late final AnimationController _pulseController;

  final List<Particle> _particles = [];
  final List<Offset> _grainPoints = [];
  final List<double> _grainOpacities = [];
  final List<double> _grainRadii = [];

  bool _initialized = false;
  bool _appTransitioning = false;
  bool _readyToExit = false;
  final SplashAudioController _audioController = SplashAudioController();
  bool _whooshTriggered = false;

  late final Animation<double> _backgroundFade;
  late final Animation<double> _particleBirth;
  late final Animation<double> _convergence;
  late final Animation<double> _logoReveal;
  late final Animation<double> _wordmarkReveal;
  late final Animation<double> _taglineReveal;

  @override
  void initState() {
    super.initState();
    _controller = SplashController();
    _controller.addListener(_onControllerStateChanged);

    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    );

    _masterController.addListener(_onTick);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
      lowerBound: 1.0,
      upperBound: 1.008,
    )..repeat(reverse: true);

    _backgroundFade = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.0, 0.04, curve: Curves.easeOut),
    );
    _particleBirth = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.04, 0.14, curve: Curves.easeInOut),
    );
    _convergence = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.10, 0.20, curve: Curves.easeIn),
    );
    _logoReveal = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.21, 0.26, curve: Curves.elasticOut),
    );
    _wordmarkReveal = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.26, 0.32, curve: Curves.easeOut),
    );
    _taglineReveal = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.30, 0.36, curve: Curves.easeOut),
    );

    _masterController.forward();
    _controller.initializeApp();

    // Audio: initialize and preload in background, does not block
    _audioController.init();

    // Audio strike fires 100ms before the logo flash
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) _audioController.playStrike();
    });
  }

  void _onControllerStateChanged() {
    if (_controller.isReady && !_appTransitioning && !_readyToExit) {
      _readyToExit = true;
      _appTransitioning = true;
      setState(() {});
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      _initGrain(size);
      _initParticles(size);
      _initialized = true;
    }
  }

  void _initGrain(Size size) {
    final random = math.Random();
    const count = 1000;
    for (int i = 0; i < count; i++) {
      _grainPoints.add(Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      ));
      _grainOpacities.add(random.nextDouble() * 0.02 + 0.02);
      _grainRadii.add(random.nextDouble() * 0.3 + 0.3);
    }
  }

  void _initParticles(Size size) {
    final random = math.Random();
    const count = 300;

    for (int i = 0; i < count; i++) {
      final randType = random.nextDouble();
      Color color;
      if (randType < 0.6) {
        color = const Color(0xFF3B82F6); // Blue
      } else if (randType < 0.9) {
        color = const Color(0xFFFB923C); // Orange
      } else {
        color = const Color(0xFFE2E8F0); // White
      }

      final angle = random.nextDouble() * 2 * math.pi;
      final speed = random.nextDouble() * 0.5 + 0.3;

      _particles.add(
        Particle(
          position: Offset(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height,
          ),
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          radius: random.nextDouble() * 1.6 + 1.2,
          color: color,
          opacity: 0.0,
          trailOpacity: 0.0,
          trail: [],
          phase: ParticlePhase.drifting,
          birthDelay: random.nextDouble(), // 0.0 to 1.0 (mapped to 400-1400ms)
          orbitAngle: random.nextDouble() * 2 * math.pi,
          orbitRadius: random.nextDouble() * 30 + 60,
          orbitSpeed: random.nextDouble() * 0.4 + 0.3,
        ),
      );
    }
  }

  void _onTick() {
    if (!mounted || !_initialized) return;

    final elapsedMs = _masterController.value * 10000;
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    // Audio: whoosh starts at exactly 400ms
    if (elapsedMs >= 400 && !_whooshTriggered) {
      _whooshTriggered = true;
      _audioController.playWhoosh();
    }

    for (var p in _particles) {
      if (elapsedMs < 400) continue; // Not born yet

      // Phase 2: Birth & Drifting
      if (elapsedMs >= 400 && elapsedMs < 1000) {
        p.phase = ParticlePhase.drifting;
        
        final birthTimeMs = 400 + (p.birthDelay * 600);
        if (elapsedMs >= birthTimeMs) {
          final birthProgress = (elapsedMs - birthTimeMs) / 400.0;
          p.updateOpacity(birthProgress.clamp(0.0, 1.0));
        }
        
        p.position += p.velocity;
        
      } 
      // Phase 3: Convergence
      else if (elapsedMs >= 1000 && elapsedMs < 2000) {
        p.phase = ParticlePhase.converging;
        final convergenceProgress = _convergence.value;
        
        final toCenter = center - p.position;
        final distance = toCenter.distance;
        
        if (distance > 1.0) {
          final speed = (distance * 0.04 + 1.5) * convergenceProgress;
          p.velocity = (toCenter / distance) * speed;
          p.position += p.velocity;
        }

        // Trail logic
        p.trail.add(p.position);
        if (p.trail.length > 5) {
          p.trail.removeAt(0);
        }

      }
      // Phase 4: Dispersing / Orbit
      else if (elapsedMs >= 2200) {
        if (p.phase == ParticlePhase.converging) {
          p.phase = ParticlePhase.dispersing;
          p.trail.clear();
          
          // Only a few survive
          final isSurvivor = _particles.indexOf(p) % 50 == 0; // ~6 survivors
          if (isSurvivor) {
            p.phase = ParticlePhase.orbiting;
          }
        }

        if (p.phase == ParticlePhase.dispersing) {
          final disperseProgress = (elapsedMs - 2200) / 600.0;
          p.position += p.velocity * (1.0 - disperseProgress.clamp(0.0, 1.0));
          p.updateOpacity((1.0 - disperseProgress * 1.5).clamp(0.0, 1.0));
        } else if (p.phase == ParticlePhase.orbiting) {
          p.orbitAngle += (p.orbitSpeed / 60); // approx per frame
          p.position = center + Offset(
            math.cos(p.orbitAngle) * p.orbitRadius,
            math.sin(p.orbitAngle) * p.orbitRadius,
          );
          p.updateOpacity(1.0);
        }
      }
    }
    
    // Check for animation completion
    if (elapsedMs >= 4200 && !_controller.isReady && _controller.appReady) {
      _controller.onAnimationComplete();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    _controller.dispose();
    _masterController.dispose();
    _pulseController.dispose();
    _audioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedOpacity(
        opacity: _appTransitioning ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 400),
        child: Stack(
          children: [
            // Background Layer
            AnimatedBuilder(
              animation: _backgroundFade,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      Colors.black,
                      const Color(0xFF070C1A),
                      _backgroundFade.value,
                    ),
                  ),
                );
              },
            ),

            // Vignette overlay
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF000000).withOpacity(0.5),
                  ],
                ),
              ),
            ),

            // Grain Layer
            if (_initialized)
              AnimatedBuilder(
                animation: _backgroundFade,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: GrainPainter(
                      points: _grainPoints,
                      opacities: _grainOpacities,
                      radii: _grainRadii,
                      globalOpacity: _backgroundFade.value * 0.035 / 0.02,
                    ),
                  );
                },
              ),

            // Particle Layer
            if (_initialized)
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _masterController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: ParticlePainter(particles: _particles),
                    );
                  },
                ),
              ),

            // Flash Layer
            AnimatedBuilder(
              animation: _masterController,
              builder: (context, child) {
                final elapsedMs = _masterController.value * 10000;
                double flashRadius = 0.0;
                double flashOpacity = 0.0;

                if (elapsedMs >= 2000 && elapsedMs <= 2100) {
                  final progress = (elapsedMs - 2000) / 100;
                  flashRadius = progress * 180;
                  flashOpacity = 1.0 - progress;
                }

                return CustomPaint(
                  size: Size.infinite,
                  painter: FlashPainter(
                    flashRadius: flashRadius,
                    flashOpacity: flashOpacity,
                  ),
                );
              },
            ),

            // Center Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  AnimatedBuilder(
                    animation: _masterController,
                    builder: (context, child) {
                      final elapsedMs = _masterController.value * 10000;
                      if (elapsedMs < 2100) return const SizedBox(width: 80, height: 80);
                      
                      return ScaleTransition(
                        scale: _logoReveal,
                        child: FadeTransition(
                          opacity: _logoReveal,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: elapsedMs >= 3600 ? _pulseController.value : 1.0,
                                child: child,
                              );
                            },
                            child: const LogoWidget(),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Wordmark
                  AnimatedBuilder(
                    animation: _masterController,
                    builder: (context, child) {
                      final elapsedMs = _masterController.value * 10000;
                      if (elapsedMs < 2600) return const SizedBox(height: 50);

                      return FadeTransition(
                        opacity: _wordmarkReveal,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - _wordmarkReveal.value)),
                          child: const WordmarkWidget(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Underline
                  AnimatedBuilder(
                    animation: _masterController,
                    builder: (context, child) {
                      final elapsedMs = _masterController.value * 10000;
                      double width = 0.0;
                      if (elapsedMs >= 2750 && elapsedMs <= 3050) {
                        width = ((elapsedMs - 2750) / 300) * 180;
                      } else if (elapsedMs > 3050) {
                        width = 180.0;
                      }

                      return Container(
                        height: 1,
                        width: width,
                        color: const Color(0xFF2563EB),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Tagline
                  AnimatedBuilder(
                    animation: _masterController,
                    builder: (context, child) {
                      final elapsedMs = _masterController.value * 10000;
                      if (elapsedMs < 3000) return const SizedBox(height: 20);

                      return TaglineWidget(animation: _taglineReveal);
                    },
                  ),
                ],
              ),
            ),

            // Bottom Overlay Layer
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _masterController,
                builder: (context, child) {
                  final elapsedMs = _masterController.value * 10000;
                  final showProgress = elapsedMs > 4200 && !_controller.appReady;
                  final versionOpacity = elapsedMs >= 3000 ? 
                     ((elapsedMs - 3000) / 400).clamp(0.0, 0.4) : 0.0;

                  return Column(
                    children: [
                      ProgressBarWidget(isVisible: showProgress),
                      const SizedBox(height: 20),
                      Opacity(
                        opacity: versionOpacity,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: Text(
                              "v2.x.x",
                              style: GoogleFonts.sourceCodePro(
                                fontWeight: FontWeight.w400,
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
