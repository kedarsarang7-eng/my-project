/// MobileShop Pending State Manager (Dart)
///
/// Manages pending, unconfirmed, and failed operations. Ensures that
/// operations without [AuthoritativeConfirmation] are never labeled as
/// committed or server-confirmed. Provides typed recovery guidance for
/// the UI layer.
///
/// Requirements: 7.14–7.15, 12.4–12.5, 12.9–12.10; GR-3
library;

import 'package:flutter/foundation.dart';

import '../auth/tenant_context.dart';
import '../database/mobile_shop_database.dart';
import '../repository/mobile_shop_local_repository.dart';

// ─── Recovery Guidance Types ─────────────────────────────────────────────────

/// Classification of recovery action available for a pending/failed operation.
enum RecoveryAction {
  /// Operation can be safely retried (idempotent).
  retry,

  /// Operation requires manual conflict resolution.
  resolveConflict,

  /// Operation must wait for server reconciliation.
  awaitReconciliation,

  /// Operation is terminal — cannot be recovered automatically.
  terminal,

  /// Operation is unknown (not found locally).
  unknown,
}

/// Typed recovery guidance returned to the UI for a pending operation.
@immutable
class RecoveryGuidance {
  /// The operation this guidance applies to.
  final String operationId;

  /// Recommended recovery action.
  final RecoveryAction action;

  /// Whether automatic retry is safe.
  final bool isRetrySafe;

  /// Human-readable reason for the current state.
  final String reason;

  /// Number of attempts already made (for retry budget display).
  final int attemptCount;

  /// Last error message, if any.
  final String? lastError;

  /// The current outbox status of the operation.
  final String? outboxStatus;

  const RecoveryGuidance({
    required this.operationId,
    required this.action,
    required this.isRetrySafe,
    required this.reason,
    required this.attemptCount,
    this.lastError,
    this.outboxStatus,
  });

  /// Whether the operation needs user attention.
  bool get needsUserAction =>
      action == RecoveryAction.resolveConflict ||
      action == RecoveryAction.terminal;

  @override
  String toString() =>
      'RecoveryGuidance(op=$operationId, action=$action, '
      'retrySafe=$isRetrySafe, attempts=$attemptCount)';
}

// ─── Service ─────────────────────────────────────────────────────────────────

/// Manages pending and unconfirmed operations.
///
/// Key rules:
/// - Never labels unconfirmed operations as committed/current.
/// - Failed operations remain pending with recovery details until explicit
///   resolution or successful retry.
/// - Provides typed recovery guidance for the UI.
class PendingStateManager {
  final MobileShopLocalRepository _repository;

  PendingStateManager({required MobileShopLocalRepository repository})
    : _repository = repository;

  /// Keeps an operation in pending state with recovery details.
  ///
  /// Used when synchronization fails or an operation outcome lacks
  /// AuthoritativeConfirmation. The operation remains in the outbox
  /// as queued/failed — it is NOT discarded (Req 7.14, GR-3).
  Future<void> retainAsPending(
    TenantContext context,
    String operationId,
  ) async {
    // Verify tenant isolation
    if (!context.isMobileShop) return;

    // Mark the mutation as failed with a recoverable reason.
    // This keeps it visible in the outbox without discarding it.
    await _repository.markMutationFailed(
      context,
      operationId,
      'Retained as pending: awaiting authoritative confirmation',
    );
  }

  /// Creates a durable conflict for an operation with version mismatch.
  ///
  /// The conflict retains both the local and server versions (Req 7.8).
  /// Neither version is discarded or silently overwritten.
  Future<void> markAsConflicted(
    TenantContext context,
    String operationId, {
    required int localVersion,
    required int serverVersion,
    String entityId = '',
    String entityType = 'IMEI_UNIT',
    int dataModelVersion = 1,
  }) async {
    if (!context.isMobileShop) return;

    final now = DateTime.now();

    final conflict = MobileConflictEntity(
      id: 'pending_conflict_${operationId}_${now.millisecondsSinceEpoch}',
      tenantId: context.tenantId,
      operationId: operationId,
      entityType: entityType,
      entityId: entityId,
      localVersion: localVersion,
      serverVersion: serverVersion,
      reason: 'VERSION_MISMATCH',
      resolutionStatus: ConflictResolutionStatus.unresolved,
      resolutionEvidence: null,
      dataModelVersion: dataModelVersion,
      createdAt: now,
      resolvedAt: null,
      updatedAt: now,
    );

    await _repository.insertConflict(context, conflict);

    // Also mark the outbox mutation as failed so it doesn't get re-pushed.
    await _repository.markMutationFailed(
      context,
      operationId,
      'Conflict: local v$localVersion vs server v$serverVersion',
    );
  }

  /// Returns typed retry/recovery guidance for the UI.
  ///
  /// Inspects the outbox mutation and conflict state to determine
  /// what action the user or system should take. Never labels an
  /// unconfirmed operation as committed (Req 12.9, GR-3).
  Future<RecoveryGuidance> getRecoveryGuidance(
    TenantContext context,
    String operationId,
  ) async {
    if (!context.isMobileShop) {
      return RecoveryGuidance(
        operationId: operationId,
        action: RecoveryAction.unknown,
        isRetrySafe: false,
        reason: 'Non-mobile-shop tenant',
        attemptCount: 0,
      );
    }

    // Check if the operation has an unresolved conflict
    final conflicts = await _repository.listConflicts(
      context,
      resolutionStatus: ConflictResolutionStatus.unresolved,
    );

    final hasConflict = conflicts.any((c) => c.operationId == operationId);

    // Check the outbox for the operation's current state
    final mutations = await _repository.getNextMutations(context, 100);
    final mutation = _findMutation(mutations, operationId);

    if (hasConflict) {
      return RecoveryGuidance(
        operationId: operationId,
        action: RecoveryAction.resolveConflict,
        isRetrySafe: false,
        reason: 'Version conflict detected — requires manual resolution',
        attemptCount: mutation != null ? _getRetryCount(mutation) : 0,
        lastError: 'Version mismatch between local and server state',
        outboxStatus: mutation?.status ?? OutboxStatus.failed,
      );
    }

    if (mutation == null) {
      // Operation not in outbox — may have been sent already or unknown
      return RecoveryGuidance(
        operationId: operationId,
        action: RecoveryAction.unknown,
        isRetrySafe: false,
        reason: 'Operation not found in local outbox',
        attemptCount: 0,
      );
    }

    // Determine guidance based on outbox status
    final status = mutation.status;

    if (status == OutboxStatus.queued) {
      return RecoveryGuidance(
        operationId: operationId,
        action: RecoveryAction.retry,
        isRetrySafe: true,
        reason: 'Queued for next sync cycle',
        attemptCount: _getRetryCount(mutation),
        outboxStatus: status,
      );
    }

    if (status == OutboxStatus.sending) {
      return RecoveryGuidance(
        operationId: operationId,
        action: RecoveryAction.awaitReconciliation,
        isRetrySafe: false,
        reason: 'Currently being sent — awaiting server response',
        attemptCount: _getRetryCount(mutation),
        outboxStatus: status,
      );
    }

    if (status == OutboxStatus.failed) {
      // Failed operations need classification: retryable or terminal
      final isRetryable = _isRetryableFailure(mutation);
      return RecoveryGuidance(
        operationId: operationId,
        action: isRetryable ? RecoveryAction.retry : RecoveryAction.terminal,
        isRetrySafe: isRetryable,
        reason: isRetryable
            ? 'Failed but retry-safe — will be retried next cycle'
            : 'Terminal failure — requires manual intervention',
        attemptCount: _getRetryCount(mutation),
        lastError: 'Operation failed after ${mutation.retryCount} attempts',
        outboxStatus: status,
      );
    }

    if (status == OutboxStatus.sent) {
      // Sent but not yet confirmed — awaiting reconciliation
      return RecoveryGuidance(
        operationId: operationId,
        action: RecoveryAction.awaitReconciliation,
        isRetrySafe: false,
        reason: 'Sent to server — awaiting authoritative confirmation',
        attemptCount: _getRetryCount(mutation),
        outboxStatus: status,
      );
    }

    // Fallback: unknown status
    return RecoveryGuidance(
      operationId: operationId,
      action: RecoveryAction.unknown,
      isRetrySafe: false,
      reason: 'Unknown operation status: $status',
      attemptCount: 0,
      outboxStatus: status,
    );
  }

  /// Finds a mutation in the list by operation ID.
  MobileOutboxMutationEntity? _findMutation(
    List<MobileOutboxMutationEntity> mutations,
    String operationId,
  ) {
    for (final m in mutations) {
      if (m.operationId == operationId) return m;
    }
    return null;
  }

  /// Extracts retry count from mutation entity.
  int _getRetryCount(MobileOutboxMutationEntity mutation) {
    return mutation.retryCount;
  }

  /// Determines if a failed operation is retry-safe.
  ///
  /// Per Req 12.5: if a failed operation has no documented retry-safe
  /// classification, it is terminal until reconciliation or explicit user
  /// action establishes a safe retry.
  bool _isRetryableFailure(MobileOutboxMutationEntity mutation) {
    // If retryCount is still below maxRetries, the operation can be retried.
    if (mutation.retryCount < mutation.maxRetries) {
      return true;
    }

    // Per Req 12.5: exhausted retry budget → terminal until proven safe
    return false;
  }
}
