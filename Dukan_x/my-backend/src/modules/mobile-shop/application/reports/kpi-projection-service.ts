/**
 * KPI Projection Service — Tenant-Bound Projection Management
 *
 * Manages confirmed KPI projections stored via AP-13.
 * Projections are non-authoritative (rebuildable from source data) and
 * include source watermark metadata that never outranks source records.
 *
 * Requirements: 4.9, 9.1–9.9, 9.12–9.13
 */

import type { TenantContextWire } from '../../schemas/common.schema';
import type { MobileShopRepository } from '../../persistence/mobile-shop.repository';
import type { DynamoItem, PaginatedResult } from '../../persistence/repository-base';
import {
  type KpiMetric,
  type KpiProjectionItem,
  type SourceWatermark,
  type ProjectionUpsertInput,
  type ReportSummary,
  type SingleValueReport,
  KPI_METRICS,
} from './report-types';
import {
  queryLifecycleStockSummary,
  queryRepairSummary,
  queryExchangeSummary,
  queryWarrantySummary,
  queryUsedStockSummary,
  queryReturnSummary,
  queryFinanceSummary,
  queryConflictSummary,
  queryReconciliationSummary,
} from './report-queries';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Result of a projection query */
export interface ProjectionQueryResult {
  readonly projections: readonly KpiProjectionItem[];
  readonly hasMore: boolean;
  readonly lastEvaluatedKey?: Record<string, unknown>;
}

/** Result of a projection upsert */
export interface ProjectionUpsertResult {
  readonly metric: KpiMetric;
  readonly dimension: string;
  readonly value: number;
  readonly sourceWatermark: SourceWatermark;
  readonly upsertedAt: string;
}

/** Result of a full projection refresh */
export interface ProjectionRefreshResult {
  readonly refreshedMetrics: readonly KpiMetric[];
  readonly failedMetrics: readonly KpiMetric[];
  readonly refreshedAt: string;
}

// ─── KPI Projection Service ──────────────────────────────────────────────────

export class KpiProjectionService {
  private readonly repository: MobileShopRepository;

  constructor(repository: MobileShopRepository) {
    this.repository = repository;
  }

  // ─── Query Projections (AP-13) ───────────────────────────────────────────

  /**
   * Get KPI projections for the tenant, optionally filtered by metrics.
   * Uses AP-13 bounded query. Returns projection items with watermark.
   */
  async getKpiProjections(
    ctx: TenantContextWire,
    metrics?: readonly KpiMetric[],
  ): Promise<ProjectionQueryResult> {
    // If specific metrics requested, query each one individually
    if (metrics && metrics.length > 0) {
      const allProjections: KpiProjectionItem[] = [];

      for (const metric of metrics) {
        const result: PaginatedResult = await this.repository.queryKpiProjections(
          ctx, metric, undefined,
        );
        const items = this.parseProjectionItems(result.items as DynamoItem[]);
        allProjections.push(...items);
      }

      return {
        projections: allProjections,
        hasMore: false,
      };
    }

    // No filter: query all projections for the tenant
    const result: PaginatedResult = await this.repository.queryKpiProjections(ctx);
    const projections = this.parseProjectionItems(result.items as DynamoItem[]);

    return {
      projections,
      hasMore: result.hasMore,
      lastEvaluatedKey: result.lastEvaluatedKey,
    };
  }

  // ─── Upsert Projection ──────────────────────────────────────────────────

  /**
   * Upsert a single KPI projection with watermark/confirmation metadata.
   * This writes directly to the projection partition (AP-13).
   * Projections are non-authoritative and rebuildable from source data.
   */
  async updateProjection(
    ctx: TenantContextWire,
    metric: KpiMetric,
    dimension: string,
    value: number,
    sourceWatermark: SourceWatermark,
  ): Promise<ProjectionUpsertResult> {
    const now = new Date().toISOString();

    // Build the projection item for DynamoDB
    const item: ProjectionUpsertInput = {
      metric,
      dimension,
      value,
      sourceWatermark,
    };

    // Use the repository to persist via AP-13 key structure
    // PK = TENANT#t#PROJECTION, SK = KPI#metric#dimension
    await this.putProjectionItem(ctx, item);

    return {
      metric,
      dimension,
      value,
      sourceWatermark,
      upsertedAt: now,
    };
  }

  // ─── Refresh All Projections ─────────────────────────────────────────────

  /**
   * Recalculates all KPI projections from bounded source queries.
   * Each metric is refreshed independently — failures do not block others.
   * Projections are non-authoritative and can be rebuilt at any time.
   */
  async refreshProjections(ctx: TenantContextWire): Promise<ProjectionRefreshResult> {
    const refreshedMetrics: KpiMetric[] = [];
    const failedMetrics: KpiMetric[] = [];
    const now = new Date().toISOString();

    for (const metric of KPI_METRICS) {
      try {
        const report = await this.queryReportForMetric(ctx, metric);
        if (report) {
          await this.persistReportAsProjections(ctx, metric, report);
          refreshedMetrics.push(metric);
        } else {
          failedMetrics.push(metric);
        }
      } catch {
        failedMetrics.push(metric);
      }
    }

    return {
      refreshedMetrics,
      failedMetrics,
      refreshedAt: now,
    };
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────

  /**
   * Parse raw DynamoDB items into typed KpiProjectionItem objects.
   */
  private parseProjectionItems(items: DynamoItem[]): KpiProjectionItem[] {
    return items.map((item) => ({
      metric: (item['metric'] as KpiMetric) ?? (item['SK'] as string)?.split('#')[1] as KpiMetric,
      dimension: (item['dimension'] as string) ?? (item['SK'] as string)?.split('#')[2] ?? 'TOTAL',
      value: (item['value'] as number) ?? 0,
      sourceWatermark: {
        confirmedAt: (item['confirmedAt'] as string) ?? '',
        dataModelVersion: (item['dataModelVersion'] as number) ?? 1,
        refreshedAt: (item['refreshedAt'] as string) ?? '',
        state: (item['projectionState'] as SourceWatermark['state']) ?? 'current',
      },
    }));
  }

  /**
   * Query the appropriate report for a given metric.
   */
  private async queryReportForMetric(
    ctx: TenantContextWire,
    metric: KpiMetric,
  ): Promise<ReportSummary | SingleValueReport | null> {
    switch (metric) {
      case 'STOCK_BY_LIFECYCLE':
        return queryLifecycleStockSummary(ctx, this.repository);
      case 'REPAIRS_BY_STATUS':
        return queryRepairSummary(ctx, this.repository);
      case 'EXCHANGES_BY_STATUS':
        return queryExchangeSummary(ctx, this.repository);
      case 'WARRANTIES_ACTIVE':
      case 'WARRANTIES_EXPIRING':
        return queryWarrantySummary(ctx, this.repository);
      case 'USED_STOCK_COUNT':
        return queryUsedStockSummary(ctx, this.repository);
      case 'RETURNS_COUNT':
        return queryReturnSummary(ctx, this.repository);
      case 'FINANCE_ACTIVE':
        return queryFinanceSummary(ctx, this.repository);
      case 'CONFLICTS_UNRESOLVED':
        return queryConflictSummary(ctx, this.repository);
      case 'RECONCILIATION_PENDING':
        return queryReconciliationSummary(ctx, this.repository);
      case 'MARGIN_AVERAGE':
        // Margin calculation requires sale/cost data — returns null until
        // a dedicated margin access pattern or aggregation is available
        return null;
      default:
        return null;
    }
  }

  /**
   * Persist a report result as individual projection items.
   */
  private async persistReportAsProjections(
    ctx: TenantContextWire,
    metric: KpiMetric,
    report: ReportSummary | SingleValueReport,
  ): Promise<void> {
    const watermark = report.sourceWatermark;

    if ('dimensions' in report) {
      // Multi-dimension report
      for (const dim of report.dimensions) {
        await this.updateProjection(ctx, metric, dim.dimension, dim.count, watermark);
      }
      // Also store total
      await this.updateProjection(ctx, metric, 'TOTAL', report.total, watermark);
    } else {
      // Single-value report
      await this.updateProjection(ctx, metric, 'TOTAL', report.value, watermark);
    }
  }

  /**
   * Persist a projection item to DynamoDB via the repository's write path.
   * Uses PutItem semantics — upserts the projection record.
   */
  private async putProjectionItem(
    ctx: TenantContextWire,
    input: ProjectionUpsertInput,
  ): Promise<void> {
    // Import dynamically to match the repository pattern
    const { PutCommand } = await import('@aws-sdk/lib-dynamodb');
    const { buildProjectionPK } = await import('../../persistence/key-codec');

    const pk = buildProjectionPK(ctx.tenantId);
    const sk = `KPI#${input.metric}#${input.dimension}`;

    const command = new PutCommand({
      TableName: (this.repository as unknown as { tableName: string }).tableName,
      Item: {
        PK: pk,
        SK: sk,
        tenantId: ctx.tenantId,
        entityType: 'PROJECTION',
        metric: input.metric,
        dimension: input.dimension,
        value: input.value,
        confirmedAt: input.sourceWatermark.confirmedAt,
        refreshedAt: input.sourceWatermark.refreshedAt,
        dataModelVersion: input.sourceWatermark.dataModelVersion,
        projectionState: input.sourceWatermark.state,
        updatedAt: new Date().toISOString(),
      },
      ReturnConsumedCapacity: 'TOTAL',
    });

    await (this.repository as unknown as { client: import('@aws-sdk/lib-dynamodb').DynamoDBDocumentClient }).client.send(command);
  }
}
