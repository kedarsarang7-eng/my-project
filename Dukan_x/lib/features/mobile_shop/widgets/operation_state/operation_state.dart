/// OperationState — Centralized Visible Operation State Model (Dart)
///
/// A sealed class hierarchy defining ALL possible operation states for any
/// MobileShop screen or component. Unlike [ReconciliationStatusDisplay] which
/// handles billing/sync states specifically, this is a CENTRALIZED system
/// usable by ALL screens for ANY operation.
///
/// Features:
/// - 10 distinct states: loading, empty, disabled, pending, stale,
///   conflicted, unavailable, failed, complete, signedOut
/// - Typed [RecoveryAction] with correlation/retry guidance
/// - Progress announcements for screen readers (Semantics liveRegion)
/// - Integration with existing [ConsistencyOutcome], [CommerceOutcome],
///   [ScreenState], and [KpiState]
/// - Never shows false success (GR-3)
///
/// Requirements: 7.14, 9.1–9.6, 11.7–11.8, 12.4–12.10; GR-3
library;

import 'package:flutter/foundation.dart';

// ─── Recovery Action ─────────────────────────────────────────────────────────

/// The type of recovery action available for a failed or retryable operation.
enum RecoveryActionType {
  /// Retry the same operation with the same identity.
  retry,

  /// Contact support with the correlation ID.
  contactSupport,

  /// Sign in again (session expired).
  signIn,

  /// View and resolve conflicts manually.
  viewConflicts,

  /// Wait for reconciliation to complete.
  waitForReconciliation,

  /// Dismiss the error and continue.
  dismiss,

  /// Navigate to a detail view for more information.
  viewDetails,
}

/// Typed recovery action exposing correlation ID, retryable flag,
/// and suggested user action.
///
/// Every operation failure carries at least one [RecoveryAction] so the UI
/// can present meaningful guidance rather than a generic error.
@immutable
class RecoveryAction {
  /// The type of recovery action suggested.
  final RecoveryActionType type;

  /// Human-readable label for the action button/link.
  final String label;

  /// Whether the operation can be retried automatically.
  final bool retryable;

  /// Correlation ID for tracing (included in support contact).
  final String? correlationId;

  /// Operation ID for retry identity reuse.
  final String? operationId;

  /// Optional description providing more context.
  final String? description;

  const RecoveryAction({
    required this.type,
    required this.label,
    this.retryable = false,
    this.correlationId,
    this.operationId,
    this.description,
  });

  /// Factory: retry action with operation identity.
  const RecoveryAction.retry({
    required String operationId,
    String? correlationId,
  }) : this(
         type: RecoveryActionType.retry,
         label: 'Retry',
         retryable: true,
         operationId: operationId,
         correlationId: correlationId,
       );

  /// Factory: contact support action.
  const RecoveryAction.contactSupport({required String correlationId})
    : this(
        type: RecoveryActionType.contactSupport,
        label: 'Contact Support',
        retryable: false,
        correlationId: correlationId,
      );

  /// Factory: sign in action.
  const RecoveryAction.signIn()
    : this(type: RecoveryActionType.signIn, label: 'Sign In', retryable: false);

  /// Factory: view conflicts action.
  const RecoveryAction.viewConflicts({String? correlationId})
    : this(
        type: RecoveryActionType.viewConflicts,
        label: 'View Conflicts',
        retryable: false,
        correlationId: correlationId,
      );
}

// ─── Operation State ─────────────────────────────────────────────────────────

/// Sealed class representing every possible visible operation state.
///
/// Each state carries contextual data (message, recovery actions, timestamps)
/// enabling the UI to render appropriate visuals, accessibility labels,
/// and user actions.
///
/// The "complete" state requires authoritative confirmation (GR-3):
/// only [OperationComplete] represents success, and it MUST carry
/// a non-null [confirmedAt] timestamp proving backend confirmation.
@immutable
sealed class OperationState {
  /// Human-readable label for this state.
  String get label;

  /// Accessibility announcement for screen readers.
  String get accessibilityAnnouncement;

  /// Whether the state represents a terminal condition (no further change expected).
  bool get isTerminal;

  /// Available recovery actions (empty for non-error states).
  List<RecoveryAction> get recoveryActions;

  const OperationState();
}

/// Loading state — operation in progress, no result yet.
///
/// Prevents "spinner forever" with optional [startedAt] for timeout detection.
@immutable
class OperationLoading extends OperationState {
  /// Optional message describing what is being loaded.
  final String? message;

  /// When the loading started (for timeout detection).
  final DateTime? startedAt;

  /// Percentage progress (0.0–1.0) if known.
  final double? progress;

  const OperationLoading({this.message, this.startedAt, this.progress});

  @override
  String get label => message ?? 'Loading…';

  @override
  String get accessibilityAnnouncement => progress != null
      ? 'Loading: ${(progress! * 100).round()} percent complete'
      : 'Loading${message != null ? ': $message' : ''}';

  @override
  bool get isTerminal => false;

  @override
  List<RecoveryAction> get recoveryActions => const [];
}

/// Empty state — confirmed no data exists (not an error).
@immutable
class OperationEmpty extends OperationState {
  /// Description of what is empty.
  final String message;

  /// Whether zero should be displayed (per metric contract).
  final bool showZero;

  const OperationEmpty({
    this.message = 'No items found',
    this.showZero = false,
  });

  @override
  String get label => message;

  @override
  String get accessibilityAnnouncement => message;

  @override
  bool get isTerminal => true;

  @override
  List<RecoveryAction> get recoveryActions => const [];
}

/// Disabled state — action is unavailable due to missing preconditions.
@immutable
class OperationDisabled extends OperationState {
  /// Why the action is disabled.
  final String reason;

  /// The precondition that is not met.
  final DisabledReason disabledReason;

  const OperationDisabled({
    required this.reason,
    this.disabledReason = DisabledReason.generic,
  });

  @override
  String get label => reason;

  @override
  String get accessibilityAnnouncement => 'Action disabled: $reason';

  @override
  bool get isTerminal => true;

  @override
  List<RecoveryAction> get recoveryActions => switch (disabledReason) {
    DisabledReason.signInRequired => [const RecoveryAction.signIn()],
    DisabledReason.permissionRequired => const [],
    DisabledReason.offline => const [],
    DisabledReason.generic => const [],
  };
}

/// Reason an action is disabled.
enum DisabledReason { signInRequired, permissionRequired, offline, generic }

/// Pending state — operation accepted locally or by server, awaiting confirmation.
///
/// Never displayed as "committed" or "successful" (GR-3, Req 12.9).
@immutable
class OperationPending extends OperationState {
  /// Description of what is pending.
  final String message;

  /// The operation being tracked.
  final String? operationId;

  /// Whether the operation is queued locally (offline) or accepted by server.
  final PendingKind kind;

  /// When the pending state began.
  final DateTime? startedAt;

  const OperationPending({
    this.message = 'Awaiting confirmation…',
    this.operationId,
    this.kind = PendingKind.localQueued,
    this.startedAt,
  });

  @override
  String get label => switch (kind) {
    PendingKind.localQueued => 'Pending Sync',
    PendingKind.serverAccepted => 'Processing',
    PendingKind.reconciling => 'Reconciling',
  };

  @override
  String get accessibilityAnnouncement =>
      'Operation pending: $message. Status: $label';

  @override
  bool get isTerminal => false;

  @override
  List<RecoveryAction> get recoveryActions => [
    if (operationId != null)
      RecoveryAction(
        type: RecoveryActionType.viewDetails,
        label: 'View Status',
        operationId: operationId,
      ),
  ];
}

/// Kind of pending state.
enum PendingKind {
  /// Queued locally, not yet sent to server.
  localQueued,

  /// Server accepted, reconciliation in progress.
  serverAccepted,

  /// Active reconciliation underway.
  reconciling,
}

/// Stale state — previously confirmed data, but refresh is pending or failed.
@immutable
class OperationStale extends OperationState {
  /// Description of the stale condition.
  final String message;

  /// When the data was last confirmed.
  final DateTime? lastConfirmedAt;

  /// Refresh status.
  final StaleRefreshStatus refreshStatus;

  const OperationStale({
    this.message = 'Data may be outdated',
    this.lastConfirmedAt,
    this.refreshStatus = StaleRefreshStatus.refreshing,
  });

  @override
  String get label => 'Stale';

  @override
  String get accessibilityAnnouncement {
    final timeInfo = lastConfirmedAt != null
        ? ' Last updated: ${lastConfirmedAt!.toIso8601String()}'
        : '';
    return 'Data may be outdated.$timeInfo Status: ${refreshStatus.name}';
  }

  @override
  bool get isTerminal => false;

  @override
  List<RecoveryAction> get recoveryActions => const [];
}

/// Refresh status for stale data.
enum StaleRefreshStatus { refreshing, retryPending, notAttempted }

/// Conflicted state — local and server versions disagree.
@immutable
class OperationConflicted extends OperationState {
  /// Description of the conflict.
  final String message;

  /// Correlation ID for the conflict.
  final String? correlationId;

  /// Operation that caused the conflict.
  final String? operationId;

  /// Whether automatic resolution is possible.
  final bool autoResolvable;

  const OperationConflicted({
    this.message = 'A conflict was detected',
    this.correlationId,
    this.operationId,
    this.autoResolvable = false,
  });

  @override
  String get label => 'Conflict';

  @override
  String get accessibilityAnnouncement =>
      'Conflict detected: $message. Manual review may be required.';

  @override
  bool get isTerminal => false;

  @override
  List<RecoveryAction> get recoveryActions => [
    RecoveryAction.viewConflicts(correlationId: correlationId),
    if (correlationId != null)
      RecoveryAction.contactSupport(correlationId: correlationId!),
  ];
}

/// Unavailable state — dependency or service is unreachable.
@immutable
class OperationUnavailable extends OperationState {
  /// Why the service is unavailable.
  final String message;

  /// Correlation ID for support.
  final String? correlationId;

  const OperationUnavailable({
    this.message = 'Service unavailable',
    this.correlationId,
  });

  @override
  String get label => 'Unavailable';

  @override
  String get accessibilityAnnouncement => 'Service unavailable: $message';

  @override
  bool get isTerminal => false;

  @override
  List<RecoveryAction> get recoveryActions => [
    if (correlationId != null)
      RecoveryAction.contactSupport(correlationId: correlationId!),
  ];
}

/// Failed state — operation completed with a terminal or retryable error.
@immutable
class OperationFailed extends OperationState {
  /// Error description.
  final String message;

  /// Typed error code.
  final String? errorCode;

  /// Whether the operation can be retried.
  final bool retryable;

  /// Correlation ID for tracking.
  final String? correlationId;

  /// Operation ID for retry identity reuse.
  final String? operationId;

  const OperationFailed({
    required this.message,
    this.errorCode,
    this.retryable = false,
    this.correlationId,
    this.operationId,
  });

  @override
  String get label => 'Failed';

  @override
  @override
  String get accessibilityAnnouncement {
    final retryHint = retryable ? ' You can retry this operation.' : '';
    return 'Operation failed: $message.$retryHint';
  }

  @override
  bool get isTerminal => !retryable;

  @override
  List<RecoveryAction> get recoveryActions => [
    if (retryable && operationId != null)
      RecoveryAction.retry(
        operationId: operationId!,
        correlationId: correlationId,
      ),
    if (!retryable && correlationId != null)
      RecoveryAction.contactSupport(correlationId: correlationId!),
  ];
}

/// Complete state — operation confirmed by authoritative backend.
///
/// **GR-3 Enforcement:** This state REQUIRES [confirmedAt] to be non-null,
/// proving that [AuthoritativeConfirmation] was received. The UI must NEVER
/// render "complete" without this proof.
@immutable
class OperationComplete extends OperationState {
  /// Success message.
  final String message;

  /// When the backend confirmed the operation — REQUIRED for GR-3.
  final DateTime confirmedAt;

  /// Operation ID for reference.
  final String? operationId;

  const OperationComplete({
    this.message = 'Operation completed successfully',
    required this.confirmedAt,
    this.operationId,
  });

  @override
  String get label => 'Complete';

  @override
  String get accessibilityAnnouncement =>
      'Operation complete: $message. Confirmed at ${confirmedAt.toIso8601String()}';

  @override
  bool get isTerminal => true;

  @override
  List<RecoveryAction> get recoveryActions => const [];
}

/// Signed-out state — session expired or missing, no domain access.
@immutable
class OperationSignedOut extends OperationState {
  /// Message explaining the session state.
  final String message;

  const OperationSignedOut({
    this.message = 'Your session has expired. Please sign in to continue.',
  });

  @override
  String get label => 'Signed Out';

  @override
  String get accessibilityAnnouncement => 'Session expired. $message';

  @override
  bool get isTerminal => true;

  @override
  List<RecoveryAction> get recoveryActions => [const RecoveryAction.signIn()];
}
