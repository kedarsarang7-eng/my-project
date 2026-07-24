/**
 * Service Job Schema
 *
 * Represents repair/service jobs with status transitions,
 * technician assignment, fault details, and cost estimates.
 *
 * Requirements: 5.1–5.3; GR-2
 */

import type { Money, TenantScopedEntity } from './common.schema';

/** Service job status following allowed transitions */
export type ServiceJobStatus =
  | 'RECEIVED'
  | 'DIAGNOSED'
  | 'ESTIMATE_SENT'
  | 'APPROVED'
  | 'IN_PROGRESS'
  | 'PARTS_ORDERED'
  | 'READY'
  | 'DELIVERED'
  | 'CANCELLED';

/** Priority level */
export type ServicePriority = 'LOW' | 'NORMAL' | 'HIGH' | 'URGENT';

/** A service/repair job for a device */
export interface ServiceJob extends TenantScopedEntity {
  /** IMEI of the device being serviced */
  readonly imei: string;
  /** Unit ID of the device */
  readonly unitId: string;
  /** Customer who owns/submitted the device */
  readonly customerId: string;
  readonly customerName: string;

  /** Current status */
  readonly status: ServiceJobStatus;
  readonly priority: ServicePriority;

  /** Fault/issue description */
  readonly faultDescription: string;
  /** Diagnosis notes from technician */
  readonly diagnosisNotes?: string;

  /** Assigned technician */
  readonly technicianId?: string;
  readonly technicianName?: string;

  /** Estimated cost for the repair */
  readonly estimatedCost?: Money;
  /** Actual cost after completion */
  readonly actualCost?: Money;

  /** Whether device is under warranty */
  readonly underWarranty: boolean;
  /** Warranty claim ID if applicable */
  readonly warrantyClaimId?: string;

  /** Dates */
  readonly receivedAt: string;   // ISO 8601
  readonly estimatedCompletionAt?: string; // ISO 8601
  readonly completedAt?: string; // ISO 8601
  readonly deliveredAt?: string; // ISO 8601

  /** Due date for service completion */
  readonly dueAt?: string; // ISO 8601

  /** Notes */
  readonly notes?: string;

  /** Operation that created/last mutated this job */
  readonly operationId: string;
}

/** Command to update service job status */
export interface ServiceJobTransitionCommand {
  readonly tenantId: string;
  readonly jobId: string;
  readonly targetStatus: ServiceJobStatus;
  readonly expectedVersion: number;
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly actor: string;
  readonly notes?: string;
  readonly actualCost?: Money;
  readonly dataModelVersion: number;
}
