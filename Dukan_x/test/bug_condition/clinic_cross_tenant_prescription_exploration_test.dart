// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: prescriptions.crossTenantQuery (Requirement 1.1)
//
// PrescriptionRepository.getRecentPrescriptions(doctorId) ignores its
// `doctorId` argument entirely and returns the 50 most recent prescriptions
// across ALL doctors/tenants in the shared database. This test seeds rows for
// two distinct userId values ('doc_A' and 'doc_B') and asserts that calling
// getRecentPrescriptions('doc_A') returns ONLY 'doc_A' rows. On unfixed code
// this assertion FAILS because 'doc_B' rows leak through.
//
// **Validates: Requirements 1.1**
//
// COUNTEREXAMPLE (documented after first run):
// getRecentPrescriptions('doc_A') returned 6 rows total — 3 rows where
// userId == 'doc_A' AND 3 rows where userId == 'doc_B'. The query does not
// filter by the provided doctorId at all; it returns the 50 most recent
// prescriptions across every tenant.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/doctor/data/repositories/prescription_repository.dart';
import 'package:dukanx/features/doctor/models/prescription_model.dart';

/// Fake SyncManager — enqueue is a no-op for this exploration test.
class _FakeSyncManager extends Fake implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem item) async => 'fake-op';
}

/// Fake SessionManager that returns a fixed ownerId for seeding.
/// Used only to call createPrescription through the repository's normal path.
class _FakeSessionManager {
  final String ownerId;
  _FakeSessionManager(this.ownerId);
}

void main() {
  group('Bug Condition 1.1 — prescriptions.crossTenantQuery', () {
    late AppDatabase db;
    late PrescriptionRepository repo;
    late _FakeSyncManager fakeSyncManager;

    const uuid = Uuid();
    const docA = 'doc_A';
    const docB = 'doc_B';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      fakeSyncManager = _FakeSyncManager();
      repo = PrescriptionRepository(db: db, syncManager: fakeSyncManager);

      // Seed 3 prescriptions for doc_A
      for (int i = 0; i < 3; i++) {
        final id = uuid.v4();
        final now = DateTime.now().subtract(Duration(minutes: i));
        await db
            .into(db.prescriptions)
            .insert(
              PrescriptionsCompanion.insert(
                id: id,
                userId: docA,
                visitId: 'visit_a_$i',
                patientId: 'patient_a_$i',
                doctorId: Value(docA),
                date: now,
                medicinesJson: jsonEncode([
                  {'name': 'Med_A_$i', 'dosage': '1-0-1'},
                ]),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      // Seed 3 prescriptions for doc_B
      for (int i = 0; i < 3; i++) {
        final id = uuid.v4();
        final now = DateTime.now().subtract(Duration(minutes: i + 10));
        await db
            .into(db.prescriptions)
            .insert(
              PrescriptionsCompanion.insert(
                id: id,
                userId: docB,
                visitId: 'visit_b_$i',
                patientId: 'patient_b_$i',
                doctorId: Value(docB),
                date: now,
                medicinesJson: jsonEncode([
                  {'name': 'Med_B_$i', 'dosage': '0-1-0'},
                ]),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // Core assertion: getRecentPrescriptions('doc_A') must return ONLY doc_A
    // rows. On unfixed code this FAILS — doc_B rows leak through because the
    // query has no WHERE clause filtering by userId/doctorId.
    // =========================================================================
    test(
      'getRecentPrescriptions(doc_A) returns only doc_A prescriptions',
      () async {
        final results = await repo.getRecentPrescriptions(docA);

        // Verify we actually got results (sanity check)
        expect(
          results.isNotEmpty,
          isTrue,
          reason: 'Expected at least one prescription in the database',
        );

        // The critical assertion: every returned row must belong to doc_A.
        // On UNFIXED code this FAILS because the query returns all 6 rows
        // (3 for doc_A + 3 for doc_B) without filtering.
        for (final prescription in results) {
          expect(
            prescription.doctorId,
            equals(docA),
            reason:
                'COUNTEREXAMPLE: getRecentPrescriptions("$docA") returned a '
                'prescription with doctorId="${prescription.doctorId}" '
                '(id=${prescription.id}, patientId=${prescription.patientId}). '
                'The query ignores its doctorId argument and returns rows '
                'from ALL tenants.',
          );
        }

        // Additional: verify no doc_B rows leaked through
        final docBRows = results.where((p) => p.doctorId == docB).toList();
        expect(
          docBRows,
          isEmpty,
          reason:
              'COUNTEREXAMPLE: getRecentPrescriptions("$docA") returned '
              '${docBRows.length} row(s) belonging to "$docB". '
              'Cross-tenant data leak confirmed — the query does not filter '
              'by the provided doctorId at all.',
        );
      },
    );

    // =========================================================================
    // Additional: verify the total row count to confirm cross-tenant leak
    // =========================================================================
    test(
      'getRecentPrescriptions(doc_A) returns exactly 3 rows (not 6)',
      () async {
        final results = await repo.getRecentPrescriptions(docA);

        // On FIXED code: exactly 3 (only doc_A's prescriptions)
        // On UNFIXED code: 6 (all prescriptions from both tenants)
        expect(
          results.length,
          equals(3),
          reason:
              'COUNTEREXAMPLE: getRecentPrescriptions("$docA") returned '
              '${results.length} rows instead of 3. Expected only doc_A\'s '
              'prescriptions, but got rows from all tenants because the query '
              'has no WHERE clause filtering by userId/doctorId.',
        );
      },
    );
  });
}
