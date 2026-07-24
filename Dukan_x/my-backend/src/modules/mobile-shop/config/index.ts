/**
 * Mobile Shop — Documented Configuration
 *
 * Centralized, typed, version-controlled configuration for the MobileShop domain.
 * Eliminates scattered production literals and provides environment-overridable defaults.
 *
 * Referenced by: Requirements 3.2, 6.7–6.9, 6.14–6.17, 6.20, 6.29–6.38, 7.2–7.3, 12.1–12.6; GR-4
 */

export { VALIDATION_CONFIG, type ValidationConfig } from './validation.config';
export { BOUNDS_CONFIG, type BoundsConfig } from './bounds.config';
export { RETRY_CONFIG, type RetryConfig } from './retry.config';
export { RETENTION_CONFIG, type RetentionConfig } from './retention.config';
export { TRANSACTION_FIT_CONFIG, type TransactionFitConfig } from './transaction-fit.config';
export { PAGINATION_CONFIG, type PaginationConfig } from './pagination.config';
export { OFFLINE_ELIGIBILITY_CONFIG, type OfflineEligibilityConfig } from './offline-eligibility.config';
export { FEATURE_POLICY_CONFIG, type FeaturePolicyConfig } from './feature-policy.config';
export { MODEL_VERSION_CONFIG, type ModelVersionConfig } from './model-version.config';
export { ERROR_CODES, type ErrorCode, type DeterministicOutcome } from './error-codes.config';
export { CORRELATION_CONFIG, type CorrelationConfig } from './correlation.config';
export { RECOVERY_CONFIG, type RecoveryConfig } from './recovery.config';
