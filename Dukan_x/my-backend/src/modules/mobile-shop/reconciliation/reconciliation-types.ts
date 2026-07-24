/**
 * Reconciliation Worker Types
 *
 * Defines configuration, result, and lease types for durable reconciliation workers.
 * Workers conditionally lease pending records, execute idempotent bounded steps,
 * and finalize only after all effects are confirmed.
 *
 * Requirements: 3.4–3.6, 5.2, 6.9, 6.32, 6.38, 12.9
 */

import type { RetryPolicy } from '../config/retry.config';

// ─── Worker Configuration ────────────────────────────────────────────────────

/** Configuration for reconciliation worker behavior */
export interface WorkerConfig {
  /** DynamoDB table name */
  readonly tableName: string;
  /** Duration in seconds a worker holds an exclusive lease on a record */
  readonly leaseDurationSeconds: number;
  /** Maximum attempts before marking a record as permanently failed */
  readonly maxAttempts: number;
  /** Backoff policy for scheduling retry after step failure */
  readonly backoffPolicy: RetryPolicy;
  /** Maximum number of records to pick up in one processNext invocation */
  readonly batchSize: number;
  /** GSI1 index name for reconciliation work query (AP-12) */
  readonly gsi1IndexName: string;
  /** Shard bucket for the worker's GSI1 key (e.g. 'ROOT') */
  readonly bucket: string;
}

/** Default worker configuration */
export const DEFAULT_WORKER_CONFIG: Omit<WorkerConfig, 'tableName'> = {
  leaseDurationSeconds: 60,
  maxAttempts: 5,
  backoffPolicy: {
    maxRetries: 5,
    baseDelayMs: 500,
    maxDelayMs: 30_000,
    jitterFactor: 0.3,
    backoffMultiplier: 2,
  },
  batchSize: 5,
  gsi1IndexName: 'GSI1',
  bucket: 'ROOT',
} as const;

// ─── Step Execution Results ──────────────────────────────────────────────────

/** Possible outcomes of executing a single reconciliation step */
export type StepExecutionStatus = 'success' | 'already-done' | 'failed';

/** Result of executing one reconciliation step */
export interface StepExecutionResult {
  readonly status: StepExecutionStatus;
  /** Step ID that was executed */
  readonly stepId: string;
  /** Error message when status is 'failed' */
  readonly error?: string;
  /** Whether the step can be retried (transient failure) */
  readonly retryable?: boolean;
}

// ─── Lease Results ───────────────────────────────────────────────────────────

/** Possible outcomes of attempting to acquire a lease */
export type LeaseStatus = 'acquired' | 'already-leased' | 'not-found';

/** Result of a lease acquisition attempt */
export interface LeaseResult {
  readonly status: LeaseStatus;
  /** The reconciliation record ID */
  readonly reconciliationId: string;
  /** Worker ID that acquired the lease (when status='acquired') */
  readonly workerId?: string;
  /** Lease expiry ISO timestamp (when status='acquired') */
  readonly expiresAt?: string;
}

// ─── Worker Context ──────────────────────────────────────────────────────────

/** Context passed to every worker operation */
export interface WorkerContext {
  readonly tenantId: string;
  readonly workerId: string;
  readonly correlationId: string;
}
