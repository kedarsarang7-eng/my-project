import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/services/role_management_service.dart';
import '../../data/shortcuts_repository.dart';

import '../models/user_shortcut_config.dart';
import '../../data/shortcut_definitions.dart'; // We'll create this next

class ShortcutService {
  final ShortcutsRepository _repository;

  ShortcutService({ShortcutsRepository? repository})
    : _repository = repository ?? ShortcutsRepository();

  /// Initialize system definitions if needed
  Future<void> initializeSystem(String userId) async {
    // 1. Seed definitions
    await _repository.seedDefinitions(defaultShortcuts);

    // 2. Initialize user defaults
    await _repository.initializeForUser(userId);
  }

  /// Get shortcuts visible to current user based on role & business type
  Future<List<UserShortcutConfig>> getVisibleShortcuts({
    required String userId,
    required UserRole role,
    required BusinessType businessType,
  }) async {
    // 1. Get user's configured shortcuts (this returns stream usually, but strictly speaking repo has watch)
    // For service method, we might want a snapshot.
    // But typically UI watches the Repo stream.
    // This method is for filtering logic helper.

    // Instead, let's expose a method to filter a list
    return []; // Placeholder: The logic is moved to Provider usually for reactive filtering
  }

  /// Filter logic to be used by Provider
  List<UserShortcutConfig> filterShortcuts(
    List<UserShortcutConfig> allShortcuts,
    UserRole role,
    BusinessType businessType,
  ) {
    return allShortcuts.where((config) {
      final def = config.definition;

      // 1. Check permission
      if (def.requiredPermission != null) {
        if (!RolePermissions.hasPermission(role, def.requiredPermission!)) {
          return false;
        }
      }

      // 2. Check business type
      if (def.allowedBusinessTypes.isNotEmpty &&
          !def.allowedBusinessTypes.contains('*')) {
        // allowBusinessTypes is List<String> from domain model
        if (!def.allowedBusinessTypes.contains(businessType.name)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> updateShortcutOrder(
    String userId,
    List<String> shortcutIds,
  ) async {
    await _repository.updateOrder(userId, shortcutIds);
  }

  Future<void> recordUsage(String userId, String shortcutId) async {
    await _repository.incrementUsage(userId, shortcutId);
  }

  Future<void> toggleShortcut(
    String userId,
    String shortcutId,
    bool isEnabled,
  ) async {
    await _repository.toggleShortcut(userId, shortcutId, isEnabled);
  }
}
