/**
 * Exchange Schema
 *
 * Represents device exchange with old/new device tracking,
 * valuation, financial adjustment, and lifecycle transitions.
 *
 * Requirements: 5.4; GR-2
 */

import type { Money, TenantScopedEntity } from './common.schema';

/** Exchange status */
export type ExchangeStatus =
  | 'INITIATED'
  | 'VALUATION_PENDING'
  | 'VALUATION_APPROVED'
  | 'APPROVED'
  | 'COMPLETED'
  | 'CANCELLED';

/** A device exchange record */
export interface Exchange extends TenantScopedEntity {
  /** Customer performing the exchange */
  readonly customerId: string;
  readonly customerName: string;

  /** Current status */
  readonly status: ExchangeStatus;

  // ─── Old Device (being exchanged in) ───────────────────────────────────────
  /** IMEI of old device being given up */
  readonly oldDeviceImei: string;
  readonly oldDeviceUnitId: string;
  readonly oldDeviceBrand: string;
  readonly oldDeviceModel: string;
  /** Condition assessment of old device */
  readonly oldDeviceCondition: string;
  /** Valuation of old device in minor units */
  readonly oldDeviceValuation: Money;

  // ─── New Device (being given out) ──────────────────────────────────────────
  /** IMEI of new device being issued */
  readonly newDeviceImei: string;
  readonly newDeviceUnitId: string;
  readonly newDeviceBrand: string;
  readonly newDeviceModel: string;
  /** Sale price of new device in minor units */
  readonly newDeviceSalePrice: Money;

  // ─── Financial Adjustment ──────────────────────────────────────────────────
  /** Amount customer pays/receives after exchange valuation */
  readonly adjustmentAmount: Money;
  /** Positive = customer pays, negative = customer receives */
  readonly adjustmentDirection: 'CUSTOMER_PAYS' | 'CUSTOMER_RECEIVES';

  /** Approval details */
  readonly approvedBy?: string;
  readonly approvedAt?: string; // ISO 8601

  /** Linked invoice for the exchange */
  readonly invoiceId?: string;

  /** Operation that created this exchange */
  readonly operationId: string;

  /** Notes */
  readonly notes?: string;
}
