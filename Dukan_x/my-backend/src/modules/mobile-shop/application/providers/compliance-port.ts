/**
 * Compliance Port — e-Way Bill and Regulatory Compliance Interface
 *
 * Defines the provider-neutral contract for e-Way bill generation and
 * regulatory compliance operations. Integrates with the EXISTING e-Way
 * architecture in the project.
 *
 * Key invariants:
 * - Feature-policy gate (E_WAY_BILL) checked before execution
 * - Integrates with existing compliance architecture (not replacing it)
 * - Provider_Request_Id for retry safety on external submissions
 * - Transaction thresholds and jurisdiction rules determine applicability
 * - Online connectivity required for e-Way generation
 *
 * Requirements: 10.12, 10.6–10.9
 */

import type { Money, TenantContextWire } from '../../schemas/common.schema';
import type {
  ProviderRequestContext,
  ProviderOutcome,
  FeatureGateResult,
} from './provider-port';
import { checkFeatureGate } from './provider-port';

// ─── Feature Gate ────────────────────────────────────────────────────────────

/** Feature policy ID for e-Way bill compliance */
export const E_WAY_BILL_FEATURE_ID = 'E_WAY_BILL' as const;

/**
 * Checks the E_WAY_BILL feature gate before any compliance operation.
 */
export function checkComplianceGate(
  tenantCapabilities: readonly string[],
  correlationId: string,
): FeatureGateResult {
  return checkFeatureGate(E_WAY_BILL_FEATURE_ID, tenantCapabilities, correlationId);
}

// ─── e-Way Bill Types ────────────────────────────────────────────────────────

/** e-Way bill generation request */
export interface EwayBillRequest {
  /** Invoice reference for this shipment */
  readonly invoiceId: string;
  /** Invoice number (printed on the bill) */
  readonly invoiceNumber: string;
  /** Invoice date (ISO 8601) */
  readonly invoiceDate: string;
  /** Total invoice value in integer minor units */
  readonly invoiceValue: Money;
  /** Supply type (outward/inward) */
  readonly supplyType: SupplyType;
  /** Document type */
  readonly documentType: EwayDocumentType;
  /** Consignor (from) details */
  readonly from: EwayPartyDetails;
  /** Consignee (to) details */
  readonly to: EwayPartyDetails;
  /** Transport details */
  readonly transport: TransportDetails;
  /** Line items for the e-Way bill */
  readonly items: readonly EwayLineItem[];
}

/** Supply direction */
export type SupplyType = 'OUTWARD' | 'INWARD';

/** e-Way document type */
export type EwayDocumentType =
  | 'TAX_INVOICE'
  | 'BILL_OF_SUPPLY'
  | 'DELIVERY_CHALLAN'
  | 'CREDIT_NOTE';

/** Party details for e-Way bill */
export interface EwayPartyDetails {
  /** GSTIN (if registered) */
  readonly gstin?: string;
  /** Legal name */
  readonly legalName: string;
  /** Trading name */
  readonly tradeName?: string;
  /** Address line 1 */
  readonly address1: string;
  /** Address line 2 */
  readonly address2?: string;
  /** City */
  readonly city: string;
  /** State code (2-digit numeric) */
  readonly stateCode: string;
  /** PIN code */
  readonly pinCode: string;
}

/** Transport details */
export interface TransportDetails {
  /** Transport mode */
  readonly mode: TransportMode;
  /** Transporter name */
  readonly transporterName?: string;
  /** Transporter GSTIN */
  readonly transporterGstin?: string;
  /** Transport document number (LR/RR/AWB) */
  readonly documentNumber?: string;
  /** Transport document date */
  readonly documentDate?: string;
  /** Vehicle number (for road transport) */
  readonly vehicleNumber?: string;
  /** Vehicle type */
  readonly vehicleType?: VehicleType;
  /** Approximate distance in km */
  readonly distanceKm: number;
}

/** Transport mode */
export type TransportMode = 'ROAD' | 'RAIL' | 'AIR' | 'SHIP';

/** Vehicle type for road transport */
export type VehicleType = 'REGULAR' | 'OVER_DIMENSIONAL_CARGO';

/** Line item for e-Way bill */
export interface EwayLineItem {
  /** HSN code */
  readonly hsnCode: string;
  /** Product description */
  readonly description: string;
  /** Quantity */
  readonly quantity: number;
  /** Unit of measure */
  readonly unit: string;
  /** Taxable value in integer minor units */
  readonly taxableValue: Money;
  /** Tax rate in basis points */
  readonly taxRateBps: number;
  /** CGST amount */
  readonly cgst: Money;
  /** SGST amount */
  readonly sgst: Money;
  /** IGST amount (for inter-state) */
  readonly igst?: Money;
}

/** e-Way bill generation response */
export interface EwayBillResponse {
  /** Generated e-Way bill number */
  readonly ewayBillNumber: string;
  /** Generation date (ISO 8601) */
  readonly generatedAt: string;
  /** Validity period end (ISO 8601) */
  readonly validUntil: string;
  /** Current status */
  readonly status: EwayBillStatus;
}

/** e-Way bill status lifecycle */
export type EwayBillStatus =
  | 'GENERATED'
  | 'ACTIVE'
  | 'CANCELLED'
  | 'EXPIRED';

/** e-Way bill cancellation request */
export interface EwayCancellationRequest {
  /** e-Way bill number to cancel */
  readonly ewayBillNumber: string;
  /** Cancellation reason code */
  readonly reasonCode: EwayCancellationReason;
  /** Free-text remarks */
  readonly remarks: string;
}

/** Standard cancellation reasons */
export type EwayCancellationReason =
  | 'DUPLICATE'
  | 'ORDER_CANCELLED'
  | 'DATA_ENTRY_MISTAKE'
  | 'OTHERS';

/** e-Way bill cancellation response */
export interface EwayCancellationResponse {
  /** Whether cancellation was accepted */
  readonly cancelled: boolean;
  /** Cancellation timestamp (if accepted) */
  readonly cancelledAt?: string;
  /** Rejection reason (if not accepted — e.g., already transported) */
  readonly rejectionReason?: string;
}

/** Compliance verification request */
export interface ComplianceVerificationRequest {
  /** Invoice value in integer minor units */
  readonly invoiceValue: Money;
  /** Supply type */
  readonly supplyType: SupplyType;
  /** Source state code */
  readonly fromStateCode: string;
  /** Destination state code */
  readonly toStateCode: string;
  /** Whether goods are being transported */
  readonly goodsInTransit: boolean;
}

/** Compliance verification result */
export interface ComplianceVerificationResult {
  /** Whether e-Way bill is required for this transaction */
  readonly ewayBillRequired: boolean;
  /** Reason for the determination */
  readonly reason: string;
  /** Applicable threshold in integer minor units */
  readonly applicableThreshold?: Money;
  /** Whether this is inter-state (different rules may apply) */
  readonly isInterState: boolean;
}

// ─── Compliance Port ─────────────────────────────────────────────────────────

/**
 * Provider-neutral interface for e-Way bill and compliance operations.
 *
 * This port integrates with the EXISTING e-Way architecture in the project
 * rather than replacing it. Implementations connect to the government
 * e-Way bill portal or approved intermediary.
 */
export interface CompliancePort {
  readonly providerType: 'compliance';
  readonly requiredFeature: typeof E_WAY_BILL_FEATURE_ID;

  /**
   * Generate an e-Way bill for a qualifying transaction.
   * Provider_Request_Id is derived before submission for retry safety.
   * Online connectivity required.
   */
  generateEwayBill(
    context: ProviderRequestContext,
    request: EwayBillRequest,
  ): Promise<ProviderOutcome<EwayBillResponse>>;

  /**
   * Cancel a previously generated e-Way bill.
   * Subject to time-based restrictions (typically within 24 hours).
   */
  cancelEwayBill(
    context: ProviderRequestContext,
    request: EwayCancellationRequest,
  ): Promise<ProviderOutcome<EwayCancellationResponse>>;

  /**
   * Verify whether a transaction requires e-Way documentation.
   * Checks transaction thresholds and jurisdiction rules.
   * Does not make external calls — rule-based determination.
   */
  verifyCompliance(
    context: TenantContextWire,
    request: ComplianceVerificationRequest,
  ): ComplianceVerificationResult;
}

// ─── Domain Persistence Types ────────────────────────────────────────────────

/**
 * e-Way bill record persisted in tenant-scoped DynamoDB.
 * Tracks the full lifecycle of an e-Way bill.
 */
export interface EwayBillRecord {
  readonly tenantId: string;
  readonly recordId: string;
  readonly invoiceId: string;
  readonly invoiceNumber: string;
  /** Generated e-Way bill number (once received) */
  readonly ewayBillNumber?: string;
  /** Provider_Request_Id used for the submission */
  readonly providerRequestId: string;
  /** Invoice value */
  readonly invoiceValue: Money;
  readonly supplyType: SupplyType;
  /** From state code */
  readonly fromStateCode: string;
  /** To state code */
  readonly toStateCode: string;
  /** Validity end (ISO 8601) */
  readonly validUntil?: string;
  /** Current status */
  readonly status: EwayBillDomainStatus;
  /** Cancellation details (if cancelled) */
  readonly cancellation?: {
    readonly reasonCode: EwayCancellationReason;
    readonly remarks: string;
    readonly cancelledAt: string;
  };
  readonly version: number;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** Domain-level e-Way bill status */
export type EwayBillDomainStatus =
  | 'PENDING_GENERATION'
  | 'GENERATED'
  | 'ACTIVE'
  | 'CANCELLED'
  | 'EXPIRED'
  | 'RECONCILING';
