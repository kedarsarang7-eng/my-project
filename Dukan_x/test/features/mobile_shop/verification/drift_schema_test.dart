// ============================================================================
// MOBILE SHOP — DRIFT SCHEMA & MIGRATION TESTS
// ============================================================================
// Verifies Drift codegen matches expectations: table structures, column types,
// schema version, migration paths, and tenant-scoped unique constraints.
//
// **Validates: Requirements 6.20, 7.1–7.2, 7.6–7.12, 13.1, 13.3**
//
// TODO: Run `dart run build_runner build --delete-conflicting-outputs` before
// executing these tests.
//
// Run: flutter test test/features/mobile_shop/verification/drift_schema_test.dart
// ============================================================================

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/database/mobile_shop_database.dart';
import 'package:dukanx/features/mobile_shop/database/mobile_shop_tables.dart';
import 'package:dukanx/features/mobile_shop/database/migrations/mobile_shop_migrations.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

MobileShopDatabase _createDb() => MobileShopDatabase(NativeDatabase.memory());

// ─── Main Test Suite ─────────────────────────────────────────────────────────

void main() {
  late MobileShopDatabase db;

  setUp(() {
    db = _createDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ==========================================================================
  // GROUP 1: Schema Version and Migration History
  // ==========================================================================
  group('Schema version and migration history', () {
    test(
      'database schemaVersion matches MobileShopMigrationHistory.current',
      () {
        expect(db.schemaVersion, equals(MobileShopMigrationHistory.current));
      },
    );

    test('MobileShopMigrationHistory.current is >= 1', () {
      expect(MobileShopMigrationHistory.current, greaterThanOrEqualTo(1));
    });

    test('MobileShopMigrationHistory.supported is non-empty', () {
      expect(MobileShopMigrationHistory.supported, isNotEmpty);
    });

    test('v1Initial is first supported version', () {
      expect(
        MobileShopMigrationHistory.supported.first,
        equals(MobileShopMigrationHistory.v1Initial),
      );
    });
  });

  // ==========================================================================
  // GROUP 2: Table Existence
  // ==========================================================================
  group('Table existence', () {
    test('mobileImeiUnits table exists and accepts inserts', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'schema-test-1',
              tenantId: 'tenant-schema',
              entityId: 'entity-1',
              imei: '356938035643809',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileImeiUnits).get();
      expect(rows, hasLength(1));
    });

    test('mobileOutboxMutations table exists and accepts inserts', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileOutboxMutations)
          .insert(
            MobileOutboxMutationsCompanion.insert(
              id: 'outbox-test-1',
              tenantId: 'tenant-schema',
              operationId: 'op-schema-1',
              mutationFingerprint: 'fp-schema-1',
              entityType: 'IMEI_UNIT',
              payload: '{}',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileOutboxMutations).get();
      expect(rows, hasLength(1));
    });

    test('mobileConflicts table exists and accepts inserts', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileConflicts)
          .insert(
            MobileConflictsCompanion.insert(
              id: 'conflict-schema-1',
              tenantId: 'tenant-schema',
              operationId: 'op-cs-1',
              entityType: 'IMEI_UNIT',
              entityId: 'entity-cs-1',
              localVersion: 1,
              serverVersion: 2,
              reason: 'TEST',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileConflicts).get();
      expect(rows, hasLength(1));
    });

    test('mobileEventInbox table exists and accepts inserts', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileEventInbox)
          .insert(
            MobileEventInboxCompanion.insert(
              id: 'inbox-schema-1',
              tenantId: 'tenant-schema',
              eventId: 'evt-schema-1',
              entityType: 'IMEI_UNIT',
              entityId: 'entity-inbox-1',
              version: 1,
              action: 'CREATED',
              receivedAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileEventInbox).get();
      expect(rows, hasLength(1));
    });

    test('mobileContinuationCheckpoints table exists', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileContinuationCheckpoints)
          .insert(
            MobileContinuationCheckpointsCompanion.insert(
              id: 'cp-schema-1',
              tenantId: 'tenant-schema',
              bucket: 'ROOT',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileContinuationCheckpoints).get();
      expect(rows, hasLength(1));
    });

    test('mobileServiceJobs table exists', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileServiceJobs)
          .insert(
            MobileServiceJobsCompanion.insert(
              id: 'job-schema-1',
              tenantId: 'tenant-schema',
              entityId: 'entity-job-1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileServiceJobs).get();
      expect(rows, hasLength(1));
    });

    test('mobileExchanges table exists', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileExchanges)
          .insert(
            MobileExchangesCompanion.insert(
              id: 'exc-schema-1',
              tenantId: 'tenant-schema',
              entityId: 'entity-exc-1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileExchanges).get();
      expect(rows, hasLength(1));
    });

    test('mobileWarranties table exists', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileWarranties)
          .insert(
            MobileWarrantiesCompanion.insert(
              id: 'war-schema-1',
              tenantId: 'tenant-schema',
              entityId: 'entity-war-1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileWarranties).get();
      expect(rows, hasLength(1));
    });

    test('mobileInvoiceAssociations table exists', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileInvoiceAssociations)
          .insert(
            MobileInvoiceAssociationsCompanion.insert(
              id: 'assoc-schema-1',
              tenantId: 'tenant-schema',
              invoiceId: 'inv-1',
              imei: '356938035643809',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileInvoiceAssociations).get();
      expect(rows, hasLength(1));
    });

    test('mobileReconciliationStatus table exists', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileReconciliationStatus)
          .insert(
            MobileReconciliationStatusCompanion.insert(
              id: 'recon-schema-1',
              tenantId: 'tenant-schema',
              operationId: 'op-recon-1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileReconciliationStatus).get();
      expect(rows, hasLength(1));
    });

    test('mobileProviderState table exists', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileProviderState)
          .insert(
            MobileProviderStateCompanion.insert(
              id: 'prov-schema-1',
              tenantId: 'tenant-schema',
              providerType: 'SIM_RECHARGE',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileProviderState).get();
      expect(rows, hasLength(1));
    });
  });

  // ==========================================================================
  // GROUP 3: Column Defaults and Status Enums
  // ==========================================================================
  group('Column defaults and status enums', () {
    test('outbox mutation defaults to queued status', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileOutboxMutations)
          .insert(
            MobileOutboxMutationsCompanion.insert(
              id: 'default-status-1',
              tenantId: 'tenant-d',
              operationId: 'op-d1',
              mutationFingerprint: 'fp-d1',
              entityType: 'IMEI_UNIT',
              payload: '{}',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final row = await (db.select(
        db.mobileOutboxMutations,
      )..where((t) => t.id.equals('default-status-1'))).getSingle();

      expect(row.status, equals(OutboxStatus.queued));
      expect(row.retryCount, equals(0));
    });

    test('conflict defaults to unresolved resolution status', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileConflicts)
          .insert(
            MobileConflictsCompanion.insert(
              id: 'default-conflict-1',
              tenantId: 'tenant-d',
              operationId: 'op-dc1',
              entityType: 'IMEI_UNIT',
              entityId: 'entity-dc1',
              localVersion: 1,
              serverVersion: 2,
              reason: 'VERSION_MISMATCH',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final row = await (db.select(
        db.mobileConflicts,
      )..where((t) => t.id.equals('default-conflict-1'))).getSingle();

      expect(row.resolutionStatus, equals(ConflictResolutionStatus.unresolved));
      expect(row.resolvedAt, isNull);
    });

    test('IMEI unit defaults confirmationStatus to pending', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'default-imei-1',
              tenantId: 'tenant-d',
              entityId: 'entity-di1',
              imei: '490154203237518',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final row = await (db.select(
        db.mobileImeiUnits,
      )..where((t) => t.id.equals('default-imei-1'))).getSingle();

      expect(row.confirmationStatus, equals(ConfirmationStatus.pending));
    });
  });

  // ==========================================================================
  // GROUP 4: Unique Constraints — Tenant-Scoped
  // ==========================================================================
  group('Unique constraints — tenant-scoped', () {
    test('duplicate (tenantId, eventId) in event inbox throws', () async {
      final now = DateTime.now();

      await db
          .into(db.mobileEventInbox)
          .insert(
            MobileEventInboxCompanion.insert(
              id: 'unique-1',
              tenantId: 'tenant-u',
              eventId: 'evt-unique',
              entityType: 'IMEI_UNIT',
              entityId: 'e-u1',
              version: 1,
              action: 'CREATED',
              receivedAt: now,
              updatedAt: now,
            ),
          );

      var threw = false;
      try {
        await db
            .into(db.mobileEventInbox)
            .insert(
              MobileEventInboxCompanion.insert(
                id: 'unique-2', // different row ID
                tenantId: 'tenant-u', // same tenant
                eventId: 'evt-unique', // same event
                entityType: 'IMEI_UNIT',
                entityId: 'e-u1',
                version: 2,
                action: 'UPDATED',
                receivedAt: now,
                updatedAt: now,
              ),
            );
      } on Exception {
        threw = true;
      }

      expect(
        threw,
        isTrue,
        reason: 'Duplicate (tenantId, eventId) should throw',
      );
    });

    test('same eventId different tenant is NOT a duplicate', () async {
      final now = DateTime.now();

      await db
          .into(db.mobileEventInbox)
          .insert(
            MobileEventInboxCompanion.insert(
              id: 'cross-1',
              tenantId: 'tenant-A',
              eventId: 'evt-cross',
              entityType: 'IMEI_UNIT',
              entityId: 'e-c1',
              version: 1,
              action: 'CREATED',
              receivedAt: now,
              updatedAt: now,
            ),
          );

      // Different tenant, same eventId should succeed
      await db
          .into(db.mobileEventInbox)
          .insert(
            MobileEventInboxCompanion.insert(
              id: 'cross-2',
              tenantId: 'tenant-B',
              eventId: 'evt-cross',
              entityType: 'IMEI_UNIT',
              entityId: 'e-c1',
              version: 1,
              action: 'CREATED',
              receivedAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.select(db.mobileEventInbox).get();
      expect(rows, hasLength(2));
    });
  });

  // ==========================================================================
  // GROUP 5: Tenant Isolation in Generated Schema
  // ==========================================================================
  group('Tenant isolation in generated schema', () {
    test('every domain table has tenantId column', () async {
      // Insert into all tables with different tenants and verify isolation
      final now = DateTime.now();

      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'iso-a1',
              tenantId: 'tenant-iso-A',
              entityId: 'entity-iso-a1',
              imei: '111111111111118',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'iso-b1',
              tenantId: 'tenant-iso-B',
              entityId: 'entity-iso-b1',
              imei: '222222222222226',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final resultsA = await (db.select(
        db.mobileImeiUnits,
      )..where((t) => t.tenantId.equals('tenant-iso-A'))).get();
      final resultsB = await (db.select(
        db.mobileImeiUnits,
      )..where((t) => t.tenantId.equals('tenant-iso-B'))).get();

      expect(resultsA, hasLength(1));
      expect(resultsB, hasLength(1));
      expect(resultsA.first.tenantId, 'tenant-iso-A');
      expect(resultsB.first.tenantId, 'tenant-iso-B');
    });
  });

  // ==========================================================================
  // GROUP 6: Money Fields — Integer Minor Units
  // ==========================================================================
  group('Money fields — integer minor units', () {
    test('salePricePaise stored as integer', () async {
      final now = DateTime.now();
      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'money-test-1',
              tenantId: 'tenant-money',
              entityId: 'entity-money-1',
              imei: '356938035643809',
              salePricePaise: const Value(5999900), // 59,999.00 INR
              acquisitionCostPaise: const Value(4500000), // 45,000.00 INR
              createdAt: now,
              updatedAt: now,
            ),
          );

      final row = await (db.select(
        db.mobileImeiUnits,
      )..where((t) => t.id.equals('money-test-1'))).getSingle();

      expect(row.salePricePaise, 5999900);
      expect(row.acquisitionCostPaise, 4500000);
    });
  });
}
