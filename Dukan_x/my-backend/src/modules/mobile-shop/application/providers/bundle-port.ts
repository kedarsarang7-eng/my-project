/**
 * Bundle Service — Handset/Accessory Accounting Separation
 *
 * Separates stock, tax, and accounting lines for handset vs accessory items.
 * Preserves the handset-accessory relationship for bundle reporting while
 * maintaining independent inventory and tax treatment per line.
 *
 * Key invariants:
 * - Handset and accessory are SEPARATE stock lines (never merged)
 * - Tax is calculated INDEPENDENTLY per line type
 * - Accounting entries are SEPARATE per line type
 * - Handset-accessory relationship is preserved for reporting
 * - Configured discounts/loyalty effects apply at bundle level
 * - Feature-policy gate (BUNDLES) checked when applicable
 *
 * Requirements: 4.8, 10.10
 */

import type { Money } from '../../schemas/common.schema';
import type { FeatureGateResult } from './provider-port';
import { checkFeatureGate } from './provider-port';

// ─── Feature Gate ────────────────────────────────────────────────────────────

/** Feature policy ID for bundle operations */
export const BUNDLES_FEATURE_ID = 'BUNDLES' as const;

/**
 * Checks the BUNDLES feature gate.
 */
export function checkBundleGate(
  tenantCapabilities: readonly string[],
  correlationId: string,
): FeatureGateResult {
  return checkFeatureGate(BUNDLES_FEATURE_ID, tenantCapabilities, correlationId);
}

// ─── Bundle Line Types ───────────────────────────────────────────────────────

/** The type of item in a bundle */
export type BundleLineType = 'HANDSET' | 'ACCESSORY';

/** A single line item within a bundle sale */
export interface BundleLine {
  /** Unique line identifier within the invoice */
  readonly lineId: string;
  /** Line type determines stock/tax/accounting treatment */
  readonly lineType: BundleLineType;
  /** Item identifier (IMEI for handset, SKU for accessory) */
  readonly itemIdentifier: string;
  /** Item description */
  readonly description: string;
  /** Quantity (always 1 for handset/IMEI-tracked items) */
  readonly quantity: number;
  /** Unit price in integer minor units */
  readonly unitPrice: Money;
  /** Applicable tax rate (basis points, e.g., 1800 = 18%) */
  readonly taxRateBps: number;
  /** Calculated tax amount in integer minor units */
  readonly taxAmount: Money;
  /** Line total including tax */
  readonly lineTotal: Money;
  /** HSN/SAC code for tax classification */
  readonly hsnSacCode?: string;
}

/** A handset line with IMEI tracking */
export interface HandsetLine extends BundleLine {
  readonly lineType: 'HANDSET';
  /** Normalized IMEI (15-digit Luhn-valid) */
  readonly imei: string;
  /** Brand/manufacturer */
  readonly brand?: string;
  /** Device model */
  readonly model?: string;
}

/** An accessory line */
export interface AccessoryLine extends BundleLine {
  readonly lineType: 'ACCESSORY';
  /** SKU or internal catalogue reference */
  readonly sku: string;
  /** Category of accessory (case, charger, screen protector, etc.) */
  readonly accessoryCategory?: string;
}

// ─── Bundle Definition ───────────────────────────────────────────────────────

/** A bundle groups one handset with one or more accessories */
export interface BundleDefinition {
  /** Unique bundle identifier within the invoice */
  readonly bundleId: string;
  /** The primary handset line */
  readonly handsetLine: HandsetLine;
  /** Associated accessory lines */
  readonly accessoryLines: readonly AccessoryLine[];
  /** Bundle-level discount (if any) in integer minor units */
  readonly bundleDiscount?: Money;
  /** Loyalty/reward points applied */
  readonly loyaltyPointsApplied?: number;
  /** Bundle-level promotion/offer reference */
  readonly promotionRef?: string;
}

// ─── Bundle Accounting Separation ────────────────────────────────────────────

/** Separated accounting view for a bundle */
export interface BundleAccountingSeparation {
  /** The bundle this separation applies to */
  readonly bundleId: string;
  /** Stock lines — separate inventory entries per item */
  readonly stockLines: readonly StockEntry[];
  /** Tax lines — separate tax per item type */
  readonly taxLines: readonly TaxEntry[];
  /** Accounting lines — separate journal entries per type */
  readonly accountingLines: readonly AccountingEntry[];
  /** Bundle totals for validation */
  readonly totals: BundleTotals;
}

/** Stock/inventory entry — one per physical item */
export interface StockEntry {
  readonly lineId: string;
  readonly lineType: BundleLineType;
  readonly itemIdentifier: string;
  readonly quantity: number;
  readonly costPrice: Money;
  readonly salePrice: Money;
  /** For handsets, links to IMEI lifecycle transition */
  readonly imeiRef?: string;
}

/** Tax entry — separate per item type/HSN code */
export interface TaxEntry {
  readonly lineId: string;
  readonly lineType: BundleLineType;
  readonly hsnSacCode?: string;
  readonly taxableAmount: Money;
  readonly taxRateBps: number;
  readonly cgst: Money;
  readonly sgst: Money;
  readonly igst?: Money;
}

/** Accounting journal entry — separate per item type */
export interface AccountingEntry {
  readonly lineId: string;
  readonly lineType: BundleLineType;
  readonly accountCode: string;
  readonly debitAmount: Money;
  readonly creditAmount: Money;
  readonly narration: string;
}

/** Bundle-level totals for validation/reporting */
export interface BundleTotals {
  readonly handsetSubtotal: Money;
  readonly accessorySubtotal: Money;
  readonly totalTax: Money;
  readonly bundleDiscount: Money;
  readonly grandTotal: Money;
}

// ─── Bundle Service Interface ────────────────────────────────────────────────

/**
 * Service for managing bundle operations with separated accounting.
 *
 * This is NOT an external provider port — it's a domain service that
 * handles the internal logic of separating stock/tax/accounting lines.
 */
export interface BundleService {
  /**
   * Separates a bundle into independent stock, tax, and accounting lines.
   * Preserves the handset-accessory relationship for reporting.
   *
   * @param bundle - The bundle definition with handset and accessory lines
   * @returns Separated accounting view with independent lines per type
   */
  separateAccountingLines(bundle: BundleDefinition): BundleAccountingSeparation;

  /**
   * Validates bundle integrity:
   * - Handset quantity is always 1
   * - Tax amounts match rate × taxable amount
   * - Line totals sum correctly
   * - Bundle discount does not exceed line totals
   */
  validateBundle(bundle: BundleDefinition): BundleValidationResult;

  /**
   * Calculates bundle totals from individual lines.
   * Applies bundle-level discount proportionally or as configured.
   */
  calculateTotals(bundle: BundleDefinition): BundleTotals;
}

/** Bundle validation result */
export type BundleValidationResult =
  | { readonly valid: true }
  | { readonly valid: false; readonly errors: readonly BundleValidationError[] };

/** Individual bundle validation error */
export interface BundleValidationError {
  readonly field: string;
  readonly code: string;
  readonly message: string;
}

// ─── Domain Persistence Types ────────────────────────────────────────────────

/**
 * Bundle record persisted in tenant-scoped DynamoDB.
 * Preserves the handset-accessory relationship for reporting.
 */
export interface BundleRecord {
  readonly tenantId: string;
  readonly bundleId: string;
  readonly invoiceId: string;
  /** The primary handset IMEI */
  readonly handsetImei: string;
  /** Accessory SKUs included in this bundle */
  readonly accessorySkus: readonly string[];
  /** Bundle-level discount applied */
  readonly bundleDiscount?: Money;
  /** Loyalty points applied */
  readonly loyaltyPointsApplied?: number;
  /** Promotion/offer reference */
  readonly promotionRef?: string;
  /** Status of the bundle */
  readonly status: BundleStatus;
  readonly version: number;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** Bundle lifecycle status */
export type BundleStatus =
  | 'ACTIVE'
  | 'PARTIALLY_RETURNED'
  | 'FULLY_RETURNED'
  | 'CANCELLED';
