/**
 * Audit Event Schema
 *
 * Immutable audit event with actor, action, before/after digest,
 * evidence references, and correlation. Application workloads
 * may create and read but never update or delete these records.
 *
 * Requirements: 3.3, 4.3, 5.2, 8.11–8.12; GR-2
 */

import type { Versioned } from './common.schema';

/** Action categories for audit events */
export type AuditAction =
  | 'SALE_COMMITTED'
  | 'SALE_ACCEPTED_PENDING'
  | 'SALE_CANCELLED'
  | 'LIFECYCLE_TRANSITION'
  | 'INTAKE_ACCEPTED'
  | 'INTAKE_REJECTED'
  | 'RESERVATION_CREATED'
  | 'RESERVATION_RELEASED'
  | 'RETURN_COMPLETED'
  | 'RETURN_DISPOSITION'
  | 'EXCHANGE_COMPLETED'
  | 'SERVICE_STATUS_CHANGE'
  | 'WARRANTY_REGISTERED'
  | 'WARRANTY_CLAIMED'
  | 'FINANCE_APPROVED'
  | 'RECHARGE_COMPLETED'
  | 'VALUATION_APPROVED'
  | 'CORRECTION';

/** An immutable audit event — append-only */
export interface AuditEvent extends Versioned {
  readonly tenantId: string;
  /** Unique event identifier */
  readonly eventId: string;

  /** Actor who performed the action */
  readonly actorId: string;
  readonly actorName?: string;

  /** What happened */
  readonly action: AuditAction;

  /** Entity affected */
  readonly entityType: string;
  readonly entityId: string;

  /** Operation that produced this event */
  readonly operationId: string;
  /** Correlation ID for request tracing */
  readonly correlationId: string;

  /** Before/after state digests (SHA-256 hex) */
  readonly beforeDigest?: string;
  readonly afterDigest?: string;

  /** Human-readable reason/notes */
  readonly reason?: string;

  /** Evidence references */
  readonly evidenceRefs?: readonly string[];

  /** If this is a correction, link to the corrected event */
  readonly correctsEventId?: string;

  /** When the event occurred (ISO 8601) */
  readonly occurredAt: string;

  /** ISO 8601 timestamp of persistence */
  readonly createdAt: string;
}
