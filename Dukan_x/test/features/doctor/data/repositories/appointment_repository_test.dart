import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/doctor/data/repositories/appointment_repository.dart';
import 'package:dukanx/features/doctor/models/appointment_model.dart';

// Spy implementation to track sync operations
class SpySyncManager extends Fake implements SyncManager {
  final List<SyncQueueItem> enqueuedItems = [];

  @override
  Future<String> enqueue(SyncQueueItem item) async {
    enqueuedItems.add(item);
    return 'spy-op-${enqueuedItems.length}';
  }
}

void main() {
  late AppDatabase db;
  late SpySyncManager spySyncManager;
  late AppointmentRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    spySyncManager = SpySyncManager();
    repository = AppointmentRepository(db: db, syncManager: spySyncManager);
  });

  tearDown(() async {
    await db.close();
  });

  group('AppointmentRepository Tests', () {
    test(
      'createAppointment should insert into database and enqueue sync',
      () async {
        final appointment = AppointmentModel(
          id: const Uuid().v4(),
          doctorId: 'doctor-123',
          patientId: 'patient-456',
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
          status: AppointmentStatus.scheduled,
          purpose: 'General Checkup',
          notes: 'First visit',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.createAppointment(appointment);

        // Verify sync was enqueued
        expect(spySyncManager.enqueuedItems.length, 1);
        final syncItem = spySyncManager.enqueuedItems.first;
        expect(syncItem.operationType, SyncOperationType.create);
        expect(syncItem.targetCollection, 'appointments');
        expect(syncItem.documentId, appointment.id);
      },
    );

    test('updateAppointment should update database and enqueue sync', () async {
      // First create an appointment
      final appointment = AppointmentModel(
        id: const Uuid().v4(),
        doctorId: 'doctor-123',
        patientId: 'patient-456',
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        status: AppointmentStatus.scheduled,
        purpose: 'General Checkup',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createAppointment(appointment);
      spySyncManager.enqueuedItems.clear();

      // Update appointment status
      final updatedAppointment = appointment.copyWith(
        status: AppointmentStatus.completed,
        notes: 'Completed successfully',
      );
      await repository.updateAppointment(updatedAppointment);

      // Verify sync was enqueued for update
      expect(spySyncManager.enqueuedItems.length, 1);
      final syncItem = spySyncManager.enqueuedItems.first;
      expect(syncItem.operationType, SyncOperationType.update);
      expect(syncItem.targetCollection, 'appointments');
    });

    test('getAppointmentsForDoctor should return filtered results', () async {
      final doctorId = 'doctor-123';
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Create appointments
      final appt1 = AppointmentModel(
        id: const Uuid().v4(),
        doctorId: doctorId,
        patientId: 'patient-1',
        scheduledTime: startOfDay.add(const Duration(hours: 10)),
        status: AppointmentStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final appt2 = AppointmentModel(
        id: const Uuid().v4(),
        doctorId: doctorId,
        patientId: 'patient-2',
        scheduledTime: startOfDay.add(const Duration(hours: 14)),
        status: AppointmentStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create appointment for different doctor (should not be returned)
      final appt3 = AppointmentModel(
        id: const Uuid().v4(),
        doctorId: 'other-doctor',
        patientId: 'patient-3',
        scheduledTime: startOfDay.add(const Duration(hours: 11)),
        status: AppointmentStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createAppointment(appt1);
      await repository.createAppointment(appt2);
      await repository.createAppointment(appt3);

      final results = await repository.getAppointmentsForDoctor(
        doctorId,
        startOfDay,
        endOfDay,
      );

      expect(results.length, 2);
      expect(results.every((a) => a.doctorId == doctorId), true);
    });

    test('watchAppointmentsForDoctor should emit updates', () async {
      final doctorId = 'doctor-watch-test';
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Create initial appointment
      final appt = AppointmentModel(
        id: const Uuid().v4(),
        doctorId: doctorId,
        patientId: 'patient-watch',
        scheduledTime: startOfDay.add(const Duration(hours: 10)),
        status: AppointmentStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createAppointment(appt);

      // Watch and verify
      final stream = repository.watchAppointmentsForDoctor(doctorId, today);
      final firstEmission = await stream.first;

      expect(firstEmission.length, 1);
      expect(firstEmission.first.id, appt.id);
    });

    test('status transitions should work correctly', () async {
      final appointment = AppointmentModel(
        id: const Uuid().v4(),
        doctorId: 'doctor-status',
        patientId: 'patient-status',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        status: AppointmentStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createAppointment(appointment);

      // Transition to completed
      final completed = appointment.copyWith(
        status: AppointmentStatus.completed,
      );
      await repository.updateAppointment(completed);

      // Verify the status was updated
      final results = await repository.getAppointmentsForDoctor(
        'doctor-status',
        DateTime.now().subtract(const Duration(hours: 1)),
        DateTime.now().add(const Duration(hours: 2)),
      );

      expect(results.first.status, AppointmentStatus.completed);
    });

    test('cancelled appointments should persist status', () async {
      final appointment = AppointmentModel(
        id: const Uuid().v4(),
        doctorId: 'doctor-cancel',
        patientId: 'patient-cancel',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        status: AppointmentStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createAppointment(appointment);

      // Cancel the appointment
      final cancelled = appointment.copyWith(
        status: AppointmentStatus.cancelled,
      );
      await repository.updateAppointment(cancelled);

      final results = await repository.getAppointmentsForDoctor(
        'doctor-cancel',
        DateTime.now().subtract(const Duration(hours: 1)),
        DateTime.now().add(const Duration(hours: 2)),
      );

      expect(results.first.status, AppointmentStatus.cancelled);
    });
  });
}
