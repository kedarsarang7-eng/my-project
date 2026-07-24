/**
 * Continuation Token Tests
 *
 * Verifies:
 * - Valid token round-trips: create → validate → returns exclusiveStartKey
 * - Expired token is rejected
 * - Cross-tenant token is rejected
 * - Wrong access pattern is rejected
 * - Wrong query hash is rejected
 * - Tampered signature is rejected
 * - Malformed token is rejected
 * - Unsupported model version is rejected
 *
 * Requirements: 6.15–6.17, 13.4, 13.6
 */

import {
  createContinuationToken,
  validateContinuationToken,
  computeQueryHash,
} from '../continuation-token';
import { PAGINATION_CONFIG } from '../../config/pagination.config';
import type { AccessPatternId } from '../access-patterns';

const SECRET = 'test-secret-key-for-unit-tests';
const TENANT_A = 'tenant-abc-123';
const TENANT_B = 'tenant-xyz-789';
const ACCESS_PATTERN: AccessPatternId = 'AP-03';
const EXCLUSIVE_START_KEY = { PK: 'TENANT#tenant-abc-123#ENTITY#UNIT#u1', SK: 'META#UNIT' };

function createValidToken(overrides?: Partial<Parameters<typeof createContinuationToken>[0]>) {
  const queryParams = { state: 'IN_STOCK', tenantId: TENANT_A };
  const queryHash = computeQueryHash(queryParams);

  return {
    token: createContinuationToken(
      {
        tenantId: TENANT_A,
        accessPatternId: ACCESS_PATTERN,
        queryHash,
        indexName: 'GSI1',
        exclusiveStartKey: EXCLUSIVE_START_KEY,
        dataModelVersion: 1,
        ...overrides,
      },
      SECRET,
    ),
    queryHash,
  };
}

describe('Continuation Token', () => {
  describe('valid token round-trip', () => {
    it('create → validate → returns exclusiveStartKey', () => {
      const { token, queryHash } = createValidToken();

      const result = validateContinuationToken(
        token,
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(true);
      if (result.valid) {
        expect(result.exclusiveStartKey).toEqual(EXCLUSIVE_START_KEY);
      }
    });

    it('computeQueryHash is deterministic for same params', () => {
      const params = { state: 'IN_STOCK', tenantId: TENANT_A };
      const hash1 = computeQueryHash(params);
      const hash2 = computeQueryHash(params);
      expect(hash1).toBe(hash2);
    });

    it('computeQueryHash is order-independent', () => {
      const hash1 = computeQueryHash({ a: '1', b: '2' });
      const hash2 = computeQueryHash({ b: '2', a: '1' });
      expect(hash1).toBe(hash2);
    });
  });

  describe('expired token rejection', () => {
    it('rejects token that has expired', () => {
      const { token, queryHash } = createValidToken();

      // Simulate time past expiry
      const futureTime = Math.floor(Date.now() / 1000) + PAGINATION_CONFIG.tokenExpirySeconds + 10;

      const result = validateContinuationToken(
        token,
        { tenantId: TENANT_A, nowEpochSeconds: futureTime },
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('EXPIRED');
      }
    });
  });

  describe('cross-tenant token rejection', () => {
    it('rejects token when validated with different tenant', () => {
      const { token, queryHash } = createValidToken();

      const result = validateContinuationToken(
        token,
        { tenantId: TENANT_B }, // Different tenant
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('TENANT_MISMATCH');
      }
    });
  });

  describe('wrong access pattern rejection', () => {
    it('rejects token when validated with different access pattern', () => {
      const { token, queryHash } = createValidToken();

      const result = validateContinuationToken(
        token,
        { tenantId: TENANT_A },
        'AP-07' as AccessPatternId, // Different AP
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('ACCESS_PATTERN_MISMATCH');
      }
    });
  });

  describe('wrong query hash rejection', () => {
    it('rejects token when validated with different query hash', () => {
      const { token } = createValidToken();

      const differentHash = computeQueryHash({ state: 'SOLD', tenantId: TENANT_A });

      const result = validateContinuationToken(
        token,
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        differentHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('QUERY_HASH_MISMATCH');
      }
    });
  });

  describe('tampered signature rejection', () => {
    it('rejects token with tampered signature', () => {
      const { token, queryHash } = createValidToken();

      // Tamper with the signature portion
      const parts = token.split('.');
      const tamperedToken = parts[0] + '.TAMPERED_SIGNATURE_DATA';

      const result = validateContinuationToken(
        tamperedToken,
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('SIGNATURE_INVALID');
      }
    });

    it('rejects token validated with different secret', () => {
      const { token, queryHash } = createValidToken();

      const result = validateContinuationToken(
        token,
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        queryHash,
        'wrong-secret',
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('SIGNATURE_INVALID');
      }
    });
  });

  describe('malformed token rejection', () => {
    it('rejects token without separator', () => {
      const { queryHash } = createValidToken();

      const result = validateContinuationToken(
        'no-separator-here',
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('SIGNATURE_INVALID');
      }
    });

    it('rejects empty string token', () => {
      const { queryHash } = createValidToken();

      const result = validateContinuationToken(
        '',
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('SIGNATURE_INVALID');
      }
    });

    it('rejects token with invalid base64 payload', () => {
      const { queryHash } = createValidToken();

      // Create a token-like string with valid separator but garbage payload
      const result = validateContinuationToken(
        '!!!invalid-base64!!!.some-signature',
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('SIGNATURE_INVALID');
      }
    });
  });

  describe('unsupported model version rejection', () => {
    it('rejects token with model version below minSupportedVersion', () => {
      const queryParams = { state: 'IN_STOCK', tenantId: TENANT_A };
      const queryHash = computeQueryHash(queryParams);

      const token = createContinuationToken(
        {
          tenantId: TENANT_A,
          accessPatternId: ACCESS_PATTERN,
          queryHash,
          indexName: 'GSI1',
          exclusiveStartKey: EXCLUSIVE_START_KEY,
          dataModelVersion: 0, // Below min supported
        },
        SECRET,
      );

      const result = validateContinuationToken(
        token,
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('MODEL_VERSION_UNSUPPORTED');
      }
    });

    it('rejects token with model version above maxSupportedVersion', () => {
      const queryParams = { state: 'IN_STOCK', tenantId: TENANT_A };
      const queryHash = computeQueryHash(queryParams);

      const token = createContinuationToken(
        {
          tenantId: TENANT_A,
          accessPatternId: ACCESS_PATTERN,
          queryHash,
          indexName: 'GSI1',
          exclusiveStartKey: EXCLUSIVE_START_KEY,
          dataModelVersion: 999, // Above max supported
        },
        SECRET,
      );

      const result = validateContinuationToken(
        token,
        { tenantId: TENANT_A },
        ACCESS_PATTERN,
        queryHash,
        SECRET,
      );

      expect(result.valid).toBe(false);
      if (!result.valid) {
        expect(result.reason).toBe('MODEL_VERSION_UNSUPPORTED');
      }
    });
  });
});
