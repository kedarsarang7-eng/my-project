/**
 * Throttling Recovery — Rate-Limited Operation Handling
 *
 * Manages throttled DynamoDB operations with typed outcomes, retry budget
 * tracking, and retained idempotency. When retries are exhausted, the
 * idempotency record is preserved so future manual retry remains safe.
 *
 * Requirements: 6.38, 8.13, 13.6
 */

import { RETRY_CONFIG, type RetryPolicy } from '../config/retry.config';

// ─── Typed Outcomes ──────────────────────────────────────────────────────────

/**
 * Outcome when an operation is throttled but retries remain.
 * Client should retry with the suggested backoff.
 */
export interface RateLimitedPending {
  readonly type: 'RATE_LIMITED_PENDING';
  readonly operationId: string;
  readonly attemptsUsed: number;
  readonly maxAttempts: number;
  readonly retryAfterMs: number;
  readonly policyKey: RetryPolicyKey;
  readonly idempotencyRetained: true;
  readonly message: string;
}

/**
 * Outcome when an operation has exhausted its retry budget.
 * Manual recovery needed — but idempotency record is preserved
 * so future retry is safe.
 */
export interface RateLimitedExhausted {
  readonly type: 'RATE_LIMITED_EXHAUSTED';
  readonly operationId: string;
  readonly attemptsUsed: number;
  readonly maxAttempts: number;
  readonly policyKey: RetryPolicyKey;
  readonly idempotencyRetained: true;
  readonly message: string;
}

/** Union of throttling recovery outcomes */
export type ThrottlingOutcome = RateLimitedPending | RateLimitedExhausted;

// ─── Policy Key ──────────────────────────────────────────────────────────────

/** Keys into RETRY_CONFIG for policy lookup */
export type RetryPolicyKey = keyof typeof RETRY_CONFIG;

// ─── Retry Budget State ──────────────────────────────────────────────────────

/** Current retry state for a tracked operation */
export interface RetryBudgetState {
  readonly operationId: string;
  readonly policyKey: RetryPolicyKey;
  readonly attemptsUsed: number;
  readonly maxAttempts: number;
  readonly lastAttemptAt: string;
  readonly nextRetryAfterMs: number;
  readonly exhausted: boolean;
}

// ─── Throttling Recovery Service ─────────────────────────────────────────────

/**
 * ThrottlingRecoveryService handles DynamoDB throttled operations.
 *
 * Key behaviors:
 * - Tracks retry attempts against configured budgets from RETRY_CONFIG
 * - Returns typed `RATE_LIMITED_PENDING` when retries remain (client should wait)
 * - Returns typed `RATE_LIMITED_EXHAUSTED` when budget is spent (manual recovery needed)
 * - Always preserves the idempotency record (operation can still be retried later)
 * - Never fabricates success or loses queued work
 */
export class ThrottlingRecoveryService {
  /** In-memory attempt tracking (production would use durable storage) */
  private readonly attemptStore = new Map<string, {
    attempts: number;
    policyKey: RetryPolicyKey;
    lastAttemptAt: string;
  }>();

  constructor(
    private readonly deps: {
      /**
       * Preserves the idempotency record for a throttled operation.
       * Ensures the operation can be safely retried in the future
       * even after the retry budget is exhausted.
       */
      readonly preserveIdempotencyRecord: (operationId: string) => Promise<void>;
      /** Emits structured observability for throttling events */
      readonly emitThrottlingMetric: (data: {
        operationId: string;
        policyKey: RetryPolicyKey;
        attemptsUsed: number;
        maxAttempts: number;
        exhausted: boolean;
        retryAfterMs: number;
      }) => void;
    },
  ) {}

  /**
   * Handles a throttled operation by checking retry budget and returning
   * a typed outcome.
   *
   * Flow:
   * 1. Check remaining retry budget from RETRY_CONFIG
   * 2. If budget exhausted → preserve idempotency → return RATE_LIMITED_EXHAUSTED
   * 3. If budget remains → return RATE_LIMITED_PENDING with retry-after guidance
   *
   * The idempotency record is ALWAYS preserved regardless of exhaustion state.
   */
  async handleThrottledOperation(
    operationId: string,
    policyKey: RetryPolicyKey,
  ): Promise<ThrottlingOutcome> {
    const policy = RETRY_CONFIG[policyKey];
    const currentAttempts = this.incrementAttempts(operationId, policyKey);
    const exhausted = this.isExhausted(currentAttempts, policyKey);

    // Always preserve idempotency — operation can be retried later
    await this.deps.preserveIdempotencyRecord(operationId);

    const retryAfterMs = exhausted ? 0 : this.calculateBackoff(currentAttempts, policy);

    // Emit observability
    this.deps.emitThrottlingMetric({
      operationId,
      policyKey,
      attemptsUsed: currentAttempts,
      maxAttempts: policy.maxRetries,
      exhausted,
      retryAfterMs,
    });

    if (exhausted) {
      return {
        type: 'RATE_LIMITED_EXHAUSTED',
        operationId,
        attemptsUsed: currentAttempts,
        maxAttempts: policy.maxRetries,
        policyKey,
        idempotencyRetained: true,
        message: `Retry budget exhausted after ${currentAttempts} attempts. Idempotency record preserved for manual recovery.`,
      };
    }

    return {
      type: 'RATE_LIMITED_PENDING',
      operationId,
      attemptsUsed: currentAttempts,
      maxAttempts: policy.maxRetries,
      retryAfterMs,
      policyKey,
      idempotencyRetained: true,
      message: `Operation throttled. Retry after ${retryAfterMs}ms (attempt ${currentAttempts}/${policy.maxRetries}).`,
    };
  }

  /**
   * Checks the current retry budget state for an operation.
   */
  checkRetryBudget(operationId: string, policyKey: RetryPolicyKey): RetryBudgetState {
    const policy = RETRY_CONFIG[policyKey];
    const tracked = this.attemptStore.get(operationId);
    const attemptsUsed = tracked?.attempts ?? 0;
    const exhausted = this.isExhausted(attemptsUsed, policyKey);

    return {
      operationId,
      policyKey,
      attemptsUsed,
      maxAttempts: policy.maxRetries,
      lastAttemptAt: tracked?.lastAttemptAt ?? '',
      nextRetryAfterMs: exhausted ? 0 : this.calculateBackoff(attemptsUsed, policy),
      exhausted,
    };
  }

  /**
   * Determines whether the retry budget is exhausted for a given attempt count.
   */
  isExhausted(attempts: number, policyKey: RetryPolicyKey): boolean {
    const policy = RETRY_CONFIG[policyKey];
    return attempts >= policy.maxRetries;
  }

  /**
   * Resets the retry budget for an operation (e.g. after manual recovery).
   */
  resetBudget(operationId: string): void {
    this.attemptStore.delete(operationId);
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────

  private incrementAttempts(operationId: string, policyKey: RetryPolicyKey): number {
    const existing = this.attemptStore.get(operationId);
    const newAttempts = (existing?.attempts ?? 0) + 1;

    this.attemptStore.set(operationId, {
      attempts: newAttempts,
      policyKey,
      lastAttemptAt: new Date().toISOString(),
    });

    return newAttempts;
  }

  private calculateBackoff(attempts: number, policy: RetryPolicy): number {
    const baseDelay = policy.baseDelayMs * Math.pow(policy.backoffMultiplier, attempts - 1);
    const cappedDelay = Math.min(baseDelay, policy.maxDelayMs);

    // Apply jitter
    const jitter = cappedDelay * policy.jitterFactor * Math.random();
    return Math.round(cappedDelay + jitter);
  }
}
