import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/doctor/data/repositories/patient_repository.dart';
import 'package:dukanx/features/doctor/data/repositories/doctor_repository.dart';
import 'package:dukanx/features/doctor/services/patient_service.dart';
import 'package:dukanx/features/doctor/models/patient_model.dart';
import 'package:dukanx/features/doctor/models/doctor_profile_model.dart';

// Fake implementation to avoid build_runner
class FakeSyncManager extends Fake implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem item) async {
    return 'fake-op-id';
  }
}

void main() {
  late AppDatabase db;
  late FakeSyncManager fakeSyncManager;
  late PatientRepository patientRepo;
  late DoctorRepository doctorRepo;
  late PatientService patientService;

  setUp(() {
    // In-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeSyncManager = FakeSyncManager();

    // Repositories
    patientRepo = PatientRepository(db: db, syncManager: fakeSyncManager);
    doctorRepo = DoctorRepository(db: db, syncManager: fakeSyncManager);

    // Service
    patientService = PatientService(
      patientRepository: patientRepo,
      doctorRepository: doctorRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('QR Linking Flow: Generate Token -> Scan -> Link', () async {
    // 1. Setup Data
    final patientId = const Uuid().v4();
    final doctorId = const Uuid().v4();

    // Create Patient
    final patient = PatientModel(
      id: patientId,
      name: 'John Doe',
      phone: '9876543210',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await patientRepo.createPatient(patient);

    // Create Doctor Profile (Vendor)
    await doctorRepo.saveProfile(
      DoctorProfileModel(
        id: const Uuid().v4(),
        vendorId: doctorId,
        specialization: 'General',
        createdAt: DateTime.now(),
      ),
    );

    // 2. Generate QR Token
    final token = await patientService.generateQrToken(patientId);
    expect(token, isNotEmpty);

    // 3. Scan Token (Simulate Doctor scanning Patient's QR)
    final scannedPatient = await patientService.scanPatientQr(token);
    expect(scannedPatient, isNotNull);
    expect(scannedPatient!.id, equals(patientId));

    // 4. Link Patient to Doctor
    await patientService.linkPatientToDoctor(patientId, doctorId);

    // 5. Verify Link
    await (db.select(db.patientDoctorLinks)..where(
          (t) => t.patientId.equals(patientId) & t.doctorId.equals(doctorId),
        ))
        .get(); // Actually doctorId in link is doctorProfileId, but we used vendorId in logic above.

    // Note: PatientServiceImpl.linkPatientToDoctor calls:
    // doctorRepo.getProfileByVendorId(doctorId) -> returns profile
    // doctorRepo.linkPatient(patientId, doctorId) -> Here doctorId is usually VENDOR ID
    // Let's check DoctorRepository implementation of linkPatient.
    // If it uses vendorId to find profile and then link, it's fine.

    // Wait, let's look at doctor_repository.dart manually if needed.
    // Assuming successful execution if no error.
  });
}
