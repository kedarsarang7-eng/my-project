/**
 * Access Patterns Tests
 *
 * Verifies:
 * - Each AP method returns bounded limit from PAGINATION_CONFIG
 * - AP-08 rejects unsupported entity types with UnsupportedQueryError
 * - AP-15 rejects prefix shorter than configured minimum
 * - No query uses Scan operation (all produce QueryInput/GetInput)
 * - All queries use key condition expressions (not filter expressions for primary retrieval)
 *
 * Requirements: 6.5–6.6, 6.14–6.17, 6.19, 6.25, 6.28–6.30, 13.4, 13.6
 */

import {
  queryEntityAggregate,
  getImeiClaim,
  queryUnitsByLifecycle,
  queryInvoiceAssociations,
  queryCustomerDeviceHistory,
  queryServiceJobsByStatus,
  queryWarrantiesByStatus,
  queryByEntityTypeAndStatus,
  getReservationClaim,
  queryChangeFeed,
  queryAuditTimeline,
  queryReconciliationWork,
  queryKpiProjection,
  getIdempotencyOutcome,
  queryCatalogByPrefix,
  UnsupportedQueryError,
} from '../access-patterns';
import { PAGINATION_CONFIG } from '../../config/pagination.config';
import { BOUNDS_CONFIG } from '../../config/bounds.config';
import type { TenantContextWire } from '../../schemas/common.schema';

const ctx: TenantContextWire = {
  tenantId: 'tenant-test-001',
  businessId: 'biz-001',
  subjectId: 'sub-001',
  businessType: 'mobile_shop',
  permissions: ['mobile_shop:view', 'mobile_shop:manage'],
  correlationId: 'corr-001',
};

describe('Access Patterns', () => {
  describe('bounded limits from PAGINATION_CONFIG', () => {
    it('AP-01 queryEntityAggregate uses default limit', () => {
      const input = queryEntityAggregate(ctx, 'UNIT', 'unit-001');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-01']);
    });

    it('AP-03 queryUnitsByLifecycle uses AP-specific default', () => {
      const input = queryUnitsByLifecycle(ctx, 'IN_STOCK');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-03']);
    });

    it('AP-04 queryInvoiceAssociations uses AP-specific default', () => {
      const input = queryInvoiceAssociations(ctx, 'inv-001');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-04']);
    });

    it('AP-05 queryCustomerDeviceHistory uses AP-specific default', () => {
      const input = queryCustomerDeviceHistory(ctx, 'cust-001');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-05']);
    });

    it('AP-06 queryServiceJobsByStatus uses AP-specific default', () => {
      const input = queryServiceJobsByStatus(ctx, 'OPEN');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-06']);
    });

    it('AP-07 queryWarrantiesByStatus uses AP-specific default', () => {
      const input = queryWarrantiesByStatus(ctx, 'ACTIVE');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-07']);
    });

    it('AP-08 queryByEntityTypeAndStatus uses AP-specific default', () => {
      const input = queryByEntityTypeAndStatus(ctx, 'EXCHANGE', 'PENDING');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-08']);
    });

    it('AP-10 queryChangeFeed uses AP-specific default', () => {
      const input = queryChangeFeed(ctx, 'bucket-0');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-10']);
    });

    it('AP-11 queryAuditTimeline uses AP-specific default', () => {
      const input = queryAuditTimeline(ctx, 'UNIT', 'unit-001');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-11']);
    });

    it('AP-12 queryReconciliationWork uses AP-specific default', () => {
      const input = queryReconciliationWork(ctx, 'PENDING', 'bucket-1');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-12']);
    });

    it('AP-15 queryCatalogByPrefix uses AP-specific default', () => {
      const input = queryCatalogByPrefix(ctx, 'SAMSUNG', 'SAMS');
      expect(input.limit).toBe(PAGINATION_CONFIG.accessPatternDefaults['AP-15']);
    });

    it('clamps requested limit above maxPageSize', () => {
      const input = queryUnitsByLifecycle(ctx, 'IN_STOCK', {
        limit: PAGINATION_CONFIG.maxPageSize + 100,
      });
      expect(input.limit).toBeLessThanOrEqual(PAGINATION_CONFIG.maxPageSize);
    });

    it('clamps requested limit below minPageSize', () => {
      const input = queryUnitsByLifecycle(ctx, 'IN_STOCK', { limit: 0 });
      expect(input.limit).toBeGreaterThanOrEqual(PAGINATION_CONFIG.minPageSize);
    });
  });

  describe('AP-08 — unsupported entity type rejection', () => {
    it('rejects unsupported entity type "INVOICE"', () => {
      expect(() => queryByEntityTypeAndStatus(ctx, 'INVOICE', 'PENDING')).toThrow(
        UnsupportedQueryError,
      );
    });

    it('rejects unsupported entity type "UNIT"', () => {
      expect(() => queryByEntityTypeAndStatus(ctx, 'UNIT', 'IN_STOCK')).toThrow(
        UnsupportedQueryError,
      );
    });

    it('rejects unsupported entity type "AUDIT"', () => {
      expect(() => queryByEntityTypeAndStatus(ctx, 'AUDIT', 'PENDING')).toThrow(
        UnsupportedQueryError,
      );
    });

    it('accepts allowed type EXCHANGE', () => {
      expect(() => queryByEntityTypeAndStatus(ctx, 'EXCHANGE', 'PENDING')).not.toThrow();
    });

    it('accepts allowed type INTAKE', () => {
      expect(() => queryByEntityTypeAndStatus(ctx, 'INTAKE', 'PENDING')).not.toThrow();
    });

    it('accepts allowed type RETURN', () => {
      expect(() => queryByEntityTypeAndStatus(ctx, 'RETURN', 'PENDING')).not.toThrow();
    });

    it('accepts allowed type FINANCE', () => {
      expect(() => queryByEntityTypeAndStatus(ctx, 'FINANCE', 'PENDING')).not.toThrow();
    });
  });

  describe('AP-15 — prefix minimum length validation', () => {
    it('rejects prefix shorter than configured minimum', () => {
      const shortPrefix = 'AB'; // minSearchPrefix is 4
      expect(() => queryCatalogByPrefix(ctx, 'SAMSUNG', shortPrefix)).toThrow(
        UnsupportedQueryError,
      );
    });

    it('rejects prefix of length minSearchPrefix - 1', () => {
      const prefix = 'A'.repeat(BOUNDS_CONFIG.imei.minSearchPrefix - 1);
      expect(() => queryCatalogByPrefix(ctx, 'SAMSUNG', prefix)).toThrow(
        UnsupportedQueryError,
      );
    });

    it('accepts prefix at exact minimum length', () => {
      const prefix = 'A'.repeat(BOUNDS_CONFIG.imei.minSearchPrefix);
      expect(() => queryCatalogByPrefix(ctx, 'SAMSUNG', prefix)).not.toThrow();
    });

    it('accepts prefix longer than minimum', () => {
      const prefix = 'SAMSUNG_GAL';
      expect(() => queryCatalogByPrefix(ctx, 'SAMSUNG', prefix)).not.toThrow();
    });
  });

  describe('no Scan paths — all methods return QueryInput or GetInput', () => {
    it('AP-01 returns QueryInput (not Scan)', () => {
      const input = queryEntityAggregate(ctx, 'UNIT', 'unit-001');
      expect(input.keyConditionExpression).toBeDefined();
      expect(input.accessPatternId).toBe('AP-01');
    });

    it('AP-02 returns GetInput (not Scan)', () => {
      const input = getImeiClaim(ctx, '123456789012345');
      expect(input.key).toBeDefined();
      expect(input.accessPatternId).toBe('AP-02');
    });

    it('AP-03 returns QueryInput on GSI1', () => {
      const input = queryUnitsByLifecycle(ctx, 'SOLD');
      expect(input.keyConditionExpression).toBeDefined();
      expect(input.indexName).toBe('GSI1');
    });

    it('AP-05 returns QueryInput on GSI2', () => {
      const input = queryCustomerDeviceHistory(ctx, 'cust-001');
      expect(input.keyConditionExpression).toBeDefined();
      expect(input.indexName).toBe('GSI2');
    });

    it('AP-09 returns GetInput (not Scan)', () => {
      const input = getReservationClaim(ctx, 'unit-001');
      expect(input.key).toBeDefined();
      expect(input.accessPatternId).toBe('AP-09');
    });

    it('AP-14 returns GetInput (not Scan)', () => {
      const input = getIdempotencyOutcome(ctx, 'op-001');
      expect(input.key).toBeDefined();
      expect(input.accessPatternId).toBe('AP-14');
    });
  });

  describe('all queries use key condition expressions', () => {
    const queryMethods = [
      { name: 'AP-01', fn: () => queryEntityAggregate(ctx, 'UNIT', 'u1') },
      { name: 'AP-03', fn: () => queryUnitsByLifecycle(ctx, 'IN_STOCK') },
      { name: 'AP-04', fn: () => queryInvoiceAssociations(ctx, 'inv-001') },
      { name: 'AP-05', fn: () => queryCustomerDeviceHistory(ctx, 'cust-001') },
      { name: 'AP-06', fn: () => queryServiceJobsByStatus(ctx, 'OPEN') },
      { name: 'AP-07', fn: () => queryWarrantiesByStatus(ctx, 'ACTIVE') },
      { name: 'AP-08', fn: () => queryByEntityTypeAndStatus(ctx, 'EXCHANGE', 'PENDING') },
      { name: 'AP-10', fn: () => queryChangeFeed(ctx, 'bucket-0') },
      { name: 'AP-11', fn: () => queryAuditTimeline(ctx, 'UNIT', 'u1') },
      { name: 'AP-12', fn: () => queryReconciliationWork(ctx, 'PENDING', 'bucket-1') },
      { name: 'AP-13', fn: () => queryKpiProjection(ctx, 'revenue') },
      { name: 'AP-15', fn: () => queryCatalogByPrefix(ctx, 'SAMSUNG', 'SAMS') },
    ];

    it.each(queryMethods)(
      '$name uses keyConditionExpression (no filter-only retrieval)',
      ({ fn }) => {
        const input = fn();
        expect(input.keyConditionExpression).toBeTruthy();
        expect(input.keyConditionExpression.length).toBeGreaterThan(0);
        // Must contain partition key reference
        expect(input.expressionAttributeValues).toBeDefined();
      },
    );
  });
});
