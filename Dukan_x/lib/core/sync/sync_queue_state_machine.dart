// ============================================================================
// SYNC QUEUE STATE MACHINE
// ============================================================================
// Manages the state transitions and persistence of sync operations
//
// States:
// - PENDING: Operation created, waiting to sync
// - IN_PROGRESS: Currently syncing to Firestore
// - SYNCED: Successfully synced
// - FAILED: Sync failed (will retry)
// - RETRY: Scheduled for retry with backoff
// - DEAD_LETTER: Failed after max retries, needs manual intervention
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';

/// Sync operation states
enum SyncStatus {
  pending('PENDING'),
  inProgress('IN_PROGRESS'),
  synced('SYNCED'),
  failed('FAILED'),
  retry('RETRY'),
  deadLetter('DEAD_LETTER');

  final String value;
  const SyncStatus(this.value);

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SyncStatus.pending,
    );
  }
}

/// Operation types
enum SyncOperationType {
  create('CREATE'),
  update('UPDATE'),
  delete('DELETE'),
  uploadFile('UPLOAD_FILE');

  final String value;
  const SyncOperationType(this.value);

  static SyncOperationType fromString(String value) {
    return SyncOperationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SyncOperationType.create,
    );
  }
}

/// Sync Queue Entry Model
class SyncQueueItem {
  final String operationId;
  final SyncOperationType operationType;
  final String targetCollection;
  final String documentId;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final DateTime? syncedAt;
  final int priority;
  final String? parentOperationId;
  final int stepNumber;
  final int totalSteps;
  final String userId;

  /// Device ID for multi-device conflict resolution
  final String? deviceId;

  // NEW: Integrity Check
  final String payloadHash;

  // NEW: Strict Ordering Group
  final String? dependencyGroup;

  // NEW: Owner Isolation
  final String ownerId;

  SyncQueueItem({
    required this.operationId,
    required this.operationType,
    required this.targetCollection,
    required this.documentId,
    required this.payload,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    this.lastAttemptAt,
    this.syncedAt,
    this.priority = 5,
    this.parentOperationId,
    this.stepNumber = 1,
    this.totalSteps = 1,
    required this.userId,
    this.deviceId,
    required this.payloadHash,
    this.dependencyGroup,
    required this.ownerId,
  });

  /// Generate deterministic operation ID for idempotency
  static String generateOperationId({
    required String userId,
    required String targetCollection,
    required String documentId,
    required SyncOperationType operationType,
    DateTime? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now();
    final input =
        '$userId:$targetCollection:$documentId:${operationType.value}:${ts.millisecondsSinceEpoch}';
    // Use UUID v5 for deterministic ID based on input
    return const Uuid().v5(Uuid.NAMESPACE_URL, input);
  }

  /// Create a new sync queue item
  factory SyncQueueItem.create({
    required String userId,
    required SyncOperationType operationType,
    required String targetCollection,
    required String documentId,
    required Map<String, dynamic> payload,
    int priority = 5,
    String? parentOperationId,
    int stepNumber = 1,
    int totalSteps = 1,
    String? deviceId,
    String? dependencyGroup,
    String? ownerId,
  }) {
    final now = DateTime.now();
    // Compute hash
    final payloadString = jsonEncode(payload);
    // Simple hash for now (in prod use actual SHA256)
    final payloadHash = payloadString.hashCode
        .toString(); // Placeholder for SHA-256

    return SyncQueueItem(
      operationId: generateOperationId(
        userId: userId,
        targetCollection: targetCollection,
        documentId: documentId,
        operationType: operationType,
        timestamp: now,
      ),
      operationType: operationType,
      targetCollection: targetCollection,
      documentId: documentId,
      payload: payload,
      status: SyncStatus.pending,
      createdAt: now,
      priority: priority,
      parentOperationId: parentOperationId,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      userId: userId,
      deviceId: deviceId,
      payloadHash: payloadHash,
      dependencyGroup: dependencyGroup,
      ownerId: ownerId ?? userId, // Default to userId if not provided
    );
  }

  /// Copy with new values
  SyncQueueItem copyWith({
    SyncStatus? status,
    int? retryCount,
    String? lastError,
    DateTime? lastAttemptAt,
    DateTime? syncedAt,
    String? deviceId,
    String? payloadHash,
    String? dependencyGroup,
    String? ownerId,
  }) {
    return SyncQueueItem(
      operationId: operationId,
      operationType: operationType,
      targetCollection: targetCollection,
      documentId: documentId,
      payload: payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      priority: priority,
      parentOperationId: parentOperationId,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      userId: userId,
      deviceId: deviceId ?? this.deviceId,
      payloadHash: payloadHash ?? this.payloadHash,
      dependencyGroup: dependencyGroup ?? this.dependencyGroup,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'operationType': operationType.value,
      'targetCollection': targetCollection,
      'documentId': documentId,
      'payload': jsonEncode(payload),
      'status': status.value,
      'retryCount': retryCount,
      'lastError': lastError,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'priority': priority,
      'parentOperationId': parentOperationId,
      'stepNumber': stepNumber,
      'totalSteps': totalSteps,
      'userId': userId,
      'deviceId': deviceId,
      'payloadHash': payloadHash,
      'dependencyGroup': dependencyGroup,
      'ownerId': ownerId,
    };
  }

  /// Create from database map
  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      operationId: map['operationId'] as String,
      operationType: SyncOperationType.fromString(
        map['operationType'] as String,
      ),
      targetCollection: map['targetCollection'] as String,
      documentId: map['documentId'] as String,
      payload: map['payload'] is String
          ? jsonDecode(map['payload'] as String) as Map<String, dynamic>
          : map['payload'] as Map<String, dynamic>,
      status: SyncStatus.fromString(map['status'] as String),
      retryCount: map['retryCount'] as int? ?? 0,
      lastError: map['lastError'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateTime.parse(map['lastAttemptAt'] as String)
          : null,
      syncedAt: map['syncedAt'] != null
          ? DateTime.parse(map['syncedAt'] as String)
          : null,
      priority: map['priority'] as int? ?? 5,
      parentOperationId: map['parentOperationId'] as String?,
      stepNumber: map['stepNumber'] as int? ?? 1,
      totalSteps: map['totalSteps'] as int? ?? 1,
      userId: map['userId'] as String,
      deviceId: map['deviceId'] as String?,
      payloadHash: map['payloadHash'] as String? ?? '',
      dependencyGroup: map['dependencyGroup'] as String?,
      ownerId: map['ownerId'] as String? ?? map['userId'] as String,
    );
  }

  /// Calculate next retry time with exponential backoff + jitter
  DateTime calculateNextRetryTime() {
    // Base delay: 1 second, max delay: 5 minutes
    const baseDelayMs = 1000;
    const maxDelayMs = 300000; // 5 minutes

    // Exponential backoff: 2^retryCount * baseDelay
    final exponentialDelay = min(
      baseDelayMs * pow(2, retryCount).toInt(),
      maxDelayMs,
    );

    // Add jitter (random 0-25% of delay)
    final jitter = Random().nextInt((exponentialDelay * 0.25).toInt());
    final totalDelay = exponentialDelay + jitter;

    return DateTime.now().add(Duration(milliseconds: totalDelay));
  }

  /// Check if should move to dead letter (max 5 retries)
  bool shouldMoveToDeadLetter() {
    return retryCount >= 5;
  }

  @override
  String toString() {
    return 'SyncQueueItem(operationId: $operationId, type: ${operationType.value}, '
        'collection: $targetCollection, docId: $documentId, status: ${status.value}, '
        'retries: $retryCount)';
  }
}

/// State transition rules for sync queue
class SyncStateTransition {
  /// Valid state transitions
  static const Map<SyncStatus, List<SyncStatus>> validTransitions = {
    SyncStatus.pending: [SyncStatus.inProgress, SyncStatus.deadLetter],
    SyncStatus.inProgress: [
      SyncStatus.synced,
      SyncStatus.failed,
      SyncStatus.retry,
    ],
    SyncStatus.failed: [SyncStatus.retry, SyncStatus.deadLetter],
    SyncStatus.retry: [
      SyncStatus.pending,
      SyncStatus.inProgress,
      SyncStatus.deadLetter,
    ],
    SyncStatus.synced: [], // Terminal state
    SyncStatus.deadLetter: [SyncStatus.pending], // Can be manually retried
  };

  /// Check if transition is valid
  static bool isValidTransition(SyncStatus from, SyncStatus to) {
    return validTransitions[from]?.contains(to) ?? false;
  }

  /// Get allowed transitions from current state
  static List<SyncStatus> getAllowedTransitions(SyncStatus current) {
    return validTransitions[current] ?? [];
  }
}

/// Multi-step operation tracker
class MultiStepOperation {
  final String parentOperationId;
  final String userId;
  final String description;
  final List<OperationStep> steps;
  final DateTime createdAt;

  MultiStepOperation({
    required this.parentOperationId,
    required this.userId,
    required this.description,
    required this.steps,
    required this.createdAt,
  });

  /// Get current step (first non-completed step)
  OperationStep? get currentStep {
    try {
      return steps.firstWhere((s) => !s.isCompleted);
    } catch (_) {
      return null;
    }
  }

  /// Check if all steps are completed
  bool get isCompleted => steps.every((s) => s.isCompleted);

  /// Get completion percentage
  double get completionPercentage {
    final completed = steps.where((s) => s.isCompleted).length;
    return steps.isEmpty ? 0 : (completed / steps.length) * 100;
  }

  /// Create sync queue items for all pending steps
  List<SyncQueueItem> createSyncQueueItems() {
    return steps.asMap().entries.where((e) => !e.value.isCompleted).map((
      entry,
    ) {
      final index = entry.key;
      final step = entry.value;
      return SyncQueueItem.create(
        userId: userId,
        operationType: step.operationType,
        targetCollection: step.targetCollection,
        documentId: step.documentId,
        payload: step.payload,
        priority: step.priority,
        parentOperationId: parentOperationId,
        stepNumber: index + 1,
        totalSteps: steps.length,
      );
    }).toList();
  }
}

/// Individual step in a multi-step operation
class OperationStep {
  final String name;
  final SyncOperationType operationType;
  final String targetCollection;
  final String documentId;
  final Map<String, dynamic> payload;
  final int priority;
  bool isCompleted;
  String? error;
  DateTime? completedAt;

  OperationStep({
    required this.name,
    required this.operationType,
    required this.targetCollection,
    required this.documentId,
    required this.payload,
    this.priority = 5,
    this.isCompleted = false,
    this.error,
    this.completedAt,
  });

  void markCompleted() {
    isCompleted = true;
    completedAt = DateTime.now();
  }

  void markFailed(String errorMessage) {
    error = errorMessage;
  }
}

/// Factory for creating common multi-step operations
class MultiStepOperationFactory {
  static const _uuid = Uuid();

  /// Create a Scan Bill multi-step operation
  static MultiStepOperation scanBill({
    required String userId,
    required String imageLocalPath,
    required String billId,
  }) {
    final parentId = _uuid.v4();
    return MultiStepOperation(
      parentOperationId: parentId,
      userId: userId,
      description: 'Scan Bill: Upload image, OCR, create bill',
      createdAt: DateTime.now(),
      steps: [
        OperationStep(
          name: 'Upload Image',
          operationType: SyncOperationType.uploadFile,
          targetCollection: 'bill_images',
          documentId: billId,
          payload: {
            'localPath': imageLocalPath,
            'remotePath': 'vendors/$userId/bills/$billId/receipt.jpg',
          },
          priority: 1,
        ),
        OperationStep(
          name: 'Trigger OCR',
          operationType: SyncOperationType.create,
          targetCollection: 'ocr_jobs',
          documentId: billId,
          payload: {'billId': billId, 'status': 'pending'},
          priority: 2,
        ),
        OperationStep(
          name: 'Create Bill Draft',
          operationType: SyncOperationType.create,
          targetCollection: 'bills',
          documentId: billId,
          payload: {'id': billId, 'status': 'DRAFT', 'source': 'SCAN'},
          priority: 3,
        ),
      ],
    );
  }

  /// Create a Voice Bill multi-step operation
  static MultiStepOperation voiceBill({
    required String userId,
    required String audioLocalPath,
    required String billId,
  }) {
    final parentId = _uuid.v4();
    return MultiStepOperation(
      parentOperationId: parentId,
      userId: userId,
      description: 'Voice Bill: Upload audio, STT, NLP, create bill',
      createdAt: DateTime.now(),
      steps: [
        OperationStep(
          name: 'Upload Audio',
          operationType: SyncOperationType.uploadFile,
          targetCollection: 'voice_recordings',
          documentId: billId,
          payload: {
            'localPath': audioLocalPath,
            'remotePath': 'users/$userId/bills/$billId/voice.m4a',
          },
          priority: 1,
        ),
        OperationStep(
          name: 'Trigger STT',
          operationType: SyncOperationType.create,
          targetCollection: 'stt_jobs',
          documentId: billId,
          payload: {'billId': billId, 'status': 'pending'},
          priority: 2,
        ),
        OperationStep(
          name: 'Create Bill Draft',
          operationType: SyncOperationType.create,
          targetCollection: 'bills',
          documentId: billId,
          payload: {'id': billId, 'status': 'DRAFT', 'source': 'VOICE'},
          priority: 3,
        ),
      ],
    );
  }
}
