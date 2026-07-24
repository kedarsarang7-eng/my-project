/**
 * Report Queries Integration Tests
 *
 * Tests bounded queries for report summaries, KPI projection service,
 * tenant isolation, watermark metadata, and no-fabrication guarantees.
 *
 * Mocks the MobileShopRepository to isolate query logic.
 *
 * Requirements covered: 9.7–9.13, 13.1, 13.6
 */

import { randomUUID } from 'crypto';
import {
  queryLifecycleStockSummary,
  queryRepairSummary,
  queryUsedStockSummary,
  queryReturnSummary,
} from '../../reports/report-queries';
import { KpiProjectionService } from '../../reports/kpi-projection-service';
import type { TenantContextWire } from '../../../schemas/common.schema';

// ─── Mock Repository ─────────────────────────────────────────────────────────

const mockRepository = {
  queryUnitsByLifecycleState: jest.fn(),
  queryServiceJobs: jest.fn(),
  queryByTypeAndStatus: jest.fn(),
  queryWarranties: jest.fn(),
  queryReconciliationWork: jest.fn(),
  queryKpiProjections: jest.fn(),
  tableName: 'MobileShop-test',
  client: { send: jest.fn() },
} as any;

// ─── Helpers ─────────────────────────────────────────────────────────────────

function makeTenantCtx(tenantId = 'tenant-1'): TenantContextWire {
  return {
    tenantId,
    businessId: 'biz-1',
    subjectId: 'user-1',
    businessType: 'mobile_shop',
    permissions: ['mobile_shop:reports:view'],
    correlationId: `corr-${randomUUID().slice(0, 8)}`,
  } as TenantContextWire;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('Report Queries', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ─── queryLifecycleStockSummary ──────────────────────────────────────────

  describe('queryLifecycleStockSummary', () => {
    it('returns watermarked dimensions for each lifecycle state', async () => {
      // Each lifecycle state query returns a count
      mockRepository.queryUnitsByLifecycleState.mockResolvedValue({
        items: [],
        count: 5,
        hasMore: false,
      });

      const ctx = makeTenantCtx();
      const result = await queryLifecycleStockSummary(ctx, mockRepository);

      expect(result.metric).toBe('STOCK_BY_LIFECYCLE');
      expect(result.dimensions.length).toBeGreaterThan(0);
      expect(result.sourceWatermark).toBeDefined();
      expect(result.sourceWatermark.state).toBe('current');
      expect(result.sourceWatermark.confirmedAt).toBeDefined();
      expect(result.sourceWatermark.dataModelVersion).toBe(1);
      expect(result.sourceWatermark.refreshedAt).toBeDefined();
      expect(result.total).toBeGreaterThanOrEqual(0);
    });

    it('includes all known lifecycle states in dimensions', async () => {
      mockRepository.queryUnitsByLifecycleState.mockResolvedValue({
        items: [],
        count: 0,
        hasMore: false,
      });

      const ctx = makeTenantCtx();
      const result = await queryLifecycleStockSummary(ctx, mockRepository);

      const dimensionNames = result.dimensions.map((d) => d.dimension);
      expect(dimensionNames).toContain('IN_STOCK');
      expect(dimensionNames).toContain('SOLD');
      expect(dimensionNames).toContain('RESERVED');
      expect(dimensionNames).toContain('RETURNED');
      expect(dimensionNames).toContain('DEMO');
      expect(dimensionNames).toContain('IN_SERVICE');
      expect(dimensionNames).toContain('EXCHANGED');
      expect(dimensionNames).toContain('DAMAGED');
      expect(dimensionNames).toContain('RETIRED');
    });

    it('never returns fabricated values (fails gracefully with zero on query error)', async () => {
      // Simulate some queries failing
      mockRepository.queryUnitsByLifecycleState
        .mockResolvedValueOnce({ items: [], count: 3, hasMore: false }) // IN_STOCK ok
        .mockRejectedValueOnce(new Error('DynamoDB error'))              // RESERVED fails
        .mockResolvedValue({ items: [], count: 1, hasMore: false });    // rest ok

      const ctx = makeTenantCtx();
      const result = await queryLifecycleStockSummary(ctx, mockRepository);

      // RESERVED should be 0 (not fabricated)
      const reservedDim = result.dimensions.find((d) => d.dimension === 'RESERVED');
      expect(reservedDim).toBeDefined();
      expect(reservedDim!.count).toBe(0);

      // IN_STOCK should have its real value
      const inStockDim = result.dimensions.find((d) => d.dimension === 'IN_STOCK');
      expect(inStockDim).toBeDefined();
      expect(inStockDim!.count).toBe(3);
    });
  });

  // ─── Report queries include all known statuses ───────────────────────────

  describe('queryRepairSummary', () => {
    it('includes all known service job statuses', async () => {
      mockRepository.queryServiceJobs.mockResolvedValue({
        items: [],
        count: 0,
        hasMore: false,
      });

      const ctx = makeTenantCtx();
      const result = await queryRepairSummary(ctx, mockRepository);

      expect(result.metric).toBe('REPAIRS_BY_STATUS');
      const dimensionNames = result.dimensions.map((d) => d.dimension);
      expect(dimensionNames).toContain('RECEIVED');
      expect(dimensionNames).toContain('READY');
      expect(dimensionNames).toContain('DELIVERED');
      expect(dimensionNames).toContain('CANCELLED');
    });
  });

  // ─── KpiProjectionService uses AP-13 ─────────────────────────────────────

  describe('KpiProjectionService.getKpiProjections', () => {
    it('uses AP-13 via repository.queryKpiProjections', async () => {
      mockRepository.queryKpiProjections.mockResolvedValue({
        items: [
          {
            metric: 'STOCK_BY_LIFECYCLE',
            dimension: 'IN_STOCK',
            value: 42,
            confirmedAt: '2025-01-15T10:00:00Z',
            dataModelVersion: 1,
            refreshedAt: '2025-01-15T10:00:00Z',
            projectionState: 'current',
          },
        ],
        hasMore: false,
        count: 1,
      });

      const service = new KpiProjectionService(mockRepository);
      const ctx = makeTenantCtx();
      const result = await service.getKpiProjections(ctx, ['STOCK_BY_LIFECYCLE']);

      expect(mockRepository.queryKpiProjections).toHaveBeenCalledWith(
        ctx,
        'STOCK_BY_LIFECYCLE',
        undefined,
      );
      expect(result.projections.length).toBeGreaterThanOrEqual(1);
      expect(result.projections[0].metric).toBe('STOCK_BY_LIFECYCLE');
    });
  });

  // ─── No fabricated values (graceful failure) ──────────────────────────────

  describe('no fabricated values', () => {
    it('queryUsedStockSummary fails gracefully with error watermark state', async () => {
      mockRepository.queryUnitsByLifecycleState.mockRejectedValueOnce(
        new Error('DynamoDB unavailable'),
      );

      const ctx = makeTenantCtx();
      const result = await queryUsedStockSummary(ctx, mockRepository);

      expect(result.value).toBe(0);
      expect(result.sourceWatermark.state).toBe('error');
      expect(result.metric).toBe('USED_STOCK_COUNT');
    });

    it('queryReturnSummary fails gracefully with error watermark state', async () => {
      mockRepository.queryUnitsByLifecycleState.mockRejectedValueOnce(
        new Error('DynamoDB timeout'),
      );

      const ctx = makeTenantCtx();
      const result = await queryReturnSummary(ctx, mockRepository);

      expect(result.value).toBe(0);
      expect(result.sourceWatermark.state).toBe('error');
    });
  });

  // ─── Tenant isolation ─────────────────────────────────────────────────────

  describe('tenant isolation', () => {
    it('queries pass tenantId via TenantContextWire to repository', async () => {
      mockRepository.queryUnitsByLifecycleState.mockResolvedValue({
        items: [],
        count: 0,
        hasMore: false,
      });

      const tenantA = makeTenantCtx('tenant-A');
      const tenantB = makeTenantCtx('tenant-B');

      await queryLifecycleStockSummary(tenantA, mockRepository);
      await queryLifecycleStockSummary(tenantB, mockRepository);

      // First batch of calls should be with tenant-A context
      const firstCallCtx = mockRepository.queryUnitsByLifecycleState.mock.calls[0][0];
      expect(firstCallCtx.tenantId).toBe('tenant-A');

      // After all tenant-A calls, the next batch should be tenant-B
      // There are 10 lifecycle states, so calls 10+ should be tenant-B
      const laterCallCtx = mockRepository.queryUnitsByLifecycleState.mock.calls[10][0];
      expect(laterCallCtx.tenantId).toBe('tenant-B');
    });

    it('KpiProjectionService passes tenant context to AP-13 query', async () => {
      mockRepository.queryKpiProjections.mockResolvedValue({
        items: [],
        hasMore: false,
        count: 0,
      });

      const service = new KpiProjectionService(mockRepository);
      const ctx = makeTenantCtx('tenant-isolated');

      await service.getKpiProjections(ctx);

      expect(mockRepository.queryKpiProjections).toHaveBeenCalledWith(ctx);
      const callArg = mockRepository.queryKpiProjections.mock.calls[0][0];
      expect(callArg.tenantId).toBe('tenant-isolated');
    });
  });
});
