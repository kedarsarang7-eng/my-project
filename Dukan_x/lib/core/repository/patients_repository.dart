import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../models/patient.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

class PatientsRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  PatientsRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'patients';

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Create a new patient
  /// [userId] is the Clinic Owner ID
  Future<RepositoryResult<Patient>> createPatient(Patient patient) async {
    return await errorHandler.runSafe<Patient>(() async {
      final now = DateTime.now();

      // Ensure ID is generated if empty? Usually ID is passed in patient object from UI or ViewModel
      // But if empty, we should generate? PatientsRepository usually expects ID.
      // We will assume ID is present.

      await database
          .into(database.patients)
          .insert(
            PatientsCompanion.insert(
              id: patient.id,
              userId: patient.userId,
              customerId: Value(
                patient.customerId.isNotEmpty ? patient.customerId : null,
              ),
              name: patient.name,
              phone: Value(patient.phone),
              age: Value(patient.age),
              gender: Value(patient.gender),
              bloodGroup: Value(patient.bloodGroup),
              allergies: Value(patient.allergies.join(',')),
              chronicConditions: Value(patient.chronicConditions.join(',')),
              emergencyContact: Value(
                '${patient.emergencyContactName}|${patient.emergencyContactPhone}',
              ),
              isActive: const Value(true),
              isSynced: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: patient.userId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: patient.id,
        payload: patient.toMap(),
      );
      await syncManager.enqueue(item);

      return patient.copyWith(createdAt: now, updatedAt: now);
    }, 'createPatient');
  }

  /// Update patient
  Future<RepositoryResult<Patient>> updatePatient(Patient patient) async {
    return await errorHandler.runSafe<Patient>(() async {
      final now = DateTime.now();
      final updated = patient.copyWith(updatedAt: now);

      await (database.update(
        database.patients,
      )..where((t) => t.id.equals(patient.id))).write(
        PatientsCompanion(
          name: Value(updated.name),
          phone: Value(updated.phone),
          customerId: Value(
            updated.customerId.isNotEmpty ? updated.customerId : null,
          ),
          age: Value(updated.age),
          gender: Value(updated.gender),
          bloodGroup: Value(updated.bloodGroup),
          allergies: Value(updated.allergies.join(',')),
          chronicConditions: Value(updated.chronicConditions.join(',')),
          emergencyContact: Value(
            '${updated.emergencyContactName}|${updated.emergencyContactPhone}',
          ),
          isActive: const Value(true),
          isSynced: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: patient.userId,
        operationType: SyncOperationType.update,
        targetCollection: collectionName,
        documentId: patient.id,
        payload: updated.toMap(),
      );
      await syncManager.enqueue(item);

      return updated;
    }, 'updatePatient');
  }

  /// Get patient by ID
  Future<RepositoryResult<Patient?>> getById(String id) async {
    return await errorHandler.runSafe<Patient?>(() async {
      final result =
          await (database.select(database.patients)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
              .getSingleOrNull();

      if (result == null) return null;
      return _entityToPatient(result);
    }, 'getById');
  }

  /// Search patients
  Future<RepositoryResult<List<Patient>>> search(
    String query, {
    required String userId,
    int limit = 50,
  }) async {
    return await errorHandler.runSafe<List<Patient>>(() async {
      if (query.isEmpty) {
        // Return recent patients
        final recent =
            await (database.select(database.patients)
                  ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
                  ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
                  ..limit(limit))
                .get();
        return recent.map(_entityToPatient).toList();
      }

      final results =
          await (database.select(database.patients)
                ..where(
                  (t) =>
                      t.userId.equals(userId) &
                      t.deletedAt.isNull() &
                      (t.name.like('%$query%') | t.phone.like('%$query%')),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.name)])
                ..limit(limit))
              .get();

      return results.map(_entityToPatient).toList();
    }, 'search');
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  Patient _entityToPatient(PatientEntity e) {
    // Parse emergency contact "Name|Phone"
    String ecName = '';
    String ecPhone = '';
    if (e.emergencyContact != null && e.emergencyContact!.contains('|')) {
      final parts = e.emergencyContact!.split('|');
      ecName = parts[0];
      ecPhone = parts.length > 1 ? parts[1] : '';
    } else {
      ecName = e.emergencyContact ?? '';
    }

    return Patient(
      id: e.id,
      userId: e.userId,
      customerId: e.customerId ?? '',
      name: e.name,
      phone: e.phone,
      age: e.age ?? 0,
      gender: e.gender ?? 'Other',
      bloodGroup: e.bloodGroup ?? '',
      allergies:
          e.allergies?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      chronicConditions:
          e.chronicConditions?.split(',').where((s) => s.isNotEmpty).toList() ??
          [],
      emergencyContactName: ecName,
      emergencyContactPhone: ecPhone,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      lastVisitId: e.lastVisitId,
    );
  }
}
