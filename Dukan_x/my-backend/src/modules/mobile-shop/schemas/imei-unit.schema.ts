/**
 * IMEI Unit Schema
 *
 * Represents a tenant-scoped device unit identified by a normalized
 * 15-digit Luhn-valid IMEI with lifecycle state, version, condition,
 * ownership, valuation, warranty, and tenant binding.
 *
 * Requirements: 3.3–3.8, 4.1, 4.5–4.9; GR-2
 */

import type { Money, TenantScopedEntity, EvidenceReference } from './common.schema';

/** Canonical lifecycle states for an IMEI unit */
export type DeviceLifecycleState =
  | 'IN_STOCK'
  | 'SECOND_HAND'
  | 'RESERVED'
  | 'SALE_PENDING'
  | 'SOLD'
  | 'RETURNED'
  | 'DEMO'
  | 'IN_SERVICE'
  | 'EXCHANGED'
  | 'DAMAGED'
  | 'RETIRED';

/** Physical condition of the device */
export type DeviceCondition =
  | 'NEW'
  | 'LIKE_NEW'
  | 'GOOD'
  | 'FAIR'
  | 'POOR'
  | 'DAMAGED';

/** How the device was acquired */
export type OwnershipSource =
  | 'PURCHASED_NEW'
  | 'SECOND_HAND_INTAKE'
  | 'EXCHANGE_IN'
  | 'RETURN'
  | 'DEMO_ALLOCATION'
  | 'TRANSFER';

/** An IMEI Unit — one physical handset in tenant inventory */
export interface ImeiUnit extends TenantScopedEntity {
  /** Normalized 15-digit IMEI (ASCII digits only) */
  readonly imei: string;
  /** Current lifecycle state */
  readonly lifecycleState: DeviceLifecycleState;
  /** Physical condition */
  readonly condition: DeviceCondition;
  /** How the device was acquired */
  readonly ownershipSource: OwnershipSource;
  /** Brand name */
  readonly brand: string;
  /** Model name */
  readonly model: string;
  /** Optional color/variant */
  readonly color?: string;
  /** Optional storage capacity (e.g. "128GB") */
  readonly storage?: string;

  // ─── Valuation ─────────────────────────────────────────────────────────────
  /** Acquisition cost in minor units */
  readonly acquisitionCost: Money;
  /** Current sale price in minor units */
  readonly salePrice: Money;
  /** Optional market valuation for second-hand */
  readonly marketValuation?: Money;

  // ─── Warranty ──────────────────────────────────────────────────────────────
  /** Warranty start date (ISO 8601 date) */
  readonly warrantyStartDate?: string;
  /** Warranty end date (ISO 8601 date) */
  readonly warrantyEndDate?: string;
  /** Warranty provider name */
  readonly warrantyProvider?: string;

  // ─── Associations ──────────────────────────────────────────────────────────
  /** Customer ID (if sold/reserved) */
  readonly customerId?: string;
  /** Invoice ID from the last sale */
  readonly saleInvoiceId?: string;
  /** Sale timestamp */
  readonly soldAt?: string; // ISO 8601
  /** Supplier/vendor ID for acquisition */
  readonly supplierId?: string;
  /** Exchange ID if acquired via exchange */
  readonly exchangeId?: string;
  /** Intake ID if second-hand intake */
  readonly intakeId?: string;

  // ─── Evidence ──────────────────────────────────────────────────────────────
  /** Evidence references (photos, receipts, etc.) */
  readonly evidenceRefs?: readonly EvidenceReference[];
}

/** Command to transition an IMEI unit's lifecycle state */
export interface DeviceLifecycleTransitionCommand {
  readonly tenantId: string;
  readonly imei: string;
  readonly targetState: DeviceLifecycleState;
  readonly expectedVersion: number;
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly actor: string;
  readonly reason: string;
  readonly evidenceRefs?: readonly EvidenceReference[];
  readonly dataModelVersion: number;
}
