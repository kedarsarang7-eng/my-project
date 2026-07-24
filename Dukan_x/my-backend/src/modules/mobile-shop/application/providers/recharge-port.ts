/**
 * Recharge Provider Port — SIM / Recharge Provider-Neutral Interface
 *
 * Defines the provider-neutral contract for SIM activation and mobile
 * recharge operations. No specific provider is selected.
 *
 * Key invariants:
 * - Feature-policy gate (SIM_RECHARGE) checked before execution
 * - Provider_Request_Id derived once, reused on safe retry
 * - Masked mobile number in persistence (only last 4 digits visible)
 * - Ambiguous outcomes reconcile by Provider_Request_Id before resubmission
 *
 * Requirements: 10.5–10.9
 */

import type { Money, TenantContextWire } from '../../schemas/common.schema';
import type {
  ProviderRequestContext,
  ProviderOutcome,
  FeatureGateResult,
} from './provider-port';
import { checkFeatureGate } from './provider-port';

// ─── Feature Gate ────────────────────────────────────────────────────────────

/** Feature policy ID required for SIM/recharge operations */
export const SIM_RECHARGE_FEATURE_ID = 'SIM_RECHARGE' as const;

/**
 * Checks the SIM_RECHARGE feature gate before any recharge provider call.
 */
export function checkRechargeGate(
  tenantCapabilities: readonly string[],
  correlationId: string,
): FeatureGateResult {
  return checkFeatureGate(SIM_RECHARGE_FEATURE_ID, tenantCapabilities, correlationId);
}

// ─── Recharge Types ──────────────────────────────────────────────────────────

/** Recharge/SIM operation request */
export interface RechargeRequest {
  /** Masked mobile number (e.g., '****1234') */
  readonly maskedMobileNumber: string;
  /** Recharge plan/pack identifier */
  readonly planId: string;
  /** Plan description */
  readonly planDescription: string;
  /** Recharge amount in integer minor units */
  readonly amount: Money;
  /** Provider identifier (provider-neutral label) */
  readonly providerId: string;
  /** Customer reference (optional) */
  readonly customerRef?: string;
  /** External reference if pre-validated */
  readonly externalRef?: string;
}

/** Recharge operation response from provider */
export interface RechargeResponse {
  /** Provider-assigned transaction reference */
  readonly providerTransactionId: string;
  /** Result status */
  readonly status: RechargeStatus;
  /** Provider reference number (for customer receipt) */
  readonly providerReference: string;
  /** Timestamp of completion */
  readonly completedAt?: string;
  /** Failure reason (if failed) */
  readonly failureReason?: string;
}

/** Recharge operation status */
export type RechargeStatus =
  | 'INITIATED'
  | 'PROCESSING'
  | 'COMPLETED'
  | 'FAILED'
  | 'REFUNDED';

// ─── Recharge Provider Port ──────────────────────────────────────────────────

/**
 * Provider-neutral interface for SIM/recharge operations.
 *
 * Implementations will be provided per recharge aggregator once selected.
 * This port defines the contract only.
 */
export interface RechargeProviderPort {
  readonly providerType: 'recharge';
  readonly requiredFeature: typeof SIM_RECHARGE_FEATURE_ID;

  /**
   * Initiate a recharge operation.
   * Provider_Request_Id is derived before submission for safe retry.
   * Ambiguous outcomes → check status before resubmission.
   */
  initiateRecharge(
    context: ProviderRequestContext,
    request: RechargeRequest,
  ): Promise<ProviderOutcome<RechargeResponse>>;

  /**
   * Check the status of a previously initiated recharge.
   * Used for ambiguous-outcome reconciliation and polling.
   */
  checkStatus(
    context: ProviderRequestContext,
    providerTransactionId: string,
  ): Promise<ProviderOutcome<RechargeResponse>>;
}

// ─── Domain Persistence Types ────────────────────────────────────────────────

/**
 * Recharge transaction record persisted in tenant-scoped DynamoDB.
 * Domain view independent of provider.
 */
export interface RechargeRecord {
  readonly tenantId: string;
  readonly transactionId: string;
  readonly maskedMobileNumber: string;
  readonly planId: string;
  readonly planDescription: string;
  readonly amount: Money;
  readonly providerId: string;
  readonly customerRef?: string;
  /** Provider_Request_Id used for the submission */
  readonly providerRequestId: string;
  /** Provider-assigned reference (once received) */
  readonly providerReference?: string;
  /** External reference from provider */
  readonly externalRef?: string;
  /** Operation_Id from the domain command */
  readonly operationId: string;
  /** Current domain status */
  readonly status: RechargeDomainStatus;
  readonly version: number;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** Domain-level recharge status */
export type RechargeDomainStatus =
  | 'INITIATED'
  | 'PENDING_PROVIDER'
  | 'COMPLETED'
  | 'FAILED'
  | 'REFUNDED'
  | 'RECONCILING';
