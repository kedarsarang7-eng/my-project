// Entity Action Panel - Reusable Edit/View/Delete Actions
// Provides a consistent three-dot menu with CRUD operations across the application

import 'package:flutter/material.dart';

/// Action types available in the panel
enum EntityAction {
  view,
  edit,
  delete,
  duplicate,
  export,
  print,
  activate,
  deactivate,
  custom,
}

/// Configuration for a single action item
class ActionConfig {
  final EntityAction type;
  final String label;
  final IconData icon;
  final Color? iconColor;
  final Color? textColor;
  final bool showDivider;
  final String? customValue;
  final bool destructive;

  const ActionConfig({
    required this.type,
    required this.label,
    required this.icon,
    this.iconColor,
    this.textColor,
    this.showDivider = false,
    this.customValue,
    this.destructive = false,
  });

  // Predefined action configs
  static const view = ActionConfig(
    type: EntityAction.view,
    label: 'View Details',
    icon: Icons.visibility_outlined,
    iconColor: Color(0xFF2563EB),
  );

  static const edit = ActionConfig(
    type: EntityAction.edit,
    label: 'Edit',
    icon: Icons.edit_outlined,
    iconColor: Color(0xFF7C3AED),
  );

  static const delete = ActionConfig(
    type: EntityAction.delete,
    label: 'Delete',
    icon: Icons.delete_outline,
    iconColor: Color(0xFFDC2626),
    textColor: Color(0xFFDC2626),
    destructive: true,
  );

  static const duplicate = ActionConfig(
    type: EntityAction.duplicate,
    label: 'Duplicate',
    icon: Icons.copy_outlined,
    iconColor: Color(0xFF059669),
  );

  static const export = ActionConfig(
    type: EntityAction.export,
    label: 'Export',
    icon: Icons.download_outlined,
    iconColor: Color(0xFF6B7280),
  );

  static const print = ActionConfig(
    type: EntityAction.print,
    label: 'Print',
    icon: Icons.print_outlined,
    iconColor: Color(0xFF6B7280),
  );

  static const activate = ActionConfig(
    type: EntityAction.activate,
    label: 'Activate',
    icon: Icons.check_circle_outline,
    iconColor: Color(0xFF059669),
  );

  static const deactivate = ActionConfig(
    type: EntityAction.deactivate,
    label: 'Deactivate',
    icon: Icons.block_outlined,
    iconColor: Color(0xFFF59E0B),
  );
}

/// Callback when an action is selected
typedef ActionCallback =
    void Function(EntityAction action, String? customValue);

/// A reusable three-dot action panel widget
class EntityActionPanel extends StatelessWidget {
  final List<ActionConfig> actions;
  final ActionCallback onAction;
  final String? tooltip;
  final Widget? child;
  final Offset offset;
  final Color? iconColor;
  final double iconSize;

  const EntityActionPanel({
    super.key,
    required this.actions,
    required this.onAction,
    this.tooltip,
    this.child,
    this.offset = const Offset(0, 40),
    this.iconColor,
    this.iconSize = 20,
  });

  /// Standard configuration with View, Edit, Delete
  factory EntityActionPanel.standard({
    Key? key,
    required VoidCallback onView,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    bool canDelete = true,
    bool canEdit = true,
    bool canView = true,
  }) {
    final actions = <ActionConfig>[
      if (canView) ActionConfig.view,
      if (canEdit) ActionConfig.edit,
      if (canDelete) ...[
        const ActionConfig(
          type: EntityAction.delete,
          label: 'Delete',
          icon: Icons.delete_outline,
          iconColor: Color(0xFFDC2626),
          textColor: Color(0xFFDC2626),
          showDivider: true,
          destructive: true,
        ),
      ],
    ];

    return EntityActionPanel(
      key: key,
      actions: actions,
      onAction: (action, _) {
        switch (action) {
          case EntityAction.view:
            onView();
            break;
          case EntityAction.edit:
            onEdit();
            break;
          case EntityAction.delete:
            onDelete();
            break;
          default:
            break;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDark ? Colors.white70 : Colors.grey[700];

    return PopupMenuButton<String>(
      offset: offset,
      tooltip: tooltip ?? 'More actions',
      onSelected: (value) {
        final action = actions.firstWhere(
          (a) => a.customValue == value || a.type.name == value,
          orElse: () => actions.first,
        );
        onAction(action.type, action.customValue);
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        for (var i = 0; i < actions.length; i++) {
          final action = actions[i];

          // Add divider if requested
          if (action.showDivider && i > 0) {
            items.add(const PopupMenuDivider());
          }

          final value = action.customValue ?? action.type.name;

          items.add(
            PopupMenuItem<String>(
              value: value,
              height: 40,
              child: Row(
                children: [
                  Icon(
                    action.icon,
                    size: 18,
                    color: action.iconColor ?? defaultIconColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                          action.textColor ??
                          (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return items;
      },
      child:
          child ??
          Icon(
            Icons.more_vert,
            size: iconSize,
            color: iconColor ?? defaultIconColor,
          ),
    );
  }
}

/// Desktop-optimized action panel with hover effects
class DesktopEntityActionPanel extends StatefulWidget {
  final List<ActionConfig> actions;
  final ActionCallback onAction;
  final String? tooltip;

  const DesktopEntityActionPanel({
    super.key,
    required this.actions,
    required this.onAction,
    this.tooltip,
  });

  @override
  State<DesktopEntityActionPanel> createState() =>
      _DesktopEntityActionPanelState();
}

class _DesktopEntityActionPanelState extends State<DesktopEntityActionPanel> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: EntityActionPanel(
          actions: widget.actions,
          onAction: widget.onAction,
          tooltip: widget.tooltip,
          offset: const Offset(-100, 30),
        ),
      ),
    );
  }
}

/// Confirmation dialog for destructive actions
class DeleteConfirmationDialog extends StatelessWidget {
  final String entityName;
  final String? entityIdentifier;
  final String? warningMessage;
  final bool isSoftDelete;

  const DeleteConfirmationDialog({
    super.key,
    required this.entityName,
    this.entityIdentifier,
    this.warningMessage,
    this.isSoftDelete = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Text('Delete $entityName?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entityIdentifier != null)
            Text(
              'Entity: $entityIdentifier',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          if (entityIdentifier != null) const SizedBox(height: 12),
          Text(
            warningMessage ??
                'Are you sure you want to delete this $entityName? This action ${isSoftDelete ? 'can be undone' : 'cannot be undone'}.',
          ),
          if (isSoftDelete) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This item will be marked as deleted but can be restored from the recycle bin.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  static Future<bool> show({
    required BuildContext context,
    required String entityName,
    String? entityIdentifier,
    String? warningMessage,
    bool isSoftDelete = true,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => DeleteConfirmationDialog(
            entityName: entityName,
            entityIdentifier: entityIdentifier,
            warningMessage: warningMessage,
            isSoftDelete: isSoftDelete,
          ),
        ) ??
        false;
  }
}

/// Helper mixin for screens to easily implement action handling
mixin EntityActionMixin<T extends StatefulWidget> on State<T> {
  /// Handle action with built-in confirmation for destructive actions
  Future<void> handleEntityAction({
    required EntityAction action,
    required String entityName,
    String? entityId,
    String? entityIdentifier,
    required VoidCallback onView,
    required VoidCallback onEdit,
    required Future<void> Function() onDelete,
    VoidCallback? onDuplicate,
  }) async {
    switch (action) {
      case EntityAction.view:
        onView();
        break;
      case EntityAction.edit:
        onEdit();
        break;
      case EntityAction.delete:
        final confirmed = await DeleteConfirmationDialog.show(
          context: context,
          entityName: entityName,
          entityIdentifier: entityIdentifier,
        );
        if (confirmed) {
          await onDelete();
        }
        break;
      case EntityAction.duplicate:
        onDuplicate?.call();
        break;
      default:
        break;
    }
  }
}
