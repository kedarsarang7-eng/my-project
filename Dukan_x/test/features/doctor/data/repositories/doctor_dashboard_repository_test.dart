import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/doctor/data/repositories/doctor_dashboard_repository.dart';
import 'package:dukanx/features/doctor/data/repositories/patient_repository.dart';
import 'package:dukanx/features/doctor/data/repositories/appointment_repository.dart';
import 'package:dukanx/features/doctor/models/patient_model.dart';
import 'package:dukanx/features/doctor/models/appointment_model.dart';

// Fake SyncManager for testing
class FakeSyncManager extends Fake implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem item) async => 'fake-op-id';
}

void main() {
  late AppDatabase db;
  late FakeSyncManager fakeSyncManager;
  late DoctorDashboardRepository dashboardRepo;
  late PatientRepository patientRepo;
  late AppointmentRepository appointmentRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeSyncManager = FakeSyncManager();
    dashboardRepo = DoctorDashboardRepository(db);
    patientRepo = PatientRepository(db: db, syncManager: fakeSyncManager);
    appointmentRepo = AppointmentRepository(
      db: db,
      syncManager: fakeSyncManager,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DoctorDashboardRepository Tests', () {
    test('getPatientStats should return correct counts', () async {
      final doctorId = 'doctor-stats';

      // Create patients
      await patientRepo.createPatient(
        PatientModel(
          id: const Uuid().v4(),
          name: 'Patient 1',
          phone: '1111111111',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await patientRepo.createPatient(
        PatientModel(
          id: const Uuid().v4(),
          name: 'Patient 2',
          phone: '2222222222',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final stats = await dashboardRepo.getPatientStats(doctorId);

      expect(stats, isA<Map<String, int>>());
      expect(stats.containsKey('total'), true);
      expect(stats['total'], 2);
    });

    test(
      'watchDailyAppointments should return appointments for today',
      () async {
        final doctorId = 'doctor-daily';
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        // Create appointment for today
        await appointmentRepo.createAppointment(
          AppointmentModel(
            id: const Uuid().v4(),
            doctorId: doctorId,
            patientId: 'patient-daily',
            scheduledTime: startOfDay.add(const Duration(hours: 10)),
            status: AppointmentStatus.scheduled,
            purpose: 'Checkup',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final stream = dashboardRepo.watchDailyAppointments(doctorId, today);
        final appointments = await stream.first;

        expect(appointments.isNotEmpty, true);
      },
    );

    test('getPatientDetails should return patient info', () async {
      final patientId = const Uuid().v4();

      await patientRepo.createPatient(
        PatientModel(
          id: patientId,
          name: 'Test Patient',
          phone: '9876543210',
          age: 30,
          gender: 'Male',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final patient = await dashboardRepo.getPatientDetails(patientId);

      expect(patient, isNotNull);
      expect(patient!.name, 'Test Patient');
      expect(patient.age, 30);
    });

    test(
      'getPatientDetails should return null for non-existent patient',
      () async {
        final patient = await dashboardRepo.getPatientDetails(
          'non-existent-id',
        );
        expect(patient, isNull);
      },
    );

    test('getSmartInsights should return insights map', () async {
      final doctorId = 'doctor-insights';

      final insights = await dashboardRepo.getSmartInsights(doctorId);

      expect(insights, isA<Map<String, String>>());
    });

    test('getWeeklyAnalytics should return weekly data', () async {
      final doctorId = 'doctor-weekly';

      final weeklyData = await dashboardRepo.getWeeklyAnalytics(doctorId);

      expect(weeklyData, isA<Map<String, int>>());
    });

    test('getMonthlyAnalytics should return monthly data', () async {
      final doctorId = 'doctor-monthly';

      final monthlyData = await dashboardRepo.getMonthlyAnalytics(doctorId);

      expect(monthlyData, isA<Map<String, int>>());
    });

    test('getDashboardAlerts should return alerts list', () async {
      final doctorId = 'doctor-alerts';

      final alerts = await dashboardRepo.getDashboardAlerts(doctorId);

      expect(alerts, isA<List<Map<String, dynamic>>>());
    });
  });
}
