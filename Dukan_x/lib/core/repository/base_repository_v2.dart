// ============================================================================
// BASE REPOSITORY V2 - OFFLINE-FIRST FOUNDATION
// ============================================================================
// Abstract base class for all repositories
// Enforces: Drift as source of truth, sync queue, error handling
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

// Re-export RepositoryResult for convenience
export '../error/error_handler.dart'
    show RepositoryResult, RepositoryErrorCategory;

/// Base repository interface
abstract class BaseRepositoryV2<T, ID> {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  BaseRepositoryV2({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  // ============================================
  // ABSTRACT METHODS (Must be implemented)
  // ============================================

  /// Collection name in Firestore
  String get collectionName;

  /// Convert entity to database row
  Map<String, dynamic> entityToDbMap(T entity);

  /// Convert database row to entity
  T dbMapToEntity(Map<String, dynamic> map);

  /// Convert entity to Firestore map (excludes local-only fields)
  Map<String, dynamic> entityToFirestoreMap(T entity);

  /// Get entity ID
  ID getEntityId(T entity);

  // ============================================
  // LOCAL CRUD OPERATIONS (Source of Truth)
  // ============================================

  /// Create entity locally and queue for sync
  Future<RepositoryResult<T>> create(T entity, {required String userId}) async {
    return await errorHandler.runSafe<T>(() async {
      final id = getEntityId(entity);
      final dbMap = entityToDbMap(entity);

      // Insert into local DB
      await insertLocal(dbMap);
      debugPrint('[$runtimeType] Created locally: $id');

      // Queue for remote sync
      await _queueForSync(
        operationType: SyncOperationType.create,
        documentId: id.toString(),
        payload: entityToFirestoreMap(entity),
        userId: userId,
      );

      return entity;
    }, 'create');
  }

  /// Update entity locally and queue for sync
  Future<RepositoryResult<T>> update(T entity, {required String userId}) async {
    return await errorHandler.runSafe<T>(() async {
      final id = getEntityId(entity);
      final dbMap = entityToDbMap(entity);

      // Update in local DB
      await updateLocal(id.toString(), dbMap);
      debugPrint('[$runtimeType] Updated locally: $id');

      // Queue for remote sync
      await _queueForSync(
        operationType: SyncOperationType.update,
        documentId: id.toString(),
        payload: entityToFirestoreMap(entity),
        userId: userId,
      );

      return entity;
    }, 'update');
  }

  /// Delete entity locally and queue for sync
  Future<RepositoryResult<bool>> delete(ID id, {required String userId}) async {
    return await errorHandler.runSafe<bool>(() async {
      // Soft delete in local DB
      await deleteLocal(id.toString());
      debugPrint('[$runtimeType] Deleted locally: $id');

      // Queue for remote sync
      await _queueForSync(
        operationType: SyncOperationType.delete,
        documentId: id.toString(),
        payload: {},
        userId: userId,
      );

      return true;
    }, 'delete');
  }

  /// Get entity by ID from local DB
  Future<RepositoryResult<T?>> getById(ID id) async {
    return await errorHandler.runSafe<T?>(() async {
      final result = await getLocalById(id.toString());
      if (result == null) return null;
      return dbMapToEntity(result);
    }, 'getById');
  }

  /// Get all entities from local DB
  Future<RepositoryResult<List<T>>> getAll({String? userId}) async {
    return await errorHandler.runSafe<List<T>>(() async {
      final results = await getAllLocal(userId: userId);
      return results.map((map) => dbMapToEntity(map)).toList();
    }, 'getAll');
  }

  /// Watch all entities (Stream)
  Stream<List<T>> watchAll({String? userId});

  /// Watch single entity by ID
  Stream<T?> watchById(ID id);

  // ============================================
  // ABSTRACT LOCAL DB OPERATIONS
  // ============================================

  /// Insert into local database
  Future<void> insertLocal(Map<String, dynamic> data);

  /// Update in local database
  Future<void> updateLocal(String id, Map<String, dynamic> data);

  /// Delete from local database (soft delete)
  Future<void> deleteLocal(String id);

  /// Get by ID from local database
  Future<Map<String, dynamic>?> getLocalById(String id);

  /// Get all from local database
  Future<List<Map<String, dynamic>>> getAllLocal({String? userId});

  // ============================================
  // SYNC QUEUE OPERATIONS
  // ============================================

  Future<void> _queueForSync({
    required SyncOperationType operationType,
    required String documentId,
    required Map<String, dynamic> payload,
    required String userId,
  }) async {
    final item = SyncQueueItem.create(
      userId: userId,
      operationType: operationType,
      targetCollection: collectionName,
      documentId: documentId,
      payload: payload,
    );

    await syncManager.enqueue(item);
    debugPrint(
      '[$runtimeType] Queued for sync: ${operationType.value} $documentId',
    );
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Generate UUID
  String generateId() => const Uuid().v4();

  /// Get current timestamp
  DateTime now() => DateTime.now();
}
