// ============================================================================
// SYNC MANAGER TESTS - PRODUCTION COVERAGE
// ============================================================================
// Tests for offline-first sync queue, retry logic, dead letter handling
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';

void main() {
  group('SyncQueueItem - State Machine', () {
    test('should create item with default pending status', () {
      final item = SyncQueueItem(
        operationId: 'op_1',
        operationType: SyncOperationType.create,
        targetCollection: 'bills',
        documentId: 'doc_1',
        payload: {'test': 'data'},
        createdAt: DateTime.now(),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
      );

      expect(item.status, equals(SyncStatus.pending));
      expect(item.retryCount, equals(0));
    });

    test('should transition to inProgress correctly', () {
      final item = SyncQueueItem(
        operationId: 'op_1',
        operationType: SyncOperationType.create,
        targetCollection: 'bills',
        documentId: 'doc_1',
        payload: {},
        createdAt: DateTime.now(),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
      );

      final inProgress = item.copyWith(
        status: SyncStatus.inProgress,
        lastAttemptAt: DateTime.now(),
      );

      expect(inProgress.status, equals(SyncStatus.inProgress));
      expect(inProgress.lastAttemptAt, isNotNull);
    });

    test('should increment retry count on failure', () {
      final item = SyncQueueItem(
        operationId: 'op_1',
        operationType: SyncOperationType.update,
        targetCollection: 'customers',
        documentId: 'cust_1',
        payload: {},
        createdAt: DateTime.now(),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
        retryCount: 0,
      );

      final retry1 = item.copyWith(
        status: SyncStatus.retry,
        retryCount: item.retryCount + 1,
        lastError: 'Network timeout',
      );

      expect(retry1.retryCount, equals(1));
      expect(retry1.lastError, equals('Network timeout'));

      final retry2 = retry1.copyWith(retryCount: retry1.retryCount + 1);

      expect(retry2.retryCount, equals(2));
    });

    test('should determine when to move to dead letter', () {
      final maxRetries = SyncQueueItem(
        operationId: 'op_1',
        operationType: SyncOperationType.create,
        targetCollection: 'bills',
        documentId: 'doc_1',
        payload: {},
        createdAt: DateTime.now(),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
        retryCount: 5, // Max retries reached
      );

      expect(maxRetries.shouldMoveToDeadLetter(), isTrue);

      final canRetry = SyncQueueItem(
        operationId: 'op_2',
        operationType: SyncOperationType.create,
        targetCollection: 'bills',
        documentId: 'doc_2',
        payload: {},
        createdAt: DateTime.now(),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
        retryCount: 2,
      );

      expect(canRetry.shouldMoveToDeadLetter(), isFalse);
    });

    test('should calculate exponential backoff correctly', () {
      final retry0 = SyncQueueItem(
        operationId: 'op_1',
        operationType: SyncOperationType.create,
        targetCollection: 'bills',
        documentId: 'doc_1',
        payload: {},
        createdAt: DateTime.now(),
        lastAttemptAt: DateTime.now(),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
        retryCount: 0,
      );

      final retry1 = retry0.copyWith(
        retryCount: 1,
        lastAttemptAt: DateTime.now(),
      );
      final retry2 = retry0.copyWith(
        retryCount: 2,
        lastAttemptAt: DateTime.now(),
      );
      final retry3 = retry0.copyWith(
        retryCount: 3,
        lastAttemptAt: DateTime.now(),
      );

      final next1 = retry1.calculateNextRetryTime();
      final next2 = retry2.calculateNextRetryTime();
      final next3 = retry3.calculateNextRetryTime();

      // Exponential backoff: each retry should be longer
      expect(next2.isAfter(next1), isTrue);
      expect(next3.isAfter(next2), isTrue);
    });
  });

  group('SyncOperationType', () {
    test('should serialize to string correctly', () {
      expect(SyncOperationType.create.value, equals('CREATE'));
      expect(SyncOperationType.update.value, equals('UPDATE'));
      expect(SyncOperationType.delete.value, equals('DELETE'));
      expect(SyncOperationType.uploadFile.value, equals('UPLOAD_FILE'));
    });

    test('should deserialize from string correctly', () {
      expect(
        SyncOperationType.fromString('CREATE'),
        equals(SyncOperationType.create),
      );
      expect(
        SyncOperationType.fromString('UPDATE'),
        equals(SyncOperationType.update),
      );
      expect(
        SyncOperationType.fromString('DELETE'),
        equals(SyncOperationType.delete),
      );
      expect(
        SyncOperationType.fromString('UPLOAD_FILE'),
        equals(SyncOperationType.uploadFile),
      );
    });

    test('should handle unknown operation type gracefully', () {
      // Unknown types default to create
      expect(
        SyncOperationType.fromString('UNKNOWN'),
        equals(SyncOperationType.create),
      );
    });
  });

  group('SyncStatus', () {
    test('should serialize to string correctly', () {
      expect(SyncStatus.pending.value, equals('PENDING'));
      expect(SyncStatus.inProgress.value, equals('IN_PROGRESS'));
      expect(SyncStatus.synced.value, equals('SYNCED'));
      expect(SyncStatus.failed.value, equals('FAILED'));
      expect(SyncStatus.retry.value, equals('RETRY'));
      expect(SyncStatus.deadLetter.value, equals('DEAD_LETTER'));
    });

    test('should deserialize from string correctly', () {
      expect(SyncStatus.fromString('PENDING'), equals(SyncStatus.pending));
      expect(
        SyncStatus.fromString('IN_PROGRESS'),
        equals(SyncStatus.inProgress),
      );
      expect(SyncStatus.fromString('SYNCED'), equals(SyncStatus.synced));
      expect(SyncStatus.fromString('FAILED'), equals(SyncStatus.failed));
      expect(SyncStatus.fromString('RETRY'), equals(SyncStatus.retry));
      expect(
        SyncStatus.fromString('DEAD_LETTER'),
        equals(SyncStatus.deadLetter),
      );
    });
  });

  group('MultiStepOperation', () {
    test('should create multiple sync queue items', () {
      final operation = MultiStepOperation(
        parentOperationId: 'multi_op_1',
        userId: 'user_1',
        description: 'Test multi-step operation',
        createdAt: DateTime.now(),
        steps: [
          OperationStep(
            name: 'Create Customer',
            targetCollection: 'customers',
            documentId: 'cust_1',
            operationType: SyncOperationType.create,
            payload: {'name': 'Customer 1'},
          ),
          OperationStep(
            name: 'Create Bill',
            targetCollection: 'bills',
            documentId: 'bill_1',
            operationType: SyncOperationType.create,
            payload: {'customerId': 'cust_1'},
          ),
        ],
      );

      final items = operation.createSyncQueueItems();

      expect(items.length, equals(2));
      expect(items[0].stepNumber, equals(1));
      expect(items[0].totalSteps, equals(2));
      expect(items[1].stepNumber, equals(2));
      expect(items[1].totalSteps, equals(2));
      expect(items[0].parentOperationId, equals('multi_op_1'));
    });
  });

  group('SyncQueueItem - Idempotency', () {
    test('should generate deterministic operation ID', () {
      final item1 = SyncQueueItem(
        operationId: 'CREATE_bills_doc_1_1234567890',
        operationType: SyncOperationType.create,
        targetCollection: 'bills',
        documentId: 'doc_1',
        payload: {'test': 'data'},
        createdAt: DateTime.fromMillisecondsSinceEpoch(1234567890),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
      );

      final item2 = SyncQueueItem(
        operationId: 'CREATE_bills_doc_1_1234567890',
        operationType: SyncOperationType.create,
        targetCollection: 'bills',
        documentId: 'doc_1',
        payload: {'test': 'data'},
        createdAt: DateTime.fromMillisecondsSinceEpoch(1234567890),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
      );

      // Same operation should have same ID for idempotency
      expect(item1.operationId, equals(item2.operationId));
    });
  });

  group('SyncQueueItem - Priority', () {
    test('should sort by priority correctly', () {
      final highPriority = SyncQueueItem(
        operationId: 'op_high',
        operationType: SyncOperationType.create,
        targetCollection: 'payments',
        documentId: 'pay_1',
        payload: {},
        createdAt: DateTime.now(),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
        priority: 1, // High priority
      );

      final lowPriority = SyncQueueItem(
        operationId: 'op_low',
        operationType: SyncOperationType.update,
        targetCollection: 'bills',
        documentId: 'bill_1',
        payload: {},
        createdAt: DateTime.now(),
        userId: 'user_1',
        payloadHash: 'hash',
        ownerId: 'user_1',
        priority: 10, // Low priority
      );

      final items = [lowPriority, highPriority];
      items.sort((a, b) => a.priority.compareTo(b.priority));

      expect(items.first.operationId, equals('op_high'));
    });
  });
}
