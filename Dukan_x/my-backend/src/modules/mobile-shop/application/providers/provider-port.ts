/**
 * Base Provider Port — Provider-Neutral Interface Foundation
 *
 * Defines the generic typed provider port interface, request context with
 * Provider_Request_Id generation and reuse, and feature-policy gating.
 *
 * Key invariants:
 * - Provider_Request_Id is derived ONCE from operationId + provider type
 * - On retry, the SAME Provider_Request_Id is reused (never regenerated)
 * - Feature-policy gate check happens BEFORE any provider call
 * - Ambiguous outcomes trigger status check before resubmission
 *
 * Requirements: 10.6–10.9; GR-4.3
 */

import type { TenantContextWire } from '../../schemas/common.schema';
import type { DeterministicOutcome } from '../error-mapper';
import type { OutcomeCategory } from '../../config/error-codes.config';
import { FEATURE_POLICY_CONFIG } from '../../config/feature-policy.config';

// ─── Provider Request Identity ───────────────────────────────────────────────

/**
 * A stable external-provider request identity.
 * Derived once per logical provider submission and REUSED on retry.
 */
export interface ProviderRequestId {
  /** The generated provider request identifier */
  readonly value: string;
  /** The operation that created this request ID */
  readonly operationId: string;
  /** The provider type this ID was issued for */
  readonly providerType: string;
  /** ISO 8601 timestamp when the ID was first issued */
  readonly issuedAt: string;
}

/**
 * Derives a Provider_Request_Id from operationId and provider type.
 * The same inputs ALWAYS produce the same output — deterministic derivation.
 *
 * Format: `PRQ-{providerType}-{operationId}`
 */
export function deriveProviderRequestId(
  operationId: string,
  providerType: string,
): ProviderRequestId {
  return {
    value: `PRQ-${providerType}-${operationId}`,
    operationId,
    providerType,
    issuedAt: new Date().toISOString(),
  };
}

// ─── Provider Request Context ────────────────────────────────────────────────

/**
 * Context carried with every provider request.
 * Includes tenant, correlation, the derived Provider_Request_Id, and retry metadata.
 */
export interface ProviderRequestContext {
  /** Authenticated tenant context */
  readonly tenant: TenantContextWire;
  /** Derived Provider_Request_Id (reused on retry) */
  readonly providerRequestId: ProviderRequestId;
  /** Operation_Id from the domain command */
  readonly operationId: string;
  /** Mutation_Fingerprint for idempotency */
  readonly mutationFingerprint: string;
  /** Correlation ID for distributed tracing */
  readonly correlationId: string;
  /** Current retry attempt (0 = first attempt) */
  readonly retryAttempt: number;
  /** Whether this is a retry of a previously submitted request */
  readonly isRetry: boolean;
}

// ─── Provider Outcome ────────────────────────────────────────────────────────

/** Discriminated union for provider operation results */
export type ProviderOutcome<TResponse> =
  | ProviderSuccess<TResponse>
  | ProviderPending
  | ProviderAmbiguous
  | ProviderRejected
  | ProviderUnavailable;

/** Provider confirmed the operation succeeded */
export interface ProviderSuccess<TResponse> {
  readonly type: 'success';
  readonly response: TResponse;
  readonly providerRequestId: string;
  readonly providerReference?: string;
}

/** Provider accepted but final status is pending */
export interface ProviderPending {
  readonly type: 'pending';
  readonly providerRequestId: string;
  readonly providerReference?: string;
  readonly statusCheckAfter?: string; // ISO 8601
}

/** Provider returned an ambiguous or unavailable outcome */
export interface ProviderAmbiguous {
  readonly type: 'ambiguous';
  readonly providerRequestId: string;
  readonly reason: string;
}

/** Provider explicitly rejected the request */
export interface ProviderRejected {
  readonly type: 'rejected';
  readonly providerRequestId: string;
  readonly reason: string;
  readonly code?: string;
}

/** Provider is unavailable (network, timeout, maintenance) */
export interface ProviderUnavailable {
  readonly type: 'unavailable';
  readonly providerRequestId: string;
  readonly reason: string;
  readonly retryable: boolean;
}

// ─── Generic Provider Port Interface ─────────────────────────────────────────

/**
 * Generic typed provider port interface.
 * All external provider interactions implement this contract.
 *
 * @template TRequest - The provider-specific request payload
 * @template TResponse - The provider-specific success response
 */
export interface ProviderPort<TRequest, TResponse> {
  /** Unique provider type identifier (e.g., 'finance', 'recharge', 'ocr') */
  readonly providerType: string;

  /** Required feature policy ID that must be enabled */
  readonly requiredFeature: string;

  /**
   * Execute the provider operation.
   * Feature-policy gate is checked before invocation.
   * Provider_Request_Id must be consistent across retries.
   */
  execute(
    context: ProviderRequestContext,
    request: TRequest,
  ): Promise<ProviderOutcome<TResponse>>;

  /**
   * Check the status of a previously submitted request.
   * Used for ambiguous-outcome reconciliation before resubmission.
   */
  checkStatus(
    context: ProviderRequestContext,
  ): Promise<ProviderOutcome<TResponse>>;
}

// ─── Feature Policy Gate ─────────────────────────────────────────────────────

/**
 * Result of a feature-policy gate check.
 */
export type FeatureGateResult =
  | { readonly allowed: true }
  | { readonly allowed: false; readonly outcome: DeterministicOutcome };

/**
 * Checks whether a feature is enabled for the tenant before provider invocation.
 * Returns a deterministic outcome if the feature is disabled or the tenant
 * lacks the required capability.
 *
 * @param featureId - The feature policy ID to check
 * @param tenantCapabilities - The tenant's active capabilities
 * @param correlationId - For error tracing
 */
export function checkFeatureGate(
  featureId: string,
  tenantCapabilities: readonly string[],
  correlationId: string,
): FeatureGateResult {
  const feature = FEATURE_POLICY_CONFIG.features.find(
    (f) => f.featureId === featureId,
  );

  if (!feature) {
    return {
      allowed: false,
      outcome: {
        code: 'FEATURE_NOT_FOUND',
        category: 'authorization' as OutcomeCategory,
        retryable: false,
        statePreserved: true,
        fields: ['featureId'],
        httpStatus: 403,
        correlationId,
      },
    };
  }

  // Check required capability
  if (feature.requiredCapability && !tenantCapabilities.includes(feature.requiredCapability)) {
    return {
      allowed: false,
      outcome: {
        code: 'FEATURE_DISABLED',
        category: 'authorization' as OutcomeCategory,
        retryable: false,
        statePreserved: true,
        fields: ['featureId'],
        httpStatus: 403,
        correlationId,
      },
    };
  }

  return { allowed: true };
}

// ─── Retry Safety Validation ─────────────────────────────────────────────────

/**
 * Validates that a retry uses the same Provider_Request_Id and semantically
 * identical payload. Returns a mismatch outcome if the payload differs.
 *
 * Requirement 10.8: If retry would reuse a Provider_Request_Id with a different
 * payload, return idempotency-mismatch and make no external submission.
 */
export function validateRetryConsistency(
  originalFingerprint: string,
  retryFingerprint: string,
  correlationId: string,
): FeatureGateResult {
  if (originalFingerprint !== retryFingerprint) {
    return {
      allowed: false,
      outcome: {
        code: 'PROVIDER_IDEMPOTENCY_MISMATCH',
        category: 'conflict' as OutcomeCategory,
        retryable: false,
        statePreserved: true,
        fields: ['providerRequestId', 'mutationFingerprint'],
        httpStatus: 409,
        correlationId,
      },
    };
  }

  return { allowed: true };
}
