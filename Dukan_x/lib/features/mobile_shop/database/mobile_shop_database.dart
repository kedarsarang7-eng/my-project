// ============================================================================
// MOBILE SHOP — DRIFT DATABASE CLASS
// ============================================================================
// Includes all MobileShop-specific tables for domain projections and
// synchronization state. This database is a dedicated scope for the mobile
// shop feature, separate from the core AppDatabase.
//
// After modifying tables, run:
//   dart run build_runner build --delete-conflicting-outputs
//
// Requirements: 6.24, 7.1–7.2, 7.6–7.9, 7.13–7.15; GR-2
// ============================================================================

import 'package:drift/drift.dart';

import 'migrations/mobile_shop_migrations.dart';
import 'mobile_shop_tables.dart';

part 'mobile_shop_database.g.dart';

/// Drift database containing all MobileShop domain projection and
/// synchronization tables.
///
/// This database is tenant-scoped at the application layer — every query
/// and mutation MUST include the authenticated tenantId. The database itself
/// does not enforce tenant isolation beyond unique constraints that include
/// tenantId; the repository layer is responsible for including tenant
/// predicates on every operation.
///
/// NOTE: Run `dart run build_runner build --delete-conflicting-outputs`
/// to regenerate the `mobile_shop_database.g.dart` file.
@DriftDatabase(
  tables: [
    // Domain projections
    MobileImeiUnits,
    MobileInvoiceAssociations,
    MobileServiceJobs,
    MobileExchanges,
    MobileWarranties,
    MobileReconciliationStatus,
    MobileProviderState,
    // Synchronization state
    MobileOutboxMutations,
    MobileConflicts,
    MobileEventInbox,
    MobileContinuationCheckpoints,
  ],
)
class MobileShopDatabase extends _$MobileShopDatabase {
  MobileShopDatabase(super.e);

  @override
  int get schemaVersion => MobileShopMigrationHistory.current;

  @override
  MigrationStrategy get migration => MobileShopMigrationStrategy.build();
}
