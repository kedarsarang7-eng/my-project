/**
 * OCR Provider Port — OCR Intake Provider-Neutral Interface
 *
 * Defines the provider-neutral contract for optical character recognition
 * used during device intake (model/IMEI extraction from documents).
 *
 * Key invariants:
 * - Feature-policy gate (OCR_INTAKE) checked before execution
 * - When OCR is disabled by product policy, all OCR entry points are removed
 * - Extracted data is VALIDATED before acceptance (never trusted raw)
 * - Provider_Request_Id for retry safety
 *
 * Requirements: 10.1–10.2, 10.6–10.9
 */

import type { TenantContextWire } from '../../schemas/common.schema';
import type {
  ProviderRequestContext,
  ProviderOutcome,
  FeatureGateResult,
} from './provider-port';
import { checkFeatureGate } from './provider-port';

// ─── Feature Gate ────────────────────────────────────────────────────────────

/** Feature policy ID required for OCR operations */
export const OCR_FEATURE_ID = 'OCR_INTAKE' as const;

/**
 * Checks the OCR_INTAKE feature gate before any OCR provider call.
 * When product policy disables OCR, this returns `allowed: false`.
 */
export function checkOcrGate(
  tenantCapabilities: readonly string[],
  correlationId: string,
): FeatureGateResult {
  return checkFeatureGate(OCR_FEATURE_ID, tenantCapabilities, correlationId);
}

// ─── OCR Types ───────────────────────────────────────────────────────────────

/** OCR image submission request */
export interface OcrSubmitRequest {
  /** Reference to the uploaded image in approved storage */
  readonly imageRef: string;
  /** Content type of the uploaded image */
  readonly contentType: string;
  /** SHA-256 digest of the image for integrity */
  readonly imageDigest: string;
  /** Focus type — what to extract from this image */
  readonly focusType: OcrFocusType;
  /** Optional hint for expected device model */
  readonly modelHint?: string;
}

/** What the OCR should focus on extracting */
export type OcrFocusType =
  | 'IMEI_LABEL'      // Extract IMEI from device label/sticker
  | 'DEVICE_BOX'      // Extract model + IMEI from box
  | 'INVOICE_SCAN'    // Extract details from purchase invoice
  | 'WARRANTY_CARD';  // Extract warranty details

/** OCR extraction result from provider */
export interface OcrResult {
  /** Provider-assigned result identifier */
  readonly resultId: string;
  /** Processing status */
  readonly status: OcrResultStatus;
  /** Extracted fields (raw, unvalidated) */
  readonly extractedFields: OcrExtractedFields;
  /** Confidence score (0.0 - 1.0) */
  readonly confidence: number;
  /** Processing duration in milliseconds */
  readonly processingMs?: number;
}

/** OCR processing status */
export type OcrResultStatus =
  | 'PROCESSING'
  | 'COMPLETED'
  | 'PARTIAL'    // Some fields extracted, others failed
  | 'FAILED';

/** Raw extracted fields from OCR (must be validated before use) */
export interface OcrExtractedFields {
  /** Raw IMEI string (unvalidated — must pass Luhn/normalization) */
  readonly rawImei?: string;
  /** Raw device model string */
  readonly rawModel?: string;
  /** Raw serial number */
  readonly rawSerial?: string;
  /** Raw brand */
  readonly rawBrand?: string;
  /** Additional raw text extracted */
  readonly additionalText?: string;
}

// ─── OCR Provider Port ───────────────────────────────────────────────────────

/**
 * Provider-neutral interface for OCR document intake.
 *
 * Implementations will be provided per OCR service once selected.
 * This port defines the contract only.
 *
 * IMPORTANT: Extracted data from OCR is NEVER accepted directly.
 * It must pass through the same validation pipeline (IMEI normalization,
 * Luhn, 15-digit check) before domain acceptance.
 */
export interface OcrProviderPort {
  readonly providerType: 'ocr';
  readonly requiredFeature: typeof OCR_FEATURE_ID;

  /**
   * Submit an image for OCR processing.
   * Provider_Request_Id is derived before submission for retry safety.
   * Online connectivity is required (feature.onlineRequired = true).
   */
  submitImage(
    context: ProviderRequestContext,
    request: OcrSubmitRequest,
  ): Promise<ProviderOutcome<OcrResult>>;

  /**
   * Get the result of a previously submitted OCR job.
   * Used for async OCR processing and ambiguous-outcome reconciliation.
   */
  getResult(
    context: ProviderRequestContext,
    resultId: string,
  ): Promise<ProviderOutcome<OcrResult>>;
}

// ─── Domain Persistence Types ────────────────────────────────────────────────

/**
 * OCR submission record persisted in tenant-scoped DynamoDB.
 * Tracks the OCR job lifecycle from submission to validated acceptance.
 */
export interface OcrSubmissionRecord {
  readonly tenantId: string;
  readonly submissionId: string;
  /** Image reference in approved storage */
  readonly imageRef: string;
  readonly imageDigest: string;
  readonly focusType: OcrFocusType;
  /** Provider_Request_Id used for the submission */
  readonly providerRequestId: string;
  /** Provider result ID (once received) */
  readonly providerResultId?: string;
  /** Raw extracted fields (unvalidated) */
  readonly rawExtraction?: OcrExtractedFields;
  /** Whether extraction passed domain validation */
  readonly validationStatus: OcrValidationStatus;
  /** Validated IMEI (only if it passed normalization + Luhn) */
  readonly validatedImei?: string;
  /** Validated model (only if it matched catalogue) */
  readonly validatedModel?: string;
  /** Current domain status */
  readonly status: OcrDomainStatus;
  readonly version: number;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** OCR extraction validation status */
export type OcrValidationStatus =
  | 'PENDING'
  | 'PASSED'
  | 'PARTIAL_PASS'   // Some fields valid, others not
  | 'FAILED';

/** Domain-level OCR submission status */
export type OcrDomainStatus =
  | 'SUBMITTED'
  | 'PROCESSING'
  | 'EXTRACTED'
  | 'VALIDATED'
  | 'REJECTED'
  | 'RECONCILING';
