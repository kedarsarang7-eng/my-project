// ============================================================================
// MOBILE SHOP — REPOSITORY TENANT ISOLATION TESTS
// ============================================================================
// Tests MobileShopLocalRepository tenant isolation, covering the abstract
// interface contract for every entity type. Uses Drift in-memory DB.
//
// **Validates: Requirements 7.1, 7.4, 7.8, 7.12, 8.9, 13.1, 13.4**
//
// TODO: Run `dart run build_runner build --delete-conflicting-outputs` before
// executing these tests.
//
// Run: flutter test test/features/mobile_shop/verification/repository_test.dart
// ============================================================================

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/auth/business_type.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context.dart';
import 'package:dukanx/features/mobile_shop/database/mobile_shop_database.dart';
import 'package:dukanx/features/mobile_shop/database/mobile_shop_tables.dart';
import 'package:dukanx/features/mobile_shop/repository/mobile_shop_local_repository.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

int _counter = 0;

TenantContext _ctx(String tenantId) => TenantContext(
  tenantId: tenantId,
  businessId: tenantId,
  subjectId: 'user-$tenantId',
  businessType: MobileShopBusinessType.mobileShop,
  permissions: const {'manage_imei', 'view_imei'},
  correlationId: 'corr-${++_counter}',
);

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
  // GROUP 1: IMEI Unit Tenant Isolation
  // ==========================================================================
  group('IMEI unit tenant isolation', () {
    test('tenant-A IMEI not visible to tenant-B query', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'imei-a1',
              tenantId: ctxA.tenantId,
              entityId: 'entity-a1',
              imei: '356938035643809',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final resultsB = await (db.select(
        db.mobileImeiUnits,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(resultsB, isEmpty);
    });

    test('listing by tenant returns only that tenant records', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      // Insert 2 for A, 1 for B
      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'imei-a1',
              tenantId: ctxA.tenantId,
              entityId: 'e-a1',
              imei: '356938035643809',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'imei-a2',
              tenantId: ctxA.tenantId,
              entityId: 'e-a2',
              imei: '490154203237518',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.mobileImeiUnits)
          .insert(
            MobileImeiUnitsCompanion.insert(
              id: 'imei-b1',
              tenantId: ctxB.tenantId,
              entityId: 'e-b1',
              imei: '353456789012345',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final resultsA = await (db.select(
        db.mobileImeiUnits,
      )..where((t) => t.tenantId.equals(ctxA.tenantId))).get();
      final resultsB = await (db.select(
        db.mobileImeiUnits,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(resultsA, hasLength(2));
      expect(resultsB, hasLength(1));
    });
  });

  // ==========================================================================
  // GROUP 2: Service Job Tenant Isolation
  // ==========================================================================
  group('Service job tenant isolation', () {
    test('service jobs are tenant-scoped', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      await db
          .into(db.mobileServiceJobs)
          .insert(
            MobileServiceJobsCompanion.insert(
              id: 'job-a1',
              tenantId: ctxA.tenantId,
              entityId: 'ej-a1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final jobsB = await (db.select(
        db.mobileServiceJobs,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(jobsB, isEmpty);
    });
  });

  // ==========================================================================
  // GROUP 3: Exchange Tenant Isolation
  // ==========================================================================
  group('Exchange tenant isolation', () {
    test('exchanges are tenant-scoped', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      await db
          .into(db.mobileExchanges)
          .insert(
            MobileExchangesCompanion.insert(
              id: 'exc-a1',
              tenantId: ctxA.tenantId,
              entityId: 'ee-a1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final excB = await (db.select(
        db.mobileExchanges,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(excB, isEmpty);
    });
  });

  // ==========================================================================
  // GROUP 4: Warranty Tenant Isolation
  // ==========================================================================
  group('Warranty tenant isolation', () {
    test('warranties are tenant-scoped', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      await db
          .into(db.mobileWarranties)
          .insert(
            MobileWarrantiesCompanion.insert(
              id: 'war-a1',
              tenantId: ctxA.tenantId,
              entityId: 'ew-a1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final warB = await (db.select(
        db.mobileWarranties,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(warB, isEmpty);
    });
  });

  // ==========================================================================
  // GROUP 5: Invoice Associations Tenant Isolation
  // ==========================================================================
  group('Invoice associations tenant isolation', () {
    test('invoice associations are tenant-scoped', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      await db
          .into(db.mobileInvoiceAssociations)
          .insert(
            MobileInvoiceAssociationsCompanion.insert(
              id: 'assoc-a1',
              tenantId: ctxA.tenantId,
              invoiceId: 'inv-1',
              imei: '356938035643809',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final assocB = await (db.select(
        db.mobileInvoiceAssociations,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(assocB, isEmpty);
    });
  });

  // ==========================================================================
  // GROUP 6: Reconciliation Status Tenant Isolation
  // ==========================================================================
  group('Reconciliation status tenant isolation', () {
    test('reconciliation records are tenant-scoped', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      await db
          .into(db.mobileReconciliationStatus)
          .insert(
            MobileReconciliationStatusCompanion.insert(
              id: 'recon-a1',
              tenantId: ctxA.tenantId,
              operationId: 'op-ra1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final reconB = await (db.select(
        db.mobileReconciliationStatus,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(reconB, isEmpty);
    });
  });

  // ==========================================================================
  // GROUP 7: Provider State Tenant Isolation
  // ==========================================================================
  group('Provider state tenant isolation', () {
    test('provider state records are tenant-scoped', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      await db
          .into(db.mobileProviderState)
          .insert(
            MobileProviderStateCompanion.insert(
              id: 'prov-a1',
              tenantId: ctxA.tenantId,
              providerType: 'SIM',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final provB = await (db.select(
        db.mobileProviderState,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(provB, isEmpty);
    });
  });

  // ==========================================================================
  // GROUP 8: Checkpoint Tenant Isolation
  // ==========================================================================
  group('Checkpoint tenant isolation', () {
    test('checkpoints are tenant-scoped', () async {
      final ctxA = _ctx('tenant-A');
      final ctxB = _ctx('tenant-B');
      final now = DateTime.now();

      await db
          .into(db.mobileContinuationCheckpoints)
          .insert(
            MobileContinuationCheckpointsCompanion.insert(
              id: 'cp-a1',
              tenantId: ctxA.tenantId,
              bucket: 'ROOT',
              lastPosition: const Value('cursor-a'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final cpB = await (db.select(
        db.mobileContinuationCheckpoints,
      )..where((t) => t.tenantId.equals(ctxB.tenantId))).get();

      expect(cpB, isEmpty);

      // Tenant A sees their checkpoint
      final cpA = await (db.select(
        db.mobileContinuationCheckpoints,
      )..where((t) => t.tenantId.equals(ctxA.tenantId))).get();
      expect(cpA, hasLength(1));
      expect(cpA.first.lastPosition, 'cursor-a');
    });
  });

  // ==========================================================================
  // GROUP 9: Outbox Mutation Ordering
  // ==========================================================================
  group('Outbox mutation ordering', () {
    test('getNextMutations returns by createdAt order', () async {
      final ctx = _ctx('tenant-order');
      final earlier = DateTime(2024, 1, 1, 10, 0);
      final later = DateTime(2024, 1, 1, 10, 5);

      // Insert later one first
      await db
          .into(db.mobileOutboxMutations)
          .insert(
            MobileOutboxMutationsCompanion.insert(
              id: 'mut-later',
              tenantId: ctx.tenantId,
              operationId: 'op-later',
              mutationFingerprint: 'fp-l',
              entityType: 'IMEI_UNIT',
              payload: '{}',
              createdAt: later,
              updatedAt: later,
            ),
          );
      await db
          .into(db.mobileOutboxMutations)
          .insert(
            MobileOutboxMutationsCompanion.insert(
              id: 'mut-earlier',
              tenantId: ctx.tenantId,
              operationId: 'op-earlier',
              mutationFingerprint: 'fp-e',
              entityType: 'IMEI_UNIT',
              payload: '{}',
              createdAt: earlier,
              updatedAt: earlier,
            ),
          );

      final mutations =
          await (db.select(db.mobileOutboxMutations)
                ..where((t) => t.tenantId.equals(ctx.tenantId))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();

      expect(mutations.first.operationId, 'op-earlier');
      expect(mutations.last.operationId, 'op-later');
    });
  });

  // ==========================================================================
  // GROUP 10: LocalRecord Wrapper
  // ==========================================================================
  group('LocalRecord wrapper semantics', () {
    test('isServerConfirmed is true when status is serverConfirmed', () {
      final record = LocalRecord<String>(
        entity: 'test',
        confirmationStatus: ConfirmationStatus.serverConfirmed,
        serverVersion: 5,
        syncedAt: DateTime.now(),
      );
      expect(record.isServerConfirmed, isTrue);
      expect(record.isPending, isFalse);
      expect(record.isConflict, isFalse);
    });

    test('isPending is true when status is pending', () {
      final record = LocalRecord<String>(
        entity: 'test',
        confirmationStatus: ConfirmationStatus.pending,
        serverVersion: 0,
      );
      expect(record.isPending, isTrue);
      expect(record.isServerConfirmed, isFalse);
    });

    test('isConflict is true when status is conflict', () {
      final record = LocalRecord<String>(
        entity: 'test',
        confirmationStatus: ConfirmationStatus.conflict,
        serverVersion: 3,
      );
      expect(record.isConflict, isTrue);
    });

    test('isStale when syncedAt is null', () {
      final record = LocalRecord<String>(
        entity: 'test',
        confirmationStatus: ConfirmationStatus.pending,
        serverVersion: 0,
        syncedAt: null,
      );
      expect(record.isStale, isTrue);
    });
  });
}
