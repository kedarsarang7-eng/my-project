// ============================================================================
// WhatsApp Automation Module — Retry Policy Service — Unit Tests (Task 11.1)
// ============================================================================
// Verifies the pure retry-policy logic:
// - Transient errors are retried with backoff
// - Permanent errors are immediately failed with no retry
// - Max attempts exhausted → failed
// - Expired messages are never dispatched
// - Policy defaults and bounds are enforced
//
// Requirements: 4.7, 8.1, 8.2, 8.8, 9.4, 10.7
// ============================================================================

import {
  nextAttempt,
  createRetryPolicy,
  isTransientError,
  isPermanentError,
  isMessageExpired,
  computeExpiresAt,
  DEFAULT_MAX_ATTEMPTS,
  DEFAULT_BACKOFF_SECONDS,
  DEFAULT_EXPIRY_SECONDS,
  MIN_MAX_ATTEMPTS,
  MAX_MAX_ATTEMPTS,
  MIN_BACKOFF_SECONDS,
  MAX_BACKOFF_SECONDS,
  MIN_EXPIRY_SECONDS,
  MAX_EXPIRY_SECONDS,
  TRANSIENT_ERROR_CODES,
  PERMANENT_ERROR_CODES,
  type DispatchAttemptState,
  type RetryPolicy,
} from '../retry-policy.service';

describe('retry-policy.service', () => {
  // ── createRetryPolicy ───────────────────────────────────────────────────────

  describe('createRetryPolicy()', () => {
    it('returns defaults when no overrides provided', () => {
      const policy = createRetryPolicy();
      expect(policy.maxAttempts).toBe(DEFAULT_MAX_ATTEMPTS);
      expect(policy.backoffSeconds).toBe(DEFAULT_BACKOFF_SECONDS);
      expect(policy.expirySeconds).toBe(DEFAULT_EXPIRY_SECONDS);
    });

    it('accepts valid overrides within bounds', () => {
      const policy = createRetryPolicy({
        maxAttempts: 5,
        backoffSeconds: 120,
        expirySeconds: 3600,
      });
      expect(policy.maxAttempts).toBe(5);
      expect(policy.backoffSeconds).toBe(120);
      expect(policy.expirySeconds).toBe(3600);
    });

    it('clamps maxAttempts below minimum to 1', () => {
      const policy = createRetryPolicy({ maxAttempts: 0 });
      expect(policy.maxAttempts).toBe(MIN_MAX_ATTEMPTS);
    });

    it('clamps maxAttempts above maximum to 10', () => {
      const policy = createRetryPolicy({ maxAttempts: 99 });
      expect(policy.maxAttempts).toBe(MAX_MAX_ATTEMPTS);
    });

    it('clamps backoffSeconds below minimum to 1', () => {
      const policy = createRetryPolicy({ backoffSeconds: 0 });
      expect(policy.backoffSeconds).toBe(MIN_BACKOFF_SECONDS);
    });

    it('clamps backoffSeconds above maximum to 3600', () => {
      const policy = createRetryPolicy({ backoffSeconds: 9999 });
      expect(policy.backoffSeconds).toBe(MAX_BACKOFF_SECONDS);
    });

    it('clamps expirySeconds below minimum to 60', () => {
      const policy = createRetryPolicy({ expirySeconds: 10 });
      expect(policy.expirySeconds).toBe(MIN_EXPIRY_SECONDS);
    });

    it('clamps expirySeconds above maximum to 604800', () => {
      const policy = createRetryPolicy({ expirySeconds: 999999 });
      expect(policy.expirySeconds).toBe(MAX_EXPIRY_SECONDS);
    });

    it('uses defaults for NaN values', () => {
      const policy = createRetryPolicy({
        maxAttempts: NaN,
        backoffSeconds: NaN,
        expirySeconds: NaN,
      });
      expect(policy.maxAttempts).toBe(DEFAULT_MAX_ATTEMPTS);
      expect(policy.backoffSeconds).toBe(DEFAULT_BACKOFF_SECONDS);
      expect(policy.expirySeconds).toBe(DEFAULT_EXPIRY_SECONDS);
    });
  });

  // ── Error Classification ────────────────────────────────────────────────────

  describe('isTransientError()', () => {
    it('classifies NETWORK_TIMEOUT as transient', () => {
      expect(isTransientError('NETWORK_TIMEOUT')).toBe(true);
    });

    it('classifies GATEWAY_ERROR as transient', () => {
      expect(isTransientError('GATEWAY_ERROR')).toBe(true);
    });

    it('classifies SERVICE_UNAVAILABLE as transient', () => {
      expect(isTransientError('SERVICE_UNAVAILABLE')).toBe(true);
    });

    it('classifies INVALID_RECIPIENT as permanent (not transient)', () => {
      expect(isTransientError('INVALID_RECIPIENT')).toBe(false);
    });

    it('classifies INVALID_NUMBER as permanent (not transient)', () => {
      expect(isTransientError('INVALID_NUMBER')).toBe(false);
    });

    it('is case-insensitive (normalizes to uppercase)', () => {
      expect(isTransientError('network_timeout')).toBe(true);
      expect(isTransientError('invalid_recipient')).toBe(false);
    });

    it('defaults unknown error codes to transient (fail-safe)', () => {
      expect(isTransientError('SOME_UNKNOWN_ERROR')).toBe(true);
    });

    it('treats empty string as transient (fail-safe)', () => {
      expect(isTransientError('')).toBe(true);
    });
  });

  describe('isPermanentError()', () => {
    it('classifies INVALID_RECIPIENT as permanent', () => {
      expect(isPermanentError('INVALID_RECIPIENT')).toBe(true);
    });

    it('classifies NETWORK_TIMEOUT as not permanent', () => {
      expect(isPermanentError('NETWORK_TIMEOUT')).toBe(false);
    });
  });

  // ── Expiry ──────────────────────────────────────────────────────────────────

  describe('isMessageExpired()', () => {
    const policy = createRetryPolicy({ expirySeconds: 3600 }); // 1 hour

    it('returns false when message is within expiry window', () => {
      const state: DispatchAttemptState = {
        attempts: 1,
        errorCode: 'NETWORK_TIMEOUT',
        enqueuedAt: '2024-01-01T00:00:00Z',
        now: '2024-01-01T00:30:00Z', // 30 min later, within 1h expiry
      };
      expect(isMessageExpired(state, policy)).toBe(false);
    });

    it('returns true when message is past expiry window', () => {
      const state: DispatchAttemptState = {
        attempts: 1,
        errorCode: 'NETWORK_TIMEOUT',
        enqueuedAt: '2024-01-01T00:00:00Z',
        now: '2024-01-01T01:00:01Z', // 1h + 1s later, past 1h expiry
      };
      expect(isMessageExpired(state, policy)).toBe(true);
    });

    it('returns true when explicit expiresAt has passed', () => {
      const state: DispatchAttemptState = {
        attempts: 1,
        errorCode: 'NETWORK_TIMEOUT',
        enqueuedAt: '2024-01-01T00:00:00Z',
        now: '2024-01-01T02:00:00Z',
        expiresAt: '2024-01-01T01:00:00Z',
      };
      expect(isMessageExpired(state, policy)).toBe(true);
    });

    it('returns true at exactly the expiry boundary', () => {
      const state: DispatchAttemptState = {
        attempts: 1,
        errorCode: 'NETWORK_TIMEOUT',
        enqueuedAt: '2024-01-01T00:00:00Z',
        now: '2024-01-01T01:00:00Z', // exactly at 1h boundary
      };
      expect(isMessageExpired(state, policy)).toBe(true);
    });
  });

  // ── nextAttempt (core logic) ────────────────────────────────────────────────

  describe('nextAttempt()', () => {
    const defaultPolicy = createRetryPolicy({
      maxAttempts: 3,
      backoffSeconds: 60,
      expirySeconds: 86400, // 24h
    });

    describe('transient errors → retry', () => {
      it('schedules a retry for a transient error with attempts remaining', () => {
        const state: DispatchAttemptState = {
          attempts: 1,
          errorCode: 'NETWORK_TIMEOUT',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-01T00:01:00Z',
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('retry');
        if (result.action === 'retry') {
          // retryAt should be now + 60s
          expect(result.retryAt).toBe('2024-01-01T00:02:00.000Z');
        }
      });

      it('schedules retry for GATEWAY_ERROR', () => {
        const state: DispatchAttemptState = {
          attempts: 2,
          errorCode: 'GATEWAY_ERROR',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-01T00:05:00Z',
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('retry');
        if (result.action === 'retry') {
          expect(result.retryAt).toBe('2024-01-01T00:06:00.000Z');
        }
      });
    });

    describe('permanent errors → immediate failure', () => {
      it('immediately fails for INVALID_RECIPIENT', () => {
        const state: DispatchAttemptState = {
          attempts: 1,
          errorCode: 'INVALID_RECIPIENT',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-01T00:01:00Z',
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('failed');
        if (result.action === 'failed') {
          expect(result.reason).toContain('Permanent error');
          expect(result.reason).toContain('INVALID_RECIPIENT');
        }
      });

      it('immediately fails for INVALID_NUMBER even on first attempt', () => {
        const state: DispatchAttemptState = {
          attempts: 1,
          errorCode: 'INVALID_NUMBER',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-01T00:00:05Z',
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('failed');
      });

      it('does not retry permanent errors even with attempts remaining', () => {
        const state: DispatchAttemptState = {
          attempts: 1,
          errorCode: 'FORBIDDEN',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-01T00:00:05Z',
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('failed');
      });
    });

    describe('max attempts exhausted → failed', () => {
      it('fails when attempts equal maxAttempts', () => {
        const state: DispatchAttemptState = {
          attempts: 3,
          errorCode: 'NETWORK_TIMEOUT',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-01T00:05:00Z',
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('failed');
        if (result.action === 'failed') {
          expect(result.reason).toContain('exhausted');
        }
      });

      it('fails when attempts exceed maxAttempts', () => {
        const state: DispatchAttemptState = {
          attempts: 5,
          errorCode: 'GATEWAY_ERROR',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-01T00:10:00Z',
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('failed');
      });
    });

    describe('expired messages → never dispatched', () => {
      it('returns expired when message is past expiry window', () => {
        const state: DispatchAttemptState = {
          attempts: 1,
          errorCode: 'NETWORK_TIMEOUT',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-02T01:00:00Z', // 25h later, past 24h expiry
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('expired');
      });

      it('expiry takes priority over retry eligibility', () => {
        const state: DispatchAttemptState = {
          attempts: 1,
          errorCode: 'NETWORK_TIMEOUT',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-02T01:00:00Z',
        };
        // Even though it's transient with attempts remaining, it's expired
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('expired');
      });

      it('expiry takes priority over permanent error classification', () => {
        const state: DispatchAttemptState = {
          attempts: 1,
          errorCode: 'INVALID_RECIPIENT',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-02T01:00:00Z',
        };
        const result = nextAttempt(state, defaultPolicy);
        expect(result.action).toBe('expired');
      });
    });

    describe('backoff timing', () => {
      it('computes retryAt as now + backoffSeconds', () => {
        const policy = createRetryPolicy({ backoffSeconds: 120, maxAttempts: 5, expirySeconds: 86400 });
        const state: DispatchAttemptState = {
          attempts: 2,
          errorCode: 'NETWORK_TIMEOUT',
          enqueuedAt: '2024-01-01T00:00:00Z',
          now: '2024-01-01T00:10:00Z',
        };
        const result = nextAttempt(state, policy);
        expect(result.action).toBe('retry');
        if (result.action === 'retry') {
          // 00:10:00 + 120s = 00:12:00
          expect(result.retryAt).toBe('2024-01-01T00:12:00.000Z');
        }
      });
    });
  });

  // ── computeExpiresAt ────────────────────────────────────────────────────────

  describe('computeExpiresAt()', () => {
    it('computes expiry as enqueuedAt + expirySeconds', () => {
      const policy = createRetryPolicy({ expirySeconds: 3600 });
      const result = computeExpiresAt('2024-01-01T00:00:00Z', policy);
      expect(result).toBe('2024-01-01T01:00:00.000Z');
    });

    it('throws for invalid enqueuedAt timestamp', () => {
      const policy = createRetryPolicy();
      expect(() => computeExpiresAt('not-a-date', policy)).toThrow();
    });
  });
});
