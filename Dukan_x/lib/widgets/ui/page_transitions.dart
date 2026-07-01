// ============================================================================
// MODERN PAGE TRANSITIONS
// ============================================================================
// Smooth, premium page transitions for DukanX:
// - Fade + Slide transitions
// - Scale transitions for dialogs
// - Hero-ready route builder
// ============================================================================

import 'package:flutter/material.dart';

/// Custom page route with fade + slide animation
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Curve curve;

  FadeSlidePageRoute({
    required this.page,
    Duration duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curvedAnimation = CurvedAnimation(
             parent: animation,
             curve: curve,
           );

           return FadeTransition(
             opacity: curvedAnimation,
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0.1, 0),
                 end: Offset.zero,
               ).animate(curvedAnimation),
               child: child,
             ),
           );
         },
         transitionDuration: duration,
         reverseTransitionDuration: duration,
       );
}

/// Scale transition for modals and dialogs
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ScalePageRoute({
    required this.page,
    Duration duration = const Duration(milliseconds: 250),
  }) : super(
         opaque: false,
         barrierDismissible: true,
         barrierColor: Colors.black54,
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutBack,
           );

           return ScaleTransition(
             scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
             child: FadeTransition(opacity: curved, child: child),
           );
         },
         transitionDuration: duration,
       );
}

/// Navigation helper with modern transitions
class FuturisticNavigator {
  /// Push with fade+slide transition
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push(FadeSlidePageRoute<T>(page: page));
  }

  /// Push replacement with fade+slide transition
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) {
    return Navigator.of(
      context,
    ).pushReplacement(FadeSlidePageRoute<T>(page: page));
  }

  /// Show modal with scale transition
  static Future<T?> showModal<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push(ScalePageRoute<T>(page: page));
  }

  /// Push and remove all with fade transition
  static Future<T?> pushAndRemoveAll<T>(BuildContext context, Widget page) {
    return Navigator.of(
      context,
    ).pushAndRemoveUntil(FadeSlidePageRoute<T>(page: page), (route) => false);
  }
}

/// Shimmer loading effect widget
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: isDark
                  ? [Colors.white10, Colors.white24, Colors.white10]
                  : [
                      Colors.grey.shade200,
                      Colors.grey.shade100,
                      Colors.grey.shade200,
                    ],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer card loading placeholder
class ShimmerCard extends StatelessWidget {
  final double height;

  const ShimmerCard({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const ShimmerLoading(width: 50, height: 50, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                ShimmerLoading(height: 16, width: 140, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerLoading(height: 12, width: 100, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
