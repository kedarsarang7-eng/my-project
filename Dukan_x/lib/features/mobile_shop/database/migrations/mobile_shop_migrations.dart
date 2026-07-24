// ============================================================================
// MOBILE SHOP — DRIFT MIGRATION STRATEGY
// ============================================================================
// Documents migration policies and version history for the MobileShop Drift
// database. All schema changes MUST follow the rules below to preserve
// offline queued work, synchronization state, and tenant ownership.
//
// Requirements: 6.20, 13.3
// ============================================================================

import 'package:drift/drift.dart';

// ============================================================================
// MIGRATION RULES — INVIOLABLE CONSTRAINTS
// ============================================================================
//
// 1. NEVER drop the MobileOutboxMutations table or any of its columns.
//    Queued work must survive every migration. Pending offline mutations
//    represent uncommitted user intent and cannot be silently discarded.
//
// 2. NEVER drop the MobileConflicts table or any of its columns.
//    Conflict records represent unresolved divergence between local and
//    server state. Losing them hides data integrity issues from the user.
//
// 3. NEVER drop confirmation metadata columns (confirmationStatus,
//    serverVersion, syncedAt, dataModelVersion) from any table.
//    These columns distinguish pending/draft from server-confirmed state.
//
// 4. NEVER drop tenantId from any table.
//    Tenant ownership is a hard isolation boundary. Every row must remain
//    attributable to exactly one tenant.
//
// 5. NEVER drop the MobileEventInbox table or any of its columns.
//    The event inbox provides at-most-once delivery semantics and prevents
//    version regression from duplicate event application.
//
// 6. Adding new columns MUST use nullable types OR provide a non-null
//    default value. Existing rows cannot satisfy a non-nullable constraint
//    without a default.
//
// 7. Removing columns requires a TWO-VERSION deprecation window:
//    - Version N: Mark the column as deprecated (document intent to remove).
//    - Version N+1: Remove the column from the schema.
//    This ensures any client on version N can still read/write the column
//    during the transition.
//
// 8. Table renames are treated as DROP + CREATE. Instead, create the new
//    table and migrate data, preserving the old table for the deprecation
//    window.
//
// 9. Index changes (adding/removing unique constraints) must be validated
//    against existing data before migration. A failing unique constraint
//    on existing rows will crash the migration.
//
// 10. Every migration step MUST be idempotent when possible. If a migration
//     is interrupted and restarted, it should not corrupt data.
// ============================================================================

/// Documents the version history of the MobileShop Drift database.
///
/// Each constant represents a schema version with a short description of
/// what changed. The [MobileShopDatabase.onUpgrade] handler uses these
/// constants to apply incremental migrations.
///
/// When adding a new version:
/// 1. Add a new constant here with the next integer.
/// 2. Add the migration logic in [MobileShopMigrationStrategy.onUpgrade].
/// 3. Update [MobileShopDatabase.schemaVersion] to the new value.
/// 4. Run `dart run build_runner build --delete-conflicting-outputs`.
/// 5. Write a migration test verifying upgrade from every supported prior
///    version to the new version (task 10.4).
class MobileShopMigrationHistory {
  MobileShopMigrationHistory._();

  /// Initial schema — all domain projection and synchronization tables.
  ///
  /// Tables: MobileImeiUnits, MobileInvoiceAssociations, MobileServiceJobs,
  /// MobileExchanges, MobileWarranties, MobileReconciliationStatus,
  /// MobileProviderState, MobileOutboxMutations, MobileConflicts,
  /// MobileEventInbox, MobileContinuationCheckpoints.
  static const int v1Initial = 1;

  // ──────────────────────────────────────────────────────────────────────────
  // Future versions — add below following this pattern:
  //
  // /// Description of what v2 adds/changes.
  // static const int v2AddSomeColumn = 2;
  //
  // /// Description of what v3 adds/changes.
  // static const int v3AddNewTable = 3;
  // ──────────────────────────────────────────────────────────────────────────

  /// The current (latest) schema version.
  static const int current = v1Initial;

  /// All supported schema versions that can be migrated from.
  /// Clients on versions outside this list must perform a fresh install.
  static const List<int> supported = [v1Initial];
}

/// Provides the migration strategy for [MobileShopDatabase].
///
/// This class encapsulates all version-to-version upgrade logic. It is
/// designed to be forward-compatible: new versions add `case` branches
/// without modifying existing ones.
///
/// Usage in the database class:
/// ```dart
/// @override
/// MigrationStrategy get migration => MobileShopMigrationStrategy.build();
/// ```
class MobileShopMigrationStrategy {
  MobileShopMigrationStrategy._();

  /// Builds the [MigrationStrategy] for the MobileShop database.
  ///
  /// - [onCreate]: Creates all tables from scratch (fresh install).
  /// - [onUpgrade]: Applies incremental migrations from [from] to [to].
  /// - [beforeOpen]: Optional hook for post-migration validation.
  static MigrationStrategy build() {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Apply migrations sequentially from the current version to target.
        // Each step upgrades exactly one version increment.
        for (var target = from + 1; target <= to; target++) {
          await _applyMigration(m, target);
        }
      },
      beforeOpen: (OpeningDetails details) async {
        // Future: Add post-migration integrity checks here if needed.
        // For example, verify that critical tables exist after upgrade.
      },
    );
  }

  /// Applies a single version migration step.
  ///
  /// Each case corresponds to the TARGET version being migrated TO.
  /// The migration assumes the database is currently at [targetVersion - 1].
  static Future<void> _applyMigration(Migrator m, int targetVersion) async {
    switch (targetVersion) {
      // ────────────────────────────────────────────────────────────────────
      // v1 is the initial schema — no migration needed (handled by onCreate)
      // ────────────────────────────────────────────────────────────────────

      // ────────────────────────────────────────────────────────────────────
      // Future migrations go here. Example:
      //
      // case MobileShopMigrationHistory.v2AddSomeColumn:
      //   await m.addColumn(tableNameHere, tableNameHere.newColumn);
      //   break;
      //
      // case MobileShopMigrationHistory.v3AddNewTable:
      //   await m.createTable(newTable);
      //   break;
      // ────────────────────────────────────────────────────────────────────

      default:
        // Unknown target version — this should not happen if
        // MobileShopMigrationHistory.supported is kept up-to-date.
        throw StateError(
          'MobileShop database: no migration path to version $targetVersion. '
          'Supported versions: ${MobileShopMigrationHistory.supported}',
        );
    }
  }
}
