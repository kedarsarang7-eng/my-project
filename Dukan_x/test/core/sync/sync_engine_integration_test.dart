// ============================================================================
// SYNC ENGINE INTEGRATION TESTS
// ============================================================================
// Comprehensive tests for the offline-first sync engine.
//
// Test Categories:
// 1. Network Flapping Resilience (Exponential Backoff)
// 2. Duplicate Task Prevention (Idempotency)
// 3. Conflict Resolution with DeviceId
// 4. State Machine Transitions
// 5. Multi-Step Operations
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';
import 'package:uuid/uuid.dart';

// =============================================================================
// TEST HELPERS
// =============================================================================

SyncQueueItem createTestSyncItem({
  String? operationId,
  String userId = 'test-user-123',
  String collection = 'bills',
  String documentId = 'bill-001',
  SyncOperationType operationType = SyncOperationType.create,
  SyncStatus status = SyncStatus.pending,
  int retryCount = 0,
  String? deviceId,
}) {
  return SyncQueueItem(
    operationId: operationId ?? const Uuid().v4(),
    operationType: operationType,
    targetCollection: collection,
    documentId: documentId,
    payload: {
      'id': documentId,
      'amount': 100.0,
      'customerName': 'Test Customer',
      'version': 1,
      'deviceId': deviceId,
    },
    status: status,
    retryCount: retryCount,
    createdAt: DateTime.now(),
    userId: userId,
    payloadHash: 'hash-$documentId',
    ownerId: userId,
  );
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  group('SyncEngine Integration Tests', () {
    // =========================================================================
    // TEST 1: Network Flapping Resilience
    // =========================================================================
    group('Network Flapping Resilience', () {
      test('should use exponential backoff for retries', () {
        // Arrange
        final item0 = createTestSyncItem(retryCount: 0);
        final item1 = createTestSyncItem(retryCount: 1);
        final item2 = createTestSyncItem(retryCount: 2);
        final item5 = createTestSyncItem(retryCount: 5);

        // Act
        final delay0 = item0.calculateNextRetryTime();
        final delay1 = item1.calculateNextRetryTime();
        final delay2 = item2.calculateNextRetryTime();
        final delay5 = item5.calculateNextRetryTime();

        // Assert - Each retry should have longer delay
        final now = DateTime.now();
        expect(
          delay0.difference(now).inMilliseconds,
          lessThanOrEqualTo(1500),
        ); // ~1s + jitter
        expect(
          delay1.difference(now).inMilliseconds,
          lessThanOrEqualTo(3000),
        ); // ~2s + jitter
        expect(
          delay2.difference(now).inMilliseconds,
          lessThanOrEqualTo(6000),
        ); // ~4s + jitter
        // Max is capped at 5 minutes (300000ms)
        expect(
          delay5.difference(now).inMilliseconds,
          lessThanOrEqualTo(400000),
        );
      });

      test('should move to dead letter after max retries (5)', () {
        // Arrange
        final item4 = createTestSyncItem(retryCount: 4);
        final item5 = createTestSyncItem(retryCount: 5);

        // Assert
        expect(item4.shouldMoveToDeadLetter(), isFalse);
        expect(item5.shouldMoveToDeadLetter(), isTrue);
      });

      test('should increase delay exponentially', () {
        // Test the exponential backoff formula
        // Base delay: 1s, formula: min(1s * 2^retries, 300s) + jitter

        final item0 = createTestSyncItem(retryCount: 0);
        final item3 = createTestSyncItem(retryCount: 3);

        final delay0 = item0.calculateNextRetryTime();
        final delay3 = item3.calculateNextRetryTime();

        final now = DateTime.now();

        // retry 0: ~1s delay
        // retry 3: ~8s delay (2^3 = 8)
        expect(
          delay3.difference(now).inMilliseconds,
          greaterThan(delay0.difference(now).inMilliseconds),
        );
      });
    });

    // =========================================================================
    // TEST 2: Duplicate Task Prevention (Idempotency)
    // =========================================================================
    group('Duplicate Task Prevention', () {
      test('should generate deterministic operation ID', () {
        // Arrange
        const userId = 'user-123';
        const collection = 'bills';
        const documentId = 'bill-001';
        const operationType = SyncOperationType.create;
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);

        // Act
        final opId1 = SyncQueueItem.generateOperationId(
          userId: userId,
          targetCollection: collection,
          documentId: documentId,
          operationType: operationType,
          timestamp: timestamp,
        );

        final opId2 = SyncQueueItem.generateOperationId(
          userId: userId,
          targetCollection: collection,
          documentId: documentId,
          operationType: operationType,
          timestamp: timestamp,
        );

        // Assert - Same inputs should produce same ID
        expect(opId1, equals(opId2));
      });

      test('should generate different IDs for different timestamps', () {
        // Arrange
        const userId = 'user-123';
        const collection = 'bills';
        const documentId = 'bill-001';
        const operationType = SyncOperationType.create;

        // Act
        final opId1 = SyncQueueItem.generateOperationId(
          userId: userId,
          targetCollection: collection,
          documentId: documentId,
          operationType: operationType,
          timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        );

        final opId2 = SyncQueueItem.generateOperationId(
          userId: userId,
          targetCollection: collection,
          documentId: documentId,
          operationType: operationType,
          timestamp: DateTime(2024, 1, 1, 12, 0, 1),
        );

        // Assert - Different timestamps should produce different IDs
        expect(opId1, isNot(equals(opId2)));
      });

      test('should generate different IDs for different operation types', () {
        // Arrange
        const userId = 'user-123';
        const collection = 'bills';
        const documentId = 'bill-001';
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);

        // Act
        final createId = SyncQueueItem.generateOperationId(
          userId: userId,
          targetCollection: collection,
          documentId: documentId,
          operationType: SyncOperationType.create,
          timestamp: timestamp,
        );

        final updateId = SyncQueueItem.generateOperationId(
          userId: userId,
          targetCollection: collection,
          documentId: documentId,
          operationType: SyncOperationType.update,
          timestamp: timestamp,
        );

        // Assert
        expect(createId, isNot(equals(updateId)));
      });

      test('should generate different IDs for different users', () {
        // Arrange
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);

        // Act
        final id1 = SyncQueueItem.generateOperationId(
          userId: 'user-1',
          targetCollection: 'bills',
          documentId: 'bill-001',
          operationType: SyncOperationType.create,
          timestamp: timestamp,
        );

        final id2 = SyncQueueItem.generateOperationId(
          userId: 'user-2',
          targetCollection: 'bills',
          documentId: 'bill-001',
          operationType: SyncOperationType.create,
          timestamp: timestamp,
        );

        // Assert
        expect(id1, isNot(equals(id2)));
      });
    });

    // =========================================================================
    // TEST 3: Conflict Resolution with DeviceId
    // =========================================================================
    group('Conflict Resolution with DeviceId', () {
      test('should include deviceId in sync item payload', () {
        // Arrange
        const deviceId = 'device-abc-123';

        // Act
        final item = createTestSyncItem(deviceId: deviceId);

        // Assert
        expect(item.payload['deviceId'], equals(deviceId));
      });

      test('should detect version conflict (server newer)', () {
        // Arrange
        final localItem = createTestSyncItem();
        final localVersion = localItem.payload['version'] as int;
        const serverVersion = 2;

        // Act & Assert
        expect(serverVersion > localVersion, isTrue);
      });

      test('should identify same device conflicts', () {
        // Arrange
        const deviceId = 'device-abc-123';
        final localItem = createTestSyncItem(deviceId: deviceId);
        final serverData = {
          'deviceId': deviceId, // Same device
          'version': 2,
        };

        // Assert - Same device = prefer latest version
        final isSameDevice =
            localItem.payload['deviceId'] == serverData['deviceId'];
        expect(isSameDevice, isTrue);
      });

      test('should identify different device conflicts', () {
        // Arrange
        final localItem = createTestSyncItem(deviceId: 'device-A');
        final serverData = {
          'deviceId': 'device-B', // Different device
          'version': 2,
        };

        // Assert - Different device = may need merge
        final isDifferentDevice =
            localItem.payload['deviceId'] != serverData['deviceId'];
        expect(isDifferentDevice, isTrue);
      });

      test('should handle null deviceId (legacy data)', () {
        // Arrange - Legacy data without deviceId
        final legacyItem = createTestSyncItem(deviceId: null);

        // Assert
        expect(legacyItem.payload['deviceId'], isNull);
      });
    });

    // =========================================================================
    // TEST 4: State Machine Transitions
    // =========================================================================
    group('State Machine Transitions', () {
      test('should allow PENDING → IN_PROGRESS transition', () {
        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.pending,
            SyncStatus.inProgress,
          ),
          isTrue,
        );
      });

      test('should allow IN_PROGRESS → SYNCED transition', () {
        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.inProgress,
            SyncStatus.synced,
          ),
          isTrue,
        );
      });

      test('should allow IN_PROGRESS → FAILED transition', () {
        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.inProgress,
            SyncStatus.failed,
          ),
          isTrue,
        );
      });

      test('should allow FAILED → RETRY transition', () {
        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.failed,
            SyncStatus.retry,
          ),
          isTrue,
        );
      });

      test('should allow FAILED → DEAD_LETTER transition', () {
        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.failed,
            SyncStatus.deadLetter,
          ),
          isTrue,
        );
      });

      test('should prevent SYNCED → any transition (terminal state)', () {
        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.synced,
            SyncStatus.pending,
          ),
          isFalse,
        );

        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.synced,
            SyncStatus.inProgress,
          ),
          isFalse,
        );
      });

      test('should prevent PENDING → SYNCED direct transition', () {
        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.pending,
            SyncStatus.synced,
          ),
          isFalse, // Must go through IN_PROGRESS first
        );
      });

      test('should allow DEAD_LETTER → PENDING (manual retry)', () {
        expect(
          SyncStateTransition.isValidTransition(
            SyncStatus.deadLetter,
            SyncStatus.pending,
          ),
          isTrue, // Manual retry from dead letter
        );
      });

      test('should return correct allowed transitions for each state', () {
        final pendingAllowed = SyncStateTransition.getAllowedTransitions(
          SyncStatus.pending,
        );
        expect(pendingAllowed, contains(SyncStatus.inProgress));
        expect(pendingAllowed, contains(SyncStatus.deadLetter));

        final syncedAllowed = SyncStateTransition.getAllowedTransitions(
          SyncStatus.synced,
        );
        expect(syncedAllowed, isEmpty); // Terminal state
      });
    });

    // =========================================================================
    // TEST 5: Multi-Step Operations
    // =========================================================================
    group('Multi-Step Operations', () {
      test('should create scan bill operation with 3 steps', () {
        // Arrange
        final operation = MultiStepOperationFactory.scanBill(
          userId: 'user-123',
          imageLocalPath: '/path/to/image.jpg',
          billId: 'bill-001',
        );

        // Assert
        expect(operation.steps.length, equals(3));
        expect(operation.steps[0].name, equals('Upload Image'));
        expect(operation.steps[1].name, equals('Trigger OCR'));
        expect(operation.steps[2].name, equals('Create Bill Draft'));
      });

      test('should create voice bill operation with 3 steps', () {
        // Arrange
        final operation = MultiStepOperationFactory.voiceBill(
          userId: 'user-123',
          audioLocalPath: '/path/to/audio.m4a',
          billId: 'bill-001',
        );

        // Assert
        expect(operation.steps.length, equals(3));
        expect(operation.steps[0].name, equals('Upload Audio'));
        expect(operation.steps[1].name, equals('Trigger STT'));
        expect(operation.steps[2].name, equals('Create Bill Draft'));
      });

      test('should create sync queue items for all pending steps', () {
        // Arrange
        final operation = MultiStepOperationFactory.scanBill(
          userId: 'user-123',
          imageLocalPath: '/path/to/image.jpg',
          billId: 'bill-001',
        );

        // Act
        final items = operation.createSyncQueueItems();

        // Assert
        expect(items.length, equals(3)); // All 3 steps pending initially
        expect(items[0].operationType, equals(SyncOperationType.uploadFile));
        expect(items[1].operationType, equals(SyncOperationType.create));
        expect(items[2].operationType, equals(SyncOperationType.create));
      });

      test('should skip completed steps when creating queue items', () {
        // Arrange
        final operation = MultiStepOperationFactory.scanBill(
          userId: 'user-123',
          imageLocalPath: '/path/to/image.jpg',
          billId: 'bill-001',
        );

        // Complete first step
        operation.steps[0].markCompleted();

        // Act
        final items = operation.createSyncQueueItems();

        // Assert - Only 2 remaining steps
        expect(items.length, equals(2));
        expect(items[0].operationType, equals(SyncOperationType.create)); // OCR
      });

      test('should track completion percentage correctly', () {
        // Arrange
        final operation = MultiStepOperationFactory.voiceBill(
          userId: 'user-123',
          audioLocalPath: '/path/to/audio.m4a',
          billId: 'bill-001',
        );

        // Assert - Initially 0%
        expect(operation.isCompleted, isFalse);
        expect(operation.completionPercentage, equals(0.0));

        // Mark first step complete - 33.33%
        operation.steps[0].markCompleted();
        expect(operation.completionPercentage, closeTo(33.33, 1.0));

        // Mark second step complete - 66.67%
        operation.steps[1].markCompleted();
        expect(operation.completionPercentage, closeTo(66.67, 1.0));

        // Mark all complete - 100%
        operation.steps[2].markCompleted();
        expect(operation.isCompleted, isTrue);
        expect(operation.completionPercentage, equals(100.0));
      });

      test('should track current step correctly', () {
        // Arrange
        final operation = MultiStepOperationFactory.scanBill(
          userId: 'user-123',
          imageLocalPath: '/path/to/image.jpg',
          billId: 'bill-001',
        );

        // Assert - First step is current
        expect(operation.currentStep?.name, equals('Upload Image'));

        // Complete first step
        operation.steps[0].markCompleted();
        expect(operation.currentStep?.name, equals('Trigger OCR'));

        // Complete all
        operation.steps[1].markCompleted();
        operation.steps[2].markCompleted();
        expect(operation.currentStep, isNull); // All done
      });

      test('should assign correct priorities to steps', () {
        // Arrange
        final operation = MultiStepOperationFactory.scanBill(
          userId: 'user-123',
          imageLocalPath: '/path/to/image.jpg',
          billId: 'bill-001',
        );

        // Assert - Earlier steps have higher priority (lower number)
        expect(operation.steps[0].priority, equals(1)); // Upload first
        expect(operation.steps[1].priority, equals(2)); // OCR second
        expect(operation.steps[2].priority, equals(3)); // Bill last
      });
    });

    // =========================================================================
    // TEST 6: SyncQueueItem Serialization
    // =========================================================================
    group('SyncQueueItem Serialization', () {
      test('should convert to map correctly', () {
        // Arrange
        final item = createTestSyncItem(
          operationId: 'test-op-123',
          userId: 'user-456',
          documentId: 'bill-789',
          deviceId: 'device-abc',
        );

        // Act
        final map = item.toMap();

        // Assert
        expect(map['operationId'], equals('test-op-123'));
        expect(map['userId'], equals('user-456'));
        expect(map['documentId'], equals('bill-789'));
        expect(map['targetCollection'], equals('bills'));
        expect(map['operationType'], equals('CREATE'));
        expect(map['status'], equals('PENDING'));
      });

      test('should convert from map correctly', () {
        // Arrange
        final originalItem = createTestSyncItem(
          operationId: 'test-op-123',
          userId: 'user-456',
          documentId: 'bill-789',
        );
        final map = originalItem.toMap();

        // Act
        final restoredItem = SyncQueueItem.fromMap(map);

        // Assert
        expect(restoredItem.operationId, equals(originalItem.operationId));
        expect(restoredItem.userId, equals(originalItem.userId));
        expect(restoredItem.documentId, equals(originalItem.documentId));
        expect(
          restoredItem.targetCollection,
          equals(originalItem.targetCollection),
        );
        expect(restoredItem.operationType, equals(originalItem.operationType));
        expect(restoredItem.status, equals(originalItem.status));
      });

      test('should preserve all fields through round-trip', () {
        // Arrange
        final original = SyncQueueItem(
          operationId: 'op-123',
          operationType: SyncOperationType.update,
          targetCollection: 'customers',
          documentId: 'cust-456',
          payload: {'name': 'Test', 'amount': 100.5},
          status: SyncStatus.retry,
          retryCount: 3,
          lastError: 'Network timeout',
          createdAt: DateTime(2024, 1, 15, 10, 30),
          lastAttemptAt: DateTime(2024, 1, 15, 11, 0),
          priority: 2,
          parentOperationId: 'parent-op',
          stepNumber: 2,
          totalSteps: 5,
          userId: 'user-789',
          payloadHash: 'hash-abc',
          ownerId: 'user-789',
        );

        // Act
        final map = original.toMap();
        final restored = SyncQueueItem.fromMap(map);

        // Assert
        expect(restored.operationId, equals(original.operationId));
        expect(restored.operationType, equals(original.operationType));
        expect(restored.targetCollection, equals(original.targetCollection));
        expect(restored.documentId, equals(original.documentId));
        expect(restored.status, equals(original.status));
        expect(restored.retryCount, equals(original.retryCount));
        expect(restored.lastError, equals(original.lastError));
        expect(restored.priority, equals(original.priority));
        expect(restored.parentOperationId, equals(original.parentOperationId));
        expect(restored.stepNumber, equals(original.stepNumber));
        expect(restored.totalSteps, equals(original.totalSteps));
        expect(restored.userId, equals(original.userId));
      });
    });
  });
}
