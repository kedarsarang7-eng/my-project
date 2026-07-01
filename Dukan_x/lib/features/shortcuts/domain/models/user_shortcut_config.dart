import 'shortcut_definition.dart';

class UserShortcutConfig {
  final String id;
  final String userId;
  final ShortcutDefinition definition;
  final int orderIndex;
  final String? groupName;
  final bool isEnabled;
  final bool isPriority;
  final String? keyboardBinding;
  final int usageCount;

  const UserShortcutConfig({
    required this.id,
    required this.userId,
    required this.definition,
    required this.orderIndex,
    this.groupName,
    this.isEnabled = true,
    this.isPriority = false,
    this.keyboardBinding,
    this.usageCount = 0,
  });

  String get shortcutId => definition.id;

  /// Create a copy with updated fields
  UserShortcutConfig copyWith({
    String? id,
    String? userId,
    ShortcutDefinition? definition,
    int? orderIndex,
    String? groupName,
    bool? isEnabled,
    bool? isPriority,
    String? keyboardBinding,
    int? usageCount,
  }) {
    return UserShortcutConfig(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      definition: definition ?? this.definition,
      orderIndex: orderIndex ?? this.orderIndex,
      groupName: groupName ?? this.groupName,
      isEnabled: isEnabled ?? this.isEnabled,
      isPriority: isPriority ?? this.isPriority,
      keyboardBinding: keyboardBinding ?? this.keyboardBinding,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}
