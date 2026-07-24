/**
 * Finance Schema
 *
 * Finance plan, EMI details, and provider tracking.
 *
 * Requirements: 10.4–10.6; GR-2
 */

import type { Money, TenantScopedEntity } from './common.schema';

/** Finance plan status */
export type FinancePlanStatus =
  | 'APPLIED'
  | 'APPROVED'
  | 'ACTIVE'
  | 'COMPLETED'
  | 'DEFAULTED'
  | 'CANCELLED';

/** EMI status for individual installments */
export type EmiStatus =
  | 'UPCOMING'
  | 'DUE'
  | 'PAID'
  | 'OVERDUE'
  | 'WAIVED';

/** A finance plan for a device purchase */
export interface FinancePlan extends TenantScopedEntity {
  /** Customer availing finance */
  readonly customerId: string;
  readonly customerName: string;

  /** Linked invoice */
  readonly invoiceId: string;
  /** Device IMEI */
  readonly imei: string;
  readonly unitId: string;

  /** Current status */
  readonly status: FinancePlanStatus;

  /** Finance provider (bank/NBFC) — provider-neutral */
  readonly provider: string;
  /** Provider-side reference ID */
  readonly providerReference?: string;
  /** Provider_Request_Id for idempotent provider calls */
  readonly providerRequestId?: string;

  // ─── Plan Details ──────────────────────────────────────────────────────────
  /** Total financed amount in minor units */
  readonly principalAmount: Money;
  /** Down payment in minor units */
  readonly downPayment: Money;
  /** Interest rate in basis points (e.g. 1200 = 12%) */
  readonly interestRateBasisPoints: number;
  /** Number of EMI installments */
  readonly tenureMonths: number;
  /** EMI amount in minor units */
  readonly emiAmount: Money;
  /** Total payable (principal + interest) in minor units */
  readonly totalPayable: Money;

  /** Plan start date (ISO 8601 date) */
  readonly startDate: string;
  /** Plan end date (ISO 8601 date) */
  readonly endDate: string;

  /** Approval details */
  readonly approvedBy?: string;
  readonly approvedAt?: string; // ISO 8601

  /** Notes */
  readonly notes?: string;

  /** Operation that created this plan */
  readonly operationId: string;
}

/** An individual EMI installment */
export interface EmiInstallment extends TenantScopedEntity {
  /** Parent finance plan */
  readonly financePlanId: string;
  /** Installment number (1-based) */
  readonly installmentNumber: number;
  /** Due date (ISO 8601 date) */
  readonly dueDate: string;
  /** EMI amount in minor units */
  readonly amount: Money;
  /** Current status */
  readonly status: EmiStatus;
  /** Payment date if paid (ISO 8601) */
  readonly paidAt?: string;
  /** Payment reference */
  readonly paymentReference?: string;
}
