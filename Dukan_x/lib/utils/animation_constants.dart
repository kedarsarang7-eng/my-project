import 'dart:math';
import 'package:flutter/material.dart';

/// Animation durations following the spec timing cheat-sheet
class AnimationDurations {
  // Micro: 80–140ms (button presses, icon pops)
  static const micro = Duration(milliseconds: 120);

  // Small: 180–260ms (chip fill, card lifts, small modal)
  static const small = Duration(milliseconds: 220);

  // Medium: 320–450ms (screen modals, transitions)
  static const medium = Duration(milliseconds: 380);

  // Large: 600–900ms (multi-stage onboarding, complex flows)
  static const large = Duration(milliseconds: 700);

  // Stagger delay for list items
  static const staggerDelay = Duration(milliseconds: 40);
}

/// Standard easing curves per spec
class AnimationCurves {
  // Soft deceleration: cubic-bezier(0.22, 1, 0.36, 1)
  static const softDeceleration = Cubic(0.22, 1, 0.36, 1);

  // Spring-like overshoot for entrances
  static const springBounce = Curves.elasticOut;

  // Quick press response
  static const press = Curves.easeInOut;
}

/// Reusable animation builders
class AnimationHelpers {
  /// Entrance animation: fade + slide up
  static Widget fadeSlideUp({
    required Widget child,
    required AnimationController controller,
    Duration duration = const Duration(milliseconds: 260),
  }) {
    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: AnimationCurves.softDeceleration,
      ),
    );
    final slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: controller,
            curve: AnimationCurves.softDeceleration,
          ),
        );

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(position: slideAnim, child: child),
    );
  }

  /// Button press: scale with bounce
  static Widget buttonPressAnimation({
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return GestureDetector(
      onTapDown: (_) {},
      onTapUp: (_) => onPressed(),
      child: child,
    );
  }

  /// Card lift on hover: translate up + shadow deepening
  static Widget cardLiftAnimation({
    required Widget child,
    required AnimationController controller,
  }) {
    final liftAnim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(
        parent: controller,
        curve: AnimationCurves.softDeceleration,
      ),
    );

    return Transform.translate(offset: Offset(0, liftAnim.value), child: child);
  }

  /// Number count-up animation
  static Widget countUpAnimation({
    required int target,
    required TextStyle style,
    required Duration duration,
  }) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: duration,
      builder: (context, value, child) {
        return Text(value.toString(), style: style);
      },
    );
  }

  /// Color morph animation
  static Widget colorMorphAnimation({
    required Widget child,
    required Color fromColor,
    required Color toColor,
    required AnimationController controller,
  }) {
    final colorAnim = ColorTween(begin: fromColor, end: toColor).animate(
      CurvedAnimation(
        parent: controller,
        curve: AnimationCurves.softDeceleration,
      ),
    );

    return Container(color: colorAnim.value, child: child);
  }

  /// Pulse glow for status badges
  static Widget pulseGlow({
    required Widget child,
    Color glowColor = const Color(0xFFFFD166),
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 2),
      duration: duration,
      curve: Curves.linear,
      builder: (context, value, child) {
        final sineValue = (sin(value * pi) + 1) / 2;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(sineValue * 0.4),
                blurRadius: 8 * sineValue,
                spreadRadius: 2 * sineValue,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
