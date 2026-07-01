import 'package:flutter/material.dart';

enum EnterpriseButtonType { primary, secondary, outline, ghost, danger }

class EnterpriseButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EnterpriseButtonType type;
  final bool isLoading;
  final bool fullWidth;
  final double? width;
  // Legacy support
  final Color? backgroundColor;
  final Color? textColor;

  const EnterpriseButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = EnterpriseButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.width,
    this.backgroundColor,
    this.textColor,
  });

  const EnterpriseButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.width,
    this.backgroundColor,
    this.textColor,
  }) : type = EnterpriseButtonType.primary;

  const EnterpriseButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.width,
    this.backgroundColor,
    this.textColor,
  }) : type = EnterpriseButtonType.secondary;

  const EnterpriseButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.width,
    this.backgroundColor,
    this.textColor,
  }) : type = EnterpriseButtonType.outline;

  const EnterpriseButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.width,
    this.backgroundColor,
    this.textColor,
  }) : type = EnterpriseButtonType.danger;

  @override
  State<EnterpriseButton> createState() => _EnterpriseButtonState();
}

class _EnterpriseButtonState extends State<EnterpriseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (widget.onPressed == null) {
      return theme.disabledColor.withOpacity(0.2);
    }
    if (widget.backgroundColor != null) return widget.backgroundColor!;

    switch (widget.type) {
      case EnterpriseButtonType.primary:
        return theme.colorScheme.primary;
      case EnterpriseButtonType.secondary:
        return theme.colorScheme.secondaryContainer;
      case EnterpriseButtonType.outline:
      case EnterpriseButtonType.ghost:
        return Colors.transparent;
      case EnterpriseButtonType.danger:
        return theme.colorScheme.error;
    }
  }

  Color _getTextColor(ThemeData theme) {
    if (widget.onPressed == null) return theme.disabledColor;
    if (widget.textColor != null) return widget.textColor!;

    switch (widget.type) {
      case EnterpriseButtonType.primary:
      case EnterpriseButtonType.danger:
        return theme.colorScheme.onPrimary;
      case EnterpriseButtonType.secondary:
        return theme.colorScheme.onSecondaryContainer;
      case EnterpriseButtonType.outline:
      case EnterpriseButtonType.ghost:
        return _isHovered
            ? theme.colorScheme.primary
            : theme.textTheme.bodyMedium?.color ?? Colors.grey;
    }
  }

  Border? _getBorder(ThemeData theme) {
    if (widget.type == EnterpriseButtonType.outline &&
        widget.onPressed != null) {
      return Border.all(
        color: _isHovered ? theme.colorScheme.primary : theme.dividerColor,
        width: 1.5,
      );
    }
    return null;
  }

  List<BoxShadow> _getShadows(ThemeData theme) {
    if (widget.onPressed == null ||
        widget.type == EnterpriseButtonType.ghost ||
        widget.type == EnterpriseButtonType.outline) {
      return [];
    }

    if (_isHovered) {
      Color glowColor = widget.type == EnterpriseButtonType.danger
          ? theme.colorScheme.error
          : theme.colorScheme.primary;
      return [
        BoxShadow(
          color: glowColor.withOpacity(0.4),
          blurRadius: 20,
          spreadRadius: -5,
          offset: const Offset(0, 8),
        ),
      ];
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = _getBackgroundColor(theme);
    final textColor = _getTextColor(theme);
    final border = _getBorder(theme);
    final shadows = _getShadows(theme);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.fullWidth ? double.infinity : widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: border,
              boxShadow: shadows,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, color: textColor, size: 20),
                  const SizedBox(width: 12),
                ],
                Text(
                  widget.isLoading ? "Please wait..." : widget.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
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
