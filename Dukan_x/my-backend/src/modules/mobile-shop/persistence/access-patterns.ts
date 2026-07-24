/**
 * Named Access-Pattern Queries (AP-01 through AP-15)
 *
 * Each method accepts a TenantContext + specific parameters and returns
 * a typed DynamoDB query/get input. Unsupported dynamic filters throw
 * before query execution. Every query is bounded by PAGINATION_CONFIG.
 *
 * Requirements: 6.6, 6.14, 6.19, 6.25, 6.28–6.30, 8.9, 9.12
 */

import type { TenantContextWire } from '../schemas/common.schema';
import { PAGINATION_CONFIG } from '../config/pagination.config';
import { BOUNDS_CONFIG } from '../config/bounds.config';
import {
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
  encodeSK,
  encodeGSI1SK,
  encodeGSI2SK,
} from './key-codec';

// ─── Types ───────────────────────────────────────────────────────────────────

/** DynamoDB index names */
export const INDEX_NAMES = {
  GSI1: 'GSI1',
  GSI2: 'GSI2',
} as const;

/** Access pattern identifiers */
export type AccessPatternId =
  | 'AP-01' | 'AP-02' | 'AP-03' | 'AP-04' | 'AP-05'
  | 'AP-06' | 'AP-07' | 'AP-08' | 'AP-09' | 'AP-10'
  | 'AP-11' | 'AP-12' | 'AP-13' | 'AP-14' | 'AP-15';

/** Query consistency mode */
export type ConsistencyMode = 'strong' | 'eventual';

/** A typed query input ready for DynamoDB DocumentClient */
export interface QueryInput {
  readonly accessPatternId: AccessPatternId;
  readonly indexName?: string;
  readonly keyConditionExpression: string;
  readonly expressionAttributeValues: Record<string, unknown>;
  readonly expressionAttributeNames?: Record<string, string>;
  readonly limit: number;
  readonly scanIndexForward: boolean;
  readonly consistentRead: boolean;
  readonly exclusiveStartKey?: Record<string, unknown>;
}

/** A typed get input ready for DynamoDB DocumentClient */
export interface GetInput {
  readonly accessPatternId: AccessPatternId;
  readonly key: Record<string, string>;
  readonly consistentRead: boolean;
}

/** Pagination parameters accepted by list methods */
export interface PaginationParams {
  readonly limit?: number;
  readonly continuationToken?: string;
  /** Decoded exclusive start key (from continuation token service) */
  readonly exclusiveStartKey?: Record<string, unknown>;
}

// ─── Error ───────────────────────────────────────────────────────────────────

export class UnsupportedQueryError extends Error {
  public readonly code = 'UNSUPPORTED_QUERY';
  constructor(message: string) {
    super(message);
    this.name = 'UnsupportedQueryError';
  }
}

// ─── Shared Helpers ──────────────────────────────────────────────────────────

function resolveLimit(accessPatternId: AccessPatternId, requestedLimit?: number): number {
  const apDefault = PAGINATION_CONFIG.accessPatternDefaults[accessPatternId]
    ?? PAGINATION_CONFIG.defaultPageSize;

  if (requestedLimit === undefined || requestedLimit === null) {
    return apDefault;
  }

  return Math.max(
    PAGINATION_CONFIG.minPageSize,
    Math.min(requestedLimit, PAGINATION_CONFIG.maxPageSize),
  );
}

// ─── AP-01: Entity Aggregate by ID ──────────────────────────────────────────

/**
 * AP-01: Query an entity aggregate (root + children) by type and ID.
 * Base table Query, optionally strongly consistent for command pre-reads.
 */
export function queryEntityAggregate(
  ctx: TenantContextWire,
  entityType: string,
  entityId: string,
  options?: { consistency?: ConsistencyMode; skPrefix?: string; pagination?: PaginationParams },
): QueryInput {
  const pk = buildEntityAggregatePK(ctx.tenantId, entityType, entityId);
  const skPrefix = options?.skPrefix; // e.g. 'META#' or 'CHILD#'

  let keyCondition = '#pk = :pk';
  const exprValues: Record<string, unknown> = { ':pk': pk };
  const exprNames: Record<string, string> = { '#pk': 'PK' };

  if (skPrefix) {
    keyCondition += ' AND begins_with(#sk, :skPrefix)';
    exprValues[':skPrefix'] = skPrefix;
    exprNames['#sk'] = 'SK';
  }

  return {
    accessPatternId: 'AP-01',
    keyConditionExpression: keyCondition,
    expressionAttributeValues: exprValues,
    expressionAttributeNames: exprNames,
    limit: resolveLimit('AP-01', options?.pagination?.limit),
    scanIndexForward: true,
    consistentRead: options?.consistency === 'strong',
    exclusiveStartKey: options?.pagination?.exclusiveStartKey,
  };
}

// ─── AP-02: IMEI Exact Lookup ────────────────────────────────────────────────

/**
 * AP-02: Get a single IMEI claim by normalized IMEI value.
 * Strong Get — no cross-tenant signal.
 */
export function getImeiClaim(
  ctx: TenantContextWire,
  normalizedImei: string,
): GetInput {
  return {
    accessPatternId: 'AP-02',
    key: {
      PK: buildClaimPK(ctx.tenantId),
      SK: encodeSK('IMEI', normalizedImei),
    },
    consistentRead: true,
  };
}

// ─── AP-03: Units by Lifecycle/Date ──────────────────────────────────────────

/**
 * AP-03: Query units by lifecycle state, sorted by updatedAt.
 * Bounded GSI1 Query.
 */
export function queryUnitsByLifecycle(
  ctx: TenantContextWire,
  state: string,
  pagination?: PaginationParams,
  options?: { scanForward?: boolean },
): QueryInput {
  return {
    accessPatternId: 'AP-03',
    indexName: INDEX_NAMES.GSI1,
    keyConditionExpression: '#gsi1pk = :gsi1pk',
    expressionAttributeValues: { ':gsi1pk': buildUnitLifecycleGSI1PK(ctx.tenantId, state) },
    expressionAttributeNames: { '#gsi1pk': 'GSI1PK' },
    limit: resolveLimit('AP-03', pagination?.limit),
    scanIndexForward: options?.scanForward ?? false, // newest first by default
    consistentRead: false, // GSI cannot be strongly consistent
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-04: Invoice Associations ─────────────────────────────────────────────

/**
 * AP-04: Query device associations for an invoice.
 * Base table Query with SK begins_with DEVICE#.
 */
export function queryInvoiceAssociations(
  ctx: TenantContextWire,
  invoiceId: string,
  pagination?: PaginationParams,
): QueryInput {
  return {
    accessPatternId: 'AP-04',
    keyConditionExpression: '#pk = :pk AND begins_with(#sk, :skPrefix)',
    expressionAttributeValues: {
      ':pk': buildInvoicePK(ctx.tenantId, invoiceId),
      ':skPrefix': 'DEVICE#',
    },
    expressionAttributeNames: { '#pk': 'PK', '#sk': 'SK' },
    limit: resolveLimit('AP-04', pagination?.limit),
    scanIndexForward: true,
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-05: Customer Device History ──────────────────────────────────────────

/**
 * AP-05: Query device history for a customer.
 * Bounded GSI2 Query sorted by occurredAt.
 */
export function queryCustomerDeviceHistory(
  ctx: TenantContextWire,
  customerId: string,
  pagination?: PaginationParams,
  options?: { scanForward?: boolean },
): QueryInput {
  return {
    accessPatternId: 'AP-05',
    indexName: INDEX_NAMES.GSI2,
    keyConditionExpression: '#gsi2pk = :gsi2pk',
    expressionAttributeValues: { ':gsi2pk': buildCustomerHistoryGSI2PK(ctx.tenantId, customerId) },
    expressionAttributeNames: { '#gsi2pk': 'GSI2PK' },
    limit: resolveLimit('AP-05', pagination?.limit),
    scanIndexForward: options?.scanForward ?? false,
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-06: Service Jobs by Status/Due ───────────────────────────────────────

/**
 * AP-06: Query service jobs by status, sorted by dueAt.
 * Bounded GSI1 Query.
 */
export function queryServiceJobsByStatus(
  ctx: TenantContextWire,
  status: string,
  pagination?: PaginationParams,
  options?: { scanForward?: boolean },
): QueryInput {
  return {
    accessPatternId: 'AP-06',
    indexName: INDEX_NAMES.GSI1,
    keyConditionExpression: '#gsi1pk = :gsi1pk',
    expressionAttributeValues: { ':gsi1pk': buildServiceJobGSI1PK(ctx.tenantId, status) },
    expressionAttributeNames: { '#gsi1pk': 'GSI1PK' },
    limit: resolveLimit('AP-06', pagination?.limit),
    scanIndexForward: options?.scanForward ?? true, // earliest due first
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-07: Warranty Expiry/Claim Status ─────────────────────────────────────

/**
 * AP-07: Query warranties by status, sorted by expiryOrUpdated.
 * Bounded GSI1 Query.
 */
export function queryWarrantiesByStatus(
  ctx: TenantContextWire,
  status: string,
  pagination?: PaginationParams,
  options?: { scanForward?: boolean },
): QueryInput {
  return {
    accessPatternId: 'AP-07',
    indexName: INDEX_NAMES.GSI1,
    keyConditionExpression: '#gsi1pk = :gsi1pk',
    expressionAttributeValues: { ':gsi1pk': buildWarrantyGSI1PK(ctx.tenantId, status) },
    expressionAttributeNames: { '#gsi1pk': 'GSI1PK' },
    limit: resolveLimit('AP-07', pagination?.limit),
    scanIndexForward: options?.scanForward ?? true,
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-08: Exchanges/Intakes/Returns/Finance by Status ──────────────────────

/** Allowed entity types for AP-08 status queries */
const AP08_ALLOWED_TYPES = new Set([
  'EXCHANGE', 'INTAKE', 'RETURN', 'FINANCE',
]);

/**
 * AP-08: Query exchanges, intakes, returns, or finance by status.
 * Bounded GSI1 Query. Rejects unsupported entity types.
 */
export function queryByEntityTypeAndStatus(
  ctx: TenantContextWire,
  entityType: string,
  status: string,
  pagination?: PaginationParams,
  options?: { scanForward?: boolean },
): QueryInput {
  if (!AP08_ALLOWED_TYPES.has(entityType)) {
    throw new UnsupportedQueryError(
      `AP-08 does not support entity type '${entityType}'. Allowed: ${[...AP08_ALLOWED_TYPES].join(', ')}`,
    );
  }

  return {
    accessPatternId: 'AP-08',
    indexName: INDEX_NAMES.GSI1,
    keyConditionExpression: '#gsi1pk = :gsi1pk',
    expressionAttributeValues: { ':gsi1pk': buildStatusGSI1PK(ctx.tenantId, entityType, status) },
    expressionAttributeNames: { '#gsi1pk': 'GSI1PK' },
    limit: resolveLimit('AP-08', pagination?.limit),
    scanIndexForward: options?.scanForward ?? false,
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-09: Active Reservation by Unit ───────────────────────────────────────

/**
 * AP-09: Get active reservation claim for a unit.
 * Strong read of the claim item; used for conditional mutations.
 */
export function getReservationClaim(
  ctx: TenantContextWire,
  unitId: string,
): GetInput {
  return {
    accessPatternId: 'AP-09',
    key: {
      PK: buildClaimPK(ctx.tenantId),
      SK: encodeSK('RESERVATION', unitId),
    },
    consistentRead: true,
  };
}

// ─── AP-10: Tenant Change Feed ───────────────────────────────────────────────

/**
 * AP-10: Query the tenant change feed for sync pulls.
 * Base table Query sorted by sequence.
 */
export function queryChangeFeed(
  ctx: TenantContextWire,
  bucket: string,
  pagination?: PaginationParams,
  options?: { afterSequence?: string },
): QueryInput {
  const pk = buildChangeFeedPK(ctx.tenantId, bucket);
  let keyCondition = '#pk = :pk';
  const exprValues: Record<string, unknown> = { ':pk': pk };
  const exprNames: Record<string, string> = { '#pk': 'PK' };

  if (options?.afterSequence) {
    keyCondition += ' AND #sk > :afterSeq';
    exprValues[':afterSeq'] = options.afterSequence;
    exprNames['#sk'] = 'SK';
  }

  return {
    accessPatternId: 'AP-10',
    keyConditionExpression: keyCondition,
    expressionAttributeValues: exprValues,
    expressionAttributeNames: exprNames,
    limit: resolveLimit('AP-10', pagination?.limit),
    scanIndexForward: true, // oldest-first for sequential consumption
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-11: Audit Timeline ───────────────────────────────────────────────────

/**
 * AP-11: Query audit events for a specific entity.
 * Bounded GSI2 Query, immutable items.
 */
export function queryAuditTimeline(
  ctx: TenantContextWire,
  entityType: string,
  entityId: string,
  pagination?: PaginationParams,
  options?: { scanForward?: boolean },
): QueryInput {
  return {
    accessPatternId: 'AP-11',
    indexName: INDEX_NAMES.GSI2,
    keyConditionExpression: '#gsi2pk = :gsi2pk',
    expressionAttributeValues: {
      ':gsi2pk': buildAuditTimelineGSI2PK(ctx.tenantId, entityType, entityId),
    },
    expressionAttributeNames: { '#gsi2pk': 'GSI2PK' },
    limit: resolveLimit('AP-11', pagination?.limit),
    scanIndexForward: options?.scanForward ?? false, // newest first
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-12: Reconciliation Work ──────────────────────────────────────────────

/**
 * AP-12: Query reconciliation records by status and bucket (worker-only).
 * Bounded GSI1 Query sorted by nextAttemptAt.
 */
export function queryReconciliationWork(
  ctx: TenantContextWire,
  status: string,
  bucket: string,
  pagination?: PaginationParams,
): QueryInput {
  return {
    accessPatternId: 'AP-12',
    indexName: INDEX_NAMES.GSI1,
    keyConditionExpression: '#gsi1pk = :gsi1pk',
    expressionAttributeValues: {
      ':gsi1pk': buildReconciliationGSI1PK(ctx.tenantId, status, bucket),
    },
    expressionAttributeNames: { '#gsi1pk': 'GSI1PK' },
    limit: resolveLimit('AP-12', pagination?.limit),
    scanIndexForward: true, // earliest next-attempt first
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-13: KPI Projection ──────────────────────────────────────────────────

/**
 * AP-13: Get or query KPI projection items.
 * Base table Query with SK prefix KPI#metric#dimension.
 */
export function queryKpiProjection(
  ctx: TenantContextWire,
  metric?: string,
  dimension?: string,
  pagination?: PaginationParams,
): QueryInput {
  const pk = buildProjectionPK(ctx.tenantId);
  let keyCondition = '#pk = :pk';
  const exprValues: Record<string, unknown> = { ':pk': pk };
  const exprNames: Record<string, string> = { '#pk': 'PK' };

  if (metric) {
    const skPrefix = dimension ? `KPI#${metric}#${dimension}` : `KPI#${metric}`;
    keyCondition += ' AND begins_with(#sk, :skPrefix)';
    exprValues[':skPrefix'] = skPrefix;
    exprNames['#sk'] = 'SK';
  }

  return {
    accessPatternId: 'AP-13',
    keyConditionExpression: keyCondition,
    expressionAttributeValues: exprValues,
    expressionAttributeNames: exprNames,
    limit: resolveLimit('AP-13', pagination?.limit),
    scanIndexForward: true,
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}

// ─── AP-14: Idempotency Outcome ─────────────────────────────────────────────

/**
 * AP-14: Get an idempotency record by operationId.
 * Strong read before ambiguous retry.
 */
export function getIdempotencyOutcome(
  ctx: TenantContextWire,
  operationId: string,
): GetInput {
  return {
    accessPatternId: 'AP-14',
    key: {
      PK: buildIdempotencyPK(ctx.tenantId),
      SK: encodeSK('OP', operationId),
    },
    consistentRead: true,
  };
}

// ─── AP-15: Prefix Catalogue/Search ─────────────────────────────────────────

/**
 * AP-15: Query the prefix catalogue with a minimum prefix length.
 * Bounded GSI2 Query. Rejects prefixes shorter than configured minimum.
 */
export function queryCatalogByPrefix(
  ctx: TenantContextWire,
  normalizedPrefixBucket: string,
  prefix: string,
  pagination?: PaginationParams,
): QueryInput {
  if (prefix.length < BOUNDS_CONFIG.imei.minSearchPrefix) {
    throw new UnsupportedQueryError(
      `AP-15 requires a prefix of at least ${BOUNDS_CONFIG.imei.minSearchPrefix} characters, got ${prefix.length}`,
    );
  }

  return {
    accessPatternId: 'AP-15',
    indexName: INDEX_NAMES.GSI2,
    keyConditionExpression: '#gsi2pk = :gsi2pk AND begins_with(#gsi2sk, :prefix)',
    expressionAttributeValues: {
      ':gsi2pk': buildCatalogGSI2PK(ctx.tenantId, normalizedPrefixBucket),
      ':prefix': prefix,
    },
    expressionAttributeNames: { '#gsi2pk': 'GSI2PK', '#gsi2sk': 'GSI2SK' },
    limit: resolveLimit('AP-15', pagination?.limit),
    scanIndexForward: true,
    consistentRead: false,
    exclusiveStartKey: pagination?.exclusiveStartKey,
  };
}
