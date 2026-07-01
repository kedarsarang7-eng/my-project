// ============================================================================
// PREMIUM FLOATING ACTION BUTTON
// ============================================================================
// Futuristic floating action button with:
// - Gradient backgrounds
// - Pulsing glow animation
// - Scale-down press effect
// - Factory methods for common actions
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

/// Premium Floating Action Button with glow and animation effects
class PremiumFloatingActionButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isExtended;
  final bool enableGlow;
  final double size;

  const PremiumFloatingActionButton({
    super.key,
    required this.icon,
    this.label,
    this.onPressed,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor,
    this.isExtended = false,
    this.enableGlow = true,
    this.size = 56,
  });

  /// Factory: Create Bill / Create Invoice button
  factory PremiumFloatingActionButton.createBill({
    Key? key,
    required VoidCallback? onPressed,
    String label = 'Create Bill',
  }) {
    return PremiumFloatingActionButton(
      key: key,
      icon: Icons.add_rounded,
      label: label,
      onPressed: onPressed,
      gradient: FuturisticColors.primaryGradient,
      isExtended: label.isNotEmpty,
    );
  }

  /// Factory: Add Customer button
  factory PremiumFloatingActionButton.addCustomer({
    Key? key,
    required VoidCallback? onPressed,
    String label = 'Add Customer',
  }) {
    return PremiumFloatingActionButton(
      key: key,
      icon: Icons.person_add_rounded,
      label: label,
      onPressed: onPressed,
      gradient: FuturisticColors.successGradient,
      isExtended: label.isNotEmpty,
    );
  }

  /// Factory: Add Item / Product button
  factory PremiumFloatingActionButton.addItem({
    Key? key,
    required VoidCallback? onPressed,
    String label = 'Add Item',
  }) {
    return PremiumFloatingActionButton(
      key: key,
      icon: Icons.add_box_rounded,
      label: label,
      onPressed: onPressed,
      gradient: const LinearGradient(
        colors: [FuturisticColors.accent2, FuturisticColors.primary],
      ),
      isExtended: label.isNotEmpty,
    );
  }

  /// Factory: Save / Confirm button
  factory PremiumFloatingActionButton.save({
    Key? key,
    required VoidCallback? onPressed,
    String label = 'Save',
  }) {
    return PremiumFloatingActionButton(
      key: key,
      icon: Icons.check_rounded,
      label: label,
      onPressed: onPressed,
      gradient: FuturisticColors.successGradient,
      isExtended: label.isNotEmpty,
    );
  }

  /// Factory: Pay button
  factory PremiumFloatingActionButton.pay({
    Key? key,
    required VoidCallback? onPressed,
    String label = 'Pay Now',
  }) {
    return PremiumFloatingActionButton(
      key: key,
      icon: Icons.payment_rounded,
      label: label,
      onPressed: onPressed,
      gradient: FuturisticColors.primaryGradient,
      isExtended: label.isNotEmpty,
    );
  }

  @override
  State<PremiumFloatingActionButton> createState() =>
      _PremiumFloatingActionButtonState();
}

class _PremiumFloatingActionButtonState
    extends State<PremiumFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(
      begin: 8,
      end: 16,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    final effectiveGradient =
        widget.gradient ?? FuturisticColors.primaryGradient;
    final effectiveBgColor = widget.backgroundColor ?? FuturisticColors.primary;
    final effectiveFgColor = widget.foregroundColor ?? Colors.white;
    final glowColor = effectiveGradient.colors.first;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.size,
            constraints: BoxConstraints(
              minWidth: widget.isExtended ? 120 : widget.size,
            ),
            padding: widget.isExtended
                ? const EdgeInsets.symmetric(horizontal: 20)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              gradient: isDisabled ? null : effectiveGradient,
              color: isDisabled ? Colors.grey.shade700 : effectiveBgColor,
              borderRadius: BorderRadius.circular(widget.isExtended ? 28 : 16),
              boxShadow: widget.enableGlow && !isDisabled
                  ? [
                      BoxShadow(
                        color: glowColor.withOpacity(
                          _isPressed
                              ? 0.5
                              : _isHovered
                              ? 0.4
                              : 0.25,
                        ),
                        blurRadius: _isPressed
                            ? _glowAnimation.value
                            : _isHovered
                            ? 20
                            : 12,
                        offset: const Offset(0, 4),
                        spreadRadius: _isHovered ? 2 : 0,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isDisabled ? 0.5 : 1.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: effectiveFgColor, size: 24),
                  if (widget.isExtended && widget.label != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      widget.label!,
                      style: TextStyle(
                        color: effectiveFgColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact icon-only premium FAB variant
class PremiumFabIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? tooltip;
  final double size;

  const PremiumFabIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
    this.size = 48,
  });

  @override
  State<PremiumFabIcon> createState() => _PremiumFabIconState();
}

class _PremiumFabIconState extends State<PremiumFabIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? FuturisticColors.primary;
    final fgColor = widget.iconColor ?? Colors.white;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(widget.size / 3),
              boxShadow: [
                BoxShadow(
                  color: bgColor.withOpacity(_isHovered ? 0.5 : 0.3),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: const Offset(0, 4),
                  spreadRadius: _isHovered ? 2 : 0,
                ),
              ],
            ),
            child: Icon(widget.icon, color: fgColor, size: widget.size * 0.5),
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
