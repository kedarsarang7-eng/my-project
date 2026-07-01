import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../domain/models/shortcut_definition.dart';
import '../domain/models/user_shortcut_config.dart';
import '../../../../services/role_management_service.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class ShortcutsRepository {
  final AppDatabase _db;

  ShortcutsRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  // ============================================================================
  // DEFINITIONS (SYSTEM SHORTCUTS)
  // ============================================================================

  /// Seed or update system definitions
  Future<void> seedDefinitions(List<ShortcutDefinition> definitions) async {
    await _db.transaction(() async {
      for (final def in definitions) {
        await _db
            .into(_db.shortcutDefinitions)
            .insert(
              ShortcutDefinitionsCompanion(
                id: Value(def.id),
                label: Value(def.label),
                iconName: Value(def.iconName),
                route: Value(def.route),
                actionType: Value(def.actionType.name),
                category: Value(def.category),
                allowedBusinessTypes: Value(
                  jsonEncode(def.allowedBusinessTypes),
                ),
                requiredPermission: Value(def.requiredPermission?.name),
                hasBadge: Value(def.hasBadge),
                defaultKeyBinding: Value(def.defaultKeyBinding),
                defaultSortOrder: Value(def.defaultSortOrder),
                isDefault: Value(def.isDefault),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  /// Get all system definitions
  Future<List<ShortcutDefinition>> getAllDefinitions() async {
    final rows = await _db.select(_db.shortcutDefinitions).get();
    return rows.map((row) => _mapDefinition(row)).toList();
  }

  // ============================================================================
  // USER CONFIGURATIONS
  // ============================================================================

  /// Get user's configured shortcuts (joined with definitions)
  Stream<List<UserShortcutConfig>> watchUserShortcuts(String userId) {
    final query =
        _db.select(_db.userShortcuts).join([
            innerJoin(
              _db.shortcutDefinitions,
              _db.shortcutDefinitions.id.equalsExp(
                _db.userShortcuts.shortcutId,
              ),
            ),
          ])
          ..where(
            _db.userShortcuts.userId.equals(userId) &
                _db.userShortcuts.isEnabled.equals(true),
          )
          ..orderBy([OrderingTerm.asc(_db.userShortcuts.orderIndex)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final config = row.readTable(_db.userShortcuts);
        final def = row.readTable(_db.shortcutDefinitions);
        return _mapUserConfig(config, def);
      }).toList();
    });
  }

  /// Initialize default shortcuts for a new user
  Future<void> initializeForUser(String userId) async {
    // Check if user already has shortcuts
    final count = await (_db.select(
      _db.userShortcuts,
    )..where((t) => t.userId.equals(userId))).get().then((l) => l.length);

    if (count > 0) return; // Already initialized

    // Get default definitions
    final defaults =
        await (_db.select(_db.shortcutDefinitions)
              ..where((t) => t.isDefault.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.defaultSortOrder)]))
            .get();

    // Insert user configs
    await _db.transaction(() async {
      for (int i = 0; i < defaults.length; i++) {
        final def = defaults[i];
        await _db
            .into(_db.userShortcuts)
            .insert(
              UserShortcutsCompanion(
                id: Value(const Uuid().v4()),
                userId: Value(userId),
                shortcutId: Value(def.id),
                orderIndex: Value(i), // Maintain default order
                isEnabled: Value(true),
                createdAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    });
  }

  /// Update shortcut order (drag & drop)
  Future<void> updateOrder(String userId, List<String> shortcutIds) async {
    await _db.transaction(() async {
      for (int i = 0; i < shortcutIds.length; i++) {
        await (_db.update(_db.userShortcuts)..where(
              (t) =>
                  t.userId.equals(userId) & t.shortcutId.equals(shortcutIds[i]),
            ))
            .write(
              UserShortcutsCompanion(
                orderIndex: Value(i),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    });
  }

  /// Update usage count (analytics)
  Future<void> incrementUsage(String userId, String shortcutId) async {
    // Custom query to increment for atomicity
    await _db.customStatement(
      'UPDATE user_shortcuts SET usage_count = usage_count + 1, last_used_at = ? WHERE user_id = ? AND shortcut_id = ?',
      [DateTime.now().millisecondsSinceEpoch, userId, shortcutId],
    );
  }

  /// Toggle enabled status
  Future<void> toggleShortcut(
    String userId,
    String shortcutId,
    bool isEnabled,
  ) async {
    await (_db.update(_db.userShortcuts)..where(
          (t) => t.userId.equals(userId) & t.shortcutId.equals(shortcutId),
        ))
        .write(
          UserShortcutsCompanion(
            isEnabled: Value(isEnabled),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Add a new shortcut for user
  Future<void> addUserShortcut(String userId, String shortcutId) async {
    // Get max order index
    final maxOrder =
        await (_db.select(_db.userShortcuts)
              ..where((t) => t.userId.equals(userId))
              ..orderBy([(t) => OrderingTerm.desc(t.orderIndex)])
              ..limit(1))
            .getSingleOrNull();

    final nextOrder = (maxOrder?.orderIndex ?? -1) + 1;

    await _db
        .into(_db.userShortcuts)
        .insert(
          UserShortcutsCompanion(
            id: Value(const Uuid().v4()),
            userId: Value(userId),
            shortcutId: Value(shortcutId),
            orderIndex: Value(nextOrder),
            isEnabled: Value(true),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  // ============================================================================
  // MAPPERS
  // ============================================================================

  ShortcutDefinition _mapDefinition(ShortcutDefinitionEntity row) {
    return ShortcutDefinition(
      id: row.id,
      label: row.label,
      iconName: row.iconName,
      route: row.route,
      actionType: ActionType.values.firstWhere(
        (e) => e.name == row.actionType,
        orElse: () => ActionType.navigate,
      ),
      category: row.category,
      allowedBusinessTypes: List<String>.from(
        jsonDecode(row.allowedBusinessTypes) as List,
      ),
      requiredPermission: row.requiredPermission != null
          ? Permission.values.firstWhere(
              (e) => e.name == row.requiredPermission,
              orElse: () => Permission.viewReports, // Safe default
            )
          : null,
      hasBadge: row.hasBadge,
      defaultKeyBinding: row.defaultKeyBinding,
      defaultSortOrder: row.defaultSortOrder,
      isDefault: row.isDefault,
    );
  }

  UserShortcutConfig _mapUserConfig(
    UserShortcutEntity config,
    ShortcutDefinitionEntity def,
  ) {
    return UserShortcutConfig(
      id: config.id,
      userId: config.userId,
      definition: _mapDefinition(def),
      orderIndex: config.orderIndex,
      groupName: config.groupName,
      isEnabled: config.isEnabled,
      isPriority: config.isPriority,
      keyboardBinding: config.keyboardBinding,
      usageCount: config.usageCount,
    );
  }
}
