import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../models/lab_report_model.dart';

/// Lab Report Repository - CRUD with Sync
class LabReportRepository {
  final AppDatabase _db;
  final SyncManager _syncManager;

  LabReportRepository({
    required AppDatabase db,
    required SyncManager syncManager,
  }) : _db = db,
       _syncManager = syncManager;

  String get collectionName => 'labReports';

  // ============================================
  // CREATE
  // ============================================

  /// Order a new lab test
  Future<void> orderLabTest(LabReportModel report) async {
    final now = DateTime.now();

    await _db
        .into(_db.labReports)
        .insert(
          LabReportsCompanion.insert(
            id: report.id,
            patientId: report.patientId,
            doctorId: report.doctorId,
            testName: report.testName,
            status: Value(report.status.name.toUpperCase()),
            uploadedAt: now,
            reportUrl: Value(report.reportUrl),
          ),
        );

    // Queue for sync
    await _syncManager.enqueue(
      SyncQueueItem.create(
        userId: report.doctorId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: report.id,
        payload: report.toMap(),
      ),
    );
  }

  // ============================================
  // READ
  // ============================================

  /// Get all lab reports for a patient
  Future<List<LabReportModel>> getReportsForPatient(String patientId) async {
    final rows =
        await (_db.select(_db.labReports)
              ..where((t) => t.patientId.equals(patientId))
              ..orderBy([(t) => OrderingTerm.desc(t.uploadedAt)]))
            .get();

    return rows.map(_mapToModel).toList();
  }

  /// Get pending lab reports for a doctor
  Future<List<LabReportModel>> getPendingReports(String doctorId) async {
    final rows =
        await (_db.select(_db.labReports)
              ..where(
                (t) =>
                    t.doctorId.equals(doctorId) &
                    t.status.isIn(['PENDING', 'COLLECTED', 'PROCESSING']),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.uploadedAt)]))
            .get();

    return rows.map(_mapToModel).toList();
  }

  /// Get lab report by ID
  Future<LabReportModel?> getById(String id) async {
    final row = await (_db.select(
      _db.labReports,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (row == null) return null;
    return _mapToModel(row);
  }

  /// Watch all lab reports for a patient (streaming)
  Stream<List<LabReportModel>> watchPatientReports(String patientId) {
    return (_db.select(_db.labReports)
          ..where((t) => t.patientId.equals(patientId))
          ..orderBy([(t) => OrderingTerm.desc(t.uploadedAt)]))
        .watch()
        .map((rows) => rows.map(_mapToModel).toList());
  }

  // ============================================
  // UPDATE
  // ============================================

  /// Update lab report status
  Future<void> updateStatus(String id, LabReportStatus newStatus) async {
    final now = DateTime.now();

    await (_db.update(_db.labReports)..where((t) => t.id.equals(id))).write(
      LabReportsCompanion(
        status: Value(newStatus.name.toUpperCase()),
        uploadedAt: newStatus == LabReportStatus.uploaded
            ? Value(now)
            : const Value.absent(),
      ),
    );

    // Get updated record for sync
    final updated = await getById(id);
    if (updated != null) {
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: updated.doctorId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: id,
          payload: updated.toMap(),
        ),
      );
    }
  }

  /// Upload lab report file
  Future<void> uploadReport(String id, String reportUrl) async {
    await (_db.update(_db.labReports)..where((t) => t.id.equals(id))).write(
      LabReportsCompanion(
        reportUrl: Value(reportUrl),
        status: const Value('UPLOADED'),
        uploadedAt: Value(DateTime.now()),
      ),
    );

    final updated = await getById(id);
    if (updated != null) {
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: updated.doctorId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: id,
          payload: updated.toMap(),
        ),
      );
    }
  }

  // ============================================
  // DELETE
  // ============================================

  /// Cancel a lab test order (soft delete via status)
  Future<void> cancelLabTest(String id) async {
    // For now, we just update status. In real system, might want soft delete.
    await updateStatus(id, LabReportStatus.pending);
  }

  // ============================================
  // HELPERS
  // ============================================

  LabReportModel _mapToModel(LabReportEntity row) {
    return LabReportModel(
      id: row.id,
      patientId: row.patientId,
      doctorId: row.doctorId,
      visitId: null, // Table doesn't have visitId yet
      testName: row.testName,
      testCode: null,
      reportUrl: row.reportUrl,
      notes: null,
      status: LabReportModel.parseStatus(row.status),
      orderedAt: row.uploadedAt,
      uploadedAt: row.status == 'UPLOADED' ? row.uploadedAt : null,
      createdAt: row.uploadedAt,
      updatedAt: row.uploadedAt,
    );
  }
}
