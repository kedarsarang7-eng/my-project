// ============================================================================
// FUTURISTIC BUTTON WIDGET
// ============================================================================
// Modern button component with:
// - Rounded corners (16-24px)
// - Soft glow/elevation
// - Subtle scale animation on press
// - Gradient backgrounds
// - Modern typography
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

/// A futuristic button with animations and modern styling
class FuturisticButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final bool isOutlined;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const FuturisticButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isOutlined = false,
    this.borderRadius = 16,
    this.padding,
    this.width,
    this.height,
  });

  /// Primary action button (indigo gradient)
  factory FuturisticButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return FuturisticButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      gradient: FuturisticColors.primaryGradient,
      foregroundColor: Colors.white,
      isLoading: isLoading,
    );
  }

  /// Secondary action button (outlined purple)
  factory FuturisticButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return FuturisticButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isOutlined: true,
      backgroundColor: FuturisticColors.secondary,
      isLoading: isLoading,
    );
  }

  /// Success/Confirm button (cyan gradient)
  factory FuturisticButton.success({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return FuturisticButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      gradient: FuturisticColors.successGradient,
      foregroundColor: Colors.white,
      isLoading: isLoading,
    );
  }

  /// Warning button (amber)
  factory FuturisticButton.warning({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return FuturisticButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      gradient: FuturisticColors.warningGradient,
      foregroundColor: Colors.white,
      isLoading: isLoading,
    );
  }

  /// Danger/Error button (orange gradient)
  factory FuturisticButton.danger({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return FuturisticButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      gradient: FuturisticColors.errorGradient,
      foregroundColor: Colors.white,
      isLoading: isLoading,
    );
  }

  @override
  State<FuturisticButton> createState() => _FuturisticButtonState();
}

class _FuturisticButtonState extends State<FuturisticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final effectiveGradient = widget.gradient;
    final effectiveBgColor = widget.backgroundColor ?? FuturisticColors.primary;
    final effectiveFgColor =
        widget.foregroundColor ??
        (widget.isOutlined ? effectiveBgColor : Colors.white);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height ?? 56,
          padding:
              widget.padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: widget.isOutlined ? null : effectiveGradient,
            color: widget.isOutlined
                ? Colors.transparent
                : (effectiveGradient == null ? effectiveBgColor : null),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.isOutlined
                ? Border.all(color: effectiveBgColor, width: 2)
                : null,
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color:
                          (effectiveGradient != null
                                  ? effectiveGradient.colors.first
                                  : effectiveBgColor)
                              .withOpacity(_isPressed ? 0.4 : 0.25),
                      blurRadius: _isPressed ? 12 : 8,
                      offset: const Offset(0, 4),
                      spreadRadius: _isPressed ? 2 : 0,
                    ),
                  ],
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isDisabled ? 0.6 : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(effectiveFgColor),
                    ),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, color: effectiveFgColor, size: 20),
                if ((widget.icon != null || widget.isLoading) &&
                    widget.label.isNotEmpty)
                  const SizedBox(width: 10),
                if (widget.label.isNotEmpty)
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: effectiveFgColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact icon-only futuristic button
class FuturisticIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final String? tooltip;

  const FuturisticIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.tooltip,
  });

  @override
  State<FuturisticIconButton> createState() => _FuturisticIconButtonState();
}

class _FuturisticIconButtonState extends State<FuturisticIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? FuturisticColors.primary;
    final fgColor = widget.iconColor ?? Colors.white;

    Widget button = GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(widget.size / 3),
            boxShadow: [
              BoxShadow(
                color: bgColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(widget.icon, color: fgColor, size: widget.size * 0.5),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
