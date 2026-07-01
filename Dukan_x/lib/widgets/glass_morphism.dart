import 'dart:ui';
import 'package:flutter/material.dart';
import 'modern_ui_components.dart';
import '../core/theme/futuristic_colors.dart';

// ============================================================================
// ENHANCED GLASSMORPHISM COMPONENTS
// Premium futuristic glass effects with glow, shimmer, and animations
// ============================================================================

/// GlassMorphism is an alias for GlassContainer for consistency
typedef GlassMorphism = GlassContainer;

/// Premium Glass Container with futuristic blur and glow effects
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? borderGradient;
  final BoxBorder? border;
  final bool showGlow;
  final Color? glowColor;
  final double glowIntensity;
  final bool enableShimmer;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.blur = 12.0,
    this.opacity = 0.1,
    this.color,
    this.padding,
    this.margin,
    this.borderGradient,
    this.border,
    this.showGlow = false,
    this.glowColor,
    this.glowIntensity = 0.3,
    this.enableShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Premium glass gradient with improved opacity
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              (color ?? FuturisticColors.darkSurfaceElevated).withOpacity(0.15),
              (color ?? FuturisticColors.darkSurface).withOpacity(0.08),
            ]
          : [
              (color ?? Colors.white).withOpacity(opacity + 0.15),
              (color ?? Colors.white).withOpacity(opacity + 0.05),
            ],
    );

    // Enhanced border with gradient support
    final effectiveBorder =
        border ??
        (borderGradient != null
            ? null
            : Border.all(
                color: isDark
                    ? FuturisticColors.glassBorder.withOpacity(0.15)
                    : FuturisticColors.glassBorder.withOpacity(0.5),
                width: 1.5,
              ));

    // Glow shadow for interactive elements
    final glowShadows = showGlow
        ? [
            BoxShadow(
              color: (glowColor ?? FuturisticColors.primary).withOpacity(
                glowIntensity,
              ),
              blurRadius: 20,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: (glowColor ?? FuturisticColors.primary).withOpacity(
                glowIntensity * 0.5,
              ),
              blurRadius: 40,
              spreadRadius: -4,
            ),
          ]
        : <BoxShadow>[];

    // Standard depth shadow
    final depthShadows = [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
        blurRadius: 16,
        spreadRadius: -2,
        offset: const Offset(0, 6),
      ),
    ];

    Widget glassWidget = Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: bgGradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: effectiveBorder,
              boxShadow: [...depthShadows, ...glowShadows],
            ),
            child: borderGradient != null
                ? _GradientBorderWrapper(
                    gradient: borderGradient!,
                    borderRadius: borderRadius,
                    child: child,
                  )
                : child,
          ),
        ),
      ),
    );

    // Add shimmer effect if enabled
    if (enableShimmer) {
      return _ShimmerWrapper(child: glassWidget);
    }

    return glassWidget;
  }
}

/// Gradient border wrapper for glass containers
class _GradientBorderWrapper extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final double borderRadius;

  const _GradientBorderWrapper({
    required this.child,
    required this.gradient,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.transparent, width: 1.5),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: GradientBoxBorder(gradient: gradient, width: 1.5),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Gradient box border implementation
class GradientBoxBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBoxBorder({required this.gradient, this.width = 1.0});

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (borderRadius != null) {
      canvas.drawRRect(borderRadius.toRRect(rect), paint);
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// Shimmer effect wrapper
class _ShimmerWrapper extends StatefulWidget {
  final Widget child;

  const _ShimmerWrapper({required this.child});

  @override
  State<_ShimmerWrapper> createState() => _ShimmerWrapperState();
}

class _ShimmerWrapperState extends State<_ShimmerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0x00FFFFFF),
                Color(0x40FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 2.0 * _controller.value, -0.5),
              end: Alignment(1.0 + 2.0 * _controller.value, 0.5),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// Premium Glass Card with tap animation
class GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool showGlow;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.showGlow = false,
    this.glowColor,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: AppAnimations.pressedScale)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = GlassContainer(
      borderRadius: widget.borderRadius,
      padding: widget.padding,
      color: Colors.white,
      opacity: 0.1,
      showGlow: widget.showGlow,
      glowColor: widget.glowColor,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: content,
            );
          },
        ),
      );
    }
    return content;
  }
}

/// Premium Glass Button with gradient and glow
class GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final bool isLoading;
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.isLoading = false,
    this.borderRadius = 12,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: AppAnimations.pressedScale)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppGradients.primaryGradient;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        if (!widget.isLoading) widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: effectiveGradient,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: _isPressed
                    ? AppShadows.glowShadow(FuturisticColors.primary)
                    : AppShadows.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    widget.label,
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
