// ============================================================================
// PREMIUM CHIP WIDGETS
// ============================================================================
// Futuristic chips for filters, tags, and selections with:
// - Neon border on selection
// - Subtle hover glow
// - Clear typography
// - Multiple variants (action, filter, choice)
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

/// Premium action chip with hover glow and press animation
class PremiumChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? selectedColor;
  final bool showCheckmark;

  const PremiumChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.selectedColor,
    this.showCheckmark = false,
  });

  @override
  State<PremiumChip> createState() => _PremiumChipState();
}

class _PremiumChipState extends State<PremiumChip>
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
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null && widget.onDelete == null;
    final selectedColor = widget.selectedColor ?? FuturisticColors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.selected
                  ? selectedColor.withOpacity(0.15)
                  : FuturisticColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.selected
                    ? selectedColor
                    : _isHovered
                    ? FuturisticColors.accent1.withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
                width: widget.selected ? 2 : 1.5,
              ),
              boxShadow: widget.selected || _isHovered
                  ? [
                      BoxShadow(
                        color: selectedColor.withOpacity(
                          widget.selected ? 0.2 : 0.1,
                        ),
                        blurRadius: _isHovered ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isDisabled ? 0.5 : 1.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showCheckmark && widget.selected) ...[
                    Icon(Icons.check_rounded, size: 16, color: selectedColor),
                    const SizedBox(width: 6),
                  ] else if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 16,
                      color: widget.selected
                          ? selectedColor
                          : FuturisticColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: widget.selected
                          ? FuturisticColors.textPrimary
                          : FuturisticColors.textSecondary,
                    ),
                  ),
                  if (widget.onDelete != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: FuturisticColors.textSecondary,
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

/// Premium filter chip group for single/multi selection
class PremiumChipGroup extends StatelessWidget {
  final List<String> options;
  final List<String> selectedOptions;
  final ValueChanged<String> onSelected;
  final bool multiSelect;
  final Color? selectedColor;
  final EdgeInsets? spacing;

  const PremiumChipGroup({
    super.key,
    required this.options,
    required this.selectedOptions,
    required this.onSelected,
    this.multiSelect = false,
    this.selectedColor,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing?.left ?? 8,
      runSpacing: spacing?.top ?? 8,
      children: options.map((option) {
        final isSelected = selectedOptions.contains(option);
        return PremiumChip(
          label: option,
          selected: isSelected,
          selectedColor: selectedColor,
          showCheckmark: multiSelect,
          onTap: () => onSelected(option),
        );
      }).toList(),
    );
  }
}

/// Status badge chip for displaying states (Paid, Pending, Overdue, etc.)
class StatusChip extends StatelessWidget {
  final String label;
  final StatusType status;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.status,
    this.icon,
  });

  factory StatusChip.paid({String label = 'Paid'}) {
    return StatusChip(
      label: label,
      status: StatusType.success,
      icon: Icons.check_circle_rounded,
    );
  }

  factory StatusChip.pending({String label = 'Pending'}) {
    return StatusChip(
      label: label,
      status: StatusType.warning,
      icon: Icons.schedule_rounded,
    );
  }

  factory StatusChip.overdue({String label = 'Overdue'}) {
    return StatusChip(
      label: label,
      status: StatusType.error,
      icon: Icons.error_rounded,
    );
  }

  factory StatusChip.info({required String label}) {
    return StatusChip(label: label, status: StatusType.info);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getStatusColors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  _StatusColors _getStatusColors() {
    switch (status) {
      case StatusType.success:
        return _StatusColors(
          background: FuturisticColors.success.withOpacity(0.15),
          foreground: FuturisticColors.success,
          border: FuturisticColors.success.withOpacity(0.3),
        );
      case StatusType.warning:
        return _StatusColors(
          background: FuturisticColors.warning.withOpacity(0.15),
          foreground: FuturisticColors.warning,
          border: FuturisticColors.warning.withOpacity(0.3),
        );
      case StatusType.error:
        return _StatusColors(
          background: FuturisticColors.error.withOpacity(0.15),
          foreground: FuturisticColors.error,
          border: FuturisticColors.error.withOpacity(0.3),
        );
      case StatusType.info:
        return _StatusColors(
          background: FuturisticColors.primary.withOpacity(0.15),
          foreground: FuturisticColors.primary,
          border: FuturisticColors.primary.withOpacity(0.3),
        );
    }
  }
}

enum StatusType { success, warning, error, info }

class _StatusColors {
  final Color background;
  final Color foreground;
  final Color border;

  _StatusColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}
