import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:flutter/foundation.dart';
import '../models/sync_failure.dart';
import '../sync_queue_state_machine.dart';

/// Stub for FirebaseException (removed with firebase_auth SDK)
class FirebaseException implements Exception {
  final String code;
  final String? message;
  final String plugin;
  FirebaseException({required this.code, this.message, this.plugin = 'firestore'});
  @override
  String toString() => 'FirebaseException($plugin/$code): $message';
}

/// Responsible for executing a single SyncQueueItem against Firestore.
/// Is isolated from the generic engine logic.
class TaskProcessor {
  final FirebaseFirestore _firestore;

  TaskProcessor({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> process(SyncQueueItem item) async {
    try {
      debugPrint(
        'TaskProcessor: Processing ${item.operationId} (${item.operationType})',
      );

      switch (item.operationType) {
        case SyncOperationType.create:
          await _executeCreate(item);
          break;
        case SyncOperationType.update:
          await _executeUpdate(item);
          break;
        case SyncOperationType.delete:
          await _executeDelete(item);
          break;
        case SyncOperationType.uploadFile:
          // File uploads are handled separately via Firebase Storage SDK
          // This sync engine focuses on Firestore document operations only
          // File upload operations should use the dedicated StorageService
          throw const SyncDataFailure(
            message:
                "File upload operations should use StorageService directly",
          );
      }
    } on FirebaseException catch (e) {
      throw _mapFirebaseError(e);
    } catch (e, st) {
      if (e is SyncFailure) rethrow; // Pass through typed failures
      throw SyncUnknownFailure(
        message: 'Unexpected error during sync execution',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _executeCreate(SyncQueueItem item) async {
    final docRef = _getDocRef(item);

    // Idempotency check handled inside transaction or pre-check
    // Using SetOptions(merge: true) is safer for idempotency if we don't strict check
    // But strict check is better for logical correctness (conflict detection)

    // We'll use the logic from legacy SyncManager:
    // check if exists, if opId matches -> success.

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data['_operationId'] == item.operationId) {
        debugPrint('TaskProcessor: Idempotent success (already applied)');
        return;
      }
      // If validation says "Create" but it exists, handle conflict?
      // Legacy manager did: "Local is newer -> Update".
      // We will trust the legacy logic.
      await _executeUpdate(item);
      return;
    }

    final payload = item.payload;
    _enrichPayload(payload, item);
    payload['createdAt'] = FieldValue.serverTimestamp();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['version'] = 1;

    await docRef.set(payload);
  }

  Future<void> _executeUpdate(SyncQueueItem item) async {
    final docRef = _getDocRef(item);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        // Fallback to create
        final payload = item.payload;
        _enrichPayload(payload, item);
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['updatedAt'] = FieldValue.serverTimestamp();
        payload['version'] = 1;
        transaction.set(docRef, payload);
        return;
      }

      final serverData = snapshot.data() as Map<String, dynamic>?;
      final currentVersion = serverData?['version'] as int? ?? 0;
      final payloadMap = item.payload;
      final payloadVersion = payloadMap['version'] as int? ?? 0;

      // Conflict Check: Server Wins if Server Version >= Payload Version
      // Exception: Idempotency (same opId)
      if (currentVersion >= payloadVersion) {
        if (serverData?['_operationId'] == item.operationId) return;

        // CONFLICT!
        throw SyncConflictFailure(
          message: "Server version $currentVersion >= Local $payloadVersion",
          originalError: {'server': serverData, 'local': payloadMap},
        );
      }

      final payload = Map<String, dynamic>.from(payloadMap);
      _enrichPayload(payload, item);
      payload['updatedAt'] = FieldValue.serverTimestamp();
      // Ensure strictly ordered versioning
      payload['version'] = payloadVersion; // Trust the local intention?
      // Ideally version = currentVersion + 1, but we trust the domain creates valid intents

      transaction.update(docRef, payload);
    });
  }

  Future<void> _executeDelete(SyncQueueItem item) async {
    final docRef = _getDocRef(item);

    // Soft delete
    await docRef.update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      '_operationId': item.operationId,
      '_payloadHash': item.payloadHash,
    });
  }

  DocumentReference _getDocRef(SyncQueueItem item) {
    return _firestore
        .collection('vendors')
        .doc(item.ownerId)
        .collection(item.targetCollection)
        .doc(item.documentId);
  }

  void _enrichPayload(Map<String, dynamic> payload, SyncQueueItem item) {
    payload['ownerId'] = item.ownerId;
    payload['_operationId'] = item.operationId;
    payload['_payloadHash'] = item.payloadHash;
  }

  SyncFailure _mapFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return SyncNetworkFailure(
          message: e.message ?? 'Network Error',
          originalError: e,
        );
      case 'permission-denied':
      case 'unauthenticated':
        return SyncAuthFailure(
          message: 'Auth Error: ${e.message}',
          originalError: e,
        );
      default:
        return SyncUnknownFailure(
          message: 'Firestore Error: ${e.message}',
          originalError: e,
        );
    }
  }
}
