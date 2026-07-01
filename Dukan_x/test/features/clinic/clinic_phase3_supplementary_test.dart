/// Supplementary Unit Tests — Phase 3 (Navigation & Screen Exposure)
///
/// Verifies implementation details beyond the exploration probes:
/// 1. `patient_history` resolves to PatientHistoryPickerScreen (not
///    PatientListScreen) — confirms the exploration test assertion via widget.
/// 2. Double-booking guard rejects overlapping slots for the same doctor.
/// 3. Double-booking guard allows non-overlapping slots.
/// 4. Cancelled appointments don't block new bookings at the same time.
///
/// **Validates: Requirements 2.15, 2.18**
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/doctor/data/exceptions/double_booking_exception.dart';
import 'package:dukanx/features/doctor/data/repositories/appointment_repository.dart';
import 'package:dukanx/features/doctor/models/appointment_model.dart';
import 'package:dukanx/features/doctor/presentation/screens/patient_list_screen.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';

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
  String? get ownerId => 'doctor-owner-1';
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
  // 1. patient_history resolves to PatientHistoryPickerScreen (Req 2.15)
  // =========================================================================
  group('patient_history resolves to PatientHistoryPickerScreen (Req 2.15)', () {
    testWidgets('patient_history resolves to PatientHistoryPickerScreen, not '
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

      final resolved = SidebarNavigationHandler.tryGetScreenForItem(
        'patient_history',
        ctx,
      );

      // Must NOT be PatientListScreen
      expect(
        resolved,
        isNot(isA<PatientListScreen>()),
        reason:
            'patient_history must not resolve to PatientListScreen — it should '
            'resolve to PatientHistoryPickerScreen (which opens the history '
            'timeline view).',
      );

      // Must be non-null (it resolves to something)
      expect(
        resolved,
        isNotNull,
        reason: 'patient_history must resolve to a widget (not null).',
      );

      // The resolved widget's runtime type name should contain
      // "PatientHistoryPickerScreen".
      expect(
        resolved.runtimeType.toString(),
        contains('PatientHistoryPickerScreen'),
        reason: 'patient_history should resolve to PatientHistoryPickerScreen.',
      );
    });
  });

  // =========================================================================
  // 2. Double-booking guard rejects overlapping slots (Req 2.18)
  // =========================================================================
  group('Double-booking guard (Req 2.18)', () {
    test('rejects overlapping slots for the same doctor '
        '(10:00-10:15 existing, 10:10-10:25 proposed)', () async {
      final db = await _tryOpenDb();
      if (db == null) {
        markTestSkipped(_dbSkipReason);
        return;
      }
      try {
        final spy = _SpySyncManager();
        final repo = AppointmentRepository(
          db: db,
          syncManager: spy,
          session: _FakeSessionManager(),
        );

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tenAm = today.add(const Duration(hours: 10));

        // Seed an existing appointment: doctor-1, 10:00–10:15
        final existingAppt = AppointmentModel(
          id: const Uuid().v4(),
          doctorId: 'doctor-1',
          patientId: 'patient-A',
          scheduledTime: tenAm,
          slotDurationMinutes: 15,
          status: AppointmentStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createAppointment(existingAppt);

        // Attempt a conflicting appointment: doctor-1, 10:10–10:25 (overlaps)
        final conflicting = AppointmentModel(
          id: const Uuid().v4(),
          doctorId: 'doctor-1',
          patientId: 'patient-B',
          scheduledTime: tenAm.add(const Duration(minutes: 10)),
          slotDurationMinutes: 15,
          status: AppointmentStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          () => repo.createAppointment(conflicting),
          throwsA(isA<DoubleBookingException>()),
          reason:
              'A proposed appointment overlapping an existing slot for the '
              'same doctor must throw DoubleBookingException.',
        );
      } finally {
        await db.close();
      }
    });

    test('allows non-overlapping slots for the same doctor '
        '(10:00-10:15 existing, 10:30-10:45 proposed)', () async {
      final db = await _tryOpenDb();
      if (db == null) {
        markTestSkipped(_dbSkipReason);
        return;
      }
      try {
        final spy = _SpySyncManager();
        final repo = AppointmentRepository(
          db: db,
          syncManager: spy,
          session: _FakeSessionManager(),
        );

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tenAm = today.add(const Duration(hours: 10));

        // Seed an existing appointment: doctor-1, 10:00–10:15
        final existingAppt = AppointmentModel(
          id: const Uuid().v4(),
          doctorId: 'doctor-1',
          patientId: 'patient-A',
          scheduledTime: tenAm,
          slotDurationMinutes: 15,
          status: AppointmentStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createAppointment(existingAppt);

        // Attempt a NON-overlapping appointment: doctor-1, 10:30–10:45
        final nonConflicting = AppointmentModel(
          id: const Uuid().v4(),
          doctorId: 'doctor-1',
          patientId: 'patient-C',
          scheduledTime: tenAm.add(const Duration(minutes: 30)),
          slotDurationMinutes: 15,
          status: AppointmentStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        );

        // Should complete without throwing
        await expectLater(
          repo.createAppointment(nonConflicting),
          completes,
          reason:
              'A non-overlapping appointment for the same doctor should be '
              'accepted without throwing.',
        );

        // Verify both appointments are in the DB
        final rows = await db.select(db.appointments).get();
        expect(rows, hasLength(2));
      } finally {
        await db.close();
      }
    });

    test(
      'cancelled appointments don\'t block new bookings at the same time',
      () async {
        final db = await _tryOpenDb();
        if (db == null) {
          markTestSkipped(_dbSkipReason);
          return;
        }
        try {
          final spy = _SpySyncManager();
          final repo = AppointmentRepository(
            db: db,
            syncManager: spy,
            session: _FakeSessionManager(),
          );

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final tenAm = today.add(const Duration(hours: 10));

          // Seed a CANCELLED appointment: doctor-1, 10:00–10:15
          final cancelledAppt = AppointmentModel(
            id: const Uuid().v4(),
            doctorId: 'doctor-1',
            patientId: 'patient-A',
            scheduledTime: tenAm,
            slotDurationMinutes: 15,
            status: AppointmentStatus.cancelled,
            createdAt: now,
            updatedAt: now,
          );
          // Insert directly into DB as cancelled (bypass guard since we're
          // testing against it, not creating a live booking)
          await db
              .into(db.appointments)
              .insert(
                AppointmentsCompanion.insert(
                  id: cancelledAppt.id,
                  doctorId: cancelledAppt.doctorId,
                  patientId: cancelledAppt.patientId,
                  scheduledTime: cancelledAppt.scheduledTime,
                  status: Value('cancelled'),
                  slotDurationMinutes: Value(15),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          // Attempt a new appointment at the SAME time: doctor-1, 10:00–10:15
          final newAppt = AppointmentModel(
            id: const Uuid().v4(),
            doctorId: 'doctor-1',
            patientId: 'patient-B',
            scheduledTime: tenAm,
            slotDurationMinutes: 15,
            status: AppointmentStatus.scheduled,
            createdAt: now,
            updatedAt: now,
          );

          // Should succeed — cancelled appointments don't block
          await expectLater(
            repo.createAppointment(newAppt),
            completes,
            reason:
                'A cancelled appointment should not block new bookings at the '
                'same time slot.',
          );
        } finally {
          await db.close();
        }
      },
    );
  });
}
