import 'package:dukanx/services/role_management_service.dart';

enum ActionType { navigate, function, modal }

class ShortcutDefinition {
  final String id;
  final String label;
  final String iconName;
  final String? route;
  final ActionType actionType;
  final String category;
  final List<String> allowedBusinessTypes; // '*' or specific list
  final Permission? requiredPermission;
  final bool hasBadge;
  final String? defaultKeyBinding;
  final int defaultSortOrder;
  final bool isDefault;

  const ShortcutDefinition({
    required this.id,
    required this.label,
    required this.iconName,
    this.route,
    required this.actionType,
    required this.category,
    this.allowedBusinessTypes = const ['*'],
    this.requiredPermission,
    this.hasBadge = false,
    this.defaultKeyBinding,
    this.defaultSortOrder = 100,
    this.isDefault = false,
  });
}
