/**
 * Correlation ID Configuration
 *
 * Defines format, propagation rules, and constraints for correlation IDs
 * used in observability, tracing, and audit across the MobileShop system.
 *
 * Requirements: 6.23 (observability), 12.3 (correlation propagation)
 */

export interface CorrelationConfig {
  /** Header name used to propagate correlation ID */
  readonly headerName: string;
  /** Prefix for generated correlation IDs */
  readonly prefix: string;
  /** Maximum length of a correlation ID */
  readonly maxLength: number;
  /** Regex pattern for validation */
  readonly pattern: string;
  /** Whether to generate a new ID if not provided by client */
  readonly generateIfMissing: boolean;
  /** Fields included in telemetry emission */
  readonly telemetryFields: readonly string[];
}

export const CORRELATION_CONFIG: CorrelationConfig = {
  headerName: 'X-Correlation-Id',
  prefix: 'ms-',
  maxLength: 64,
  pattern: '^[a-zA-Z0-9\\-_]{1,64}$',
  generateIfMissing: true,

  telemetryFields: [
    'correlationId',
    'tenantId',
    'operationId',
    'entityType',
    'accessPatternId',
    'tableOrIndex',
    'operationType',
    'consistencyMode',
    'itemCount',
    'consumedCapacity',
    'latencyMs',
    'conditionalResult',
    'transactionResult',
    'retryCount',
    'backoffMs',
    'throttlingReason',
    'throttlingResource',
    'reconciliationOutcome',
  ],
} as const;
