/**
 * MobileShop Application Layer — Barrel Export
 *
 * Application services that orchestrate domain logic, persistence,
 * and audit evidence creation.
 *
 * Requirements: 3.2, 3.3, 4.3, 5.2, 6.7–6.13, 6.31–6.32, 6.38,
 *              8.11–8.12, 8.14, 12.4–12.5, 12.8–12.10
 */

export {
  AuditEventService,
  type CreateAuditEventParams,
  type CreateCorrectionEventParams,
  type AuditEventResult,
  type ChangeEventResult,
} from './audit-service';

// Error Mapper — DynamoDB conditional-write and transaction error mapping
export {
  mapDynamoDbError,
  mapTransactionCancellation,
  type DeterministicOutcome,
  type ErrorMappingContext,
  type ConditionType,
  type TransactItemDescriptor,
} from './error-mapper';

// Ambiguous Outcome Handler — SDK timeout / unknown response resolution
export {
  handleAmbiguousOutcome,
  type AmbiguousResolution,
  type ResolvedOutcome,
} from './ambiguous-outcome-handler';

// Transaction Planner — pure item construction and fit calculation
export {
  TransactionPlanner,
  type MobileSaleCommand,
  type DeviceLineInput,
  type TransactionPlan,
  type PlanItem,
  type TransactUpdateItem,
} from './transaction-planner';

// Sale Outcome Types — discriminated union and authoritative confirmation
export {
  type AuthoritativeConfirmation,
  type SaleOutcome,
  type SaleCommitted,
  type SaleAcceptedPending,
  type SaleConflict,
  type SaleRejected,
  type SaleReplay,
  type AcceptedPendingHandler,
} from './sale-outcome';

// Atomic Sale Handler — orchestrates the complete sale flow
export { AtomicSaleHandler } from './atomic-sale-handler';

// Accepted-Pending Handler — oversized sale persistence with reconciliation
export {
  AcceptedPendingHandlerImpl,
  type ReconciliationStep,
  type ReconciliationLease,
  type ReconciliationRecord,
} from './accepted-pending-handler';

// Reports — KPI projections, bounded report queries, and metric types
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
  // Service
  KpiProjectionService,
  // Report queries
  queryLifecycleStockSummary,
  queryRepairSummary,
  queryExchangeSummary,
  queryWarrantySummary,
  queryUsedStockSummary,
  queryReturnSummary,
  queryFinanceSummary,
  queryConflictSummary,
  queryReconciliationSummary,
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
  type ProjectionQueryResult,
  type ProjectionUpsertResult,
  type ProjectionRefreshResult,
} from './reports';
