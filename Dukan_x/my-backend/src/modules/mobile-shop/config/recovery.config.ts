/**
 * Safe Recovery Actions Configuration
 *
 * Defines what the system does on various failure modes. Recovery actions are
 * safe, documented, and deterministic — they never fabricate success, lose
 * queued work, or allow unconfirmed states to appear committed.
 *
 * Requirements: 12.4–12.6 (recovery), GR-4
 */

/** A defined recovery action for a failure category */
export interface RecoveryAction {
  /** Failure category identifier */
  readonly failureCategory: string;
  /** Human-readable description */
  readonly description: string;
  /** Automated system action (what happens without user intervention) */
  readonly systemAction: string;
  /** User-facing guidance if manual resolution is needed */
  readonly userGuidance: string;
  /** Whether the system can auto-recover without user intervention */
  readonly autoRecoverable: boolean;
  /** Maximum auto-recovery attempts before escalating */
  readonly maxAutoAttempts: number;
}

export interface RecoveryConfig {
  /** Defined recovery actions by failure category */
  readonly actions: readonly RecoveryAction[];
}

export const RECOVERY_CONFIG: RecoveryConfig = {
  actions: [
    {
      failureCategory: 'TRANSACTION_CANCELLED',
      description: 'DynamoDB transaction cancelled due to condition failure',
      systemAction: 'Return deterministic conflict outcome; preserve all pre-operation state',
      userGuidance: 'Reload the item and retry with current version',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    },
    {
      failureCategory: 'THROTTLE_EXHAUSTED',
      description: 'DynamoDB throttling persisted beyond retry budget',
      systemAction: 'Return RATE_LIMITED outcome; preserve idempotency record with pending status; mark operation for deferred retry',
      userGuidance: 'Wait briefly and retry the operation',
      autoRecoverable: true,
      maxAutoAttempts: 3,
    },
    {
      failureCategory: 'AMBIGUOUS_SDK_RESPONSE',
      description: 'AWS SDK returned unknown/timeout without confirmed success or failure',
      systemAction: 'Mark operation as PENDING_RECONCILIATION; create Reconciliation_Record; do not claim success',
      userGuidance: 'Operation is pending — the system will confirm or reject automatically',
      autoRecoverable: true,
      maxAutoAttempts: 5,
    },
    {
      failureCategory: 'RECONCILIATION_STEP_FAILED',
      description: 'A reconciliation worker step failed after retries',
      systemAction: 'Record failure in Reconciliation_Record; increment attempts; schedule next retry with backoff; keep reservations active',
      userGuidance: 'The operation is being retried — no action needed unless marked terminal',
      autoRecoverable: true,
      maxAutoAttempts: 5,
    },
    {
      failureCategory: 'RECONCILIATION_TERMINAL',
      description: 'Reconciliation exhausted all retries without completing',
      systemAction: 'Mark Reconciliation_Record as terminal failure; keep reservations and claims active; emit alarm; preserve all evidence',
      userGuidance: 'Contact support to resolve this operation — reservations remain until explicitly released',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    },
    {
      failureCategory: 'SYNC_PUSH_REJECTED',
      description: 'Backend rejected a queued offline mutation during sync push',
      systemAction: 'Create a Conflict_Record with local vs server state; preserve queued mutation for resolution; remove from active push queue',
      userGuidance: 'A conflict was detected — review and resolve in the conflicts view',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    },
    {
      failureCategory: 'SYNC_PUSH_NETWORK_FAILURE',
      description: 'Network unavailable during sync push attempt',
      systemAction: 'Keep mutation in outbox; increment retry count; schedule next attempt with backoff; preserve entered data',
      userGuidance: 'Operation will sync automatically when connectivity returns',
      autoRecoverable: true,
      maxAutoAttempts: 5,
    },
    {
      failureCategory: 'PROVIDER_AMBIGUOUS',
      description: 'External provider returned ambiguous outcome (timeout/unknown)',
      systemAction: 'Store Provider_Request_Id; mark as pending provider confirmation; schedule provider reconciliation check',
      userGuidance: 'Provider status is being verified — do not resubmit',
      autoRecoverable: true,
      maxAutoAttempts: 3,
    },
    {
      failureCategory: 'SESSION_EXPIRED',
      description: 'Authentication session expired or tenant context lost',
      systemAction: 'Cancel active network operations; preserve local state; show session-error state; perform no domain reads or writes',
      userGuidance: 'Sign in again to continue',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    },
    {
      failureCategory: 'TENANT_SWITCH',
      description: 'User switched to a different tenant context',
      systemAction: 'Cancel network work; release queue leases; revoke tokens/cursors; clear in-memory state; open new tenant scope',
      userGuidance: 'Switched to the new business — previous operations are preserved in their tenant',
      autoRecoverable: false,
      maxAutoAttempts: 0,
    },
    {
      failureCategory: 'MIGRATION_PAGE_FAILURE',
      description: 'A migration/backfill page failed processing',
      systemAction: 'Persist durable checkpoint at last confirmed position; schedule retry with backoff; do not re-process completed records',
      userGuidance: 'Migration will resume automatically from last checkpoint',
      autoRecoverable: true,
      maxAutoAttempts: 3,
    },
    {
      failureCategory: 'WEBSOCKET_DISCONNECTED',
      description: 'Real-time WebSocket connection lost',
      systemAction: 'Attempt reconnection with backoff; on reconnect perform bounded pull to catch up; deduplicate events',
      userGuidance: 'Real-time updates temporarily paused — data remains up to date via pull',
      autoRecoverable: true,
      maxAutoAttempts: 10,
    },
  ],
} as const;
