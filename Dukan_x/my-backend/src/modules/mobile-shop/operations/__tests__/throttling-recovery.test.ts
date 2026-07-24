/**
 * Throttling Recovery Tests
 *
 * Verifies RATE_LIMITED_PENDING on first attempt, RATE_LIMITED_EXHAUSTED
 * after budget is spent, and idempotency retention in both cases.
 *
 * Requirements: 6.37–6.40, 8.13, 13.6
 */

import { ThrottlingRecoveryService } from '../throttling-recovery';
import { RETRY_CONFIG } from '../../config/retry.config';

// ─── Mock Dependencies ───────────────────────────────────────────────────────

function createMockDeps() {
  return {
    preserveIdempotencyRecord: jest.fn().mockResolvedValue(undefined),
    emitThrottlingMetric: jest.fn(),
  };
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('ThrottlingRecoveryService', () => {
  const OPERATION_ID = 'op-throttle-001';
  const POLICY_KEY = 'dynamoDbWrite' as const;

  describe('First attempt', () => {
    it('returns RATE_LIMITED_PENDING with retry guidance', async () => {
      const deps = createMockDeps();
      const service = new ThrottlingRecoveryService(deps);

      const result = await service.handleThrottledOperation(OPERATION_ID, POLICY_KEY);

      expect(result.type).toBe('RATE_LIMITED_PENDING');
      expect(result.operationId).toBe(OPERATION_ID);
      expect(result.attemptsUsed).toBe(1);
      expect(result.maxAttempts).toBe(RETRY_CONFIG.dynamoDbWrite.maxRetries);
      expect(result.idempotencyRetained).toBe(true);

      if (result.type === 'RATE_LIMITED_PENDING') {
        expect(result.retryAfterMs).toBeGreaterThan(0);
      }

      // Idempotency was preserved
      expect(deps.preserveIdempotencyRecord).toHaveBeenCalledWith(OPERATION_ID);
      // Metric emitted
      expect(deps.emitThrottlingMetric).toHaveBeenCalledWith(
        expect.objectContaining({
          operationId: OPERATION_ID,
          policyKey: POLICY_KEY,
          attemptsUsed: 1,
          exhausted: false,
        }),
      );
    });
  });

  describe('Exhausted budget', () => {
    it('returns RATE_LIMITED_EXHAUSTED after max retries', async () => {
      const deps = createMockDeps();
      const service = new ThrottlingRecoveryService(deps);
      const maxRetries = RETRY_CONFIG.dynamoDbWrite.maxRetries; // 3

      // Exhaust the budget
      let result: any;
      for (let i = 0; i < maxRetries; i++) {
        result = await service.handleThrottledOperation(OPERATION_ID, POLICY_KEY);
      }

      // Last call should be EXHAUSTED
      expect(result.type).toBe('RATE_LIMITED_EXHAUSTED');
      expect(result.operationId).toBe(OPERATION_ID);
      expect(result.attemptsUsed).toBe(maxRetries);
      expect(result.maxAttempts).toBe(maxRetries);
      expect(result.idempotencyRetained).toBe(true);

      // Idempotency preserved on every call
      expect(deps.preserveIdempotencyRecord).toHaveBeenCalledTimes(maxRetries);
    });
  });

  describe('Idempotency always retained', () => {
    it('preserveIdempotencyRecord is called even on exhaustion', async () => {
      const deps = createMockDeps();
      const service = new ThrottlingRecoveryService(deps);
      const maxRetries = RETRY_CONFIG.dynamoDbWrite.maxRetries;

      // Exhaust completely
      for (let i = 0; i < maxRetries + 1; i++) {
        await service.handleThrottledOperation(OPERATION_ID, POLICY_KEY);
      }

      // Every single call preserved idempotency
      expect(deps.preserveIdempotencyRecord).toHaveBeenCalledTimes(maxRetries + 1);
      // All calls used the same operationId
      for (const call of deps.preserveIdempotencyRecord.mock.calls) {
        expect(call[0]).toBe(OPERATION_ID);
      }
    });

    it('idempotencyRetained is true on both PENDING and EXHAUSTED outcomes', async () => {
      const deps = createMockDeps();
      const service = new ThrottlingRecoveryService(deps);

      // First attempt → PENDING
      const pending = await service.handleThrottledOperation('op-002', POLICY_KEY);
      expect(pending.idempotencyRetained).toBe(true);

      // Exhaust for a different op
      const maxRetries = RETRY_CONFIG.dynamoDbWrite.maxRetries;
      let exhausted: any;
      for (let i = 0; i < maxRetries; i++) {
        exhausted = await service.handleThrottledOperation('op-003', POLICY_KEY);
      }
      expect(exhausted.idempotencyRetained).toBe(true);
    });
  });
});
