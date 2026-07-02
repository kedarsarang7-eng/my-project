import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../domain/rid_generator.dart';
import 'unresolved_tenant_error.dart';

/// Idempotent stock migration utility for the Wholesale Godown / Multi-Warehouse
/// feature (Phase 7, Requirement 10.6).
///
/// Initializes [StockByLocation] records from single-stock product totals.
///
/// **Behavior:**
/// - First run: for each product with `stockQuantity > 0`, creates a
///   [StockByLocation] entry with all stock at a "Default" warehouse.
///   If no "Default" warehouse exists for the tenant, one is created first.
/// - Subsequent runs: detects the version marker and modifies zero records.
///
/// The migration is guarded by a persisted `migrationVersion` marker stored
/// in the `kv_store` table (a simple key-value store). The key is
/// `wholesale_stock_migration_v1_{tenantId}`.
///
/// This ensures idempotency per Requirement 1.10: repeated runs produce the
/// same persisted result and modify zero records after the first execution.
class WholesaleStockMigration {
  static const String _migrationKeyPrefix = 'wholesale_stock_migration_v1_';
  static const String _defaultWarehouseName = 'Default';
  static const int _migrationVersion = 1;

  final AppDatabase _db;
  final SessionManager _sessionManager;
  final RidGenerator _ridGenerator;

  WholesaleStockMigration({
    AppDatabase? db,
    SessionManager? sessionManager,
    RidGenerator? ridGenerator,
  }) : _db = db ?? sl<AppDatabase>(),
       _sessionManager = sessionManager ?? sl<SessionManager>(),
       _ridGenerator = ridGenerator ?? DefaultRidGenerator();

  /// Resolves the active Tenant_Id from the authenticated session.
  /// Throws [UnresolvedTenantError] if the tenant cannot be resolved.
  String _resolveTenantId() {
    final tenantId =
        _sessionManager.currentBusinessId ?? _sessionManager.userId;
    if (tenantId == null || tenantId.isEmpty) {
      throw UnresolvedTenantError('WholesaleStockMigration');
    }
    return tenantId;
  }

  /// Runs the idempotent stock-by-location migration for the active tenant.
  ///
  /// Returns `true` if the migration was executed (first run), or `false` if
  /// it was skipped (already completed — idempotent guard).
  Future<bool> run() async {
    final tenantId = _resolveTenantId();
    final migrationKey = '$_migrationKeyPrefix$tenantId';

    // Check the version marker in kv_store.
    final existing = await _db
        .customSelect(
          'SELECT value FROM kv_store WHERE key = ?',
          variables: [Variable<String>(migrationKey)],
        )
        .get();

    if (existing.isNotEmpty) {
      final storedVersion = int.tryParse(existing.first.read<String>('value'));
      if (storedVersion != null && storedVersion >= _migrationVersion) {
        debugPrint(
          'WholesaleStockMigration: already at version $storedVersion '
          'for tenant $tenantId — skipping (idempotent)',
        );
        return false; // Already migrated — zero records modified.
      }
    }

    // First run: ensure a "Default" warehouse exists for this tenant.
    final defaultWarehouseId = await _ensureDefaultWarehouse(tenantId);

    // Fetch all products with stock > 0 for this tenant.
    final products = await _db
        .customSelect(
          'SELECT id, stock_quantity FROM products '
          'WHERE user_id = ? AND stock_quantity > 0',
          variables: [Variable<String>(tenantId)],
        )
        .get();

    // For each product, create a StockByLocation entry at the Default warehouse.
    for (final product in products) {
      final productId = product.read<String>('id');
      final stockQty = product.read<double>('stock_quantity').round();

      if (stockQty <= 0) continue;

      // Only insert if no StockByLocation record exists yet for this
      // product at this location (prevent duplicates on partial re-runs).
      await _db.customStatement(
        'INSERT OR IGNORE INTO stock_by_location_table '
        '(tenant_id, product_id, location_id, quantity) '
        'VALUES (?, ?, ?, ?)',
        [tenantId, productId, defaultWarehouseId, stockQty],
      );
    }

    // Record the migration version marker.
    await _db.customStatement(
      'INSERT OR REPLACE INTO kv_store (key, value) VALUES (?, ?)',
      [migrationKey, _migrationVersion.toString()],
    );

    debugPrint(
      'WholesaleStockMigration: completed for tenant $tenantId — '
      '${products.length} products attributed to Default warehouse '
      '"$defaultWarehouseId"',
    );
    return true;
  }

  /// Ensures a "Default" warehouse exists for [tenantId].
  /// Returns the warehouse id (existing or newly created).
  Future<String> _ensureDefaultWarehouse(String tenantId) async {
    // Check if a "Default" warehouse already exists.
    final existing = await _db
        .customSelect(
          'SELECT id FROM warehouses_table '
          'WHERE tenant_id = ? AND name = ?',
          variables: [
            Variable<String>(tenantId),
            Variable<String>(_defaultWarehouseName),
          ],
        )
        .get();

    if (existing.isNotEmpty) {
      return existing.first.read<String>('id');
    }

    // Create the Default warehouse with an RID.
    final id = _ridGenerator.generate(tenantId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.customStatement(
      'INSERT INTO warehouses_table (id, tenant_id, name, created_at) '
      'VALUES (?, ?, ?, ?)',
      [id, tenantId, _defaultWarehouseName, now],
    );

    debugPrint(
      'WholesaleStockMigration: created Default warehouse "$id" '
      'for tenant $tenantId',
    );
    return id;
  }
}
