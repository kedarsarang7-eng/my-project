/**
 * Recharge Schema
 *
 * SIM/recharge with provider-neutral request/response.
 *
 * Requirements: 10.7–10.9; GR-2
 */

import type { Money, TenantScopedEntity } from './common.schema';

/** Recharge status */
export type RechargeStatus =
  | 'INITIATED'
  | 'PROVIDER_PENDING'
  | 'SUCCESS'
  | 'FAILED'
  | 'AMBIGUOUS'
  | 'RECONCILED';

/** Recharge type */
export type RechargeType =
  | 'PREPAID'
  | 'POSTPAID'
  | 'DATA_PACK'
  | 'DTH'
  | 'BROADBAND';

/** Provider-neutral recharge request */
export interface RechargeRequest {
  readonly tenantId: string;
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly dataModelVersion: number;

  readonly mobileNumber: string;
  readonly rechargeType: RechargeType;
  readonly provider: string;
  /** Plan/pack identifier from provider catalog */
  readonly planId: string;
  /** Recharge amount in minor units */
  readonly amount: Money;

  /** Provider_Request_Id for idempotent provider calls */
  readonly providerRequestId: string;
}

/** Provider-neutral recharge response */
export interface RechargeResponse {
  readonly status: RechargeStatus;
  /** Provider transaction reference */
  readonly providerTransactionId?: string;
  /** Failure reason (if failed) */
  readonly failureReason?: string;
  /** Completed timestamp (ISO 8601) */
  readonly completedAt?: string;
}

/** A persisted recharge record */
export interface RechargeRecord extends TenantScopedEntity {
  readonly mobileNumber: string;
  readonly rechargeType: RechargeType;
  readonly provider: string;
  readonly planId: string;
  readonly amount: Money;

  readonly status: RechargeStatus;
  readonly providerRequestId: string;
  readonly providerTransactionId?: string;
  readonly failureReason?: string;

  /** Commission earned in minor units */
  readonly commissionAmount?: Money;

  /** Timestamps */
  readonly initiatedAt: string; // ISO 8601
  readonly completedAt?: string; // ISO 8601

  /** Customer reference (optional — walk-in recharges may not have one) */
  readonly customerId?: string;

  /** Operation that created this record */
  readonly operationId: string;
}
