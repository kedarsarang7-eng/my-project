/**
 * Tenant-Bound Key Codec — MobileShop DynamoDB Persistence
 *
 * Encodes and decodes tenant identity into every base table and GSI partition key.
 * All key construction is internal — callers never see raw DynamoDB keys.
 *
 * Key format:
 *   PK  = TENANT#<tenantId>#<bucket>
 *   SK  = <PREFIX>#<entityType>#<id|sort-value>
 *   GSI1PK = TENANT#<tenantId>#<entityType>#<status|qualifier>
 *   GSI1SK = <sortField>#<id>
 *   GSI2PK = TENANT#<tenantId>#<entityType>#<qualifier>
 *   GSI2SK = <sortField>#<type>#<id>
 *
 * Requirements: 6.6, 6.14, 6.25, 6.28–6.30
 */

// ─── Constants ───────────────────────────────────────────────────────────────

const KEY_SEPARATOR = '#' as const;
const TENANT_PREFIX = 'TENANT' as const;
const META_PREFIX = 'META' as const;
const CHILD_PREFIX = 'CHILD' as const;

// ─── Types ───────────────────────────────────────────────────────────────────

/** DynamoDB base table key pair */
export interface BaseKey {
  readonly PK: string;
  readonly SK: string;
}

/** DynamoDB GSI-1 key pair */
export interface GSI1Key {
  readonly GSI1PK: string;
  readonly GSI1SK: string;
}

/** DynamoDB GSI-2 key pair */
export interface GSI2Key {
  readonly GSI2PK: string;
  readonly GSI2SK: string;
}

/** Full item key with optional GSI attributes */
export interface ItemKeys extends BaseKey {
  readonly GSI1PK?: string;
  readonly GSI1SK?: string;
  readonly GSI2PK?: string;
  readonly GSI2SK?: string;
}

/** Result of decoding a partition key */
export interface DecodedPK {
  readonly tenantId: string;
  readonly bucket: string;
}

/** Result of decoding a sort key */
export interface DecodedSK {
  readonly prefix: string;
  readonly entityType: string;
  readonly parts: readonly string[];
}

// ─── Encoding Functions ──────────────────────────────────────────────────────

/**
 * Encode a base table partition key.
 * Format: TENANT#<tenantId>#<bucket>
 *
 * Bucket examples: ENTITY#UNIT#<unitId>, CLAIM, IDEMPOTENCY, INVOICE#<id>,
 * AUDIT#<bucket>, CHANGE#<bucket>, RECON#<id>, PROJECTION, CATALOG
 */
export function encodePK(tenantId: string, ...bucketParts: string[]): string {
  assertNonEmpty(tenantId, 'tenantId');
  if (bucketParts.length === 0) {
    throw new Error('At least one bucket part is required');
  }
  return [TENANT_PREFIX, tenantId, ...bucketParts].join(KEY_SEPARATOR);
}

/**
 * Encode a base table sort key with META prefix (aggregate root).
 * Format: META#<entityType>
 */
export function encodeMetaSK(entityType: string): string {
  assertNonEmpty(entityType, 'entityType');
  return [META_PREFIX, entityType].join(KEY_SEPARATOR);
}

/**
 * Encode a base table sort key with CHILD prefix (aggregate child/association).
 * Format: CHILD#<entityType>#<id>[#<...parts>]
 */
export function encodeChildSK(entityType: string, id: string, ...parts: string[]): string {
  assertNonEmpty(entityType, 'entityType');
  assertNonEmpty(id, 'id');
  return [CHILD_PREFIX, entityType, id, ...parts].join(KEY_SEPARATOR);
}

/**
 * Encode a general sort key (non-META/CHILD, e.g. claim, reservation, etc).
 * Format: <prefix>#<value>[#<...parts>]
 */
export function encodeSK(prefix: string, value: string, ...parts: string[]): string {
  assertNonEmpty(prefix, 'prefix');
  assertNonEmpty(value, 'value');
  return [prefix, value, ...parts].join(KEY_SEPARATOR);
}

/**
 * Encode GSI-1 partition key.
 * Format: TENANT#<tenantId>#<entityType>#<qualifier>
 */
export function encodeGSI1PK(tenantId: string, entityType: string, qualifier?: string): string {
  assertNonEmpty(tenantId, 'tenantId');
  assertNonEmpty(entityType, 'entityType');
  const parts = [TENANT_PREFIX, tenantId, entityType];
  if (qualifier) {
    parts.push(qualifier);
  }
  return parts.join(KEY_SEPARATOR);
}

/**
 * Encode GSI-1 sort key.
 * Format: <sortField>#<id>[#<...parts>]
 */
export function encodeGSI1SK(sortField: string, id: string, ...parts: string[]): string {
  assertNonEmpty(sortField, 'sortField');
  assertNonEmpty(id, 'id');
  return [sortField, id, ...parts].join(KEY_SEPARATOR);
}

/**
 * Encode GSI-2 partition key.
 * Format: TENANT#<tenantId>#<entityType>#<qualifier>
 */
export function encodeGSI2PK(tenantId: string, entityType: string, qualifier?: string): string {
  assertNonEmpty(tenantId, 'tenantId');
  assertNonEmpty(entityType, 'entityType');
  const parts = [TENANT_PREFIX, tenantId, entityType];
  if (qualifier) {
    parts.push(qualifier);
  }
  return parts.join(KEY_SEPARATOR);
}

/**
 * Encode GSI-2 sort key.
 * Format: <sortField>#<type>#<id>[#<...parts>]
 */
export function encodeGSI2SK(sortField: string, ...parts: string[]): string {
  assertNonEmpty(sortField, 'sortField');
  return [sortField, ...parts].join(KEY_SEPARATOR);
}

// ─── Decoding Functions ──────────────────────────────────────────────────────

/**
 * Decode a partition key and extract tenantId.
 * Validates the TENANT prefix is present.
 */
export function decodePK(pk: string): DecodedPK {
  const segments = pk.split(KEY_SEPARATOR);
  if (segments.length < 3 || segments[0] !== TENANT_PREFIX) {
    throw new KeyCodecError(`Invalid PK format: expected TENANT#<tenantId>#<bucket>, got: ${pk}`);
  }
  return {
    tenantId: segments[1],
    bucket: segments.slice(2).join(KEY_SEPARATOR),
  };
}

/**
 * Decode a sort key into prefix, entity type, and remaining parts.
 */
export function decodeSK(sk: string): DecodedSK {
  const segments = sk.split(KEY_SEPARATOR);
  if (segments.length < 2) {
    throw new KeyCodecError(`Invalid SK format: expected at least <prefix>#<type>, got: ${sk}`);
  }
  return {
    prefix: segments[0],
    entityType: segments[1],
    parts: segments.slice(2),
  };
}

/**
 * Extract tenantId from any key that starts with TENANT#<tenantId>#.
 * Works for PK, GSI1PK, GSI2PK.
 */
export function extractTenantId(key: string): string {
  const segments = key.split(KEY_SEPARATOR);
  if (segments.length < 2 || segments[0] !== TENANT_PREFIX) {
    throw new KeyCodecError(`Cannot extract tenantId: key does not start with TENANT# prefix`);
  }
  return segments[1];
}

/**
 * Verify that a key's embedded tenantId matches the expected value.
 * Returns true if valid, false if mismatched.
 */
export function verifyTenantInKey(key: string, expectedTenantId: string): boolean {
  try {
    return extractTenantId(key) === expectedTenantId;
  } catch {
    return false;
  }
}

/**
 * Verify that a DynamoDB item's tenantId attribute matches the expected tenant.
 * Used after reads to catch any cross-tenant leakage.
 */
export function verifyItemTenant(
  item: Record<string, unknown> | undefined | null,
  expectedTenantId: string,
): boolean {
  if (!item) return false;
  return item['tenantId'] === expectedTenantId;
}

// ─── Access-Pattern Key Builders ─────────────────────────────────────────────

/** AP-01: Entity aggregate by ID */
export function buildEntityAggregatePK(tenantId: string, entityType: string, entityId: string): string {
  return encodePK(tenantId, 'ENTITY', entityType, entityId);
}

/** AP-02/AP-09: Claims (IMEI, Reservation) */
export function buildClaimPK(tenantId: string): string {
  return encodePK(tenantId, 'CLAIM');
}

/** AP-03: Units by lifecycle — GSI1 key */
export function buildUnitLifecycleGSI1PK(tenantId: string, state: string): string {
  return encodeGSI1PK(tenantId, 'UNIT', state);
}

/** AP-04: Invoice associations */
export function buildInvoicePK(tenantId: string, invoiceId: string): string {
  return encodePK(tenantId, 'INVOICE', invoiceId);
}

/** AP-05: Customer device history — GSI2 key */
export function buildCustomerHistoryGSI2PK(tenantId: string, customerId: string): string {
  return encodeGSI2PK(tenantId, 'CUSTOMER', customerId);
}

/** AP-06: Service jobs by status — GSI1 key */
export function buildServiceJobGSI1PK(tenantId: string, status: string): string {
  return encodeGSI1PK(tenantId, 'SERVICE', status);
}

/** AP-07: Warranty expiry/claim status — GSI1 key */
export function buildWarrantyGSI1PK(tenantId: string, status: string): string {
  return encodeGSI1PK(tenantId, 'WARRANTY', status);
}

/** AP-08: Exchanges/intakes/returns/finance by status — GSI1 key */
export function buildStatusGSI1PK(tenantId: string, entityType: string, status: string): string {
  return encodeGSI1PK(tenantId, entityType, status);
}

/** AP-10: Tenant change feed */
export function buildChangeFeedPK(tenantId: string, bucket: string): string {
  return encodePK(tenantId, 'CHANGE', bucket);
}

/** AP-11: Audit timeline — GSI2 key */
export function buildAuditTimelineGSI2PK(tenantId: string, entityType: string, entityId: string): string {
  return encodeGSI2PK(tenantId, 'AUDIT', `${entityType}${KEY_SEPARATOR}${entityId}`);
}

/** AP-12: Reconciliation work — GSI1 key */
export function buildReconciliationGSI1PK(tenantId: string, status: string, bucket: string): string {
  return encodeGSI1PK(tenantId, 'RECON', `${status}${KEY_SEPARATOR}${bucket}`);
}

/** AP-13: KPI projection */
export function buildProjectionPK(tenantId: string): string {
  return encodePK(tenantId, 'PROJECTION');
}

/** AP-14: Idempotency outcome */
export function buildIdempotencyPK(tenantId: string): string {
  return encodePK(tenantId, 'IDEMPOTENCY');
}

/** AP-15: Prefix catalogue/search — GSI2 key */
export function buildCatalogGSI2PK(tenantId: string, normalizedPrefixBucket: string): string {
  return encodeGSI2PK(tenantId, 'CATALOG', normalizedPrefixBucket);
}

// ─── Error ───────────────────────────────────────────────────────────────────

export class KeyCodecError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'KeyCodecError';
  }
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

function assertNonEmpty(value: string, name: string): void {
  if (!value || value.trim().length === 0) {
    throw new KeyCodecError(`Key component '${name}' must be a non-empty string`);
  }
}
