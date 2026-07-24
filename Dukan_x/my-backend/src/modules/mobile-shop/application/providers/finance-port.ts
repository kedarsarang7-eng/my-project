/**
 * Finance Provider Port — EMI / Finance Plan Provider-Neutral Interface
 *
 * Defines the provider-neutral contract for finance and EMI plan operations.
 * No specific financier is selected — this is a port interface only.
 *
 * Key invariants:
 * - Feature-policy gate (FINANCE_PLANS) checked before execution
 * - Provider_Request_Id derived once and reused on retry
 * - Ambiguous outcomes reconcile by Provider_Request_Id before resubmission
 * - Separate accounting lines for principal, fees, and installments
 *
 * Requirements: 10.4, 10.6–10.9
 */

import type { Money, TenantContextWire } from '../../schemas/common.schema';
import type {
  ProviderRequestContext,
  ProviderOutcome,
  FeatureGateResult,
} from './provider-port';
import { checkFeatureGate } from './provider-port';

// ─── Feature Gate ────────────────────────────────────────────────────────────

/** Feature policy ID required for finance operations */
export const FINANCE_FEATURE_ID = 'FINANCE_PLANS' as const;

/**
 * Checks the FINANCE_PLANS feature gate before any finance provider call.
 */
export function checkFinanceGate(
  tenantCapabilities: readonly string[],
  correlationId: string,
): FeatureGateResult {
  return checkFeatureGate(FINANCE_FEATURE_ID, tenantCapabilities, correlationId);
}

// ─── Finance Plan Types ──────────────────────────────────────────────────────

/** Finance plan submission request */
export interface FinancePlanRequest {
  /** Tenant-scoped sale/invoice reference */
  readonly invoiceId: string;
  /** IMEI of the financed device */
  readonly imei: string;
  /** Customer identity reference */
  readonly customerId: string;
  /** Financier identifier (provider-neutral label) */
  readonly financierId: string;
  /** Principal amount in integer minor units */
  readonly principal: Money;
  /** Processing fees in integer minor units */
  readonly processingFees: Money;
  /** Number of installments */
  readonly tenureMonths: number;
  /** Monthly installment amount in integer minor units */
  readonly installmentAmount: Money;
  /** Down payment (if any) in integer minor units */
  readonly downPayment?: Money;
  /** Customer eligibility result reference */
  readonly eligibilityRef?: string;
  /** Customer consent reference */
  readonly consentRef?: string;
}

/** Finance plan response from provider */
export interface FinancePlanResponse {
  /** Provider-assigned plan identifier */
  readonly providerPlanId: string;
  /** Plan status as reported by provider */
  readonly status: FinancePlanStatus;
  /** Provider-assigned reference number */
  readonly providerReference: string;
  /** Approval/disbursement timestamp (if approved) */
  readonly approvedAt?: string;
  /** Rejection reason (if rejected) */
  readonly rejectionReason?: string;
}

/** Finance plan status lifecycle */
export type FinancePlanStatus =
  | 'SUBMITTED'
  | 'UNDER_REVIEW'
  | 'APPROVED'
  | 'DISBURSED'
  | 'REJECTED'
  | 'CANCELLED';

/** Finance plan cancellation request */
export interface FinanceCancellationRequest {
  /** Provider-assigned plan identifier */
  readonly providerPlanId: string;
  /** Reason for cancellation */
  readonly reason: string;
  /** Actor who initiated cancellation */
  readonly actorId: string;
}

/** Finance plan cancellation response */
export interface FinanceCancellationResponse {
  /** Whether cancellation was accepted */
  readonly accepted: boolean;
  /** Provider status after cancellation attempt */
  readonly finalStatus: FinancePlanStatus;
  /** Rejection reason if cancellation denied */
  readonly rejectionReason?: string;
}

// ─── Finance Provider Port ───────────────────────────────────────────────────

/**
 * Provider-neutral interface for finance/EMI plan operations.
 *
 * Implementations will be provided per financier (e.g., Bajaj, HDFC, etc.)
 * once a provider is selected. This port defines the contract only.
 */
export interface FinanceProviderPort {
  readonly providerType: 'finance';
  readonly requiredFeature: typeof FINANCE_FEATURE_ID;

  /**
   * Submit a new finance plan to the financier.
   * Provider_Request_Id must be derived before submission and stored.
   * Ambiguous outcomes → check status before resubmission.
   */
  submitPlan(
    context: ProviderRequestContext,
    request: FinancePlanRequest,
  ): Promise<ProviderOutcome<FinancePlanResponse>>;

  /**
   * Check the status of a previously submitted finance plan.
   * Used for:
   * - Ambiguous-outcome reconciliation (Req 10.9)
   * - Polling pending plans for approval/disbursement updates
   */
  checkStatus(
    context: ProviderRequestContext,
    providerPlanId: string,
  ): Promise<ProviderOutcome<FinancePlanResponse>>;

  /**
   * Cancel a previously approved or pending finance plan.
   * Cancellation is subject to provider-specific policies.
   */
  cancelPlan(
    context: ProviderRequestContext,
    request: FinanceCancellationRequest,
  ): Promise<ProviderOutcome<FinanceCancellationResponse>>;
}

// ─── Domain Persistence Types ────────────────────────────────────────────────

/**
 * Finance plan record persisted in tenant-scoped DynamoDB.
 * This is the domain's view of a finance plan, independent of provider.
 */
export interface FinancePlanRecord {
  readonly tenantId: string;
  readonly planId: string;
  readonly invoiceId: string;
  readonly imei: string;
  readonly customerId: string;
  readonly financierId: string;
  readonly principal: Money;
  readonly processingFees: Money;
  readonly tenureMonths: number;
  readonly installmentAmount: Money;
  readonly downPayment?: Money;
  readonly eligibilityRef?: string;
  readonly consentRef?: string;
  /** Provider_Request_Id used for the submission */
  readonly providerRequestId: string;
  /** Provider-assigned reference (once received) */
  readonly providerReference?: string;
  /** Current domain status */
  readonly status: FinancePlanDomainStatus;
  /** Accounting linkage reference */
  readonly accountingRef?: string;
  readonly version: number;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** Domain-level finance plan status (superset of provider status) */
export type FinancePlanDomainStatus =
  | 'DRAFT'
  | 'SUBMITTED'
  | 'PENDING_PROVIDER'
  | 'APPROVED'
  | 'DISBURSED'
  | 'REJECTED'
  | 'CANCELLED'
  | 'RECONCILING';
