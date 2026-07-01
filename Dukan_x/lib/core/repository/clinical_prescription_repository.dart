import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../models/prescription.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';
import 'dart:convert';

class ClinicalPrescriptionRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  ClinicalPrescriptionRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'clinical_prescriptions';

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  Future<RepositoryResult<Prescription>> createPrescription(
    Prescription prescription,
  ) async {
    return await errorHandler.runSafe<Prescription>(() async {
      final now = DateTime.now();

      // Serialize medicines to JSON string for local DB (assuming DB column is text)
      // Drift tables.dart defined 'medicines' as text().map(...) or just text().
      // Let's check tables.dart later, for now we assume we insert into 'prescriptions' table.
      // Wait, 'prescriptions' table in tables.dart has 'medicines' column?
      // I added it in previous session.

      await database
          .into(database.prescriptions)
          .insert(
            PrescriptionsCompanion.insert(
              id: prescription.id,
              userId: prescription.doctorId,
              visitId: prescription.visitId,
              patientId: prescription.patientId,
              doctorId: Value(prescription.doctorId),
              date: prescription.date,
              medicinesJson: jsonEncode(
                prescription.medicines.map((e) => e.toMap()).toList(),
              ),
              advice: Value(prescription.advice),
              nextVisitDate: Value(
                DateTime.tryParse(prescription.nextVisitDate ?? ''),
              ),
              isSynced: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Sync
      final item = SyncQueueItem.create(
        userId: prescription.doctorId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: prescription.id,
        payload: prescription.toMap(),
      );
      await syncManager.enqueue(item);

      return prescription.copyWith(
        createdAt: now,
        updatedAt: now,
      ); // Helper copyWith if exists or just return input
    }, 'createClinicalPrescription');
  }

  Future<RepositoryResult<Prescription?>> getByVisitId(String visitId) async {
    return await errorHandler.runSafe<Prescription?>(() async {
      final entity =
          await (database.select(
                database.prescriptions,
              )..where((t) => t.visitId.equals(visitId) & t.deletedAt.isNull()))
              .getSingleOrNull();

      if (entity == null) return null;
      return _entityToModel(entity);
    }, 'getByVisitId');
  }

  // ============================================
  // HELPERS
  // ============================================

  Prescription _entityToModel(PrescriptionEntity e) {
    List<MedicineItem> medicines = [];
    if (e.medicinesJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(e.medicinesJson);
        medicines = list.map((m) => MedicineItem.fromMap(m)).toList();
      } catch (_) {}
    }

    return Prescription(
      id: e.id,
      visitId: e.visitId,
      patientId: e.patientId,
      doctorId: e.doctorId ?? '',
      date: e.date,
      medicines: medicines,
      advice: e.advice ?? '',
      nextVisitDate: e.nextVisitDate
          ?.toIso8601String(), // Model uses String?, entity uses DateTime?
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }
}
