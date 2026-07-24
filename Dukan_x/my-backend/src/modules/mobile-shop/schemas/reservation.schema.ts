/**
 * Reservation Schema
 *
 * Reservation claim binding a customer to one IMEI unit with expiry.
 * Uses conditional writes to prevent conflicting sale or reservation claims.
 *
 * Requirements: 4.6; GR-2
 */

import type { Money, TenantScopedEntity } from './common.schema';

/** Reservation status */
export type ReservationStatus =
  | 'ACTIVE'
  | 'CONVERTED'  // converted to sale
  | 'EXPIRED'
  | 'CANCELLED';

/** A device reservation claim */
export interface Reservation extends TenantScopedEntity {
  /** IMEI of the reserved device */
  readonly imei: string;
  readonly unitId: string;

  /** Customer who holds the reservation */
  readonly customerId: string;
  readonly customerName: string;

  /** Current status */
  readonly status: ReservationStatus;

  /** Reservation start (ISO 8601) */
  readonly reservedAt: string;
  /** Expiry time (ISO 8601) — after which the reservation may be released */
  readonly expiresAt: string;

  /** Optional deposit/advance in minor units */
  readonly depositAmount?: Money;
  /** Whether deposit has been collected */
  readonly depositCollected?: boolean;

  /** Resulting sale invoice if converted */
  readonly convertedInvoiceId?: string;

  /** Notes */
  readonly notes?: string;

  /** Operation that created this reservation */
  readonly operationId: string;
}
