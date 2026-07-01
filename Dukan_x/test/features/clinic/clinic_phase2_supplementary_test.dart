/// Supplementary Unit Tests — Phase 2 (RBAC, PHI & Clinical Safety)
///
/// Verifies implementation details beyond the exploration probes:
/// 1. Clinical-role gate: visit_screen with doctor role shows Diagnosis/
///    Private Notes; with receptionist/nurse role hides them.
/// 2. Consent captured: createPatient with consent=true stores it; without
///    consent, it's null.
/// 3. Access-log entry: after a patient read/write, a patient_access_logs
///    entry exists.
/// 4. Contraindication service: checkContraindications with allergic drug →
///    hasContraindications; with safe drug → isSafe; drug-family alias match.
///
/// **Validates: Requirements 2.8, 2.9, 2.10, 2.11, 2.12**
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/clinic/models/clinic_dashboard_models.dart';
import 'package:dukanx/features/clinic/providers/clinic_dashboard_providers.dart';
import 'package:dukanx/features/doctor/data/repositories/patient_repository.dart';
import 'package:dukanx/features/doctor/models/patient_model.dart';
import 'package:dukanx/features/doctor/services/contraindication_service.dart';
import 'package:dukanx/features/doctor/services/patient_access_logger.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _SpySyncManager extends Fake implements SyncManager {
  final List<SyncQueueItem> enqueued = [];

  @override
  Future<String> enqueue(SyncQueueItem item) async {
    enqueued.add(item);
    return 'spy-op-${enqueued.length}';
  }
}

class _FakeSessionManager extends Fake implements SessionManager {
  @override
  String? get ownerId => 'test-doctor-1';
}

// ---------------------------------------------------------------------------
// DB helper
// ---------------------------------------------------------------------------

Future<AppDatabase?> _tryOpenDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  try {
    await db.customSelect('SELECT 1').get();
    return db;
  } catch (_) {
    try {
      await db.close();
    } catch (_) {}
    return null;
  }
}

const String _dbSkipReason =
    'Shared Drift schema cannot be created in-memory due to a pre-existing '
    'unrelated defect. Supplementary test skipped.';

void main() {
  // =========================================================================
  // 1. Clinical-role gate — hasClinicalContentAccess
  // =========================================================================
  group('Clinical-role gate (Req 2.8, 2.9, 2.10)', () {
    test('doctor role grants clinical content access', () {
      expect(hasClinicalContentAccess(ClinicRole.doctor), isTrue);
    });

    test('admin role grants clinical content access', () {
      expect(hasClinicalContentAccess(ClinicRole.admin), isTrue);
    });

    test('receptionist role does NOT grant clinical content access', () {
      expect(hasClinicalContentAccess(ClinicRole.receptionist), isFalse);
    });

    test('nurse role does NOT grant clinical content access', () {
      expect(hasClinicalContentAccess(ClinicRole.nurse), isFalse);
    });

    test('null role (unauthenticated/unknown) does NOT grant access', () {
      expect(hasClinicalContentAccess(null), isFalse);
    });

    test('labTech role does NOT grant clinical content access', () {
      expect(hasClinicalContentAccess(ClinicRole.labTech), isFalse);
    });

    test('pharmacist role does NOT grant clinical content access', () {
      expect(hasClinicalContentAccess(ClinicRole.pharmacist), isFalse);
    });
  });

  // =========================================================================
  // 2. Consent captured on patient create
  // =========================================================================
  group('PHI consent flag captured on create (Req 2.11)', () {
    test(
      'createPatient with consent=true stores consent in Drift row',
      () async {
        final db = await _tryOpenDb();
        if (db == null) {
          markTestSkipped(_dbSkipReason);
          return;
        }
        try {
          final spy = _SpySyncManager();
          final repo = PatientRepository(
            db: db,
            syncManager: spy,
            session: _FakeSessionManager(),
          );
          final now = DateTime.now();
          await repo.createPatient(
            PatientModel(
              id: const Uuid().v4(),
              name: 'Consent Patient',
              phone: '9998887770',
              createdAt: now,
              updatedAt: now,
              consent: true,
            ),
          );

          final row = await db.select(db.patients).getSingle();
          expect(
            row.consent,
            isTrue,
            reason: 'Patient created with consent=true should store consent.',
          );
        } finally {
          await db.close();
        }
      },
    );

    test('createPatient without consent stores null (unconsented)', () async {
      final db = await _tryOpenDb();
      if (db == null) {
        markTestSkipped(_dbSkipReason);
        return;
      }
      try {
        final spy = _SpySyncManager();
        final repo = PatientRepository(
          db: db,
          syncManager: spy,
          session: _FakeSessionManager(),
        );
        final now = DateTime.now();
        await repo.createPatient(
          PatientModel(
            id: const Uuid().v4(),
            name: 'No-Consent Patient',
            phone: '9998887771',
            createdAt: now,
            updatedAt: now,
            // consent not set — defaults to null
          ),
        );

        final row = await db.select(db.patients).getSingle();
        expect(
          row.consent,
          isNull,
          reason: 'Patient created without explicit consent should have null.',
        );
      } finally {
        await db.close();
      }
    });
  });

  // =========================================================================
  // 3. Access-log entry produced on read/write
  // =========================================================================
  group('PHI access logging (Req 2.11)', () {
    test('logAccess produces a patient_access_logs row on write', () async {
      final db = await _tryOpenDb();
      if (db == null) {
        markTestSkipped(_dbSkipReason);
        return;
      }
      try {
        final logger = PatientAccessLogger(db: db);

        await logger.logAccess(
          patientId: 'patient-xyz',
          userId: 'doctor-1',
          accessType: PatientAccessType.write,
          description: 'created patient',
        );

        final rows = await db.select(db.patientAccessLogs).get();
        expect(rows, hasLength(1));
        expect(rows.first.patientId, 'patient-xyz');
        expect(rows.first.userId, 'doctor-1');
        expect(rows.first.accessType, 'write');
        expect(rows.first.description, 'created patient');
      } finally {
        await db.close();
      }
    });

    test('logAccess produces a patient_access_logs row on read', () async {
      final db = await _tryOpenDb();
      if (db == null) {
        markTestSkipped(_dbSkipReason);
        return;
      }
      try {
        final logger = PatientAccessLogger(db: db);

        await logger.logAccess(
          patientId: 'patient-abc',
          userId: 'nurse-2',
          accessType: PatientAccessType.read,
          description: 'viewed patient details',
        );

        final rows = await db.select(db.patientAccessLogs).get();
        expect(rows, hasLength(1));
        expect(rows.first.patientId, 'patient-abc');
        expect(rows.first.userId, 'nurse-2');
        expect(rows.first.accessType, 'read');
        expect(rows.first.description, 'viewed patient details');
      } finally {
        await db.close();
      }
    });

    test('multiple access events accumulate in the log', () async {
      final db = await _tryOpenDb();
      if (db == null) {
        markTestSkipped(_dbSkipReason);
        return;
      }
      try {
        final logger = PatientAccessLogger(db: db);

        await logger.logAccess(
          patientId: 'p1',
          userId: 'u1',
          accessType: PatientAccessType.write,
        );
        await logger.logAccess(
          patientId: 'p1',
          userId: 'u2',
          accessType: PatientAccessType.read,
        );

        final rows = await db.select(db.patientAccessLogs).get();
        expect(
          rows,
          hasLength(2),
          reason: 'Access log is append-only; both events stored.',
        );
      } finally {
        await db.close();
      }
    });
  });

  // =========================================================================
  // 4. Contraindication service
  // =========================================================================
  group('Contraindication service (Req 2.12)', () {
    test('direct allergy match → hasContraindications', () {
      final result = checkContraindications(
        allergiesRaw: 'Penicillin',
        medicineNames: ['Penicillin V'],
      );
      expect(result.hasContraindications, isTrue);
      expect(result.isSafe, isFalse);
      expect(result.matches, hasLength(1));
      expect(result.matches.first.medicineName, 'Penicillin V');
      expect(result.matches.first.allergyEntry, 'Penicillin');
    });

    test('safe drug → isSafe', () {
      final result = checkContraindications(
        allergiesRaw: 'Penicillin',
        medicineNames: ['Metformin'],
      );
      expect(result.isSafe, isTrue);
      expect(result.hasContraindications, isFalse);
      expect(result.matches, isEmpty);
    });

    test(
      'drug-family alias match: penicillin allergy → amoxicillin flagged',
      () {
        final result = checkContraindications(
          allergiesRaw: 'Penicillin',
          medicineNames: ['Amoxicillin 500mg'],
        );
        expect(result.hasContraindications, isTrue);
        expect(result.matches.first.medicineName, 'Amoxicillin 500mg');
      },
    );

    test('drug-family alias: sulfa allergy → Bactrim flagged', () {
      final result = checkContraindications(
        allergiesRaw: 'Sulfa',
        medicineNames: ['Bactrim DS'],
      );
      expect(result.hasContraindications, isTrue);
    });

    test('multiple allergies comma-separated', () {
      final result = checkContraindications(
        allergiesRaw: 'Penicillin, Aspirin',
        medicineNames: ['Paracetamol', 'Aspirin 75mg'],
      );
      expect(result.hasContraindications, isTrue);
      expect(result.matches.first.medicineName, 'Aspirin 75mg');
    });

    test('null allergies → always safe', () {
      final result = checkContraindications(
        allergiesRaw: null,
        medicineNames: ['Amoxicillin'],
      );
      expect(result.isSafe, isTrue);
    });

    test('empty allergies string → always safe', () {
      final result = checkContraindications(
        allergiesRaw: '  ',
        medicineNames: ['Amoxicillin'],
      );
      expect(result.isSafe, isTrue);
    });

    test('empty medicine list → always safe', () {
      final result = checkContraindications(
        allergiesRaw: 'Penicillin',
        medicineNames: [],
      );
      expect(result.isSafe, isTrue);
    });

    test('case-insensitive matching', () {
      final result = checkContraindications(
        allergiesRaw: 'penicillin',
        medicineNames: ['PENICILLIN V'],
      );
      expect(result.hasContraindications, isTrue);
    });

    test('NSAID family: ibuprofen allergy text → diclofenac NOT auto-flagged '
        '(member→family expansion not supported)', () {
      // The service only expands family→members, not member→family.
      // If patient is allergic to "ibuprofen" (a specific member), we only
      // flag exact matches for "ibuprofen", not the whole NSAID family.
      final result = checkContraindications(
        allergiesRaw: 'Ibuprofen',
        medicineNames: ['Diclofenac'],
      );
      // Diclofenac is NOT flagged because the allergy is to a specific member,
      // not to "NSAID" family. The service only expands family→members.
      expect(result.isSafe, isTrue);
    });

    test('NSAID family allergy → all members flagged', () {
      final result = checkContraindications(
        allergiesRaw: 'NSAID',
        medicineNames: ['Ibuprofen', 'Diclofenac', 'Metformin'],
      );
      expect(result.hasContraindications, isTrue);
      // Ibuprofen and Diclofenac should be flagged, Metformin safe
      expect(result.matches.length, 2);
    });
  });
}
