import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:dukanx/features/doctor/data/repositories/patient_repository.dart';
import 'package:dukanx/features/doctor/data/repositories/prescription_repository.dart';
import 'package:dukanx/features/doctor/models/patient_model.dart';
import 'package:dukanx/features/doctor/models/prescription_model.dart';

// Spy implementation to inspect enqueued items
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
  late PatientRepository patientRepo;
  late PrescriptionRepository prescriptionRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    spySyncManager = SpySyncManager();
    patientRepo = PatientRepository(db: db, syncManager: spySyncManager);
    prescriptionRepo = PrescriptionRepository(
      db: db,
      syncManager: spySyncManager,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Patient Creation should enqueue Sync Item', () async {
    final patient = PatientModel(
      id: const Uuid().v4(),
      name: 'Test Patient',
      phone: '1234567890',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await patientRepo.createPatient(patient);

    expect(spySyncManager.enqueuedItems.length, 1);
    final item = spySyncManager.enqueuedItems.first;
    expect(item.operationType, SyncOperationType.create);
    expect(item.targetCollection, 'patients');
    expect(item.documentId, patient.id);
  });

  test('Patient Update should enqueue Sync Item', () async {
    final patient = PatientModel(
      id: const Uuid().v4(),
      name: 'Test Patient',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create first (triggers first sync)
    await patientRepo.createPatient(patient);
    spySyncManager.enqueuedItems.clear(); // Clear history

    // Update
    final updatedPatient = patient.copyWith(name: 'Updated Name');
    await patientRepo.updatePatient(updatedPatient);

    expect(spySyncManager.enqueuedItems.length, 1);
    final item = spySyncManager.enqueuedItems.first;
    expect(item.operationType, SyncOperationType.update);
    expect(item.targetCollection, 'patients');
    expect(item.documentId, patient.id);
  });

  test('Prescription Creation should enqueue Sync Item', () async {
    final prescription = PrescriptionModel(
      id: const Uuid().v4(),
      doctorId: 'doc-123',
      patientId: 'pat-123',
      visitId: 'vis-123',
      date: DateTime.now(),
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await prescriptionRepo.createPrescription(prescription);

    expect(spySyncManager.enqueuedItems.length, 1);
    final item = spySyncManager.enqueuedItems.first;
    expect(item.operationType, SyncOperationType.create);
    expect(item.targetCollection, 'prescriptions');
    expect(item.documentId, prescription.id);
  });
}
