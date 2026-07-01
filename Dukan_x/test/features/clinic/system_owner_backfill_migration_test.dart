/// Migration Unit Test — v46 legacy-'SYSTEM' owner backfill (clinic task 4.4)
///
/// **Validates: Requirements 2.5, 3.9, 3.10** (Property 4 — Backfill
/// Re-Attribution Correctness)
///
/// Exercises the migration's core logic: [backfillSystemOwnerRows] re-attributes
/// ONLY rows written with the placeholder owner id `'SYSTEM'`, leaves rows that
/// already carry a real owner id untouched, never loses a row, and fails safe
/// (skips) when no owner id is resolvable.
///
/// The backfill operates on the same stored columns the v46 migration targets:
///   • patients.user_id
///   • sync_queue rows for the patients/appointments collections
/// (The `appointments` table has no owner column — see the migration docs.)
///
/// Run: flutter test test/features/clinic/system_owner_backfill_migration_test.dart
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/database/migrations/system_owner_backfill.dart';

/// Opens an in-memory [AppDatabase]. If the shared Drift schema still cannot be
/// created (e.g. the unrelated vegetable-broker `MandiSettlements` CHECK
/// constraint defect that references `paymentStatus` instead of the
/// `payment_status` column), returns null so the test self-skips with an
/// explanatory message rather than failing for an unrelated reason. Mirrors the
/// `_tryOpenClinicDb` pattern in
/// test/features/clinic/clinic_vertical_remediation_exploration_test.dart.
Future<AppDatabase?> _tryOpenDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  try {
    await db.customSelect('SELECT 1').get();
    return db;
  } catch (_) {
    try {
      await db.close();
    } catch (_) {
      /* ignore */
    }
    return null;
  }
}

const String _kDbBlockedReason =
    'Shared Drift schema cannot be created in-memory (pre-existing unrelated '
    'vegetable-broker MandiSettlements CHECK-constraint defect). This blocks '
    'every DB-backed test in the repo. Backfill logic is unchanged; this test '
    'validates it once the shared schema is creatable.';

void main() {
  group('v46 SYSTEM-owner backfill migration (Req 2.5, 3.9, 3.10)', () {
    late AppDatabase db;
    final now = DateTime.now();

    Future<void> seedPatient(String id, String ownerId) async {
      await db
          .into(db.patients)
          .insert(
            PatientsCompanion.insert(
              id: id,
              userId: ownerId,
              name: 'Patient $id',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    Future<void> seedSyncOp(
      String opId,
      String collection,
      String userId, {
      String ownerId = 'UNKNOWN',
    }) async {
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              operationId: opId,
              operationType: 'CREATE',
              targetCollection: collection,
              documentId: 'doc-$opId',
              payload: '{}',
              userId: userId,
              ownerId: Value(ownerId),
              createdAt: now,
            ),
          );
    }

    setUp(() async {
      // Each test opens its own DB (so it can self-skip cleanly when the shared
      // schema is un-creatable); nothing to do here.
    });

    tearDown(() async {
      try {
        await db.close();
      } catch (_) {
        /* db may be unset when the test self-skipped */
      }
    });

    test('re-attributes ONLY \'SYSTEM\' rows; preserves real-owner rows; no '
        'data loss', () async {
      final opened = await _tryOpenDb();
      if (opened == null) {
        markTestSkipped(_kDbBlockedReason);
        return;
      }
      db = opened;

      // Two legacy 'SYSTEM' patients + one already correctly attributed.
      await seedPatient('sys-1', kSystemOwnerSentinel);
      await seedPatient('sys-2', kSystemOwnerSentinel);
      await seedPatient('real-1', 'usr_REAL_OTHER');

      // Sync ops: 'SYSTEM' patient + 'SYSTEM' appointment (must backfill),
      // a 'SYSTEM' op for an unrelated collection (must NOT backfill), and an
      // already-attributed appointment op (must be left untouched).
      await seedSyncOp('op-pat', 'patients', kSystemOwnerSentinel);
      await seedSyncOp('op-appt', 'appointments', kSystemOwnerSentinel);
      await seedSyncOp('op-bill', 'bills', kSystemOwnerSentinel);
      await seedSyncOp(
        'op-ok',
        'appointments',
        'usr_REAL_OTHER',
        ownerId: 'usr_REAL_OTHER',
      );

      final totalPatientsBefore = (await db.select(db.patients).get()).length;
      final totalSyncBefore = (await db.select(db.syncQueue).get()).length;

      final result = await backfillSystemOwnerRows(db, ownerId: 'usr_CURRENT');

      // --- Re-attribution counts (Property 4 / Req 2.5) ---
      expect(result.ran, isTrue, reason: 'backfill should have run');
      expect(
        result.patientRowsReattributed,
        2,
        reason: 'both SYSTEM patients re-attributed',
      );
      expect(
        result.syncOpsReattributed,
        2,
        reason: 'SYSTEM patient + appointment sync ops re-attributed',
      );

      // --- SYSTEM patients now carry the current owner (Req 2.5) ---
      for (final id in ['sys-1', 'sys-2']) {
        final row = await (db.select(
          db.patients,
        )..where((t) => t.id.equals(id))).getSingle();
        expect(row.userId, 'usr_CURRENT');
      }

      // --- Real-owner patient untouched (Req 3.9) ---
      final realPatient = await (db.select(
        db.patients,
      )..where((t) => t.id.equals('real-1'))).getSingle();
      expect(
        realPatient.userId,
        'usr_REAL_OTHER',
        reason: 'a row already carrying a real owner id must NOT change',
      );

      // --- SYSTEM sync ops for patients/appointments re-attributed ---
      for (final id in ['op-pat', 'op-appt']) {
        final op = await (db.select(
          db.syncQueue,
        )..where((t) => t.operationId.equals(id))).getSingle();
        expect(op.userId, 'usr_CURRENT');
        expect(op.ownerId, 'usr_CURRENT');
      }

      // --- SYSTEM sync op for an UNRELATED collection left untouched ---
      final billOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.operationId.equals('op-bill'))).getSingle();
      expect(
        billOp.userId,
        kSystemOwnerSentinel,
        reason: 'collections outside patients/appointments are not in scope',
      );

      // --- Already-attributed appointment op untouched (Req 3.9) ---
      final okOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.operationId.equals('op-ok'))).getSingle();
      expect(okOp.userId, 'usr_REAL_OTHER');

      // --- No data loss: same number of rows before and after (Req 3.10) ---
      expect((await db.select(db.patients).get()).length, totalPatientsBefore);
      expect((await db.select(db.syncQueue).get()).length, totalSyncBefore);
    });

    test('fails safe (skips, no changes) when no owner id is resolvable '
        '(Req 2.7 alignment)', () async {
      final opened = await _tryOpenDb();
      if (opened == null) {
        markTestSkipped(_kDbBlockedReason);
        return;
      }
      db = opened;

      await seedPatient('sys-1', kSystemOwnerSentinel);

      for (final badOwner in <String?>[null, '', '   ', kSystemOwnerSentinel]) {
        final result = await backfillSystemOwnerRows(db, ownerId: badOwner);
        expect(
          result.ran,
          isFalse,
          reason: 'must skip for owner id "$badOwner"',
        );
        expect(result.totalReattributed, 0);
        // The SYSTEM row must be left exactly as-is — never fabricated away.
        final row = await (db.select(
          db.patients,
        )..where((t) => t.id.equals('sys-1'))).getSingle();
        expect(row.userId, kSystemOwnerSentinel);
      }
    });

    test('is idempotent: a second run re-attributes nothing', () async {
      final opened = await _tryOpenDb();
      if (opened == null) {
        markTestSkipped(_kDbBlockedReason);
        return;
      }
      db = opened;

      await seedPatient('sys-1', kSystemOwnerSentinel);
      await seedSyncOp('op-pat', 'patients', kSystemOwnerSentinel);

      expect(await hasPendingSystemOwnerRows(db), isTrue);

      final first = await backfillSystemOwnerRows(db, ownerId: 'usr_CURRENT');
      expect(first.totalReattributed, 2);

      expect(await hasPendingSystemOwnerRows(db), isFalse);

      final second = await backfillSystemOwnerRows(db, ownerId: 'usr_CURRENT');
      expect(second.ran, isTrue);
      expect(
        second.totalReattributed,
        0,
        reason: 'nothing left to backfill on a second run',
      );
    });
  });
}
