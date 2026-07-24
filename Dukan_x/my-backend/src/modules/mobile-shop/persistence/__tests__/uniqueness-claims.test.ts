/**
 * Uniqueness Claims Persistence Integration Tests
 *
 * Verifies:
 * - First IMEI claim succeeds
 * - Second IMEI claim with same IMEI → CLAIM_ALREADY_EXISTS (first wins)
 * - releaseImeiClaim with matching owner/version → succeeds
 * - releaseImeiClaim with wrong owner → OWNER_MISMATCH
 * - First reservation claim succeeds
 * - Second reservation for same unit → RESERVATION_ALREADY_EXISTS
 *
 * Requirements: 3.7–3.9, 6.7–6.13, 6.26–6.27
 */

import {
  createImeiClaim,
  createReservationClaim,
  releaseImeiClaim,
  releaseReservationClaim,
} from '../uniqueness-claims';
import type { TenantContextWire } from '../../schemas/common.schema';

// ─── Mock DynamoDB DocumentClient ────────────────────────────────────────────

const mockSend = jest.fn();
const mockClient = { send: mockSend } as any;
const TABLE_NAME = 'MobileShopTable';

const tenantCtx: TenantContextWire = {
  tenantId: 'tenant-claims-001',
  businessId: 'biz-claims-001',
  subjectId: 'user-001',
  businessType: 'mobile_shop',
  permissions: ['mobile_shop:write'],
  correlationId: 'corr-claims-001',
};

beforeEach(() => {
  mockSend.mockReset();
});

describe('createImeiClaim', () => {
  it('first IMEI claim succeeds', async () => {
    mockSend.mockResolvedValueOnce({});

    const result = await createImeiClaim(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      '123456789012345',
      'entity-001',
      1,
    );

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.claimType).toBe('IMEI');
      expect(result.value.normalizedImei).toBe('123456789012345');
      expect(result.value.ownerEntityId).toBe('entity-001');
      expect(result.value.ownerVersion).toBe(1);
      expect(result.value.tenantId).toBe('tenant-claims-001');
      expect(result.value.PK).toContain('TENANT#tenant-claims-001#');
      expect(result.value.SK).toContain('IMEI#123456789012345');
    }
  });

  it('second IMEI claim with same IMEI returns CLAIM_ALREADY_EXISTS (first wins)', async () => {
    const conditionalError = new Error('Conditional check failed');
    (conditionalError as any).name = 'ConditionalCheckFailedException';
    mockSend.mockRejectedValueOnce(conditionalError);

    const result = await createImeiClaim(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      '123456789012345',
      'entity-002',
      1,
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('CLAIM_ALREADY_EXISTS');
    }
  });
});

describe('releaseImeiClaim', () => {
  it('succeeds with matching owner and version', async () => {
    mockSend.mockResolvedValueOnce({});

    const result = await releaseImeiClaim(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      '123456789012345',
      'entity-001',
      1,
    );

    expect(result.ok).toBe(true);
  });

  it('returns OWNER_MISMATCH with wrong owner', async () => {
    const conditionalError = new Error('Condition not met');
    (conditionalError as any).name = 'ConditionalCheckFailedException';
    mockSend.mockRejectedValueOnce(conditionalError);

    const result = await releaseImeiClaim(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      '123456789012345',
      'wrong-entity',
      1,
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('OWNER_MISMATCH');
    }
  });
});

describe('createReservationClaim', () => {
  it('first reservation claim succeeds', async () => {
    mockSend.mockResolvedValueOnce({});

    const expiresAt = Math.floor(Date.now() / 1000) + 3600;
    const result = await createReservationClaim(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'unit-001',
      'reservation-001',
      1,
      expiresAt,
    );

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.claimType).toBe('RESERVATION');
      expect(result.value.unitId).toBe('unit-001');
      expect(result.value.reservationId).toBe('reservation-001');
      expect(result.value.reservationVersion).toBe(1);
      expect(result.value.expiresAt).toBe(expiresAt);
      expect(result.value.tenantId).toBe('tenant-claims-001');
      expect(result.value.PK).toContain('TENANT#tenant-claims-001#');
      expect(result.value.SK).toContain('RESERVATION#unit-001');
    }
  });

  it('second reservation for same unit returns RESERVATION_ALREADY_EXISTS', async () => {
    const conditionalError = new Error('Conditional check failed');
    (conditionalError as any).name = 'ConditionalCheckFailedException';
    mockSend.mockRejectedValueOnce(conditionalError);

    const expiresAt = Math.floor(Date.now() / 1000) + 3600;
    const result = await createReservationClaim(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'unit-001',
      'reservation-002',
      1,
      expiresAt,
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('RESERVATION_ALREADY_EXISTS');
    }
  });
});

describe('releaseReservationClaim', () => {
  it('succeeds with correct reservation', async () => {
    mockSend.mockResolvedValueOnce({});

    const result = await releaseReservationClaim(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'unit-001',
      'reservation-001',
      1,
    );

    expect(result.ok).toBe(true);
  });

  it('returns OWNER_MISMATCH with wrong reservation', async () => {
    const conditionalError = new Error('Condition not met');
    (conditionalError as any).name = 'ConditionalCheckFailedException';
    mockSend.mockRejectedValueOnce(conditionalError);

    const result = await releaseReservationClaim(
      mockClient,
      TABLE_NAME,
      tenantCtx,
      'unit-001',
      'wrong-reservation',
      1,
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('OWNER_MISMATCH');
    }
  });
});
