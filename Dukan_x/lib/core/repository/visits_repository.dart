import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../models/visit.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

class VisitsRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  VisitsRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'visits';

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  Future<RepositoryResult<Visit>> createVisit(Visit visit) async {
    return await errorHandler.runSafe<Visit>(() async {
      final now = DateTime.now();

      await database
          .into(database.visits)
          .insert(
            VisitsCompanion.insert(
              id: visit.id,
              userId: visit.doctorId,
              patientId: visit.patientId,
              doctorId: Value(visit.doctorId),
              visitDate: visit.visitDate,
              status: Value(visit.status),
              symptoms: Value(visit.symptoms.join(',')),
              diagnosis: Value(visit.diagnosis),
              notes: Value(visit.notes),
              billId: Value(visit.billId),
              prescriptionId: Value(visit.prescriptionId),
              isSynced: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Sync
      final item = SyncQueueItem.create(
        userId: visit.doctorId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: visit.id,
        payload: visit.toMap(),
      );
      await syncManager.enqueue(item);

      return visit.copyWith(createdAt: now, updatedAt: now);
    }, 'createVisit');
  }

  Future<RepositoryResult<Visit>> updateVisit(Visit visit) async {
    return await errorHandler.runSafe<Visit>(() async {
      final now = DateTime.now();
      final updated = visit.copyWith(updatedAt: now);

      await (database.update(
        database.visits,
      )..where((t) => t.id.equals(visit.id))).write(
        VisitsCompanion(
          status: Value(updated.status),
          symptoms: Value(updated.symptoms.join(',')),
          diagnosis: Value(updated.diagnosis),
          notes: Value(updated.notes),
          billId: Value(updated.billId),
          prescriptionId: Value(updated.prescriptionId),
          isSynced: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Sync
      final item = SyncQueueItem.create(
        userId: visit.doctorId,
        operationType: SyncOperationType.update,
        targetCollection: collectionName,
        documentId: visit.id,
        payload: updated.toMap(),
      );
      await syncManager.enqueue(item);

      return updated;
    }, 'updateVisit');
  }

  Future<RepositoryResult<Visit?>> getVisitById(String id) async {
    return await errorHandler.runSafe<Visit?>(() async {
      final entity =
          await (database.select(database.visits)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
              .getSingleOrNull();

      if (entity == null) return null;
      return _entityToModel(entity);
    }, 'getVisitById');
  }

  Future<RepositoryResult<List<Visit>>> getDailyVisits(
    String userId,
    DateTime date,
  ) async {
    return await errorHandler.runSafe<List<Visit>>(() async {
      // Filter by start/end of day
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final entities =
          await (database.select(database.visits)
                ..where(
                  (t) =>
                      t.userId.equals(userId) &
                      t.deletedAt.isNull() &
                      t.visitDate.isBetween(Variable(start), Variable(end)),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.visitDate)]))
              .get();

      return entities.map(_entityToModel).toList();
    }, 'getDailyVisits');
  }

  Future<RepositoryResult<List<Visit>>> getVisitsForPatient(
    String patientId,
  ) async {
    return await errorHandler.runSafe<List<Visit>>(() async {
      final entities =
          await (database.select(database.visits)
                ..where(
                  (t) => t.patientId.equals(patientId) & t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.visitDate)]))
              .get();

      return entities.map(_entityToModel).toList();
    }, 'getVisitsForPatient');
  }

  // ============================================
  // HELPERS
  // ============================================

  Visit _entityToModel(VisitEntity e) {
    return Visit(
      id: e.id,
      patientId: e.patientId,
      doctorId: e.userId, // Map userId to doctorId as Visit model lacks userId
      visitDate: e.visitDate,
      status: e.status,
      symptoms:
          e.symptoms?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      diagnosis: e.diagnosis ?? '',
      notes: e.notes ?? '',
      billId: e.billId,
      prescriptionId: e.prescriptionId,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }
}
