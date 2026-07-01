// ============================================================================
// PREMIUM TOGGLE SWITCH
// ============================================================================
// Futuristic toggle with:
// - Gradient track when active
// - Glow effect on thumb
// - Smooth spring animation
// - High-contrast labels
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

/// Premium animated toggle switch with glow effects
class PremiumToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? labelOn;
  final String? labelOff;
  final Color? activeColor;
  final Color? inactiveColor;
  final double width;
  final double height;

  const PremiumToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.labelOn,
    this.labelOff,
    this.activeColor,
    this.inactiveColor,
    this.width = 56,
    this.height = 32,
  });

  @override
  State<PremiumToggle> createState() => _PremiumToggleState();
}

class _PremiumToggleState extends State<PremiumToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.value ? 1.0 : 0.0,
    );

    _positionAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOut,
    );

    _glowAnimation = Tween<double>(
      begin: 0,
      end: 8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(PremiumToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.onChanged != null) {
      widget.onChanged!(!widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? FuturisticColors.primary;
    final inactiveColor = widget.inactiveColor ?? Colors.white.withOpacity(0.2);
    final isDisabled = widget.onChanged == null;

    final thumbRadius = widget.height - 8;
    final trackPadding = 4.0;
    final travelDistance = widget.width - thumbRadius - (trackPadding * 2);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isDisabled ? null : _toggle,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.5 : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Optional label
              if (widget.value && widget.labelOn != null ||
                  !widget.value && widget.labelOff != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    widget.value
                        ? (widget.labelOn ?? '')
                        : (widget.labelOff ?? ''),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.value
                          ? FuturisticColors.textPrimary
                          : FuturisticColors.textSecondary,
                    ),
                  ),
                ),

              // Toggle track & thumb
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    width: widget.width,
                    height: widget.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      gradient: widget.value
                          ? LinearGradient(
                              colors: [
                                activeColor,
                                activeColor.withOpacity(0.8),
                              ],
                            )
                          : null,
                      color: widget.value ? null : inactiveColor,
                      border: Border.all(
                        color: widget.value
                            ? activeColor.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: widget.value
                          ? [
                              BoxShadow(
                                color: activeColor.withOpacity(
                                  _isHovered ? 0.4 : 0.25,
                                ),
                                blurRadius: _isHovered ? 12 : 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left:
                              trackPadding +
                              (_positionAnimation.value * travelDistance),
                          top: trackPadding,
                          child: Container(
                            width: thumbRadius,
                            height: thumbRadius,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                                if (widget.value)
                                  BoxShadow(
                                    color: activeColor.withOpacity(
                                      _isHovered ? 0.6 : 0.4,
                                    ),
                                    blurRadius: _glowAnimation.value,
                                    spreadRadius: _isHovered ? 2 : 0,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labeled premium toggle with label on the left
class LabeledPremiumToggle extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const LabeledPremiumToggle({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        PremiumToggle(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
        ),
      ],
    );
  }
}
