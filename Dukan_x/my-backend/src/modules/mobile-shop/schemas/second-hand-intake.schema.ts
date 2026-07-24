/**
 * Second-Hand Intake Schema
 *
 * Intake with seller identity, evidence, inspection,
 * valuation, and exchange linkage.
 *
 * Requirements: 4.2–4.4; GR-2
 */

import type { Money, TenantScopedEntity, EvidenceReference } from './common.schema';
import type { DeviceCondition } from './imei-unit.schema';

/** Intake status */
export type IntakeStatus =
  | 'SUBMITTED'
  | 'INSPECTION_PENDING'
  | 'INSPECTED'
  | 'VALUATION_PENDING'
  | 'VALUATION_APPROVED'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'CANCELLED';

/** Inspection result */
export type InspectionResult =
  | 'PASS'
  | 'CONDITIONAL_PASS'
  | 'FAIL';

/** A second-hand device intake record */
export interface SecondHandIntake extends TenantScopedEntity {
  /** Normalized IMEI of the device being taken in */
  readonly imei: string;

  /** Current status */
  readonly status: IntakeStatus;

  // ─── Seller ────────────────────────────────────────────────────────────────
  /** Seller identity reference (customer/walk-in) */
  readonly sellerId: string;
  readonly sellerName: string;
  readonly sellerContact?: string;

  // ─── Device Details ────────────────────────────────────────────────────────
  readonly brand: string;
  readonly model: string;
  readonly color?: string;
  readonly storage?: string;
  readonly condition: DeviceCondition;

  // ─── Inspection ────────────────────────────────────────────────────────────
  readonly inspectionResult?: InspectionResult;
  readonly inspectionNotes?: string;
  readonly inspectedBy?: string;
  readonly inspectedAt?: string; // ISO 8601

  // ─── Valuation ─────────────────────────────────────────────────────────────
  /** Proposed purchase price (from seller) in minor units */
  readonly proposedPrice?: Money;
  /** Approved valuation in minor units */
  readonly approvedValuation?: Money;
  readonly valuationApprovedBy?: string;
  readonly valuationApprovedAt?: string; // ISO 8601

  // ─── Ownership Evidence ────────────────────────────────────────────────────
  /** Status of ownership evidence verification */
  readonly ownershipEvidenceStatus: 'PENDING' | 'VERIFIED' | 'UNVERIFIED';
  readonly evidenceRefs?: readonly EvidenceReference[];

  // ─── Linkage ───────────────────────────────────────────────────────────────
  /** Exchange ID if this intake is part of an exchange */
  readonly exchangeId?: string;
  /** Resulting IMEI unit ID after acceptance */
  readonly resultingUnitId?: string;

  /** Notes */
  readonly notes?: string;

  /** Operation that created this intake */
  readonly operationId: string;
}
