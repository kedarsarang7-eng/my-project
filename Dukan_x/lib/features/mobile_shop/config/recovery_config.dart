/// Safe Recovery Actions Configuration (Flutter)
///
/// Defines what the client does on various failure modes. Recovery actions
/// are safe and deterministic — never fabricate success or lose queued work.
///
/// Requirements: 12.4–12.6, GR-4
library;

import 'package:flutter/foundation.dart';

/// A defined recovery action for a failure category.
@immutable
class RecoveryAction {
  /// Failure category identifier.
  final String failureCategory;

  /// Human-readable description.
  final String description;

  /// Automated system action.
  final String systemAction;

  /// User-facing guidance.
  final String userGuidance;

  /// Whether the system can auto-recover without user intervention.
  final bool autoRecoverable;

  /// Maximum auto-recovery attempts before escalating.
  final int maxAutoAttempts;

  const RecoveryAction({
    required this.failureCategory,
    required this.description,
    required this.systemAction,
    required this.userGuidance,
    required this.autoRecoverable,
    required this.maxAutoAttempts,
  });
}

/// Recovery configuration.
@immutable
class RecoveryConfig {
  /// Defined recovery actions by failure category.
  final List<RecoveryAction> actions;

  const RecoveryConfig({required this.actions});

  /// Returns the recovery action for the given [failureCategory], or null.
  RecoveryAction? getAction(String failureCategory) {
    return actions
        .where((a) => a.failureCategory == failureCategory)
        .firstOrNull;
  }
}

/// Default recovery configuration.
const kRecoveryConfig = RecoveryConfig(
  actions: [
    RecoveryAction(
      failureCategory: 'TRANSACTION_CANCELLED',
      description: 'Backend transaction cancelled due to condition failure',
      systemAction: 'Preserve local state; display conflict error',
      userGuidance: 'Reload the item and retry with current version',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    ),
    RecoveryAction(
      failureCategory: 'THROTTLE_EXHAUSTED',
      description: 'Backend throttled after retry budget exhaustion',
      systemAction: 'Show rate-limited indicator; schedule deferred retry',
      userGuidance: 'Wait briefly and retry the operation',
      autoRecoverable: true,
      maxAutoAttempts: 3,
    ),
    RecoveryAction(
      failureCategory: 'AMBIGUOUS_RESPONSE',
      description: 'Backend returned unknown/timeout without confirmed outcome',
      systemAction:
          'Mark operation as pending reconciliation; do not claim success',
      userGuidance:
          'Operation is pending — the system will confirm automatically',
      autoRecoverable: true,
      maxAutoAttempts: 5,
    ),
    RecoveryAction(
      failureCategory: 'SYNC_PUSH_REJECTED',
      description: 'Backend rejected a queued offline mutation',
      systemAction: 'Create conflict record; remove from active push queue',
      userGuidance: 'A conflict was detected — review in the conflicts view',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    ),
    RecoveryAction(
      failureCategory: 'SYNC_PUSH_NETWORK_FAILURE',
      description: 'Network unavailable during sync push attempt',
      systemAction: 'Keep mutation in outbox; schedule retry with backoff',
      userGuidance: 'Operation will sync when connectivity returns',
      autoRecoverable: true,
      maxAutoAttempts: 5,
    ),
    RecoveryAction(
      failureCategory: 'PROVIDER_AMBIGUOUS',
      description: 'External provider returned ambiguous outcome',
      systemAction: 'Mark as pending provider confirmation; do not resubmit',
      userGuidance: 'Provider status is being verified — do not resubmit',
      autoRecoverable: true,
      maxAutoAttempts: 3,
    ),
    RecoveryAction(
      failureCategory: 'SESSION_EXPIRED',
      description: 'Authentication session expired or tenant context lost',
      systemAction: 'Cancel active operations; show session-error state',
      userGuidance: 'Sign in again to continue',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    ),
    RecoveryAction(
      failureCategory: 'TENANT_SWITCH',
      description: 'User switched to a different tenant context',
      systemAction:
          'Cancel network work; release leases; clear memory; open new scope',
      userGuidance: 'Switched to the new business',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    ),
    RecoveryAction(
      failureCategory: 'WEBSOCKET_DISCONNECTED',
      description: 'Real-time connection lost',
      systemAction: 'Reconnect with backoff; perform bounded pull on reconnect',
      userGuidance: 'Real-time updates paused — data stays up to date via pull',
      autoRecoverable: true,
      maxAutoAttempts: 10,
    ),
  ],
);
