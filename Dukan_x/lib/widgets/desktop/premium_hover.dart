import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../core/theme/design_tokens.dart';

/// PremiumHover — a reusable interactive wrapper that provides a smooth,
/// consistent hover feedback across the app:
///
///  • Subtle vertical lift (translateY) on hover
///  • Adaptive shadow + accent glow that brightens on hover
///  • Optional border-color shift toward the accent
///  • Optional scale-on-press feedback
///
/// Use this around cards, list rows, action chips, KPI tiles, etc. to give
/// the UI a cohesive, futuristic feel without rewriting each widget.
///
/// Example:
/// ```dart
/// PremiumHover(
///   onTap: () => doSomething(),
///   accentColor: FuturisticColors.accent1,
///   child: Container(padding: ..., child: ...),
/// )
/// ```
class PremiumHover extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accentColor;
  final double borderRadius;

  /// How far the widget lifts (in logical pixels) on hover.
  final double liftOffset;

  /// Strength of the accent glow on hover. 0 disables glow.
  final double glowIntensity;

  /// If true, wrap with [Material]+[InkWell] so a ripple shows on tap.
  /// If false (default), uses a pure GestureDetector — best for cards where
  /// the ripple would look out of place.
  final bool useInkRipple;

  /// Optional tooltip.
  final String? tooltip;

  /// Whether to enable hover effects at all (disable on disabled buttons).
  final bool enabled;

  const PremiumHover({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor,
    this.borderRadius = 12,
    this.liftOffset = 2,
    this.glowIntensity = 0.25,
    this.useInkRipple = false,
    this.tooltip,
    this.enabled = true,
  });

  @override
  State<PremiumHover> createState() => _PremiumHoverState();
}

class _PremiumHoverState extends State<PremiumHover> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);
  final ValueNotifier<bool> _pressed = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? FuturisticColors.premiumBlue;

    Widget content = ValueListenableBuilder<bool>(
      valueListenable: _hovered,
      builder: (context, isHovered, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _pressed,
          builder: (context, isPressed, _) {
            final lift = !widget.enabled
                ? 0.0
                : isPressed
                    ? 0.0
                    : (isHovered ? -widget.liftOffset : 0.0);

            return AnimatedContainer(
              duration: DesignTokens.durationFast,
              curve: DesignTokens.curveDefault,
              transform: Matrix4.translationValues(0, lift, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: widget.enabled && isHovered && widget.glowIntensity > 0
                    ? [
                        BoxShadow(
                          color: accent.withValues(
                              alpha: widget.glowIntensity * 0.55),
                          blurRadius: 18,
                          spreadRadius: 0,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: widget.child,
            );
          },
        );
      },
    );

    if (widget.useInkRipple && widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          hoverColor: FuturisticColors.hoverTint,
          child: content,
        ),
      );
    } else {
      content = GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: widget.enabled
            ? (_) => _pressed.value = true
            : null,
        onTapUp: widget.enabled
            ? (_) => _pressed.value = false
            : null,
        onTapCancel: widget.enabled
            ? () => _pressed.value = false
            : null,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    content = MouseRegion(
      cursor: widget.enabled && widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: content,
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }

    return content;
  }
}
