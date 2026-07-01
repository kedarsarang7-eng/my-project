/// Bug Condition Exploration Test — Clinic (Doctor/OPD) Vertical Remediation
///
/// **Validates: Requirements 1.2, 1.3, 1.4, 1.7, 1.10, 1.12, 1.15, 1.21, 1.26,
/// 1.28 → 2.2, 2.3, 2.4, 2.6, 2.7, 2.10, 2.12, 2.15, 2.21, 2.26, 2.28**
///
/// Property 1: Bug Condition — Clinic Vertical Defect Family
///
/// Each test below drives a defective clinic code path and asserts the intended
/// Section 2 (post-fix) behaviour from `bugfix.md` / the design's
/// `expectedBehavior(result)`.
///
/// **CRITICAL**: On UNFIXED code these assertions FAIL — failure CONFIRMS the
/// defect exists. DO NOT fix the test or the code when it fails. Failure here is
/// the GOAL of the exploration phase. After each phase fix, these SAME tests are
/// re-run (tasks 4.5 / 5.7 / 6.5 / 7.3 / 8.3) and are expected to PASS.
///
/// Two kinds of probes are used (matching the repo convention in
/// test/bug_condition/hardware_vertical_remediation_exploration_test.dart):
///   • Behavioural — drive the live repository / resolver / widget and assert
///     the output (cross-tenant counts, 'SYSTEM' attribution, patient_history
///     resolution, dashboard literals).
///   • Real-source probes — read the SHIPPING source (not a mirror) and assert
///     the fix is present. Used for screen-only / private-method defects that
///     cannot be exercised headless without the fix existing (fail-unsafe
///     fallback, clinical role gate, contraindication check, silent
///     medicine-quantity default, vitals range validation). These confirm the
///     defect against the actual code on disk.
///
/// PBT library: dartproptest ^0.2.1 — used for the sidebar-id domain
/// (navigation resolution), which has a natural generated input space.
///
/// Run: flutter test test/features/clinic/clinic_vertical_remediation_exploration_test.dart
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/doctor/data/repositories/patient_repository.dart';
import 'package:dukanx/features/doctor/data/repositories/appointment_repository.dart';
import 'package:dukanx/features/doctor/data/repositories/doctor_dashboard_repository.dart';
import 'package:dukanx/features/doctor/models/patient_model.dart';
import 'package:dukanx/features/doctor/models/appointment_model.dart';
import 'package:dukanx/features/doctor/presentation/screens/patient_list_screen.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Spy SyncManager that records every enqueued op so attribution (userId) can
/// be inspected.
class _SpySyncManager extends Fake implements SyncManager {
  final List<SyncQueueItem> enqueued = [];

  @override
  Future<String> enqueue(SyncQueueItem item) async {
    enqueued.add(item);
    return 'spy-op-${enqueued.length}';
  }
}

/// Fake SessionManager supplying a known, non-null owner id so the repositories'
/// shared [resolveOwnerId] fail-safe resolves a real tenant id under the
/// headless test harness (no GetIt registration). The behavioural BC2 probes
/// then assert the written/enqueued userId equals this real owner id — never
/// 'SYSTEM'. This only supplies the missing dependency; it does NOT weaken any
/// assertion.
class _FakeSessionManager extends Fake implements SessionManager {
  @override
  String? get ownerId => 'usr_A';
}

/// Fixed business-type notifier so the dashboard widget renders the clinic
/// branch without the license/bootstrap pipeline (same shape as the hardware
/// exploration test).
class _FixedBusinessTypeNotifier extends BusinessTypeNotifier {
  _FixedBusinessTypeNotifier(this._type);
  final BusinessType _type;
  @override
  BusinessTypeState build() => BusinessTypeState(type: _type);
}

// ---------------------------------------------------------------------------
// Real-source helpers (cwd == package root when `flutter test` runs)
// ---------------------------------------------------------------------------

/// Reads a shipping source file. Returns '' if missing so the assertion — not
/// an exception — reports the defect.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// Extracts the body of [methodSignature] up to (but not including) [nextMarker]
/// so a source probe can be scoped to a single method.
String _methodBody(String src, String methodSignature, String nextMarker) {
  final start = src.indexOf(methodSignature);
  if (start < 0) return '';
  final end = src.indexOf(nextMarker, start + methodSignature.length);
  return end < 0 ? src.substring(start) : src.substring(start, end);
}

/// Attempts to open an in-memory [AppDatabase] and force the schema migration.
///
/// The shared Drift schema is currently un-creatable in a fresh in-memory DB
/// because an unrelated, in-progress vegetable-broker table (`MandiSettlements`)
/// ships a malformed `CHECK (paymentStatus IN (...))` constraint that references
/// the Dart field name instead of the `payment_status` column. That makes
/// `createAll` throw for EVERY DB-backed test in the repo (the existing doctor
/// repo tests fail identically). When that happens this returns `null` so the
/// behavioural DB probes self-skip instead of failing for an unrelated reason —
/// they still validate the clinic fix once the shared schema is repaired.
Future<AppDatabase?> _tryOpenClinicDb() async {
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
    'Shared Drift schema cannot be created in-memory due to a pre-existing, '
    'unrelated vegetable-broker defect (MandiSettlements CHECK constraint '
    'references `paymentStatus` instead of the `payment_status` column). This '
    'blocks every DB-backed test in the repo. The clinic defect is confirmed by '
    'the companion real-source probe; this behavioural probe will validate the '
    'fix once the shared schema is repaired.';

void main() {
  // =========================================================================
  // BUG CONDITION 1 — Cross-tenant patient-count leak (1.2 → 2.2 / Property 1)
  // getPatientStats() runs `_db.select(_db.patients).get()` with NO owner
  // filter, so one clinic's "Total Patients" includes other owners' rows.
  // Expected (post-fix): counts are filtered to the authenticated owner.
  // =========================================================================
  group('Bug Condition 1 — getPatientStats is tenant-scoped (Req 2.2)', () {
    // ---- Real-source probe (deterministic; independent of the shared-schema
    // blocker). getPatientStats must filter the patients query by the owner id
    // passed in. On unfixed code the total is computed from an UNFILTERED
    // `_db.select(_db.patients).get()` ("all patients for now"), so this FAILS.
    test('COUNTEREXAMPLE (1.2): getPatientStats must filter the patients query by '
        'owner id', () {
      final src = _readSource(
        'lib/features/doctor/data/repositories/doctor_dashboard_repository.dart',
      );
      expect(
        src.isNotEmpty,
        isTrue,
        reason: 'doctor_dashboard_repository.dart must exist.',
      );

      final body = _methodBody(
        src,
        'Future<Map<String, int>> getPatientStats(',
        'Stream<List<AppointmentEntity>> watchDailyAppointments',
      );

      // The unfiltered total query is the defect signature.
      final unfilteredTotal = RegExp(r'_db\.select\(_db\.patients\)\.get\(\)');
      // A fix introduces an owner/tenant filter on the patients selection.
      final ownerFilter = RegExp(
        r'\.\.where\([^)]*patients?[^)]*\)|userId\.equals|user_id\s*=\s*\?|'
        r'\.\.where\([^)]*userId',
        caseSensitive: false,
      );

      expect(
        unfilteredTotal.hasMatch(body) && !ownerFilter.hasMatch(body),
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.2): getPatientStats computes the total from an '
            'UNFILTERED `_db.select(_db.patients).get()` with no owner/tenant '
            'predicate ("all patients for now") — so one clinic\'s total '
            'leaks every other owner\'s patient rows.',
      );
    });

    // ---- Behavioural DB probe (self-skips while the shared Drift schema is
    // un-creatable in-memory due to the unrelated MandiSettlements CHECK
    // defect). Validates the fix once that schema is repaired.
    test(
      'COUNTEREXAMPLE (1.2): total count must reflect ONLY the queried owner '
      '(behavioural)',
      () async {
        final db = await _tryOpenClinicDb();
        if (db == null) {
          markTestSkipped(_kDbBlockedReason);
          return;
        }
        try {
          final dashboardRepo = DoctorDashboardRepository(db);

          Future<void> seedPatient(String ownerId, String id) async {
            final now = DateTime.now();
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

          // Two tenants share one local DB: owner A has 1 patient, owner B 2.
          await seedPatient('usr_A', 'A1');
          await seedPatient('usr_B', 'B1');
          await seedPatient('usr_B', 'B2');

          final stats = await dashboardRepo.getPatientStats('usr_A');

          expect(
            stats['total'],
            1,
            reason:
                'COUNTEREXAMPLE (1.2): getPatientStats("usr_A") returned '
                '${stats['total']} instead of 1 — the unfiltered '
                '`_db.select(_db.patients).get()` leaks owner B\'s 2 patients '
                'into owner A\'s dashboard total.',
          );
        } finally {
          await db.close();
        }
      },
    );
  });

  // =========================================================================
  // BUG CONDITION 2 — Literal 'SYSTEM' attribution on write (1.3/1.4 → 2.3/2.4/
  // 2.6 / Property 2). PatientRepository/AppointmentRepository write/enqueue
  // userId: 'SYSTEM' instead of the real session owner id.
  // Expected (post-fix): the Drift row + the enqueued sync op carry the real
  // owner id, never 'SYSTEM'.
  // =========================================================================
  group('Bug Condition 2 — writes carry a real owner id, not \'SYSTEM\' '
      '(Req 2.3/2.4/2.6)', () {
    // ---- Real-source probes (deterministic). PatientRepository.createPatient
    // writes the patients row AND enqueues the sync op with the literal
    // userId: 'SYSTEM'; AppointmentRepository.createAppointment enqueues with
    // 'SYSTEM' too. On unfixed code these FAIL.
    final systemLiteral = RegExp(r"userId:\s*\n?\s*'SYSTEM'");

    test(
      'COUNTEREXAMPLE (1.3): patient create must not attribute the row/sync to '
      '\'SYSTEM\'',
      () {
        final src = _readSource(
          'lib/features/doctor/data/repositories/patient_repository.dart',
        );
        expect(
          src.isNotEmpty,
          isTrue,
          reason: 'patient_repository.dart must exist.',
        );

        final body = _methodBody(
          src,
          'Future<void> createPatient(',
          'Future<void> updatePatient(',
        );
        expect(
          systemLiteral.hasMatch(body),
          isFalse,
          reason:
              'COUNTEREXAMPLE (1.3): PatientRepository.createPatient writes the '
              'patients row and enqueues the sync op with the literal '
              'userId: \'SYSTEM\' — the patient is not attributable to any real '
              'clinic/owner.',
        );
      },
    );

    test(
      'COUNTEREXAMPLE (1.4): appointment create must not attribute the sync op '
      'to \'SYSTEM\'',
      () {
        final src = _readSource(
          'lib/features/doctor/data/repositories/appointment_repository.dart',
        );
        expect(
          src.isNotEmpty,
          isTrue,
          reason: 'appointment_repository.dart must exist.',
        );

        final body = _methodBody(
          src,
          'Future<void> createAppointment(',
          'Future<void> updateAppointment(',
        );
        expect(
          systemLiteral.hasMatch(body),
          isFalse,
          reason:
              'COUNTEREXAMPLE (1.4): AppointmentRepository.createAppointment '
              'enqueues the sync op with the literal userId: \'SYSTEM\' — the '
              'appointment payload is not attributable to the real clinic/owner.',
        );
      },
    );

    // ---- Behavioural DB probes (self-skip while the shared Drift schema is
    // blocked by the unrelated MandiSettlements CHECK defect).
    test(
      'COUNTEREXAMPLE (1.3): patient Drift row + sync op must not be \'SYSTEM\' '
      '(behavioural)',
      () async {
        final db = await _tryOpenClinicDb();
        if (db == null) {
          markTestSkipped(_kDbBlockedReason);
          return;
        }
        try {
          final spy = _SpySyncManager();
          final patientRepo = PatientRepository(
            db: db,
            syncManager: spy,
            session: _FakeSessionManager(),
          );
          final now = DateTime.now();
          await patientRepo.createPatient(
            PatientModel(
              id: const Uuid().v4(),
              name: 'Asha Rao',
              phone: '9990001111',
              createdAt: now,
              updatedAt: now,
            ),
          );

          final row = await db.select(db.patients).getSingle();
          final syncOp = spy.enqueued.single;

          expect(
            row.userId,
            isNot('SYSTEM'),
            reason:
                'COUNTEREXAMPLE (1.3): PatientRepository wrote the patients '
                'row with userId == "SYSTEM".',
          );
          expect(
            syncOp.userId,
            isNot('SYSTEM'),
            reason:
                'COUNTEREXAMPLE (1.3): the enqueued patient sync op carries '
                'userId == "SYSTEM" instead of the real session owner id.',
          );
        } finally {
          await db.close();
        }
      },
    );

    test('COUNTEREXAMPLE (1.4): appointment sync op must not be \'SYSTEM\' '
        '(behavioural)', () async {
      final db = await _tryOpenClinicDb();
      if (db == null) {
        markTestSkipped(_kDbBlockedReason);
        return;
      }
      try {
        final spy = _SpySyncManager();
        final appointmentRepo = AppointmentRepository(
          db: db,
          syncManager: spy,
          session: _FakeSessionManager(),
        );
        final now = DateTime.now();
        await appointmentRepo.createAppointment(
          AppointmentModel(
            id: const Uuid().v4(),
            doctorId: 'doctor-1',
            patientId: 'patient-1',
            scheduledTime: now.add(const Duration(hours: 1)),
            status: AppointmentStatus.scheduled,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final syncOp = spy.enqueued.single;
        expect(
          syncOp.userId,
          isNot('SYSTEM'),
          reason:
              'COUNTEREXAMPLE (1.4): AppointmentRepository enqueued the '
              'sync op with userId == "SYSTEM".',
        );
      } finally {
        await db.close();
      }
    });
  });

  // =========================================================================
  // BUG CONDITION 3 — Fail-unsafe `ownerId ?? 'SYSTEM'` fallback (1.7 → 2.7 /
  // Property 3). Clinic screens silently bucket a null-owner session under
  // 'SYSTEM' instead of failing safe (block/surface an error).
  // Expected (post-fix): the `?? 'SYSTEM'` fallback is gone from clinic paths.
  // Real-source probe over every shipping file that carries the fallback.
  // =========================================================================
  group('Bug Condition 3 — null-owner sessions fail safe, not bucket to '
      '\'SYSTEM\' (Req 2.7)', () {
    const clinicFallbackFiles = <String>[
      'lib/features/doctor/presentation/screens/doctor_dashboard_screen.dart',
      'lib/features/doctor/presentation/screens/visit_screen.dart',
      'lib/features/doctor/presentation/screens/doctor_revenue_screen.dart',
      'lib/features/doctor/presentation/screens/prescriptions_list_screen.dart',
      'lib/features/doctor/presentation/screens/add_prescription_screen.dart',
    ];

    final fallback = RegExp(r"\?\?\s*'SYSTEM'", caseSensitive: false);

    for (final path in clinicFallbackFiles) {
      test('COUNTEREXAMPLE (1.7): $path must not silently fall back to '
          '\'SYSTEM\'', () {
        final src = _readSource(path);
        expect(
          src.isNotEmpty,
          isTrue,
          reason: 'Expected $path to exist for the fail-safe probe.',
        );
        expect(
          fallback.hasMatch(src),
          isFalse,
          reason:
              'COUNTEREXAMPLE (1.7): $path resolves the owner id with '
              '`ownerId ?? \'SYSTEM\'`. A null-owner session is silently '
              'bucketed under "SYSTEM" instead of failing safe (block / surface '
              'an error).',
        );
      });
    }
  });

  // =========================================================================
  // BUG CONDITION 5 — Unenforced doctor-only clinical content (1.10 → 2.10 /
  // Property 5). visit_screen renders Diagnosis and "Private Notes" with NO
  // clinical role check, so any role sees doctor-only content.
  // Expected (post-fix): the clinical content is gated by a role check.
  // Real-source probe: visit_screen.dart must reference a clinical role gate.
  // =========================================================================
  group('Bug Condition 5 — visit_screen gates diagnosis/private notes by role '
      '(Req 2.10)', () {
    test(
      'COUNTEREXAMPLE (1.10): visit_screen.dart enforces a clinical role check',
      () {
        final src = _readSource(
          'lib/features/doctor/presentation/screens/visit_screen.dart',
        );
        expect(src.isNotEmpty, isTrue, reason: 'visit_screen.dart must exist.');

        // Sanity: the screen DOES render the doctor-only content today.
        expect(
          src.contains('Private Notes') && src.contains('Diagnosis'),
          isTrue,
          reason:
              'Precondition: visit_screen is expected to render Diagnosis and '
              'Private Notes sections.',
        );

        final roleGate = RegExp(
          r'ClinicRole|RolePermissions|RoleGuard|Permission\.|hasPermission|'
          r'effectiveRole',
        );
        expect(
          roleGate.hasMatch(src),
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.10): visit_screen.dart references no clinical '
              'role gate (ClinicRole / RolePermissions / RoleGuard / '
              'Permission). Diagnosis and "Private Notes (only visible to '
              'doctor)" render for every role with no enforcement.',
        );
      },
    );
  });

  // =========================================================================
  // BUG CONDITION 7 — No allergy↔prescription contraindication check (1.12 →
  // 2.12 / Property 7). A drug the patient is recorded as allergic to is saved
  // with no warning; allergies are a passive banner only.
  // Expected (post-fix): the Rx-save path cross-references patient.allergies and
  // warns/blocks. Real-source probe over the Rx-save path.
  // =========================================================================
  group('Bug Condition 7 — Rx save runs a contraindication check (Req 2.12)', () {
    const rxSavePaths = <String>[
      'lib/features/doctor/presentation/screens/add_prescription_screen.dart',
      'lib/features/doctor/data/repositories/prescription_repository.dart',
    ];

    test('COUNTEREXAMPLE (1.12): the Rx-save path references allergy/'
        'contraindication logic', () {
      final combined = rxSavePaths.map(_readSource).join('\n');
      expect(
        combined.isNotEmpty,
        isTrue,
        reason: 'Expected the Rx-save path sources to exist.',
      );

      final safetyCheck = RegExp(r'allerg|contraindicat', caseSensitive: false);
      expect(
        safetyCheck.hasMatch(combined),
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.12): neither AddPrescriptionScreen nor '
            'PrescriptionRepository references the patient\'s allergies or any '
            'contraindication check before persisting an Rx — a drug the '
            'patient is allergic to saves silently.',
      );
    });
  });

  // =========================================================================
  // BUG CONDITION 8 — Miswired patient history (1.15 → 2.15 / Property 8).
  // The sidebar id 'patient_history' resolves to PatientListScreen ("Default to
  // patient list for selection") instead of a history/timeline view.
  // Expected (post-fix): it resolves to PatientHistoryScreen (via picker) or an
  // accurately relabeled target — never the plain PatientListScreen.
  //
  // PBT over the sidebar-id domain: every clinic id must resolve to a non-null
  // screen, and 'patient_history' specifically must NOT be PatientListScreen.
  // =========================================================================
  group('Bug Condition 8 — patient_history reaches a history view (Req 2.15)', () {
    // The 13 already-correct clinic ids (preservation anchors) + the defect id.
    const clinicIds = <String>[
      'clinic_dashboard',
      'daily_appointments',
      'patients_list',
      'add_patient',
      'appointments',
      'prescriptions',
      'medicine_master',
      'lab_reports',
      'doctor_revenue',
      'new_sale',
      'revenue_overview',
      'patient_history',
    ];

    testWidgets('COUNTEREXAMPLE (1.15): patient_history must not resolve to '
        'PatientListScreen', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      // Concrete anchor — the precise defect.
      final resolved = SidebarNavigationHandler.tryGetScreenForItem(
        'patient_history',
        ctx,
      );
      expect(
        resolved,
        isNot(isA<PatientListScreen>()),
        reason:
            'COUNTEREXAMPLE (1.15): "patient_history" resolves to '
            'PatientListScreen ("Default to patient list for selection") — the '
            'dedicated history/timeline view is never reached.',
      );

      // PBT over the sidebar-id domain (sync resolver, captured context):
      // every clinic id resolves to a screen, and patient_history is not the
      // plain list.
      final held = forAll(
        (int i) {
          final id = clinicIds[i];
          final widget = SidebarNavigationHandler.tryGetScreenForItem(id, ctx);
          if (id == 'patient_history') {
            return widget != null && widget is! PatientListScreen;
          }
          return widget != null;
        },
        [Gen.interval(0, clinicIds.length - 1)],
        numRuns: 60,
      );
      expect(
        held,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.15): across the clinic sidebar-id domain, '
            '"patient_history" still resolves to the plain PatientListScreen.',
      );
    });
  });

  // =========================================================================
  // BUG CONDITION 10 — Hardcoded dashboard counts (1.21 → 2.21 / Property 10).
  // The clinic branch of BusinessAlertsWidget renders literal '18' (Today's
  // Appointments) and '7' (Pending Lab Reports), ignoring real data.
  // Expected (post-fix): counts come from live queries — the '18'/'7' literals
  // are gone. Render the widget for clinic with a distinctive seeded count.
  // =========================================================================
  group('Bug Condition 10 — clinic dashboard counts are live, not '
      'literals (Req 2.21)', () {
    testWidgets(
      'COUNTEREXAMPLE (1.21): clinic alerts must not render the hardcoded '
      '\'18\'/\'7\' literals',
      (tester) async {
        // Seed a distinctive sentinel so any live wiring would surface it
        // instead of the literals.
        const sentinel = 42;
        final seed = <String, int>{
          'todayAppointments': sentinel,
          'today_appointments': sentinel,
          'pendingLabReports': sentinel,
          'pending_lab_reports': sentinel,
          'lowStock': sentinel,
          'expiringSoon': sentinel,
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _FixedBusinessTypeNotifier(BusinessType.clinic),
              ),
              alertCountsProvider.overrideWith((ref) => Stream.value(seed)),
            ],
            child: const MaterialApp(
              home: Scaffold(body: BusinessAlertsWidget()),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.text('18'),
          findsNothing,
          reason:
              'COUNTEREXAMPLE (1.21): the clinic BusinessAlertsWidget renders '
              'the hardcoded literal "18" for Today\'s Appointments regardless '
              'of real data.',
        );
        expect(
          find.text('7'),
          findsNothing,
          reason:
              'COUNTEREXAMPLE (1.21): the clinic BusinessAlertsWidget renders '
              'the hardcoded literal "7" for Pending Lab Reports regardless of '
              'real data.',
        );
      },
    );
  });

  // =========================================================================
  // BUG CONDITION 11a — Silent medicine-quantity default (1.26 → 2.26 /
  // Property 11). `_calculateMedicineQuantity` swallows dosage/duration parse
  // failures and silently returns 1.0, causing under-dispensing/under-billing.
  // Expected (post-fix): the parse failure is surfaced, not silently defaulted.
  // Real-source probe over clinic_billing_service.dart.
  // =========================================================================
  group('Bug Condition 11a — medicine-quantity parse failure is surfaced '
      '(Req 2.26)', () {
    test(
      'COUNTEREXAMPLE (1.26): clinic_billing_service must not silently default '
      'quantity to 1.0 on parse failure',
      () {
        final src = _readSource(
          'lib/features/doctor/services/clinic_billing_service.dart',
        );
        expect(
          src.isNotEmpty,
          isTrue,
          reason: 'clinic_billing_service.dart must exist.',
        );

        // The defect signature: a catch-all that swallows the parse error and
        // returns the silent default.
        final silentDefault = RegExp(r'catch[^{]*\{\s*return\s+1\.0;');
        expect(
          silentDefault.hasMatch(src),
          isFalse,
          reason:
              'COUNTEREXAMPLE (1.26): _calculateMedicineQuantity catches the '
              'parse failure and silently `return 1.0;` — the failure is never '
              'surfaced to the user, so an unparseable dosage/duration '
              'under-dispenses and under-bills.',
        );
      },
    );
  });

  // =========================================================================
  // BUG CONDITION 11b — Unvalidated vitals (1.28 → 2.28 / Property 11).
  // visit_screen vitals use TextInputType.text with NO validators, so SpO2
  // accepts out-of-range values like "250" or "abc".
  // Expected (post-fix): SpO2 is range-validated (0–100) with feedback.
  // Real-source probe over visit_screen.dart.
  // =========================================================================
  group('Bug Condition 11b — vitals are range-validated (Req 2.28)', () {
    test(
      'COUNTEREXAMPLE (1.28): visit_screen.dart must validate the SpO2 range',
      () {
        final src = _readSource(
          'lib/features/doctor/presentation/screens/visit_screen.dart',
        );
        expect(src.isNotEmpty, isTrue, reason: 'visit_screen.dart must exist.');

        // Sanity: SpO2 is captured today.
        expect(
          src.contains('SpO2') || src.contains('spO2'),
          isTrue,
          reason: 'Precondition: visit_screen captures an SpO2 vital.',
        );

        // The fix must introduce a validator and/or an explicit 0..100 range
        // check on the vitals input.
        final hasValidation =
            src.contains('validator:') &&
            RegExp(r'100').hasMatch(src) &&
            RegExp(r'SpO2|spO2|spo2', caseSensitive: false).hasMatch(src);
        expect(
          hasValidation,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.28): the vitals inputs in visit_screen use '
              'TextInputType.text with no `validator:` and no 0–100 range check '
              'for SpO2 — values like "250" or "abc" are silently accepted.',
        );
      },
    );
  });
}
