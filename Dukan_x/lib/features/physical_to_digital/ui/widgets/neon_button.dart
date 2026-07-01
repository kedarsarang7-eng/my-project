// Neon Button Widget
//
// Small circular icon button with neon glow effect.
// Minimal, floating aesthetic for futuristic UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/p2d_theme.dart';

class NeonButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  final bool isActive;
  final String? tooltip;

  const NeonButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 44,
    this.isActive = false,
    this.tooltip,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kP2DAnimationFast);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? kP2DAccentCyan;
    final isActive = widget.isActive;

    final button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? buttonColor.withOpacity(0.2) : kP2DGlassSurface,
            border: Border.all(
              color: isActive ? buttonColor : kP2DGlassBorder,
              width: 1.5,
            ),
            boxShadow: isActive ? [kP2DNeonGlow(buttonColor, blur: 12)] : null,
          ),
          child: Icon(
            widget.icon,
            color: isActive ? buttonColor : kP2DTextSecondary,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Capture button - larger, with pulse animation
class CaptureButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isReady;
  final double size;

  const CaptureButton({
    super.key,
    required this.onTap,
    this.isReady = false,
    this.size = 72,
  });

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isReady) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CaptureButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isReady && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + (_pulseController.value * 0.08);
          final glowOpacity = widget.isReady
              ? 0.3 + (_pulseController.value * 0.3)
              : 0.0;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isReady ? kP2DGlowSuccess : kP2DTextSecondary,
                  width: 3,
                ),
                boxShadow: widget.isReady
                    ? [
                        BoxShadow(
                          color: kP2DGlowSuccess.withOpacity(glowOpacity),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isReady
                      ? kP2DGlowSuccess.withOpacity(0.2)
                      : kP2DGlassSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
