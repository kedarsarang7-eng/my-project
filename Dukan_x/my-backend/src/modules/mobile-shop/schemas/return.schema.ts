/**
 * Return Schema
 *
 * Device return with eligibility, disposition, and target lifecycle state.
 *
 * Requirements: 4.7; GR-2
 */

import type { Money, TenantScopedEntity, EvidenceReference } from './common.schema';
import type { DeviceCondition, DeviceLifecycleState } from './imei-unit.schema';

/** Return status */
export type ReturnStatus =
  | 'REQUESTED'
  | 'ELIGIBILITY_VERIFIED'
  | 'INSPECTION_PENDING'
  | 'INSPECTED'
  | 'APPROVED'
  | 'COMPLETED'
  | 'REJECTED'
  | 'CANCELLED';

/** Disposition of the returned device */
export type ReturnDisposition =
  | 'RESTOCK'
  | 'REFURBISH'
  | 'DAMAGE_WRITE_OFF'
  | 'EXCHANGE_CREDIT'
  | 'VENDOR_RETURN';

/** A device return record */
export interface Return extends TenantScopedEntity {
  /** IMEI of the returned device */
  readonly imei: string;
  readonly unitId: string;

  /** Customer returning the device */
  readonly customerId: string;
  readonly customerName: string;

  /** Current status */
  readonly status: ReturnStatus;

  // ─── Originating Sale ──────────────────────────────────────────────────────
  /** Invoice from the original sale */
  readonly originatingInvoiceId: string;
  /** Date of original sale */
  readonly originalSaleDate: string; // ISO 8601

  // ─── Eligibility ───────────────────────────────────────────────────────────
  /** Whether return is within policy window */
  readonly withinReturnWindow: boolean;
  /** Return reason */
  readonly reason: string;

  // ─── Inspection ────────────────────────────────────────────────────────────
  /** Condition at return */
  readonly returnCondition?: DeviceCondition;
  /** Physical IMEI match verified */
  readonly imeiMatchVerified?: boolean;
  readonly inspectionNotes?: string;

  // ─── Disposition ───────────────────────────────────────────────────────────
  readonly disposition?: ReturnDisposition;
  /** Target lifecycle state after return processing */
  readonly targetLifecycleState?: DeviceLifecycleState;

  // ─── Financial ─────────────────────────────────────────────────────────────
  /** Refund amount in minor units */
  readonly refundAmount?: Money;
  /** Restocking fee in minor units */
  readonly restockingFee?: Money;

  // ─── Evidence ──────────────────────────────────────────────────────────────
  readonly evidenceRefs?: readonly EvidenceReference[];

  /** Notes */
  readonly notes?: string;

  /** Operation that created this return */
  readonly operationId: string;
}
