/**
 * MobileShop Provider Ports — Barrel Export
 *
 * Provider-neutral interfaces for external capabilities:
 * finance/EMI, SIM/recharge, OCR intake, bundles, price protection,
 * and e-Way bill compliance.
 *
 * These are INTERFACES ONLY — no provider implementation is selected yet.
 * Each port requires a feature-policy gate check before execution.
 *
 * Requirements: 4.8, 10.1–10.12
 */

// Base Provider Port — generic typed interface and shared utilities
export {
  deriveProviderRequestId,
  checkFeatureGate,
  validateRetryConsistency,
  type ProviderPort,
  type ProviderRequestId,
  type ProviderRequestContext,
  type ProviderOutcome,
  type ProviderSuccess,
  type ProviderPending,
  type ProviderAmbiguous,
  type ProviderRejected,
  type ProviderUnavailable,
  type FeatureGateResult,
} from './provider-port';

// Finance/EMI Provider Port
export {
  checkFinanceGate,
  FINANCE_FEATURE_ID,
  type FinanceProviderPort,
  type FinancePlanRequest,
  type FinancePlanResponse,
  type FinancePlanStatus,
  type FinanceCancellationRequest,
  type FinanceCancellationResponse,
  type FinancePlanRecord,
  type FinancePlanDomainStatus,
} from './finance-port';

// SIM/Recharge Provider Port
export {
  checkRechargeGate,
  SIM_RECHARGE_FEATURE_ID,
  type RechargeProviderPort,
  type RechargeRequest,
  type RechargeResponse,
  type RechargeStatus,
  type RechargeRecord,
  type RechargeDomainStatus,
} from './recharge-port';

// OCR Intake Provider Port
export {
  checkOcrGate,
  OCR_FEATURE_ID,
  type OcrProviderPort,
  type OcrSubmitRequest,
  type OcrResult,
  type OcrResultStatus,
  type OcrExtractedFields,
  type OcrFocusType,
  type OcrSubmissionRecord,
  type OcrValidationStatus,
  type OcrDomainStatus,
} from './ocr-port';

// Bundle/Accessory Service
export {
  checkBundleGate,
  BUNDLES_FEATURE_ID,
  type BundleService,
  type BundleDefinition,
  type BundleLine,
  type HandsetLine,
  type AccessoryLine,
  type BundleLineType,
  type BundleAccountingSeparation,
  type StockEntry,
  type TaxEntry,
  type AccountingEntry,
  type BundleTotals,
  type BundleValidationResult,
  type BundleValidationError,
  type BundleRecord,
  type BundleStatus,
} from './bundle-port';

// Price Protection Port
export {
  checkPriceProtectionGate,
  PRICE_PROTECTION_FEATURE_ID,
  type PriceProtectionPort,
  type MarkdownRequest,
  type MarkdownReason,
  type MarginImpact,
  type ApprovalDecision,
  type MarkdownApprovalRequest,
  type MarkdownRequestResult,
  type MarkdownApprovalResult,
  type PriceProtectionRecord,
  type PriceProtectionStatus,
} from './price-protection-port';

// e-Way Bill Compliance Port
export {
  checkComplianceGate,
  E_WAY_BILL_FEATURE_ID,
  type CompliancePort,
  type EwayBillRequest,
  type EwayBillResponse,
  type EwayBillStatus,
  type EwayCancellationRequest,
  type EwayCancellationResponse,
  type EwayCancellationReason,
  type ComplianceVerificationRequest,
  type ComplianceVerificationResult,
  type EwayPartyDetails,
  type TransportDetails,
  type TransportMode,
  type VehicleType,
  type EwayLineItem,
  type EwayDocumentType,
  type SupplyType,
  type EwayBillRecord,
  type EwayBillDomainStatus,
} from './compliance-port';
