/**
 * Retry and Backoff Configuration
 *
 * Defines retry budgets, base/max delays, jitter, and throttling behavior.
 * After the budget is exhausted the system returns a typed rate-limited or
 * pending-reconciliation outcome and preserves idempotency/authoritative state.
 *
 * Requirements: 6.38
 */

export interface RetryPolicy {
  /** Maximum retry attempts before giving up */
  readonly maxRetries: number;
  /** Initial delay before first retry (ms) */
  readonly baseDelayMs: number;
  /** Maximum delay cap (ms) */
  readonly maxDelayMs: number;
  /** Jitter factor (0–1): randomness added to prevent thundering herd */
  readonly jitterFactor: number;
  /** Backoff multiplier per attempt (exponential backoff) */
  readonly backoffMultiplier: number;
}

export interface RetryConfig {
  /** DynamoDB transact/write retries on throttle or transient error */
  readonly dynamoDbWrite: RetryPolicy;
  /** DynamoDB read retries (query/get) */
  readonly dynamoDbRead: RetryPolicy;
  /** Reconciliation worker step retries */
  readonly reconciliationStep: RetryPolicy;
  /** Sync push retries (Flutter outbox) */
  readonly syncPush: RetryPolicy;
  /** External provider call retries */
  readonly providerCall: RetryPolicy;
  /** WebSocket reconnection retries */
  readonly websocketReconnect: RetryPolicy;
  /** Migration/backfill page retries */
  readonly migrationPage: RetryPolicy;
}

export const RETRY_CONFIG: RetryConfig = {
  dynamoDbWrite: {
    maxRetries: 3,
    baseDelayMs: 100,
    maxDelayMs: 2000,
    jitterFactor: 0.25,
    backoffMultiplier: 2,
  },

  dynamoDbRead: {
    maxRetries: 2,
    baseDelayMs: 50,
    maxDelayMs: 1000,
    jitterFactor: 0.1,
    backoffMultiplier: 2,
  },

  reconciliationStep: {
    maxRetries: 5,
    baseDelayMs: 500,
    maxDelayMs: 30_000,
    jitterFactor: 0.3,
    backoffMultiplier: 2,
  },

  syncPush: {
    maxRetries: 5,
    baseDelayMs: 1000,
    maxDelayMs: 60_000,
    jitterFactor: 0.25,
    backoffMultiplier: 2,
  },

  providerCall: {
    maxRetries: 3,
    baseDelayMs: 200,
    maxDelayMs: 5000,
    jitterFactor: 0.2,
    backoffMultiplier: 2,
  },

  websocketReconnect: {
    maxRetries: 10,
    baseDelayMs: 1000,
    maxDelayMs: 60_000,
    jitterFactor: 0.5,
    backoffMultiplier: 1.5,
  },

  migrationPage: {
    maxRetries: 3,
    baseDelayMs: 200,
    maxDelayMs: 5000,
    jitterFactor: 0.2,
    backoffMultiplier: 2,
  },
} as const;
