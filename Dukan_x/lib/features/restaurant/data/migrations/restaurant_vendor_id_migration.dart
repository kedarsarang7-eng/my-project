// ============================================================================
// RESTAURANT VENDOR ID MIGRATION
// ============================================================================
// One-time data migration that replaces hardcoded 'SYSTEM' vendorId in all
// restaurant Drift tables with the real tenant ID from SessionManager.
//
// Context: Prior to the P0 tenant isolation fix, all restaurant screens
// constructed queries with vendorId = 'SYSTEM'. Existing local data is stored
// under that key. After the fix, screens resolve vendorId from the session,
// so existing rows need updating to match.
//
// Safety:
// - Idempotent: guarded by SharedPreferences flag, runs at most once.
// - Graceful: skips if currentBusinessId is null or still 'SYSTEM'.
// - Non-blocking: fire-and-forget from the post-login init flow.
//
// Requirements: 2.1, 2.2, 2.3, 2.4
// ============================================================================

import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/session/session_manager.dart';

/// Migrates existing restaurant data from the legacy hardcoded 'SYSTEM'
/// vendorId to the real tenant ID resolved from [SessionManager].
class RestaurantVendorIdMigration {
  static const _key = 'restaurant_vendorid_migrated';

  /// Runs the migration if it hasn't been performed yet.
  ///
  /// Call from the post-login initialization flow. Safe to call repeatedly —
  /// the SharedPreferences guard ensures it only executes once per install.
  static Future<void> runIfNeeded(
    AppDatabase db,
    SessionManager session,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) == true) return; // Already migrated

    final vendorId = session.currentBusinessId;
    if (vendorId == null || vendorId.isEmpty || vendorId == 'SYSTEM') {
      // Can't migrate without a real tenant ID — skip silently.
      developer.log(
        'RestaurantVendorIdMigration: skipped (vendorId=$vendorId)',
        name: 'migration',
      );
      return;
    }

    developer.log(
      'RestaurantVendorIdMigration: migrating SYSTEM → $vendorId',
      name: 'migration',
    );

    try {
      await db.transaction(() async {
        // 1. restaurant_tables
        await (db.update(db.restaurantTables)
              ..where((t) => t.vendorId.equals('SYSTEM')))
            .write(RestaurantTablesCompanion(vendorId: Value(vendorId)));

        // 2. food_orders
        await (db.update(db.foodOrders)
              ..where((t) => t.vendorId.equals('SYSTEM')))
            .write(FoodOrdersCompanion(vendorId: Value(vendorId)));

        // 3. food_menu_items
        await (db.update(db.foodMenuItems)
              ..where((t) => t.vendorId.equals('SYSTEM')))
            .write(FoodMenuItemsCompanion(vendorId: Value(vendorId)));

        // 4. food_categories
        await (db.update(db.foodCategories)
              ..where((t) => t.vendorId.equals('SYSTEM')))
            .write(FoodCategoriesCompanion(vendorId: Value(vendorId)));
      });

      await prefs.setBool(_key, true);

      developer.log(
        'RestaurantVendorIdMigration: completed successfully',
        name: 'migration',
      );
    } catch (e, stack) {
      developer.log(
        'RestaurantVendorIdMigration: FAILED — $e',
        name: 'migration',
        stackTrace: stack,
      );
      // Do NOT set the flag on failure so the migration retries next launch.
    }
  }
}
