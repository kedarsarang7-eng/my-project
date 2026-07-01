// ============================================================================
// BASE REPOSITORY - OFFLINE-FIRST PATTERN
// ============================================================================
// Abstract repository implementing the dual-write architecture:
// UI → Local DB → Sync Queue → Firestore
//
// CRITICAL RULES:
// 1. UI NEVER writes directly to Firestore
// 2. Local DB is the SINGLE SOURCE OF TRUTH
// 3. All operations must succeed offline
// 4. Sync happens asynchronously in background
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../sync/sync_queue_state_machine.dart';
import '../sync/sync_manager.dart';
import '../services/device_id_service.dart';
import '../error/error_handler.dart'; // Import RepositoryResult

/// Base entity interface - all entities must implement this
abstract class BaseEntity {
  String get id;
  String get userId;
  DateTime get createdAt;
  DateTime get updatedAt;
  DateTime? get deletedAt;
  bool get isSynced;
  String? get syncOperationId;
  int get version;

  /// Convert to map for database storage
  Map<String, dynamic> toMap();

  /// Convert to map for Firestore (may differ from local)
  Map<String, dynamic> toFirestoreMap() => toMap();

  /// Check if entity is deleted (soft delete)
  bool get isDeleted => deletedAt != null;
}

/// Base Repository abstract class
/// All feature repositories should extend this
abstract class BaseRepository<T extends BaseEntity> {
  /// Unique collection/table name
  String get collectionName;

  /// Current user ID
  String get currentUserId;

  /// Sync manager instance
  SyncManager get syncManager => SyncManager.instance;

  /// UUID generator
  static const _uuid = Uuid();

  // ============================================================================
  // ABSTRACT METHODS - Must be implemented by concrete repositories
  // ============================================================================

  /// Insert entity into local database
  Future<void> insertLocal(T entity);

  /// Update entity in local database
  Future<void> updateLocal(T entity);

  /// Soft delete entity in local database
  Future<void> softDeleteLocal(String id);

  /// Get entity by ID from local database
  Future<T?> getByIdLocal(String id);

  /// Get all entities from local database
  Future<List<T>> getAllLocal();

  /// Watch entity by ID (stream)
  Stream<T?> watchById(String id);

  /// Watch all entities (stream)
  Stream<List<T>> watchAll();

  /// Create entity from map
  T fromMap(Map<String, dynamic> map);

  // ============================================================================
  // PUBLIC CRUD METHODS - Implement dual-write pattern
  // ============================================================================

  /// CREATE - Insert new entity
  /// 1. Generate ID
  /// 2. Save to local DB
  /// 3. Enqueue sync operation with deviceId
  Future<RepositoryResult<T>> create(T entity) async {
    try {
      // Validate
      if (entity.userId != currentUserId) {
        return RepositoryResult.failure('User ID mismatch');
      }

      debugPrint('BaseRepository: Creating ${entity.id} in $collectionName');

      // Get device ID for conflict resolution
      final deviceId = await DeviceIdService.instance.getDeviceId();

      // Step 1: Save to local database (MUST succeed)
      await insertLocal(entity);
      debugPrint('BaseRepository: Saved to local DB');

      // Step 2: Enqueue sync operation with deviceId (background)
      final syncItem = SyncQueueItem.create(
        userId: currentUserId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: entity.id,
        payload: entity.toFirestoreMap(),
        deviceId: deviceId,
      );
      await syncManager.enqueue(syncItem);
      debugPrint(
        'BaseRepository: Enqueued sync operation ${syncItem.operationId} with deviceId: $deviceId',
      );

      return RepositoryResult.success(entity);
    } catch (e) {
      debugPrint('BaseRepository: Create error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// UPDATE - Update existing entity
  /// 1. Get current version
  /// 2. Increment version
  /// 3. Update local DB
  /// 4. Enqueue sync operation with deviceId
  Future<RepositoryResult<T>> update(T entity) async {
    try {
      if (entity.userId != currentUserId) {
        return RepositoryResult.failure('User ID mismatch');
      }

      debugPrint('BaseRepository: Updating ${entity.id} in $collectionName');

      // Get device ID for conflict resolution
      final deviceId = await DeviceIdService.instance.getDeviceId();

      // Step 1: Update local database
      await updateLocal(entity);

      // Step 2: Enqueue sync operation with deviceId
      final syncItem = SyncQueueItem.create(
        userId: currentUserId,
        operationType: SyncOperationType.update,
        targetCollection: collectionName,
        documentId: entity.id,
        payload: entity.toFirestoreMap(),
        deviceId: deviceId,
      );
      await syncManager.enqueue(syncItem);

      return RepositoryResult.success(entity);
    } catch (e) {
      debugPrint('BaseRepository: Update error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// DELETE - Soft delete entity
  /// 1. Set deletedAt timestamp
  /// 2. Update local DB
  /// 3. Enqueue sync operation with deviceId
  Future<RepositoryResult<bool>> delete(String id) async {
    try {
      debugPrint('BaseRepository: Deleting $id from $collectionName');

      // Get device ID for conflict resolution
      final deviceId = await DeviceIdService.instance.getDeviceId();

      // Step 1: Soft delete in local database
      await softDeleteLocal(id);

      // Step 2: Enqueue sync operation with deviceId
      final syncItem = SyncQueueItem.create(
        userId: currentUserId,
        operationType: SyncOperationType.delete,
        targetCollection: collectionName,
        documentId: id,
        payload: {'deletedAt': DateTime.now().toIso8601String()},
        deviceId: deviceId,
      );
      await syncManager.enqueue(syncItem);

      return RepositoryResult.success(true);
    } catch (e) {
      debugPrint('BaseRepository: Delete error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// GET BY ID - Read from local database
  Future<RepositoryResult<T>> getById(String id) async {
    try {
      final entity = await getByIdLocal(id);
      if (entity == null) {
        return RepositoryResult.failure('Entity not found');
      }
      return RepositoryResult.success(entity);
    } catch (e) {
      return RepositoryResult.failure(e.toString());
    }
  }

  /// GET ALL - Read all from local database
  Future<RepositoryResult<List<T>>> getAll() async {
    try {
      final entities = await getAllLocal();
      return RepositoryResult.success(entities);
    } catch (e) {
      return RepositoryResult.failure(e.toString());
    }
  }

  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================

  /// Batch create multiple entities
  Future<RepositoryResult<List<T>>> createBatch(List<T> entities) async {
    try {
      for (final entity in entities) {
        await create(entity);
      }
      return RepositoryResult.success(entities);
    } catch (e) {
      return RepositoryResult.failure(e.toString());
    }
  }

  /// Batch update multiple entities
  Future<RepositoryResult<List<T>>> updateBatch(List<T> entities) async {
    try {
      for (final entity in entities) {
        await update(entity);
      }
      return RepositoryResult.success(entities);
    } catch (e) {
      return RepositoryResult.failure(e.toString());
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Generate a new unique ID
  String generateId() => _uuid.v4();

  /// Get current timestamp
  DateTime now() => DateTime.now();

  /// Create audit log entry
  ///
  /// Records immutable audit trail for compliance and debugging.
  /// Audit logs capture: userId, action type, old/new values, timestamps.
  Future<void> logAudit({
    required String recordId,
    required String action,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    try {
      // Get the database instance from sync manager or service locator
      // This is a bridge method - actual implementation depends on how
      // the repository is initialized with database access
      final String tableName = collectionName;

      // Serialize values to JSON if present
      final String? oldJson = oldValue != null ? jsonEncode(oldValue) : null;
      final String? newJson = newValue != null ? jsonEncode(newValue) : null;

      debugPrint('AUDIT: $action on $tableName/$recordId');
      debugPrint(
        '  OLD: ${oldJson?.substring(0, (oldJson.length < 100 ? oldJson.length : 100))}...',
      );
      debugPrint(
        '  NEW: ${newJson?.substring(0, (newJson.length < 100 ? newJson.length : 100))}...',
      );

      // Note: The actual database insert is handled by concrete repositories
      // that have access to AppDatabase. They should call:
      // database.insertAuditLog(
      //   userId: userId,
      //   targetTableName: tableName,
      //   recordId: recordId,
      //   action: action,
      //   oldValueJson: oldJson,
      //   newValueJson: newJson,
      // );
    } catch (e) {
      // Audit logging should never fail the main operation
      debugPrint('AUDIT LOG ERROR: $e');
    }
  }
}

/// Mixin for entities that support file attachments
mixin FileAttachmentMixin {
  /// Local file paths pending upload
  List<String> get pendingUploads;

  /// Remote URLs after upload
  List<String> get uploadedUrls;
}

/// Mixin for entities that track sync status
mixin SyncTrackingMixin {
  bool get isSynced;
  String? get syncOperationId;
  DateTime? get lastSyncedAt;
  String? get lastSyncError;
}

/// Validation helper
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult.valid() : isValid = true, errors = [];
  ValidationResult.invalid(this.errors) : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: ${errors.join(', ')}';
}

/// Entity validator interface
abstract class EntityValidator<T extends BaseEntity> {
  ValidationResult validate(T entity);
}
