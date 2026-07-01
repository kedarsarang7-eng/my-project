// Right-Click Context Menu Component
// Provides desktop-style right-click context menus with Edit/View/Delete actions

import 'package:flutter/material.dart';
import 'entity_action_panel.dart';

/// Context menu configuration for right-click menus
class ContextMenuConfig {
  final List<ActionConfig> actions;
  final ActionCallback onAction;
  final EdgeInsets padding;
  final double borderRadius;

  const ContextMenuConfig({
    required this.actions,
    required this.onAction,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.borderRadius = 8,
  });
}

/// A widget that adds right-click context menu functionality to its child
class ContextMenuWrapper extends StatelessWidget {
  final Widget child;
  final ContextMenuConfig config;
  final VoidCallback? onSecondaryTap;

  const ContextMenuWrapper({
    super.key,
    required this.child,
    required this.config,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: () => _showContextMenu(context),
      onLongPress: () => _showContextMenu(context),
      child: child,
    );
  }

  void _showContextMenu(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(config.borderRadius),
      ),
      items: config.actions.map((action) {
        return PopupMenuItem<String>(
          value: action.customValue ?? action.type.name,
          height: 40,
          child: Row(
            children: [
              Icon(action.icon, size: 18, color: action.iconColor),
              const SizedBox(width: 12),
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: action.textColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        final action = config.actions.firstWhere(
          (a) => (a.customValue ?? a.type.name) == value,
          orElse: () => config.actions.first,
        );
        config.onAction(action.type, action.customValue);
      }
    });

    onSecondaryTap?.call();
  }
}

/// Desktop-style context menu with hover effects
class DesktopContextMenu extends StatefulWidget {
  final Widget child;
  final List<ContextMenuSection> sections;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  const DesktopContextMenu({
    super.key,
    required this.child,
    required this.sections,
    this.onOpen,
    this.onClose,
  });

  @override
  State<DesktopContextMenu> createState() => _DesktopContextMenuState();
}

class _DesktopContextMenuState extends State<DesktopContextMenu> {
  bool _isMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showDesktopMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showDesktopMenu(context, details.globalPosition),
      child: widget.child,
    );
  }

  void _showDesktopMenu(BuildContext context, Offset position) {
    setState(() => _isMenuOpen = true);
    widget.onOpen?.call();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // Invisible barrier to close menu on outside click
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _isMenuOpen = false);
                  widget.onClose?.call();
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            // Context menu
            Positioned(
              left: position.dx,
              top: position.dy,
              child: _buildMenu(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            final isLast = index == widget.sections.length - 1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (section.title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      section.title!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ...section.items.map(
                  (item) => _MenuItem(
                    item: item,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _isMenuOpen = false);
                      widget.onClose?.call();
                      item.onTap();
                    },
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 16,
                    indent: 12,
                    endIndent: 12,
                    color: isDark ? Colors.grey[700] : Colors.grey[200],
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// A section in the context menu
class ContextMenuSection {
  final String? title;
  final List<ContextMenuItem> items;

  const ContextMenuSection({this.title, required this.items});
}

/// An individual item in the context menu
class ContextMenuItem {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  final bool enabled;
  final String? shortcut;

  const ContextMenuItem({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.onTap,
    this.enabled = true,
    this.shortcut,
  });
}

class _MenuItem extends StatefulWidget {
  final ContextMenuItem item;
  final VoidCallback onTap;

  const _MenuItem({required this.item, required this.onTap});

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor =
        widget.item.iconColor ?? (isDark ? Colors.white : Colors.black87);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.item.enabled ? widget.onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 18,
                color: widget.item.enabled
                    ? foregroundColor
                    : (isDark ? Colors.grey[600] : Colors.grey[400]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.item.enabled
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  ),
                ),
              ),
              if (widget.item.shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    widget.item.shortcut!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard context menu with Edit, View, Delete
class StandardContextMenu extends StatelessWidget {
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final bool canEdit;
  final bool canView;
  final bool canDelete;

  const StandardContextMenu({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    this.canEdit = true,
    this.canView = true,
    this.canDelete = true,
  });

  @override
  Widget build(BuildContext context) {
    return DesktopContextMenu(
      sections: [
        ContextMenuSection(
          items: [
            if (canView)
              ContextMenuItem(
                label: 'View Details',
                icon: Icons.visibility_outlined,
                iconColor: const Color(0xFF2563EB),
                onTap: onView,
                shortcut: 'Enter',
              ),
            if (canEdit)
              ContextMenuItem(
                label: 'Edit',
                icon: Icons.edit_outlined,
                iconColor: const Color(0xFF7C3AED),
                onTap: onEdit,
                shortcut: 'Ctrl+E',
              ),
          ],
        ),
        if (canDelete)
          ContextMenuSection(
            items: [
              ContextMenuItem(
                label: 'Delete',
                icon: Icons.delete_outline,
                iconColor: const Color(0xFFDC2626),
                onTap: onDelete,
                shortcut: 'Del',
              ),
            ],
          ),
      ],
      child: child,
    );
  }
}
