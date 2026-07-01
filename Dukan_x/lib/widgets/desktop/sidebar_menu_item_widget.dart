import 'package:flutter/material.dart';
import 'sidebar_configuration.dart'; // For models

/// Safe, isolated sidebar menu item that handles its own hover state using ValueNotifier.
/// Prevents "MouseTracker assertion failed" by keeping layout stable during interactions.
class SidebarMenuItemWidget extends StatelessWidget {
  final SidebarMenuItem item;
  final SidebarSection section;
  final SidebarMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  // Uses ValueNotifier for hover state to avoid rebuilding the widget tree
  final ValueNotifier<bool> _isHoveredNotifier = ValueNotifier(false);

  SidebarMenuItemWidget({
    required Key key, // Mandate Key for MouseTracker safety
    required this.item,
    required this.section,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isFullMode = mode == SidebarMode.expanded;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 8, top: 2, bottom: 2),
      child: MouseRegion(
        onEnter: (_) => _isHoveredNotifier.value = true,
        onExit: (_) => _isHoveredNotifier.value = false,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isHoveredNotifier,
            builder: (context, isHovered, child) {
              final effectiveColor = isSelected
                  ? section.accentColor!.withOpacity(0.1)
                  : (isHovered
                        // FIXED: theme-aware hover tint
                        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.05)
                        : Colors.transparent);

              final borderColor = isSelected
                  ? section.accentColor!.withOpacity(0.3)
                  : Colors.transparent;

              // FIXED: theme-aware icon colors
              final iconColor = isSelected
                  ? section.accentColor
                  : (isHovered ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor);

              final textColor = isSelected
                  ? theme.colorScheme.onSurface
                  : (isHovered ? Colors.white : theme.hintColor);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: iconColor),
                    if (isFullMode) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.badge) _buildBadge(),
                      if (isSelected) _buildSelectionDot(),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    // FIXED: removed FuturisticColors dependency, use standard error color
    const badgeColor = Color(0xFFEF4444); // Red 500
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionDot() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: section.accentColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: section.accentColor!.withOpacity(0.8),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}
