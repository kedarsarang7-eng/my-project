/**
 * Response Mapper Integration Tests
 *
 * Verifies HTTP response mapping for all SaleOutcome types:
 * - committed → 200 with confirmation field present
 * - acceptedPending → 202 with confirmation and reconciliationId
 * - conflict → 409 with DeterministicOutcome body
 * - rejected → uses httpStatus from outcome
 * - replay → 200 with state='CURRENT', NO confirmation field
 * - Confirmation field is ABSENT when outcome has no confirmation
 *
 * Requirements: 3.3–3.11, 6.3–6.13, 6.42, 12.7–12.10
 */

import {
  mapSaleOutcomeToResponse,
  mapDeterministicOutcomeToResponse,
} from '../response-mapper';
import type {
  SaleCommitted,
  SaleAcceptedPending,
  SaleConflict,
  SaleRejected,
  SaleReplay,
  AuthoritativeConfirmation,
} from '../../application/sale-outcome';
import type { DeterministicOutcome } from '../../application/error-mapper';
import { CORRELATION_HEADER } from '../../middleware/correlation';

// ─── Test Helpers ────────────────────────────────────────────────────────────

const correlationId = 'corr-resp-test-001';

/** Helper to extract structured result from APIGatewayProxyResultV2 */
function asStructured(response: unknown) {
  const r = response as { statusCode: number; headers?: Record<string, string>; body?: string };
  return {
    statusCode: r.statusCode,
    headers: r.headers,
    body: r.body ? JSON.parse(r.body) : undefined,
  };
}

function buildConfirmation(overrides?: Partial<AuthoritativeConfirmation>): AuthoritativeConfirmation {
  return {
    authority: 'AWS_DYNAMODB',
    state: 'COMMITTED',
    operationId: 'op-001',
    confirmedAt: '2024-06-15T10:00:00.000Z',
    dataModelVersion: 1,
    entityVersions: { 'inv-001': 1, '123456789012347': 2 },
    ...overrides,
  };
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('mapSaleOutcomeToResponse', () => {
  describe('committed → 200 with confirmation', () => {
    it('returns 200 with state=COMMITTED and confirmation field present', () => {
      const outcome: SaleCommitted = {
        type: 'committed',
        invoiceId: 'inv-001',
        confirmation: buildConfirmation(),
      };

      const { statusCode, body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(statusCode).toBe(200);
      expect(body.state).toBe('COMMITTED');
      expect(body.data.invoiceId).toBe('inv-001');
      expect(body.confirmation).toBeDefined();
      expect(body.confirmation.authority).toBe('AWS_DYNAMODB');
      expect(body.confirmation.state).toBe('COMMITTED');
      expect(body.confirmation.operationId).toBe('op-001');
      expect(body.confirmation.entityVersions).toEqual({ 'inv-001': 1, '123456789012347': 2 });
    });

    it('includes correlation header', () => {
      const outcome: SaleCommitted = {
        type: 'committed',
        invoiceId: 'inv-001',
        confirmation: buildConfirmation(),
      };

      const { headers } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(headers).toBeDefined();
      expect(headers![CORRELATION_HEADER]).toBe(correlationId);
      expect(headers!['Content-Type']).toBe('application/json');
    });
  });

  describe('acceptedPending → 202 with confirmation and reconciliationId', () => {
    it('returns 202 with state=ACCEPTED_PENDING, reconciliationId, and confirmation', () => {
      const outcome: SaleAcceptedPending = {
        type: 'acceptedPending',
        invoiceId: 'inv-002',
        reconciliationId: 'recon-001',
        confirmation: buildConfirmation({
          state: 'ACCEPTED_PENDING',
          reconciliationId: 'recon-001',
        }),
      };

      const { statusCode, body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(statusCode).toBe(202);
      expect(body.state).toBe('ACCEPTED_PENDING');
      expect(body.reconciliationId).toBe('recon-001');
      expect(body.data.invoiceId).toBe('inv-002');
      expect(body.confirmation).toBeDefined();
      expect(body.confirmation.state).toBe('ACCEPTED_PENDING');
      expect(body.confirmation.reconciliationId).toBe('recon-001');
    });
  });

  describe('conflict → 409 with DeterministicOutcome body', () => {
    it('returns 409 with error code and fields', () => {
      const outcome: SaleConflict = {
        type: 'conflict',
        outcome: {
          code: 'IDEMPOTENCY_MISMATCH',
          category: 'idempotency',
          retryable: false,
          statePreserved: true,
          fields: ['operationId', 'mutationFingerprint'],
          httpStatus: 409,
          correlationId,
        },
      };

      const { statusCode, body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(statusCode).toBe(409);
      expect(body.error).toBe('IDEMPOTENCY_MISMATCH');
      expect(body.category).toBe('idempotency');
      expect(body.retryable).toBe(false);
      expect(body.statePreserved).toBe(true);
      expect(body.fields).toEqual(['operationId', 'mutationFingerprint']);
      expect(body.correlationId).toBe(correlationId);
      // No confirmation field on conflict
      expect(body.confirmation).toBeUndefined();
    });

    it('includes details when present in DeterministicOutcome', () => {
      const outcome: SaleConflict = {
        type: 'conflict',
        outcome: {
          code: 'VERSION_CONFLICT',
          category: 'conflict',
          retryable: false,
          statePreserved: true,
          fields: ['expectedVersion'],
          httpStatus: 409,
          correlationId,
          details: { cancellationReasons: ['ConditionalCheckFailed', 'None'] },
        },
      };

      const { body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(body.details).toBeDefined();
      expect(body.details.cancellationReasons).toContain('ConditionalCheckFailed');
    });
  });

  describe('rejected → uses httpStatus from outcome', () => {
    it('returns 400 for validation errors', () => {
      const outcome: SaleRejected = {
        type: 'rejected',
        outcome: {
          code: 'SCHEMA_INVALID',
          category: 'validation',
          retryable: false,
          statePreserved: true,
          fields: ['deviceLines'],
          httpStatus: 400,
          correlationId,
        },
      };

      const { statusCode, body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(statusCode).toBe(400);
      expect(body.error).toBe('SCHEMA_INVALID');
      expect(body.category).toBe('validation');
    });

    it('returns 429 for rate limiting', () => {
      const outcome: SaleRejected = {
        type: 'rejected',
        outcome: {
          code: 'RATE_LIMITED',
          category: 'rate_limited',
          retryable: true,
          statePreserved: true,
          fields: [],
          httpStatus: 429,
          correlationId,
        },
      };

      const { statusCode, body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(statusCode).toBe(429);
      expect(body.retryable).toBe(true);
    });

    it('returns 503 for system errors', () => {
      const outcome: SaleRejected = {
        type: 'rejected',
        outcome: {
          code: 'AMBIGUOUS_OUTCOME',
          category: 'system',
          retryable: true,
          statePreserved: true,
          fields: [],
          httpStatus: 503,
          correlationId,
        },
      };

      const { statusCode } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(statusCode).toBe(503);
    });
  });

  describe('replay → 200 with state=CURRENT, NO confirmation field', () => {
    it('returns 200 with state=CURRENT and no confirmation', () => {
      const outcome: SaleReplay = {
        type: 'replay',
        operationId: 'op-001',
        status: 'COMMITTED',
        responseRef: 'inv-001',
      };

      const { statusCode, body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(statusCode).toBe(200);
      expect(body.state).toBe('CURRENT');
      expect(body.operationId).toBe('op-001');
      expect(body.status).toBe('COMMITTED');
      expect(body.responseRef).toBe('inv-001');
      // CRITICAL: No confirmation field on replay
      expect(body.confirmation).toBeUndefined();
    });

    it('handles null responseRef gracefully', () => {
      const outcome: SaleReplay = {
        type: 'replay',
        operationId: 'op-002',
        status: 'ACCEPTED_PENDING',
        responseRef: null,
      };

      const { statusCode, body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(statusCode).toBe(200);
      expect(body.state).toBe('CURRENT');
      expect(body.responseRef).toBeNull();
      expect(body.confirmation).toBeUndefined();
    });
  });

  describe('Confirmation field ABSENT when outcome has no confirmation', () => {
    it('conflict outcome has no confirmation field in response body', () => {
      const outcome: SaleConflict = {
        type: 'conflict',
        outcome: {
          code: 'CONCURRENT_CLAIM',
          category: 'conflict',
          retryable: false,
          statePreserved: true,
          fields: ['imei'],
          httpStatus: 409,
          correlationId,
        },
      };

      const { body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(body.confirmation).toBeUndefined();
    });

    it('rejected outcome has no confirmation field in response body', () => {
      const outcome: SaleRejected = {
        type: 'rejected',
        outcome: {
          code: 'OPERATION_ID_MISSING',
          category: 'validation',
          retryable: false,
          statePreserved: true,
          fields: ['operationId'],
          httpStatus: 400,
          correlationId,
        },
      };

      const { body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(body.confirmation).toBeUndefined();
    });

    it('replay outcome has no confirmation field in response body', () => {
      const outcome: SaleReplay = {
        type: 'replay',
        operationId: 'op-003',
        status: 'COMMITTED',
        responseRef: 'inv-003',
      };

      const { body } = asStructured(mapSaleOutcomeToResponse(outcome, correlationId));

      expect(body.confirmation).toBeUndefined();
    });
  });
});

describe('mapDeterministicOutcomeToResponse', () => {
  it('maps a DeterministicOutcome to its httpStatus', () => {
    const outcome: DeterministicOutcome = {
      code: 'LIFECYCLE_TRANSITION_DENIED',
      category: 'conflict',
      retryable: false,
      statePreserved: true,
      fields: ['lifecycleState'],
      httpStatus: 409,
      correlationId,
    };

    const { statusCode, body } = asStructured(mapDeterministicOutcomeToResponse(outcome, correlationId));

    expect(statusCode).toBe(409);
    expect(body.error).toBe('LIFECYCLE_TRANSITION_DENIED');
    expect(body.category).toBe('conflict');
    expect(body.statePreserved).toBe(true);
    expect(body.fields).toEqual(['lifecycleState']);
  });

  it('includes correlation header in error responses', () => {
    const outcome: DeterministicOutcome = {
      code: 'INTERNAL_ERROR',
      category: 'system',
      retryable: true,
      statePreserved: true,
      fields: [],
      httpStatus: 500,
      correlationId,
    };

    const { headers } = asStructured(mapDeterministicOutcomeToResponse(outcome, correlationId));

    expect(headers![CORRELATION_HEADER]).toBe(correlationId);
  });
});
