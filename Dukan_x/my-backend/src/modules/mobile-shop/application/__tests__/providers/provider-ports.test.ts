/**
 * Provider Port Integration Tests
 *
 * Tests provider-neutral port functions:
 * - deriveProviderRequestId: deterministic ID derivation
 * - checkFeatureGate: feature policy enforcement
 * - validateRetryConsistency: idempotency fingerprint validation
 *
 * No mocks needed — these are pure functions or use the in-memory config.
 *
 * Requirements covered: 10.1–10.12
 */

import {
  deriveProviderRequestId,
  checkFeatureGate,
  validateRetryConsistency,
} from '../../providers/provider-port';

describe('Provider Ports', () => {
  // ─── deriveProviderRequestId ───────────────────────────────────────────

  describe('deriveProviderRequestId', () => {
    it('same inputs → same output (deterministic)', () => {
      const operationId = 'op-12345';
      const providerType = 'finance';

      const result1 = deriveProviderRequestId(operationId, providerType);
      const result2 = deriveProviderRequestId(operationId, providerType);

      expect(result1.value).toBe(result2.value);
      expect(result1.operationId).toBe(result2.operationId);
      expect(result1.providerType).toBe(result2.providerType);
      expect(result1.value).toBe(`PRQ-${providerType}-${operationId}`);
    });

    it('different provider → different ID', () => {
      const operationId = 'op-12345';

      const financeId = deriveProviderRequestId(operationId, 'finance');
      const rechargeId = deriveProviderRequestId(operationId, 'recharge');

      expect(financeId.value).not.toBe(rechargeId.value);
      expect(financeId.providerType).toBe('finance');
      expect(rechargeId.providerType).toBe('recharge');
    });

    it('result includes operationId and providerType metadata', () => {
      const result = deriveProviderRequestId('op-abc', 'ocr');

      expect(result.operationId).toBe('op-abc');
      expect(result.providerType).toBe('ocr');
      expect(result.issuedAt).toBeDefined();
      expect(new Date(result.issuedAt).getTime()).not.toBeNaN();
    });
  });

  // ─── checkFeatureGate ──────────────────────────────────────────────────

  describe('checkFeatureGate', () => {
    it('feature enabled (tenant has capability) → allowed', () => {
      // IMEI_TRACKING requires 'imei_tracking' capability
      const result = checkFeatureGate(
        'IMEI_TRACKING',
        ['imei_tracking', 'service_jobs'],
        'corr-001',
      );

      expect(result.allowed).toBe(true);
    });

    it('feature disabled (tenant lacks capability) → denied with FEATURE_DISABLED', () => {
      // FINANCE_PLANS requires 'finance' capability
      const result = checkFeatureGate(
        'FINANCE_PLANS',
        ['imei_tracking', 'service_jobs'], // No 'finance' capability
        'corr-002',
      );

      expect(result.allowed).toBe(false);
      if (!result.allowed) {
        expect(result.outcome.code).toBe('FEATURE_DISABLED');
        expect(result.outcome.category).toBe('authorization');
        expect(result.outcome.httpStatus).toBe(403);
        expect(result.outcome.retryable).toBe(false);
        expect(result.outcome.statePreserved).toBe(true);
      }
    });

    it('unknown feature → denied with FEATURE_NOT_FOUND', () => {
      const result = checkFeatureGate(
        'NON_EXISTENT_FEATURE',
        ['imei_tracking'],
        'corr-003',
      );

      expect(result.allowed).toBe(false);
      if (!result.allowed) {
        expect(result.outcome.code).toBe('FEATURE_NOT_FOUND');
        expect(result.outcome.category).toBe('authorization');
        expect(result.outcome.httpStatus).toBe(403);
        expect(result.outcome.retryable).toBe(false);
        expect(result.outcome.statePreserved).toBe(true);
      }
    });
  });

  // ─── validateRetryConsistency ──────────────────────────────────────────

  describe('validateRetryConsistency', () => {
    it('same fingerprint → allowed', () => {
      const result = validateRetryConsistency(
        'fp-abc123',
        'fp-abc123',
        'corr-004',
      );

      expect(result.allowed).toBe(true);
    });

    it('different fingerprint → denied with PROVIDER_IDEMPOTENCY_MISMATCH', () => {
      const result = validateRetryConsistency(
        'fp-original',
        'fp-different',
        'corr-005',
      );

      expect(result.allowed).toBe(false);
      if (!result.allowed) {
        expect(result.outcome.code).toBe('PROVIDER_IDEMPOTENCY_MISMATCH');
        expect(result.outcome.category).toBe('conflict');
        expect(result.outcome.httpStatus).toBe(409);
        expect(result.outcome.retryable).toBe(false);
        expect(result.outcome.statePreserved).toBe(true);
        expect(result.outcome.fields).toContain('providerRequestId');
        expect(result.outcome.fields).toContain('mutationFingerprint');
      }
    });
  });
});
