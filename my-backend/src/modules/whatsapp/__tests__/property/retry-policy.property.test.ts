// ============================================================================
// Property-Based Test — Retry Policy
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 23
//
// Validates: Requirements 4.7, 8.1, 8.2, 8.8, 10.7
//
// Property 23 (design.md): Retry policy bounds attempts and classifies failures.
//
// For any RetryPolicy configuration and DispatchAttemptState:
// - Attempt count is bounded 1..10 (default 3)
// - Backoff delay is bounded 1..3600s (default 60)
// - Transient errors produce a retry decision when attempts remain
// - Permanent errors NEVER produce a retry decision (always fail immediately)
// - Exhausted attempts produce a failed decision
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  nextAttempt,
  createRetryPolicy,
  isTransientError,
  isPermanentError,
  isMessageExpired,
  RetryPolicy,
  DispatchAttemptState,
  TRANSIENT_ERROR_CODES,
  PERMANENT_ERROR_CODES,
  MIN_MAX_ATTEMPTS,
  MAX_MAX_ATTEMPTS,
  DEFAULT_MAX_ATTEMPTS,
  MIN_BACKOFF_SECONDS,
  MAX_BACKOFF_SECONDS,
  DEFAULT_BACKOFF_SECONDS,
  MIN_EXPIRY_SECONDS,
  MAX_EXPIRY_SECONDS,
  DEFAULT_EXPIRY_SECONDS,
} from '../../services/retry-policy.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** ISO-8601 UTC date string generator (valid dates in reasonable range). */
const isoDateArb: fc.Arbitrary<string> = fc
  .date({
    min: new Date('2020-01-01T00:00:00.000Z'),
    max: new Date('2030-12-31T23:59:59.999Z'),
  })
  .map((d) => d.toISOString());

/** Generates maxAttempts in valid bounds (1..10). */
const validMaxAttemptsArb: fc.Arbitrary<number> = fc.integer({
  min: MIN_MAX_ATTEMPTS,
  max: MAX_MAX_ATTEMPTS,
});

/** Generates backoff in valid bounds (1..3600). */
const validBackoffArb: fc.Arbitrary<number> = fc.integer({
  min: MIN_BACKOFF_SECONDS,
  max: MAX_BACKOFF_SECONDS,
});

/** Generates expiry in valid bounds (60..604800). */
const validExpiryArb: fc.Arbitrary<number> = fc.integer({
  min: MIN_EXPIRY_SECONDS,
  max: MAX_EXPIRY_SECONDS,
});

/** Generates a valid RetryPolicy with all fields in bounds. */
const validPolicyArb: fc.Arbitrary<RetryPolicy> = fc.record({
  maxAttempts: validMaxAttemptsArb,
  backoffSeconds: validBackoffArb,
  expirySeconds: validExpiryArb,
});

/** Generates a known transient error code. */
const transientErrorArb: fc.Arbitrary<string> = fc.constantFrom(
  ...TRANSIENT_ERROR_CODES,
);

/** Generates a known permanent error code. */
const permanentErrorArb: fc.Arbitrary<string> = fc.constantFrom(
  ...PERMANENT_ERROR_CODES,
);

/** Generates an attempt count that is below the policy max (still has retries). */
function attemptsWithRetriesArb(maxAttempts: number): fc.Arbitrary<number> {
  return fc.integer({ min: 1, max: maxAttempts - 1 });
}

/** Generates an attempt count >= maxAttempts (exhausted). */
function exhaustedAttemptsArb(maxAttempts: number): fc.Arbitrary<number> {
  return fc.integer({ min: maxAttempts, max: maxAttempts + 5 });
}

/**
 * Generates a DispatchAttemptState with a `now` that is well before
 * expiry so expiry does not interfere with retry/fail testing.
 */
function nonExpiredStateArb(
  policy: RetryPolicy,
  errorCodeArb: fc.Arbitrary<string>,
  attemptsArb: fc.Arbitrary<number>,
): fc.Arbitrary<DispatchAttemptState> {
  return fc.record({
    attempts: attemptsArb,
    errorCode: errorCodeArb,
    enqueuedAt: isoDateArb,
    now: fc.constant(''), // placeholder, computed below
  }).map((state) => {
    // Set `now` to be shortly after enqueuedAt but well before expiry
    const enqueuedMs = Date.parse(state.enqueuedAt);
    const offset = Math.min(1000, (policy.expirySeconds * 1000) / 2);
    return {
      ...state,
      now: new Date(enqueuedMs + offset).toISOString(),
    };
  });
}

// ── Property 23 Tests ───────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 23: Retry policy bounds attempts and classifies failures', () => {
  // ─────────────────────────────────────────────────────────────────────────
  // 1) Attempts bounded 1..10, default 3
  // ─────────────────────────────────────────────────────────────────────────

  describe('**Validates: Requirements 8.1, 8.2** — Attempt count bounds', () => {
    test('createRetryPolicy clamps maxAttempts to [1, 10]', () => {
      fc.assert(
        fc.property(
          fc.integer({ min: -100, max: 200 }),
          (rawAttempts) => {
            const policy = createRetryPolicy({ maxAttempts: rawAttempts });
            expect(policy.maxAttempts).toBeGreaterThanOrEqual(MIN_MAX_ATTEMPTS);
            expect(policy.maxAttempts).toBeLessThanOrEqual(MAX_MAX_ATTEMPTS);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('createRetryPolicy defaults maxAttempts to 3 when not provided', () => {
      const policy = createRetryPolicy({});
      expect(policy.maxAttempts).toBe(DEFAULT_MAX_ATTEMPTS);
    });

    test('createRetryPolicy defaults maxAttempts to 3 when undefined', () => {
      const policy = createRetryPolicy();
      expect(policy.maxAttempts).toBe(DEFAULT_MAX_ATTEMPTS);
    });

    test('valid maxAttempts values (1..10) are preserved', () => {
      fc.assert(
        fc.property(validMaxAttemptsArb, (maxAttempts) => {
          const policy = createRetryPolicy({ maxAttempts });
          expect(policy.maxAttempts).toBe(maxAttempts);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2) Backoff bounded 1..3600s, default 60
  // ─────────────────────────────────────────────────────────────────────────

  describe('**Validates: Requirements 8.1** — Backoff delay bounds', () => {
    test('createRetryPolicy clamps backoffSeconds to [1, 3600]', () => {
      fc.assert(
        fc.property(
          fc.integer({ min: -1000, max: 10000 }),
          (rawBackoff) => {
            const policy = createRetryPolicy({ backoffSeconds: rawBackoff });
            expect(policy.backoffSeconds).toBeGreaterThanOrEqual(MIN_BACKOFF_SECONDS);
            expect(policy.backoffSeconds).toBeLessThanOrEqual(MAX_BACKOFF_SECONDS);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('createRetryPolicy defaults backoffSeconds to 60 when not provided', () => {
      const policy = createRetryPolicy({});
      expect(policy.backoffSeconds).toBe(DEFAULT_BACKOFF_SECONDS);
    });

    test('valid backoffSeconds values (1..3600) are preserved', () => {
      fc.assert(
        fc.property(validBackoffArb, (backoffSeconds) => {
          const policy = createRetryPolicy({ backoffSeconds });
          expect(policy.backoffSeconds).toBe(backoffSeconds);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('retry decision schedules retry at now + backoffSeconds', () => {
      fc.assert(
        fc.property(
          validPolicyArb,
          isoDateArb,
          transientErrorArb,
          (policy, enqueuedAt, errorCode) => {
            const enqueuedMs = Date.parse(enqueuedAt);
            // Set `now` to shortly after enqueue but before expiry
            const nowMs = enqueuedMs + 1000;
            const now = new Date(nowMs).toISOString();
            const state: DispatchAttemptState = {
              attempts: 1,
              errorCode,
              enqueuedAt,
              now,
            };

            // Only test when not expired and attempts < max
            if (state.attempts >= policy.maxAttempts) return;
            if (isMessageExpired(state, policy)) return;

            const decision = nextAttempt(state, policy);
            expect(decision.action).toBe('retry');
            if (decision.action === 'retry') {
              const expectedRetryAt = new Date(nowMs + policy.backoffSeconds * 1000).toISOString();
              expect(decision.retryAt).toBe(expectedRetryAt);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3) Transient errors retried (Req 4.7, 8.1, 10.7)
  // ─────────────────────────────────────────────────────────────────────────

  describe('**Validates: Requirements 4.7, 8.1, 10.7** — Transient errors are retried', () => {
    test('transient error with remaining attempts produces retry', () => {
      fc.assert(
        fc.property(
          validPolicyArb.filter((p) => p.maxAttempts >= 2),
          transientErrorArb,
          isoDateArb,
          (policy, errorCode, enqueuedAt) => {
            const enqueuedMs = Date.parse(enqueuedAt);
            const nowMs = enqueuedMs + 1000;
            const state: DispatchAttemptState = {
              attempts: 1,
              errorCode,
              enqueuedAt,
              now: new Date(nowMs).toISOString(),
            };

            // Ensure not expired
            if (isMessageExpired(state, policy)) return;

            const decision = nextAttempt(state, policy);
            expect(decision.action).toBe('retry');
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('all known transient error codes are classified as transient', () => {
      fc.assert(
        fc.property(transientErrorArb, (errorCode) => {
          expect(isTransientError(errorCode)).toBe(true);
          expect(isPermanentError(errorCode)).toBe(false);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('transient error with exhausted attempts produces failed', () => {
      fc.assert(
        fc.property(
          validPolicyArb,
          transientErrorArb,
          isoDateArb,
          (policy, errorCode, enqueuedAt) => {
            const enqueuedMs = Date.parse(enqueuedAt);
            const nowMs = enqueuedMs + 1000;
            const state: DispatchAttemptState = {
              attempts: policy.maxAttempts, // exhausted
              errorCode,
              enqueuedAt,
              now: new Date(nowMs).toISOString(),
            };

            // Ensure not expired
            if (isMessageExpired(state, policy)) return;

            const decision = nextAttempt(state, policy);
            expect(decision.action).toBe('failed');
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4) Permanent errors NEVER retried (Req 8.8)
  // ─────────────────────────────────────────────────────────────────────────

  describe('**Validates: Requirements 8.8** — Permanent errors never retried', () => {
    test('permanent error always produces failed, never retry', () => {
      fc.assert(
        fc.property(
          validPolicyArb,
          permanentErrorArb,
          isoDateArb,
          fc.integer({ min: 0, max: 9 }),
          (policy, errorCode, enqueuedAt, attempts) => {
            const enqueuedMs = Date.parse(enqueuedAt);
            const nowMs = enqueuedMs + 1000;
            const state: DispatchAttemptState = {
              attempts,
              errorCode,
              enqueuedAt,
              now: new Date(nowMs).toISOString(),
            };

            // Ensure not expired (so we can verify it's the permanent classification causing fail)
            if (isMessageExpired(state, policy)) return;

            const decision = nextAttempt(state, policy);
            // Permanent errors must NEVER produce retry, regardless of attempt count
            expect(decision.action).not.toBe('retry');
            expect(decision.action).toBe('failed');
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('all known permanent error codes are classified as permanent', () => {
      fc.assert(
        fc.property(permanentErrorArb, (errorCode) => {
          expect(isPermanentError(errorCode)).toBe(true);
          expect(isTransientError(errorCode)).toBe(false);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('permanent error with any attempt count (0 through max) always fails immediately', () => {
      fc.assert(
        fc.property(
          validPolicyArb,
          permanentErrorArb,
          isoDateArb,
          fc.integer({ min: 0, max: MAX_MAX_ATTEMPTS }),
          (policy, errorCode, enqueuedAt, attempts) => {
            const enqueuedMs = Date.parse(enqueuedAt);
            const nowMs = enqueuedMs + 500;
            const state: DispatchAttemptState = {
              attempts,
              errorCode,
              enqueuedAt,
              now: new Date(nowMs).toISOString(),
            };

            if (isMessageExpired(state, policy)) return;

            const decision = nextAttempt(state, policy);
            expect(decision.action).toBe('failed');
            if (decision.action === 'failed') {
              expect(decision.reason).toContain('Permanent');
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Additional: createRetryPolicy validates expiry bounds
  // ─────────────────────────────────────────────────────────────────────────

  describe('Expiry bounds (supporting Req 8.2)', () => {
    test('createRetryPolicy clamps expirySeconds to [60, 604800]', () => {
      fc.assert(
        fc.property(
          fc.integer({ min: -1000, max: 1_000_000 }),
          (rawExpiry) => {
            const policy = createRetryPolicy({ expirySeconds: rawExpiry });
            expect(policy.expirySeconds).toBeGreaterThanOrEqual(MIN_EXPIRY_SECONDS);
            expect(policy.expirySeconds).toBeLessThanOrEqual(MAX_EXPIRY_SECONDS);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('expired messages are never dispatched (action is expired)', () => {
      fc.assert(
        fc.property(
          validPolicyArb,
          transientErrorArb,
          isoDateArb,
          (policy, errorCode, enqueuedAt) => {
            const enqueuedMs = Date.parse(enqueuedAt);
            // Set now well past expiry
            const nowMs = enqueuedMs + policy.expirySeconds * 1000 + 1000;
            const state: DispatchAttemptState = {
              attempts: 1,
              errorCode,
              enqueuedAt,
              now: new Date(nowMs).toISOString(),
            };

            const decision = nextAttempt(state, policy);
            expect(decision.action).toBe('expired');
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });
});
