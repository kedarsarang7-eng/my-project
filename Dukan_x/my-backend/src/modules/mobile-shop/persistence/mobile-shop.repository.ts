/**
 * Mobile Shop Repository — Concrete Access-Pattern Implementation
 *
 * Implements AP-01 through AP-15 as typed public methods. Every method:
 * - Accepts TenantContext as the first parameter
 * - Uses the key codec internally (never exposes raw keys)
 * - Rejects unsupported query shapes with a typed error before DynamoDB call
 * - Uses bounded Query only (no Scan in application paths)
 * - Returns typed results with optional continuation token metadata
 *
 * Requirements: 6.6, 6.14, 6.19, 6.25, 6.28–6.30, 8.9, 9.12
 */

import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../schemas/common.schema';
import {
  RepositoryBase,
  type RepositoryBaseConfig,
  type PaginatedResult,
  type GetResult,
  type DynamoItem,
} from './repository-base';
import {
  type PaginationParams,
  type ConsistencyMode,
  UnsupportedQueryError,
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
} from './access-patterns';
import { BOUNDS_CONFIG } from '../config/bounds.config';

// ─── Types ───────────────────────────────────────────────────────────────────

/** AP-08 supported entity types for status queries */
export type StatusQueryEntityType = 'EXCHANGE' | 'INTAKE' | 'RETURN' | 'FINANCE';

// ─── Repository ──────────────────────────────────────────────────────────────

export class MobileShopRepository extends RepositoryBase {
  constructor(client: DynamoDBDocumentClient, config: RepositoryBaseConfig) {
    super(client, config);
  }

  // ─── AP-01: Entity Aggregate by ID ────────────────────────────────────────

  /**
   * Retrieve a full entity aggregate (root + children) by type and ID.
   * Used for command pre-reads and detail views.
   */
  async getEntityAggregate(
    ctx: TenantContextWire,
    entityType: string,
    entityId: string,
    options?: { consistency?: ConsistencyMode; skPrefix?: string; pagination?: PaginationParams },
  ): Promise<PaginatedResult> {
    const input = queryEntityAggregate(ctx, entityType, entityId, options);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-02: IMEI Exact Lookup ─────────────────────────────────────────────

  /**
   * Look up a single IMEI claim by normalized value.
   * Returns the claim item or null. No cross-tenant signal.
   */
  async lookupImeiClaim(
    ctx: TenantContextWire,
    normalizedImei: string,
  ): Promise<GetResult> {
    this.assertValidImei(normalizedImei);
    const input = getImeiClaim(ctx, normalizedImei);
    return this.executeGet(ctx, input);
  }

  // ─── AP-03: Units by Lifecycle/Date ───────────────────────────────────────

  /**
   * Query units filtered by lifecycle state, sorted by updatedAt.
   * Newest first by default.
   */
  async queryUnitsByLifecycleState(
    ctx: TenantContextWire,
    state: string,
    pagination?: PaginationParams,
    options?: { scanForward?: boolean },
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(state, 'state');
    const input = queryUnitsByLifecycle(ctx, state, pagination, options);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-04: Invoice Associations ──────────────────────────────────────────

  /**
   * Query device associations (lines) for an invoice.
   */
  async queryInvoiceDeviceAssociations(
    ctx: TenantContextWire,
    invoiceId: string,
    pagination?: PaginationParams,
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(invoiceId, 'invoiceId');
    const input = queryInvoiceAssociations(ctx, invoiceId, pagination);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-05: Customer Device History ───────────────────────────────────────

  /**
   * Query device history for a specific customer.
   * Newest events first by default.
   */
  async queryCustomerDeviceHistory(
    ctx: TenantContextWire,
    customerId: string,
    pagination?: PaginationParams,
    options?: { scanForward?: boolean },
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(customerId, 'customerId');
    const input = queryCustomerDeviceHistory(ctx, customerId, pagination, options);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-06: Service Jobs by Status/Due ────────────────────────────────────

  /**
   * Query service jobs by status, sorted by due date.
   * Earliest due first by default.
   */
  async queryServiceJobs(
    ctx: TenantContextWire,
    status: string,
    pagination?: PaginationParams,
    options?: { scanForward?: boolean },
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(status, 'status');
    const input = queryServiceJobsByStatus(ctx, status, pagination, options);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-07: Warranty Expiry/Claim Status ──────────────────────────────────

  /**
   * Query warranties by status, sorted by expiry or updated date.
   */
  async queryWarranties(
    ctx: TenantContextWire,
    status: string,
    pagination?: PaginationParams,
    options?: { scanForward?: boolean },
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(status, 'status');
    const input = queryWarrantiesByStatus(ctx, status, pagination, options);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-08: Exchanges/Intakes/Returns/Finance by Status ───────────────────

  /**
   * Query exchanges, intakes, returns, or finance records by status.
   * Rejects unsupported entity types before DynamoDB call.
   */
  async queryByTypeAndStatus(
    ctx: TenantContextWire,
    entityType: StatusQueryEntityType,
    status: string,
    pagination?: PaginationParams,
    options?: { scanForward?: boolean },
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(status, 'status');
    // UnsupportedQueryError thrown inside if entityType is invalid
    const input = queryByEntityTypeAndStatus(ctx, entityType, status, pagination, options);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-09: Active Reservation by Unit ────────────────────────────────────

  /**
   * Get the active reservation claim for a specific unit.
   * Returns the reservation item or null (no cross-tenant signal).
   */
  async getReservation(
    ctx: TenantContextWire,
    unitId: string,
  ): Promise<GetResult> {
    this.assertNonEmpty(unitId, 'unitId');
    const input = getReservationClaim(ctx, unitId);
    return this.executeGet(ctx, input);
  }

  // ─── AP-10: Tenant Change Feed ────────────────────────────────────────────

  /**
   * Query the tenant change feed for sync pulls.
   * Oldest first for sequential consumption.
   */
  async queryChangeFeed(
    ctx: TenantContextWire,
    bucket: string,
    pagination?: PaginationParams,
    options?: { afterSequence?: string },
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(bucket, 'bucket');
    const input = queryChangeFeed(ctx, bucket, pagination, options);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-11: Audit Timeline ────────────────────────────────────────────────

  /**
   * Query immutable audit events for a specific entity.
   * Newest first by default.
   */
  async queryAuditTimeline(
    ctx: TenantContextWire,
    entityType: string,
    entityId: string,
    pagination?: PaginationParams,
    options?: { scanForward?: boolean },
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(entityType, 'entityType');
    this.assertNonEmpty(entityId, 'entityId');
    const input = queryAuditTimeline(ctx, entityType, entityId, pagination, options);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-12: Reconciliation Work ───────────────────────────────────────────

  /**
   * Query reconciliation records by status and bucket (worker-only).
   * Sorted by nextAttemptAt — earliest first.
   */
  async queryReconciliationWork(
    ctx: TenantContextWire,
    status: string,
    bucket: string,
    pagination?: PaginationParams,
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(status, 'status');
    this.assertNonEmpty(bucket, 'bucket');
    const input = queryReconciliationWork(ctx, status, bucket, pagination);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-13: KPI Projection ────────────────────────────────────────────────

  /**
   * Query confirmed KPI projection items.
   * Optionally filter by metric and/or dimension.
   */
  async queryKpiProjections(
    ctx: TenantContextWire,
    metric?: string,
    dimension?: string,
    pagination?: PaginationParams,
  ): Promise<PaginatedResult> {
    const input = queryKpiProjection(ctx, metric, dimension, pagination);
    return this.executeQuery(ctx, input);
  }

  // ─── AP-14: Idempotency Outcome ───────────────────────────────────────────

  /**
   * Get an idempotency record by operationId.
   * Strong read for ambiguous retry decisions.
   */
  async getIdempotencyRecord(
    ctx: TenantContextWire,
    operationId: string,
  ): Promise<GetResult> {
    this.assertNonEmpty(operationId, 'operationId');
    const input = getIdempotencyOutcome(ctx, operationId);
    return this.executeGet(ctx, input);
  }

  // ─── AP-15: Prefix Catalogue/Search ───────────────────────────────────────

  /**
   * Search the prefix catalogue with a minimum prefix length.
   * Rejects prefixes shorter than configured minimum before DynamoDB call.
   */
  async searchCatalogByPrefix(
    ctx: TenantContextWire,
    normalizedPrefixBucket: string,
    prefix: string,
    pagination?: PaginationParams,
  ): Promise<PaginatedResult> {
    this.assertNonEmpty(normalizedPrefixBucket, 'normalizedPrefixBucket');
    // UnsupportedQueryError thrown inside if prefix is too short
    const input = queryCatalogByPrefix(ctx, normalizedPrefixBucket, prefix, pagination);
    return this.executeQuery(ctx, input);
  }

  // ─── Unsupported Query Guard ──────────────────────────────────────────────

  /**
   * Reject arbitrary filter/query shapes that don't map to a cataloged AP.
   * Call this when a handler receives dynamic filter parameters.
   */
  assertSupportedQuery(filters: Record<string, unknown>): void {
    // This method is a gate — it only accepts well-known filter shapes.
    // Callers check if a combination of filters maps to a known AP before execution.
    const knownFilterKeys = new Set([
      'entityType', 'entityId', 'status', 'state', 'bucket',
      'customerId', 'invoiceId', 'unitId', 'operationId',
      'normalizedImei', 'metric', 'dimension', 'prefix',
      'normalizedPrefixBucket', 'afterSequence',
    ]);

    const unsupported = Object.keys(filters).filter(k => !knownFilterKeys.has(k));
    if (unsupported.length > 0) {
      throw new UnsupportedQueryError(
        `Unsupported filter parameters: ${unsupported.join(', ')}. Use a cataloged access pattern.`,
      );
    }
  }

  // ─── Private Validation ───────────────────────────────────────────────────

  private assertNonEmpty(value: string, name: string): void {
    if (!value || value.trim().length === 0) {
      throw new UnsupportedQueryError(`Parameter '${name}' must be a non-empty string`);
    }
  }

  private assertValidImei(normalizedImei: string): void {
    if (!normalizedImei || normalizedImei.length !== BOUNDS_CONFIG.imei.length) {
      throw new UnsupportedQueryError(
        `IMEI must be exactly ${BOUNDS_CONFIG.imei.length} characters after normalization`,
      );
    }
    if (!/^\d+$/.test(normalizedImei)) {
      throw new UnsupportedQueryError('Normalized IMEI must contain only digits');
    }
  }
}
