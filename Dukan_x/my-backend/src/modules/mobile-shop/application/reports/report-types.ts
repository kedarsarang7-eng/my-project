/**
 * Report Types — KPI Metric Definitions and Report Result Types
 *
 * Defines KPI metric constants, report result types with watermark metadata,
 * and projection state types. Projections include source watermark and
 * confirmation metadata; they never outrank source records.
 *
 * Requirements: 4.9, 9.1–9.9, 9.12–9.13
 */

// ─── KPI Metric Constants ────────────────────────────────────────────────────

/** Stock units grouped by lifecycle state */
export const STOCK_BY_LIFECYCLE = 'STOCK_BY_LIFECYCLE' as const;

/** Repairs/service jobs grouped by status */
export const REPAIRS_BY_STATUS = 'REPAIRS_BY_STATUS' as const;

/** Exchanges grouped by status */
export const EXCHANGES_BY_STATUS = 'EXCHANGES_BY_STATUS' as const;

/** Active warranties count */
export const WARRANTIES_ACTIVE = 'WARRANTIES_ACTIVE' as const;

/** Warranties expiring within configured window */
export const WARRANTIES_EXPIRING = 'WARRANTIES_EXPIRING' as const;

/** Count of second-hand/used stock units */
export const USED_STOCK_COUNT = 'USED_STOCK_COUNT' as const;

/** Count of returned units */
export const RETURNS_COUNT = 'RETURNS_COUNT' as const;

/** Active finance plans count */
export const FINANCE_ACTIVE = 'FINANCE_ACTIVE' as const;

/** Unresolved conflict records count */
export const CONFLICTS_UNRESOLVED = 'CONFLICTS_UNRESOLVED' as const;

/** Pending reconciliation records count */
export const RECONCILIATION_PENDING = 'RECONCILIATION_PENDING' as const;

/** Average margin across sold units */
export const MARGIN_AVERAGE = 'MARGIN_AVERAGE' as const;

/** All KPI metric names as a union type */
export type KpiMetric =
  | typeof STOCK_BY_LIFECYCLE
  | typeof REPAIRS_BY_STATUS
  | typeof EXCHANGES_BY_STATUS
  | typeof WARRANTIES_ACTIVE
  | typeof WARRANTIES_EXPIRING
  | typeof USED_STOCK_COUNT
  | typeof RETURNS_COUNT
  | typeof FINANCE_ACTIVE
  | typeof CONFLICTS_UNRESOLVED
  | typeof RECONCILIATION_PENDING
  | typeof MARGIN_AVERAGE;

/** All KPI metric constants grouped for iteration */
export const KPI_METRICS: readonly KpiMetric[] = [
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
] as const;

// ─── Projection State ────────────────────────────────────────────────────────

/**
 * Projection freshness states (Req 9.1–9.6).
 * - loading: no response yet, no previously confirmed value
 * - current: source returned authoritative confirmation
 * - empty: source confirmed with zero matching records
 * - stale: previously confirmed value retained while refresh pending/failed
 * - unavailable: source unavailable, no previously confirmed value
 * - error: terminal error from source
 */
export type ProjectionState =
  | 'loading'
  | 'current'
  | 'empty'
  | 'stale'
  | 'unavailable'
  | 'error';

// ─── Source Watermark ────────────────────────────────────────────────────────

/**
 * Source watermark metadata attached to every projection and report result.
 * Projections are non-authoritative — the watermark identifies the source
 * data version and never outranks source records.
 */
export interface SourceWatermark {
  /** ISO 8601 timestamp of the source data confirmation */
  readonly confirmedAt: string;
  /** Data model version of the source records */
  readonly dataModelVersion: number;
  /** ISO 8601 timestamp when the projection was last refreshed */
  readonly refreshedAt: string;
  /** Projection state reflecting freshness and source availability */
  readonly state: ProjectionState;
}

// ─── KPI Projection Item ─────────────────────────────────────────────────────

/**
 * A single KPI projection stored in DynamoDB (AP-13).
 * Non-authoritative: rebuildable from source data at any time.
 */
export interface KpiProjectionItem {
  /** KPI metric name */
  readonly metric: KpiMetric;
  /** Dimension key (e.g. lifecycle state, status value, or 'TOTAL') */
  readonly dimension: string;
  /** Projected value (count, amount in minor units, or percentage basis points) */
  readonly value: number;
  /** Source watermark metadata */
  readonly sourceWatermark: SourceWatermark;
}

// ─── Report Summary Results ──────────────────────────────────────────────────

/** A single dimension count within a report summary */
export interface DimensionCount {
  /** Dimension key (e.g. 'IN_STOCK', 'ACTIVE', 'PENDING') */
  readonly dimension: string;
  /** Count of records in this dimension */
  readonly count: number;
}

/**
 * Generic report summary result with watermark metadata.
 * Used for lifecycle stock, repairs, exchanges, warranties, etc.
 */
export interface ReportSummary {
  /** Report metric identifier */
  readonly metric: KpiMetric;
  /** Breakdown by dimension */
  readonly dimensions: readonly DimensionCount[];
  /** Total count across all dimensions */
  readonly total: number;
  /** Source watermark — when this data was confirmed */
  readonly sourceWatermark: SourceWatermark;
}

/**
 * Single-value report result (e.g. used stock count, returns count).
 */
export interface SingleValueReport {
  /** Report metric identifier */
  readonly metric: KpiMetric;
  /** The projected value */
  readonly value: number;
  /** Source watermark metadata */
  readonly sourceWatermark: SourceWatermark;
}

/** Union of all report result types */
export type ReportResult = ReportSummary | SingleValueReport;

// ─── Projection Upsert Input ─────────────────────────────────────────────────

/** Input for creating or updating a KPI projection */
export interface ProjectionUpsertInput {
  readonly metric: KpiMetric;
  readonly dimension: string;
  readonly value: number;
  readonly sourceWatermark: SourceWatermark;
}
