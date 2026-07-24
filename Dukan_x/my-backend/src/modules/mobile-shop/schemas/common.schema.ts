/**
 * Common Shared Types — MobileShop Domain Schemas
 *
 * Shared primitives used across all MobileShop domain schemas:
 * tenant context wire format, money in integer minor units,
 * Data_Model_Version, and business-type normalization.
 *
 * Requirements: 6.18, 6.33; GR-2
 */

// ─── Business-Type Normalization ─────────────────────────────────────────────

/** Canonical wire value for mobile shop business type */
export const CANONICAL_BUSINESS_TYPE = 'mobile_shop' as const;

/** Known aliases that must be normalized at boundaries */
const BUSINESS_TYPE_ALIASES: ReadonlySet<string> = new Set([
  'mobileShop',
  'mobileshop',
  'mobile_shop',
  'MobileShop',
  'MOBILESHOP',
  'MOBILE_SHOP',
]);

/**
 * Normalizes any known mobile shop alias to canonical `mobile_shop`.
 * Returns `undefined` if the input is not a mobile shop alias.
 */
export function normalizeMobileShopBusinessType(
  raw: string,
): typeof CANONICAL_BUSINESS_TYPE | undefined {
  if (BUSINESS_TYPE_ALIASES.has(raw) || raw.toLowerCase() === 'mobileshop' || raw.toLowerCase() === 'mobile_shop') {
    return CANONICAL_BUSINESS_TYPE;
  }
  return undefined;
}

/**
 * Returns true if the raw value represents a mobile shop business type.
 */
export function isMobileShopBusinessType(raw: string): boolean {
  return normalizeMobileShopBusinessType(raw) !== undefined;
}

// ─── Tenant Context (Wire Format) ───────────────────────────────────────────

/** Tenant context resolved from authenticated claims and propagated to every handler */
export interface TenantContextWire {
  readonly tenantId: string;
  readonly businessId: string;
  readonly subjectId: string;
  readonly businessType: typeof CANONICAL_BUSINESS_TYPE;
  readonly permissions: readonly string[];
  readonly correlationId: string;
}

// ─── Money (Integer Minor Units) ─────────────────────────────────────────────

/**
 * Money representation using integer minor units (paise for INR).
 * No floating-point arithmetic — all calculations in minor units.
 */
export interface Money {
  /** Amount in minor units (e.g. paise). Always a non-negative integer. */
  readonly amountMinorUnits: number;
  /** ISO 4217 currency code */
  readonly currency: string;
}

// ─── Data Model Version ──────────────────────────────────────────────────────

/** Every authoritative record includes a data model version */
export interface Versioned {
  /** Integer data model version for migration/compatibility */
  readonly dataModelVersion: number;
}

/** Every mutable entity includes an optimistic concurrency version */
export interface EntityVersion {
  /** Integer version starting at 1, incremented on each mutation */
  readonly version: number;
}

// ─── Tenant-Scoped Entity Base ───────────────────────────────────────────────

/** Base fields present on every tenant-scoped domain entity */
export interface TenantScopedEntity extends Versioned, EntityVersion {
  readonly tenantId: string;
  readonly entityId: string;
  readonly createdAt: string; // ISO 8601
  readonly updatedAt: string; // ISO 8601
}

// ─── Timestamps ──────────────────────────────────────────────────────────────

export interface Timestamps {
  readonly createdAt: string; // ISO 8601
  readonly updatedAt: string; // ISO 8601
}

// ─── Pagination ──────────────────────────────────────────────────────────────

/** Opaque continuation token for paginated queries */
export interface PaginatedRequest {
  readonly limit: number;
  readonly continuationToken?: string;
}

export interface PaginatedResponse<T> {
  readonly items: readonly T[];
  readonly continuationToken?: string;
  readonly hasMore: boolean;
}

// ─── Evidence Reference ──────────────────────────────────────────────────────

/** Reference to evidence stored in approved object storage */
export interface EvidenceReference {
  readonly referenceId: string;
  readonly storageKey: string;
  readonly contentType: string;
  readonly digest: string; // SHA-256 hex
  readonly uploadedAt: string; // ISO 8601
}
