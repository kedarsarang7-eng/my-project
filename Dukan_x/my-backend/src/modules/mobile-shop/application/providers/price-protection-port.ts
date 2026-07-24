/**
 * Price Protection Port — MRP Markdown / Price Protection Interface
 *
 * Defines the provider-neutral contract for price protection, authorized
 * markdown adjustments, and margin impact calculations.
 *
 * Key invariants:
 * - Feature-policy gate (PRICE_PROTECTION) checked before execution
 * - Every markdown requires explicit approval with reason and actor
 * - Margin impact is calculated BEFORE approval (decision aid)
 * - Approved adjustments include effective period and audit event
 * - No unauthorized price change bypasses approval workflow
 *
 * Requirements: 10.11, 10.6–10.9
 */

import type { Money, TenantContextWire } from '../../schemas/common.schema';
import type { FeatureGateResult } from './provider-port';
import { checkFeatureGate } from './provider-port';

// ─── Feature Gate ────────────────────────────────────────────────────────────

/** Feature policy ID for price protection operations */
export const PRICE_PROTECTION_FEATURE_ID = 'PRICE_PROTECTION' as const;

/**
 * Checks the PRICE_PROTECTION feature gate before any price adjustment.
 */
export function checkPriceProtectionGate(
  tenantCapabilities: readonly string[],
  correlationId: string,
): FeatureGateResult {
  return checkFeatureGate(PRICE_PROTECTION_FEATURE_ID, tenantCapabilities, correlationId);
}

// ─── Price Protection Types ──────────────────────────────────────────────────

/** Markdown/price adjustment request */
export interface MarkdownRequest {
  /** Device or item identifier (IMEI or SKU) */
  readonly itemIdentifier: string;
  /** Item type */
  readonly itemType: 'HANDSET' | 'ACCESSORY';
  /** Original MRP/list price in integer minor units */
  readonly originalPrice: Money;
  /** Proposed new selling price in integer minor units */
  readonly proposedPrice: Money;
  /** Markdown reason */
  readonly reason: MarkdownReason;
  /** Free-text justification */
  readonly justification: string;
  /** Effective start date (ISO 8601) */
  readonly effectiveFrom: string;
  /** Effective end date (ISO 8601, optional for permanent markdowns) */
  readonly effectiveTo?: string;
  /** Actor requesting the markdown */
  readonly requestedBy: string;
  /** Evidence/reference supporting the markdown (e.g., competitor price link) */
  readonly evidenceRef?: string;
}

/** Standard markdown reasons */
export type MarkdownReason =
  | 'COMPETITOR_PRICE'    // Competitor price match
  | 'SLOW_MOVING'        // Slow-moving stock clearance
  | 'DAMAGED_PACKAGING'  // Cosmetic/packaging damage
  | 'MODEL_DISCONTINUED' // End-of-life clearance
  | 'BULK_DEAL'          // Volume/bundle negotiation
  | 'CUSTOMER_LOYALTY'   // Loyalty-based price
  | 'SEASONAL'           // Seasonal/festival pricing
  | 'MANUFACTURER_REBATE' // OEM-authorized price drop
  | 'OTHER';             // Requires justification

/** Margin impact calculation result */
export interface MarginImpact {
  /** Cost price of the item in integer minor units */
  readonly costPrice: Money;
  /** Original selling price */
  readonly originalPrice: Money;
  /** Proposed selling price */
  readonly proposedPrice: Money;
  /** Original margin in integer minor units */
  readonly originalMargin: Money;
  /** Proposed margin in integer minor units */
  readonly proposedMargin: Money;
  /** Original margin percentage (basis points, e.g., 1500 = 15%) */
  readonly originalMarginBps: number;
  /** Proposed margin percentage (basis points) */
  readonly proposedMarginBps: number;
  /** Margin reduction in integer minor units */
  readonly marginReduction: Money;
  /** Whether proposed price is below cost (negative margin) */
  readonly belowCost: boolean;
}

/** Approval decision */
export interface ApprovalDecision {
  /** Whether the markdown was approved */
  readonly approved: boolean;
  /** Approver identity */
  readonly approvedBy: string;
  /** Approval timestamp (ISO 8601) */
  readonly decidedAt: string;
  /** Approval notes/conditions */
  readonly notes?: string;
  /** Rejection reason (if not approved) */
  readonly rejectionReason?: string;
  /** Approved price (may differ from proposed if conditionally approved) */
  readonly approvedPrice?: Money;
}

/** Markdown approval request */
export interface MarkdownApprovalRequest {
  /** The markdown request ID to approve/reject */
  readonly markdownRequestId: string;
  /** Approval decision */
  readonly decision: ApprovalDecision;
}

// ─── Price Protection Port ───────────────────────────────────────────────────

/**
 * Provider-neutral interface for price protection and markdown operations.
 *
 * This port handles:
 * - Markdown requests with approval workflow
 * - Margin impact calculation (decision aid before approval)
 * - Effective period management
 * - Audit trail for all price adjustments
 */
export interface PriceProtectionPort {
  readonly providerType: 'price_protection';
  readonly requiredFeature: typeof PRICE_PROTECTION_FEATURE_ID;

  /**
   * Request a price markdown/adjustment.
   * Creates a pending approval record with calculated margin impact.
   * No price change occurs until explicitly approved.
   */
  requestMarkdown(
    context: TenantContextWire,
    request: MarkdownRequest,
  ): Promise<MarkdownRequestResult>;

  /**
   * Get approval decision for a pending markdown request.
   * Processes the approval/rejection and applies the price change if approved.
   * Creates an immutable audit event for the decision.
   */
  getApproval(
    context: TenantContextWire,
    request: MarkdownApprovalRequest,
  ): Promise<MarkdownApprovalResult>;

  /**
   * Calculate margin impact for a proposed price change.
   * Used as a decision aid BEFORE submitting a markdown request.
   * Does not create any records — pure calculation.
   */
  calculateMarginImpact(
    context: TenantContextWire,
    itemIdentifier: string,
    proposedPrice: Money,
  ): Promise<MarginImpact>;
}

// ─── Result Types ────────────────────────────────────────────────────────────

/** Result of a markdown request submission */
export type MarkdownRequestResult =
  | { readonly type: 'submitted'; readonly requestId: string; readonly marginImpact: MarginImpact }
  | { readonly type: 'rejected'; readonly reason: string };

/** Result of a markdown approval processing */
export type MarkdownApprovalResult =
  | { readonly type: 'approved'; readonly effectivePrice: Money; readonly effectiveFrom: string }
  | { readonly type: 'rejected'; readonly reason: string }
  | { readonly type: 'expired'; readonly reason: string };

// ─── Domain Persistence Types ────────────────────────────────────────────────

/**
 * Price protection record persisted in tenant-scoped DynamoDB.
 * Tracks the full lifecycle of a markdown request.
 */
export interface PriceProtectionRecord {
  readonly tenantId: string;
  readonly requestId: string;
  readonly itemIdentifier: string;
  readonly itemType: 'HANDSET' | 'ACCESSORY';
  readonly originalPrice: Money;
  readonly proposedPrice: Money;
  readonly approvedPrice?: Money;
  readonly reason: MarkdownReason;
  readonly justification: string;
  readonly effectiveFrom: string;
  readonly effectiveTo?: string;
  readonly requestedBy: string;
  readonly evidenceRef?: string;
  /** Calculated margin impact at time of request */
  readonly marginImpact: MarginImpact;
  /** Approval decision (once made) */
  readonly approval?: ApprovalDecision;
  /** Current status */
  readonly status: PriceProtectionStatus;
  readonly version: number;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** Price protection record lifecycle status */
export type PriceProtectionStatus =
  | 'PENDING_APPROVAL'
  | 'APPROVED'
  | 'REJECTED'
  | 'ACTIVE'        // Approved and within effective period
  | 'EXPIRED'       // Past effective period
  | 'REVOKED';      // Manually revoked before expiry
