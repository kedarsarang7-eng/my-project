/**
 * Idempotency Persistence Integration Tests
 *
 * Verifies:
 * - First createIdempotencyRecord succeeds
 * - Second create with same operationId → IDEMPOTENCY_CONFLICT
 * - checkIdempotency for non-existent → NEW_OPERATION
 * - checkIdempotency with matching fingerprint → REPLAY
 * - checkIdempotency with different fingerprint → FINGERPRINT_MISMATCH
 * - checkIdempotency past retention → EXPIRED
 * - updateIdempotencyStatus with correct expected → succeeds
 * - updateIdempotencyStatus with wrong expected → STATUS_MISMATCH
 *
 * Requirements: 3.7–3.9, 6.7–6.13, 6.26–6.27
 */

import {
  createIdempotencyRecord,
  checkIdempotency,
  updateIdempotencyStatus,
} from '../idempotency';
import type { TenantContextWire } from '../../schemas/common.schema';

// ─── Mock DynamoDB DocumentClient ────────────────────────────────────────────

const mockSend = jest.fn();
const mockClient = { send: mockSend } as any;
const TABLE_NAME = 'MobileShopTable';

const tenantCtx: TenantContextWire = {
  tenantId: 'tenant-test-001',
  businessId: 'biz-001',
  subjectId: 'user-001',
  businessType: 'mobile_shop',
  permissions: ['mobile_shop:write'],
  correlationId: 'corr-001',
};

beforeEach(() => {
  mockSend.mockReset();
});

describe('createIdempotencyRecord', () => {
  it('first create succeeds and returns the record', async () => {
    mockSend.mockResolvedValueOnce({});

    const result = await createIdempotencyRecord(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'op-001',
      'fingerprint-abc',
      'PENDING',
      null,
    );

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.operationId).toBe('op-001');
      expect(result.value.fingerprint).toBe('fingerprint-abc');
      expect(result.value.status).toBe('PENDING');
      expect(result.value.tenantId).toBe('tenant-test-001');
      expect(result.value.PK).toContain('TENANT#tenant-test-001#');
      expect(result.value.SK).toContain('OP#op-001');
      expect(result.value.expiresAt).toBeGreaterThan(0);
      expect(result.value.retentionExpiresAt).toBeDefined();
    }
  });

  it('second create with same operationId returns IDEMPOTENCY_CONFLICT', async () => {
    const conditionalError = new Error('Conditional check failed');
    (conditionalError as any).name = 'ConditionalCheckFailedException';
    mockSend.mockRejectedValueOnce(conditionalError);

    const result = await createIdempotencyRecord(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'op-001',
      'fingerprint-abc',
      'PENDING',
      null,
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('IDEMPOTENCY_CONFLICT');
    }
  });
});

describe('checkIdempotency', () => {
  it('returns NEW_OPERATION for non-existent record', async () => {
    mockSend.mockResolvedValueOnce({ Item: undefined });

    const result = await checkIdempotency(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'op-nonexistent',
      'any-fingerprint',
    );

    expect(result.outcome).toBe('NEW_OPERATION');
  });

  it('returns REPLAY with matching fingerprint', async () => {
    const futureRetention = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    mockSend.mockResolvedValueOnce({
      Item: {
        tenantId: 'tenant-test-001',
        operationId: 'op-002',
        fingerprint: 'fingerprint-xyz',
        status: 'COMMITTED',
        responseRef: 'ref-123',
        retentionExpiresAt: futureRetention,
      },
    });

    const result = await checkIdempotency(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'op-002',
      'fingerprint-xyz',
    );

    expect(result.outcome).toBe('REPLAY');
    if (result.outcome === 'REPLAY') {
      expect(result.status).toBe('COMMITTED');
      expect(result.responseRef).toBe('ref-123');
    }
  });

  it('returns FINGERPRINT_MISMATCH with different fingerprint', async () => {
    const futureRetention = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    mockSend.mockResolvedValueOnce({
      Item: {
        tenantId: 'tenant-test-001',
        operationId: 'op-003',
        fingerprint: 'fingerprint-original',
        status: 'COMMITTED',
        responseRef: null,
        retentionExpiresAt: futureRetention,
      },
    });

    const result = await checkIdempotency(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'op-003',
      'fingerprint-different',
    );

    expect(result.outcome).toBe('FINGERPRINT_MISMATCH');
  });

  it('returns EXPIRED when past retention', async () => {
    const pastRetention = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    mockSend.mockResolvedValueOnce({
      Item: {
        tenantId: 'tenant-test-001',
        operationId: 'op-004',
        fingerprint: 'fingerprint-abc',
        status: 'COMMITTED',
        responseRef: null,
        retentionExpiresAt: pastRetention,
      },
    });

    const result = await checkIdempotency(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'op-004',
      'fingerprint-abc',
    );

    expect(result.outcome).toBe('EXPIRED');
  });
});

describe('updateIdempotencyStatus', () => {
  it('succeeds with correct expected status', async () => {
    mockSend.mockResolvedValueOnce({});

    const result = await updateIdempotencyStatus(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'op-005',
      'PENDING',
      'COMMITTED',
      'response-ref-001',
    );

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.status).toBe('COMMITTED');
    }
  });

  it('returns STATUS_MISMATCH with wrong expected status', async () => {
    const conditionalError = new Error('Condition not met');
    (conditionalError as any).name = 'ConditionalCheckFailedException';
    mockSend.mockRejectedValueOnce(conditionalError);

    const result = await updateIdempotencyStatus(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'op-005',
      'PENDING',
      'COMMITTED',
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('STATUS_MISMATCH');
    }
  });
});
