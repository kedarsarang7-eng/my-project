/**
 * Key Codec Tests
 *
 * Verifies:
 * - Every PK starts with TENANT#<tenantId>#
 * - GSI1PK and GSI2PK start with TENANT#<tenantId>#
 * - decodePK correctly extracts tenantId
 * - verifyTenantInKey returns false for mismatched tenant
 * - verifyItemTenant returns false for item with different tenantId
 * - Empty tenantId throws KeyCodecError
 *
 * Requirements: 6.5–6.6, 6.14, 6.19, 6.25, 6.28–6.30
 */

import {
  encodePK,
  encodeGSI1PK,
  encodeGSI2PK,
  decodePK,
  extractTenantId,
  verifyTenantInKey,
  verifyItemTenant,
  buildEntityAggregatePK,
  buildClaimPK,
  buildUnitLifecycleGSI1PK,
  buildInvoicePK,
  buildCustomerHistoryGSI2PK,
  buildServiceJobGSI1PK,
  buildWarrantyGSI1PK,
  buildStatusGSI1PK,
  buildChangeFeedPK,
  buildAuditTimelineGSI2PK,
  buildReconciliationGSI1PK,
  buildProjectionPK,
  buildIdempotencyPK,
  buildCatalogGSI2PK,
  KeyCodecError,
} from '../key-codec';

const TENANT_A = 'tenant-abc-123';
const TENANT_B = 'tenant-xyz-789';

describe('Key Codec', () => {
  describe('PK encoding — tenant prefix', () => {
    it('encodePK starts with TENANT#<tenantId>#', () => {
      const pk = encodePK(TENANT_A, 'ENTITY', 'UNIT', 'u1');
      expect(pk).toBe(`TENANT#${TENANT_A}#ENTITY#UNIT#u1`);
      expect(pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildEntityAggregatePK starts with TENANT#<tenantId>#', () => {
      const pk = buildEntityAggregatePK(TENANT_A, 'UNIT', 'unit-001');
      expect(pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildClaimPK starts with TENANT#<tenantId>#', () => {
      const pk = buildClaimPK(TENANT_A);
      expect(pk).toBe(`TENANT#${TENANT_A}#CLAIM`);
      expect(pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildInvoicePK starts with TENANT#<tenantId>#', () => {
      const pk = buildInvoicePK(TENANT_A, 'inv-001');
      expect(pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildChangeFeedPK starts with TENANT#<tenantId>#', () => {
      const pk = buildChangeFeedPK(TENANT_A, 'bucket-0');
      expect(pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildProjectionPK starts with TENANT#<tenantId>#', () => {
      const pk = buildProjectionPK(TENANT_A);
      expect(pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildIdempotencyPK starts with TENANT#<tenantId>#', () => {
      const pk = buildIdempotencyPK(TENANT_A);
      expect(pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });
  });

  describe('GSI1PK encoding — tenant prefix', () => {
    it('encodeGSI1PK starts with TENANT#<tenantId>#', () => {
      const gsi1pk = encodeGSI1PK(TENANT_A, 'UNIT', 'IN_STOCK');
      expect(gsi1pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildUnitLifecycleGSI1PK starts with TENANT#<tenantId>#', () => {
      const gsi1pk = buildUnitLifecycleGSI1PK(TENANT_A, 'SOLD');
      expect(gsi1pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildServiceJobGSI1PK starts with TENANT#<tenantId>#', () => {
      const gsi1pk = buildServiceJobGSI1PK(TENANT_A, 'OPEN');
      expect(gsi1pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildWarrantyGSI1PK starts with TENANT#<tenantId>#', () => {
      const gsi1pk = buildWarrantyGSI1PK(TENANT_A, 'ACTIVE');
      expect(gsi1pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildStatusGSI1PK starts with TENANT#<tenantId>#', () => {
      const gsi1pk = buildStatusGSI1PK(TENANT_A, 'EXCHANGE', 'PENDING');
      expect(gsi1pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildReconciliationGSI1PK starts with TENANT#<tenantId>#', () => {
      const gsi1pk = buildReconciliationGSI1PK(TENANT_A, 'PENDING', 'bucket-1');
      expect(gsi1pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });
  });

  describe('GSI2PK encoding — tenant prefix', () => {
    it('encodeGSI2PK starts with TENANT#<tenantId>#', () => {
      const gsi2pk = encodeGSI2PK(TENANT_A, 'CUSTOMER', 'cust-001');
      expect(gsi2pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildCustomerHistoryGSI2PK starts with TENANT#<tenantId>#', () => {
      const gsi2pk = buildCustomerHistoryGSI2PK(TENANT_A, 'cust-001');
      expect(gsi2pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildAuditTimelineGSI2PK starts with TENANT#<tenantId>#', () => {
      const gsi2pk = buildAuditTimelineGSI2PK(TENANT_A, 'UNIT', 'unit-001');
      expect(gsi2pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });

    it('buildCatalogGSI2PK starts with TENANT#<tenantId>#', () => {
      const gsi2pk = buildCatalogGSI2PK(TENANT_A, 'SAMSUNG');
      expect(gsi2pk.startsWith(`TENANT#${TENANT_A}#`)).toBe(true);
    });
  });

  describe('decodePK — extracts tenantId correctly', () => {
    it('decodes a standard PK', () => {
      const pk = encodePK(TENANT_A, 'ENTITY', 'UNIT', 'u1');
      const decoded = decodePK(pk);
      expect(decoded.tenantId).toBe(TENANT_A);
      expect(decoded.bucket).toBe('ENTITY#UNIT#u1');
    });

    it('decodes a claim PK', () => {
      const pk = buildClaimPK(TENANT_B);
      const decoded = decodePK(pk);
      expect(decoded.tenantId).toBe(TENANT_B);
      expect(decoded.bucket).toBe('CLAIM');
    });

    it('throws KeyCodecError for malformed PK', () => {
      expect(() => decodePK('INVALID_KEY')).toThrow(KeyCodecError);
    });

    it('throws KeyCodecError for PK without TENANT prefix', () => {
      expect(() => decodePK('OTHER#tenant-1#BUCKET')).toThrow(KeyCodecError);
    });
  });

  describe('verifyTenantInKey — cross-tenant detection', () => {
    it('returns true when tenant matches', () => {
      const pk = encodePK(TENANT_A, 'ENTITY', 'UNIT', 'u1');
      expect(verifyTenantInKey(pk, TENANT_A)).toBe(true);
    });

    it('returns false when tenant does not match', () => {
      const pk = encodePK(TENANT_A, 'ENTITY', 'UNIT', 'u1');
      expect(verifyTenantInKey(pk, TENANT_B)).toBe(false);
    });

    it('returns false for malformed key', () => {
      expect(verifyTenantInKey('GARBAGE', TENANT_A)).toBe(false);
    });

    it('returns false for empty key', () => {
      expect(verifyTenantInKey('', TENANT_A)).toBe(false);
    });
  });

  describe('verifyItemTenant — item-level tenant check', () => {
    it('returns true when item tenantId matches', () => {
      const item = { tenantId: TENANT_A, PK: encodePK(TENANT_A, 'CLAIM'), SK: 'IMEI#12345' };
      expect(verifyItemTenant(item, TENANT_A)).toBe(true);
    });

    it('returns false when item tenantId differs', () => {
      const item = { tenantId: TENANT_B, PK: encodePK(TENANT_B, 'CLAIM'), SK: 'IMEI#12345' };
      expect(verifyItemTenant(item, TENANT_A)).toBe(false);
    });

    it('returns false for null item', () => {
      expect(verifyItemTenant(null, TENANT_A)).toBe(false);
    });

    it('returns false for undefined item', () => {
      expect(verifyItemTenant(undefined, TENANT_A)).toBe(false);
    });

    it('returns false for item missing tenantId attribute', () => {
      const item = { PK: 'TENANT#x#CLAIM', SK: 'IMEI#12345' };
      expect(verifyItemTenant(item, TENANT_A)).toBe(false);
    });
  });

  describe('empty tenantId — throws KeyCodecError', () => {
    it('encodePK throws for empty tenantId', () => {
      expect(() => encodePK('', 'CLAIM')).toThrow(KeyCodecError);
    });

    it('encodePK throws for whitespace-only tenantId', () => {
      expect(() => encodePK('   ', 'CLAIM')).toThrow(KeyCodecError);
    });

    it('encodeGSI1PK throws for empty tenantId', () => {
      expect(() => encodeGSI1PK('', 'UNIT', 'IN_STOCK')).toThrow(KeyCodecError);
    });

    it('encodeGSI2PK throws for empty tenantId', () => {
      expect(() => encodeGSI2PK('', 'CUSTOMER', 'cust-001')).toThrow(KeyCodecError);
    });
  });
});
