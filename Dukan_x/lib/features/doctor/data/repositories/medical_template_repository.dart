import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../models/medical_template_model.dart';

/// Repository for Medical Templates
class MedicalTemplateRepository {
  final AppDatabase _db;
  final SyncManager _syncManager;

  MedicalTemplateRepository({
    required AppDatabase db,
    required SyncManager syncManager,
  }) : _db = db,
       _syncManager = syncManager;

  static const String collectionName =
      'medical_templates'; // Firestore collection

  /// Create a new template
  Future<void> createTemplate(MedicalTemplateModel template) async {
    try {
      await _db
          .into(_db.medicalTemplates)
          .insert(
            MedicalTemplatesCompanion.insert(
              id: template.id,
              userId: template.userId,
              type: template.type,
              title: template.title,
              content: template.content,
              createdAt: template.createdAt,
              updatedAt: template.updatedAt,
            ),
          );

      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: template.userId,
          operationType: SyncOperationType.create,
          targetCollection: collectionName,
          documentId: template.id,
          payload: template.toMap(),
        ),
      );
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to save template',
      );
      rethrow;
    }
  }

  /// Get templates by type
  Future<List<MedicalTemplateModel>> getTemplatesByType(
    String userId,
    String type,
  ) async {
    final rows =
        await (_db.select(_db.medicalTemplates)
              ..where((t) => t.userId.equals(userId) & t.type.equals(type))
              ..orderBy([(t) => OrderingTerm.asc(t.title)]))
            .get();

    return rows.map((row) => _mapToModel(row)).toList();
  }

  /// Delete template
  Future<void> deleteTemplate(String id, String userId) async {
    await (_db.delete(
      _db.medicalTemplates,
    )..where((t) => t.id.equals(id))).go();

    await _syncManager.enqueue(
      SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.delete,
        targetCollection: collectionName,
        documentId: id,
        payload: {},
      ),
    );
  }

  MedicalTemplateModel _mapToModel(MedicalTemplateEntity row) {
    return MedicalTemplateModel(
      id: row.id,
      userId: row.userId,
      type: row.type,
      title: row.title,
      content: row.content,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
