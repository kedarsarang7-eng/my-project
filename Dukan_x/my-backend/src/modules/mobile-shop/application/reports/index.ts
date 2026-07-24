/**
 * Reports Module — Barrel Export
 *
 * Tenant-bound KPI projections, bounded report queries, and report type
 * definitions for the MobileShop domain.
 *
 * Requirements: 4.9, 9.1–9.9, 9.12–9.13
 */

// Report Types and KPI Metric Constants
export {
  // Metric constants
  STOCK_BY_LIFECYCLE,
  REPAIRS_BY_STATUS,
  EXCHANGES_BY_STATUS,
  WARRANTIES_ACTIVE,
  WARRANTIES_EXPIRING,
  USED_STOCK_COUNT,
  RETURNS_COUNT,
  FINANCE_ACTIVE,
  CONFLICTS_UNRESOLVED,
  RECONCILIATION_PENDING,
  MARGIN_AVERAGE,
  KPI_METRICS,
  // Types
  type KpiMetric,
  type ProjectionState,
  type SourceWatermark,
  type KpiProjectionItem,
  type DimensionCount,
  type ReportSummary,
  type SingleValueReport,
  type ReportResult,
  type ProjectionUpsertInput,
} from './report-types';

// Report Queries — Bounded tenant-scoped queries per report type
export {
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

// KPI Projection Service
export {
  KpiProjectionService,
  type ProjectionQueryResult,
  type ProjectionUpsertResult,
  type ProjectionRefreshResult,
} from './kpi-projection-service';
