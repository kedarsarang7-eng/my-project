/**
 * Invoice and Invoice-Device-Line Association Schema
 *
 * Represents tenant-scoped invoices and their associations with
 * IMEI units (device lines) and accessories.
 *
 * Requirements: 3.3–3.4, 4.8; GR-2
 */

import type { Money, TenantScopedEntity } from './common.schema';

/** Invoice status */
export type InvoiceStatus =
  | 'DRAFT'
  | 'PENDING_SYNC'
  | 'COMMITTED'
  | 'ACCEPTED_PENDING'
  | 'CANCELLED'
  | 'RETURNED';

/** Line item type */
export type InvoiceLineType = 'DEVICE' | 'ACCESSORY';

/** A tenant-scoped invoice */
export interface Invoice extends TenantScopedEntity {
  readonly invoiceNumber: string;
  readonly status: InvoiceStatus;
  readonly customerId: string;
  readonly customerName: string;

  /** Total in minor units */
  readonly totalAmount: Money;
  /** Tax in minor units */
  readonly taxAmount: Money;
  /** Discount in minor units */
  readonly discountAmount: Money;
  /** Net payable in minor units */
  readonly netAmount: Money;

  /** Payment method reference */
  readonly paymentMethod?: string;
  /** Payment reference/transaction ID */
  readonly paymentReference?: string;

  /** Invoice date (ISO 8601 date) */
  readonly invoiceDate: string;
  /** Due date for payment (ISO 8601 date) */
  readonly dueDate?: string;

  /** Notes */
  readonly notes?: string;

  /** Operation that created this invoice */
  readonly operationId: string;
}

/** A device line linking an invoice to an IMEI unit */
export interface InvoiceDeviceLine extends TenantScopedEntity {
  readonly invoiceId: string;
  readonly lineType: InvoiceLineType;
  /** IMEI of the device (for DEVICE type) */
  readonly imei?: string;
  /** Unit ID reference */
  readonly unitId?: string;

  /** Item description */
  readonly description: string;
  readonly brand?: string;
  readonly model?: string;

  /** Quantity (always 1 for DEVICE, variable for ACCESSORY) */
  readonly quantity: number;
  /** Unit price in minor units */
  readonly unitPrice: Money;
  /** Line tax in minor units */
  readonly lineTax: Money;
  /** Line discount in minor units */
  readonly lineDiscount: Money;
  /** Line total in minor units */
  readonly lineTotal: Money;

  /** HSN/SAC code for tax */
  readonly hsnCode?: string;
  /** Tax rate percentage (stored as basis points, e.g. 1800 = 18%) */
  readonly taxRateBasisPoints?: number;

  /** Warranty months for this line */
  readonly warrantyMonths?: number;

  /** Parent handset line ID (for accessory bundles) */
  readonly parentLineId?: string;
}
