// Animated UI Widgets & Effects
// Premium animations for the app
//
// Created: 2024-12-25
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

/// Typing text animation widget
class TypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration typingSpeed;
  final Duration startDelay;
  final VoidCallback? onComplete;
  final bool showCursor;

  const TypingText({
    super.key,
    required this.text,
    this.style,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.startDelay = Duration.zero,
    this.onComplete,
    this.showCursor = true,
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayText = '';
  bool _showCursor = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  Future<void> _startTyping() async {
    await Future.delayed(widget.startDelay);

    for (int i = 0; i <= widget.text.length; i++) {
      if (!mounted) return;

      await Future.delayed(widget.typingSpeed);
      if (mounted) {
        setState(() {
          _displayText = widget.text.substring(0, i);
        });
      }
    }

    if (mounted) {
      setState(() => _completed = true);
      widget.onComplete?.call();

      // Blink cursor for a bit then hide
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _showCursor = !_showCursor);
      }
      if (mounted) setState(() => _showCursor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style:
            widget.style ??
            GoogleFonts.outfit(fontSize: 24, color: Colors.black),
        children: [
          TextSpan(text: _displayText),
          if (widget.showCursor && !_completed || (_completed && _showCursor))
            TextSpan(
              text: '|',
              style: TextStyle(
                color: widget.style?.color ?? Colors.black,
                fontWeight: FontWeight.w100,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shimmer loading effect
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor ?? Colors.grey.shade300,
                widget.highlightColor ?? Colors.grey.shade100,
                widget.baseColor ?? Colors.grey.shade300,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// Pulse animation widget
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

/// Floating animation widget (like floating in water)
class FloatingAnimation extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration duration;

  const FloatingAnimation({
    super.key,
    required this.child,
    this.amplitude = 8.0,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<FloatingAnimation> createState() => _FloatingAnimationState();
}

class _FloatingAnimationState extends State<FloatingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
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
        return Transform.translate(
          offset: Offset(
            0,
            widget.amplitude * math.sin(_controller.value * 2 * math.pi),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Glow animation widget
class GlowAnimation extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxBlur;
  final Duration duration;

  const GlowAnimation({
    super.key,
    required this.child,
    this.glowColor = Colors.blue,
    this.maxBlur = 20.0,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<GlowAnimation> createState() => _GlowAnimationState();
}

class _GlowAnimationState extends State<GlowAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: widget.maxBlur,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.5),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 4,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Staggered list animation
class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 100),
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOut,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    // Delay based on index
    Future.delayed(
      Duration(milliseconds: widget.delay.inMilliseconds * widget.index),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

/// Animated counter widget
class AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 1000),
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = IntTween(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = IntTween(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller.reset();
      _controller.forward();
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
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_animation.value}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// Animated progress bar
class AnimatedProgressBar extends StatefulWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double height;
  final BorderRadius? borderRadius;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.color = Colors.blue,
    this.backgroundColor = Colors.grey,
    this.height = 8,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: oldWidget.progress,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(widget.height / 2);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor.withOpacity(0.3),
            borderRadius: radius,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _animation.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.color, widget.color.withOpacity(0.8)],
                ),
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bouncing dots loading indicator
class BouncingDotsLoader extends StatefulWidget {
  final Color color;
  final double size;
  final int dotCount;

  const BouncingDotsLoader({
    super.key,
    this.color = Colors.blue,
    this.size = 10,
    this.dotCount = 3,
  });

  @override
  State<BouncingDotsLoader> createState() => _BouncingDotsLoaderState();
}

class _BouncingDotsLoaderState extends State<BouncingDotsLoader>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.dotCount,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0,
        end: -10,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Start animations with stagger
    for (int i = 0; i < widget.dotCount; i++) {
      Future.delayed(Duration(milliseconds: 200 * i), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.size / 4),
              child: Transform.translate(
                offset: Offset(0, _animations[index].value),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Animated card with hover effect
class AnimatedHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double elevation;
  final double hoverElevation;
  final BorderRadius? borderRadius;

  const AnimatedHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.elevation = 2,
    this.hoverElevation = 8,
    this.borderRadius,
  });

  @override
  State<AnimatedHoverCard> createState() => _AnimatedHoverCardState();
}

class _AnimatedHoverCardState extends State<AnimatedHoverCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _elevationAnimation = Tween<double>(
      begin: widget.elevation,
      end: widget.hoverElevation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: _elevationAnimation.value,
                    offset: Offset(0, _elevationAnimation.value / 2),
                  ),
                ],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// Success checkmark animation
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  const AnimatedCheckmark({
    super.key,
    this.size = 80,
    this.color = Colors.green,
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _circleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CheckmarkPainter(
              circleProgress: _circleAnimation.value,
              checkProgress: _checkAnimation.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final Color color;

  _CheckmarkPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw circle
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      circlePaint,
    );

    // Draw checkmark
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final startPoint = Offset(size.width * 0.25, size.height * 0.5);
      final midPoint = Offset(size.width * 0.45, size.height * 0.7);
      final endPoint = Offset(size.width * 0.75, size.height * 0.35);

      path.moveTo(startPoint.dx, startPoint.dy);

      if (checkProgress <= 0.5) {
        // First half of check
        final progress = checkProgress * 2;
        final currentPoint = Offset.lerp(startPoint, midPoint, progress)!;
        path.lineTo(currentPoint.dx, currentPoint.dy);
      } else {
        // Second half of check
        path.lineTo(midPoint.dx, midPoint.dy);
        final progress = (checkProgress - 0.5) * 2;
        final currentPoint = Offset.lerp(midPoint, endPoint, progress)!;
        path.lineTo(currentPoint.dx, currentPoint.dy);
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.circleProgress != circleProgress ||
        oldDelegate.checkProgress != checkProgress;
  }
}
