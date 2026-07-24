/**
 * Warranty Schema
 *
 * Warranty registration, claims, period, and provider tracking.
 *
 * Requirements: 5.5–5.7; GR-2
 */

import type { Money, TenantScopedEntity, EvidenceReference } from './common.schema';

/** Warranty status */
export type WarrantyStatus =
  | 'ACTIVE'
  | 'EXPIRED'
  | 'CLAIMED'
  | 'VOID';

/** Warranty claim status */
export type WarrantyClaimStatus =
  | 'SUBMITTED'
  | 'UNDER_REVIEW'
  | 'APPROVED'
  | 'REJECTED'
  | 'RESOLVED'
  | 'CLOSED';

/** Warranty type */
export type WarrantyType =
  | 'MANUFACTURER'
  | 'EXTENDED'
  | 'THIRD_PARTY'
  | 'STORE';

/** A warranty registration */
export interface Warranty extends TenantScopedEntity {
  /** IMEI of the warranted device */
  readonly imei: string;
  readonly unitId: string;

  /** Sale that established this warranty */
  readonly saleInvoiceId: string;
  readonly customerId: string;

  /** Warranty details */
  readonly warrantyType: WarrantyType;
  readonly status: WarrantyStatus;
  readonly provider: string;
  /** Warranty duration in months */
  readonly durationMonths: number;

  /** Start date (ISO 8601 date) */
  readonly startDate: string;
  /** End date (ISO 8601 date, calculated using month-end rules) */
  readonly endDate: string;

  /** Provider reference/policy number */
  readonly providerReference?: string;

  /** Cost of extended warranty (if any) in minor units */
  readonly cost?: Money;

  /** Notes */
  readonly notes?: string;

  /** Operation that created this warranty */
  readonly operationId: string;
}

/** A warranty claim */
export interface WarrantyClaim extends TenantScopedEntity {
  /** Parent warranty */
  readonly warrantyId: string;
  readonly imei: string;
  readonly unitId: string;
  readonly customerId: string;

  /** Claim details */
  readonly status: WarrantyClaimStatus;
  readonly faultDescription: string;
  /** Date claim was filed (ISO 8601) */
  readonly claimDate: string;

  /** Resolution */
  readonly resolution?: string;
  readonly resolvedAt?: string; // ISO 8601
  readonly resolutionCost?: Money;

  /** Evidence */
  readonly evidenceRefs?: readonly EvidenceReference[];

  /** Linked service job if repair was initiated */
  readonly serviceJobId?: string;

  /** Operation that created this claim */
  readonly operationId: string;
}
