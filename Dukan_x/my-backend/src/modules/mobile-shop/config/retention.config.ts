/**
 * Retention Configuration
 *
 * Defines TTLs and retention policies for idempotency records, audit events,
 * reconciliation records, change events, continuation tokens, and projections.
 *
 * Note: DynamoDB TTL is cleanup-only; business retry policy rejects keys
 * outside configured retention even if physical deletion is delayed.
 *
 * Requirements: 6.27, 6.29–6.30
 */

export interface RetentionConfig {
  /** Idempotency record retention */
  readonly idempotency: {
    /** Business-level retention window (seconds) — retries beyond this are rejected */
    readonly retentionSeconds: number;
    /** DynamoDB TTL value — physical cleanup (should exceed retentionSeconds) */
    readonly ttlSeconds: number;
  };

  /** Audit event retention */
  readonly audit: {
    /** Immutable audit events are never TTL-deleted in the application table */
    readonly permanent: true;
    /** Archive/export threshold in days (events older than this are eligible for cold export) */
    readonly archiveAfterDays: number;
  };

  /** Change feed / tenant change events */
  readonly changeFeed: {
    /** Change event retention (seconds) — bounded for pull convergence */
    readonly retentionSeconds: number;
    /** DynamoDB TTL for physical cleanup */
    readonly ttlSeconds: number;
  };

  /** Reconciliation records */
  readonly reconciliation: {
    /** Completed reconciliation records retained for observability (seconds) */
    readonly completedRetentionSeconds: number;
    /** Failed/terminal records retained for investigation (seconds) */
    readonly failedRetentionSeconds: number;
  };

  /** Continuation token expiry */
  readonly continuationToken: {
    /** Token validity duration (seconds) */
    readonly expirySeconds: number;
  };

  /** KPI projection freshness */
  readonly projection: {
    /** Stale threshold (seconds) — UI shows stale indicator after this */
    readonly staleThresholdSeconds: number;
  };
}

export const RETENTION_CONFIG: RetentionConfig = {
  idempotency: {
    retentionSeconds: 24 * 60 * 60,       // 24 hours business window
    ttlSeconds: 48 * 60 * 60,             // 48 hours physical cleanup
  },

  audit: {
    permanent: true,
    archiveAfterDays: 365,                 // 1 year before cold export eligibility
  },

  changeFeed: {
    retentionSeconds: 7 * 24 * 60 * 60,   // 7 days for sync convergence
    ttlSeconds: 10 * 24 * 60 * 60,        // 10 days physical cleanup
  },

  reconciliation: {
    completedRetentionSeconds: 30 * 24 * 60 * 60,  // 30 days
    failedRetentionSeconds: 90 * 24 * 60 * 60,     // 90 days for investigation
  },

  continuationToken: {
    expirySeconds: 5 * 60,                 // 5 minutes
  },

  projection: {
    staleThresholdSeconds: 60,             // 1 minute
  },
} as const;
