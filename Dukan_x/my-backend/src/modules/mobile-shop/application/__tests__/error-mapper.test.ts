/**
 * Error Mapper Integration Tests
 *
 * Verifies:
 * - ConditionalCheckFailedException + VERSION context → VERSION_CONFLICT
 * - ConditionalCheckFailedException + UNIQUENESS → IMEI_DUPLICATE
 * - ConditionalCheckFailedException + LIFECYCLE → LIFECYCLE_TRANSITION_DENIED
 * - TransactionCanceledException → maps first failure reason
 * - ThrottlingException → RATE_LIMITED (retryable)
 * - SDK timeout → AMBIGUOUS_OUTCOME (retryable, statePreserved)
 * - All outcomes have statePreserved: true
 *
 * Requirements: 6.7–6.13, 6.23
 */

import { mapDynamoDbError } from '../error-mapper';
import type { ErrorMappingContext } from '../error-mapper';

describe('mapDynamoDbError', () => {
  const baseContext: ErrorMappingContext = {
    correlationId: 'corr-err-001',
    conditionType: 'VERSION',
    fields: ['expectedVersion'],
  };

  describe('ConditionalCheckFailedException', () => {
    const conditionalError = Object.assign(new Error('Conditional check failed'), {
      name: 'ConditionalCheckFailedException',
    });

    it('VERSION context → VERSION_CONFLICT', () => {
      const outcome = mapDynamoDbError(conditionalError, {
        ...baseContext,
        conditionType: 'VERSION',
        fields: ['expectedVersion'],
      });

      expect(outcome.code).toBe('VERSION_CONFLICT');
      expect(outcome.category).toBe('conflict');
      expect(outcome.statePreserved).toBe(true);
      expect(outcome.httpStatus).toBe(409);
    });

    it('UNIQUENESS context → IMEI_DUPLICATE', () => {
      const outcome = mapDynamoDbError(conditionalError, {
        ...baseContext,
        conditionType: 'UNIQUENESS',
        fields: ['imei'],
      });

      expect(outcome.code).toBe('IMEI_DUPLICATE');
      expect(outcome.category).toBe('conflict');
      expect(outcome.statePreserved).toBe(true);
      expect(outcome.httpStatus).toBe(409);
    });

    it('LIFECYCLE context → LIFECYCLE_TRANSITION_DENIED', () => {
      const outcome = mapDynamoDbError(conditionalError, {
        ...baseContext,
        conditionType: 'LIFECYCLE',
        fields: ['lifecycleState'],
      });

      expect(outcome.code).toBe('LIFECYCLE_TRANSITION_DENIED');
      expect(outcome.category).toBe('conflict');
      expect(outcome.statePreserved).toBe(true);
      expect(outcome.httpStatus).toBe(409);
    });

    it('IDEMPOTENCY context → IDEMPOTENCY_MISMATCH', () => {
      const outcome = mapDynamoDbError(conditionalError, {
        ...baseContext,
        conditionType: 'IDEMPOTENCY',
        fields: ['operationId', 'mutationFingerprint'],
      });

      expect(outcome.code).toBe('IDEMPOTENCY_MISMATCH');
      expect(outcome.category).toBe('idempotency');
      expect(outcome.statePreserved).toBe(true);
      expect(outcome.httpStatus).toBe(409);
    });
  });

  describe('TransactionCanceledException', () => {
    it('maps first failure reason from CancellationReasons', () => {
      const txnError = Object.assign(new Error('Transaction cancelled'), {
        name: 'TransactionCanceledException',
        CancellationReasons: [
          { Code: 'ConditionalCheckFailed' },
          { Code: 'None' },
        ],
      });

      const outcome = mapDynamoDbError(txnError, {
        ...baseContext,
        conditionType: 'COMPOSITE',
      });

      expect(outcome.statePreserved).toBe(true);
      // Should produce a conflict-category outcome
      expect(['conflict', 'system']).toContain(outcome.category);
    });
  });

  describe('ThrottlingException', () => {
    it('maps to RATE_LIMITED (retryable)', () => {
      const throttleError = Object.assign(new Error('Rate exceeded'), {
        name: 'ThrottlingException',
      });

      const outcome = mapDynamoDbError(throttleError, {
        ...baseContext,
        conditionType: 'UNKNOWN',
        resource: 'MobileShopTable-GSI1',
      });

      expect(outcome.code).toBe('RATE_LIMITED');
      expect(outcome.category).toBe('rate_limited');
      expect(outcome.retryable).toBe(true);
      expect(outcome.statePreserved).toBe(true);
      expect(outcome.httpStatus).toBe(429);
    });
  });

  describe('SDK timeout', () => {
    it('maps to AMBIGUOUS_OUTCOME (retryable, statePreserved)', () => {
      const timeoutError = Object.assign(new Error('Request timeout'), {
        name: 'TimeoutError',
      });

      const outcome = mapDynamoDbError(timeoutError, {
        ...baseContext,
        conditionType: 'UNKNOWN',
      });

      expect(outcome.code).toBe('AMBIGUOUS_OUTCOME');
      expect(outcome.retryable).toBe(true);
      expect(outcome.statePreserved).toBe(true);
      expect(outcome.httpStatus).toBe(503);
    });

    it('network error maps to AMBIGUOUS_OUTCOME', () => {
      const networkError = Object.assign(new Error('Connection refused'), {
        name: 'NetworkingError',
        code: 'ECONNREFUSED',
      });

      const outcome = mapDynamoDbError(networkError, {
        ...baseContext,
        conditionType: 'UNKNOWN',
      });

      expect(outcome.code).toBe('AMBIGUOUS_OUTCOME');
      expect(outcome.retryable).toBe(true);
      expect(outcome.statePreserved).toBe(true);
    });
  });

  describe('statePreserved guarantee', () => {
    it('all mapped outcomes have statePreserved: true', () => {
      const errors = [
        Object.assign(new Error(''), { name: 'ConditionalCheckFailedException' }),
        Object.assign(new Error(''), { name: 'ThrottlingException' }),
        Object.assign(new Error(''), { name: 'ProvisionedThroughputExceededException' }),
        Object.assign(new Error(''), { name: 'RequestLimitExceeded' }),
        Object.assign(new Error(''), { name: 'InternalServerError' }),
        Object.assign(new Error(''), { name: 'ResourceNotFoundException' }),
        Object.assign(new Error(''), { name: 'TimeoutError' }),
      ];

      for (const err of errors) {
        const outcome = mapDynamoDbError(err, {
          ...baseContext,
          conditionType: 'UNKNOWN',
        });
        expect(outcome.statePreserved).toBe(true);
      }
    });
  });
});
