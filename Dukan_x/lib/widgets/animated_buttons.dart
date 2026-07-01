import 'package:flutter/material.dart';
import '../utils/animation_constants.dart';

class AnimatedPressButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final bool isEnabled;

  const AnimatedPressButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _shadowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationDurations.micro,
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: AnimationCurves.press),
    );

    _shadowAnim = Tween<double>(begin: 2, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: AnimationCurves.press),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isEnabled) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.isEnabled && !widget.isLoading) {
      widget.onPressed();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: (widget.backgroundColor ?? Colors.blue).withOpacity(
                      0.3,
                    ),
                    blurRadius: _shadowAnim.value,
                    offset: Offset(0, _shadowAnim.value / 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: widget.isEnabled && !widget.isLoading
                    ? widget.onPressed
                    : null,
                icon: widget.isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (widget.icon != null
                          ? Icon(widget.icon)
                          : const SizedBox()),
                label: Text(widget.label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: widget.foregroundColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnimatedSuccessTick extends StatefulWidget {
  final Duration delay;

  const AnimatedSuccessTick({super.key, this.delay = Duration.zero});

  @override
  State<AnimatedSuccessTick> createState() => _AnimatedSuccessTickState();
}

class _AnimatedSuccessTickState extends State<AnimatedSuccessTick>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationDurations.small,
      vsync: this,
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaleAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    return ScaleTransition(
      scale: scaleAnim,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFF2F9E44),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 24),
      ),
    );
  }
}
