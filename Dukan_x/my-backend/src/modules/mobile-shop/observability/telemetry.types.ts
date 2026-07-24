/**
 * DynamoDB Telemetry Type Definitions
 *
 * Structured, secret-free observability types for every DynamoDB operation
 * in the MobileShop domain. All fields are primitive types (string, number,
 * boolean) — NO objects, no PII, no secrets.
 *
 * Requirements: 6.23, 6.37–6.38, 13.6
 */

import type { AccessPatternId } from '../persistence/access-patterns';

// ─── DynamoDB Operation Types ────────────────────────────────────────────────

/** Supported DynamoDB operations */
export type DynamoDbOperationType =
  | 'Query'
  | 'Get'
  | 'Put'
  | 'Update'
  | 'Delete'
  | 'TransactWrite'
  | 'TransactGet';

// ─── Telemetry Event ─────────────────────────────────────────────────────────

/**
 * Structured telemetry event emitted for every DynamoDB operation.
 *
 * Critical rule: This interface MUST NOT contain:
 * - DynamoDB item content (no record data)
 * - User names, emails, phone numbers
 * - IMEI numbers (PII in some jurisdictions)
 * - Authentication tokens
 * - Partition key values that embed secrets
 * - Request/response bodies
 *
 * Contains ONLY operational metadata for dashboards and debugging.
 */
export interface DynamoDbTelemetryEvent {
  /** Fixed event type discriminator for CloudWatch log parsing */
  readonly eventType: 'DYNAMODB_OPERATION';
  /** ISO 8601 timestamp of the event */
  readonly timestamp: string;
  /** Correlation ID from TenantContext for request tracing */
  readonly correlationId: string;
  /** Tenant ID — partition identifier, NOT a secret */
  readonly tenantId: string;
  /** Operation ID for idempotent operation tracing */
  readonly operationId?: string;
  /** Domain entity type being operated on */
  readonly entityType?: string;
  /** Access pattern ID (AP-01 through AP-15) */
  readonly accessPatternId?: AccessPatternId;
  /** DynamoDB table name */
  readonly tableName: string;
  /** DynamoDB index name (GSI1, GSI2, or undefined for base table) */
  readonly indexName?: string;
  /** DynamoDB operation type */
  readonly operation: DynamoDbOperationType;
  /** Read consistency mode */
  readonly consistency: 'strong' | 'eventual';
  /** Number of items returned or written */
  readonly itemCount?: number;
  /** Consumed read/write capacity units */
  readonly consumedCapacityUnits?: number;
  /** Operation duration in milliseconds */
  readonly latencyMs: number;
  /** Conditional write outcome */
  readonly conditionalResult: 'success' | 'condition_failed' | 'not_applicable';
  /** Transaction outcome */
  readonly transactionResult: 'success' | 'cancelled' | 'not_applicable';
  /** Number of retries attempted */
  readonly retryCount: number;
  /** Total backoff time in milliseconds */
  readonly backoffMs: number;
  /** Throttling cause */
  readonly throttlingReason: 'table' | 'index' | 'none';
  /** Which table or index resource was throttled */
  readonly throttlingResource?: string;
  /** Reconciliation lifecycle outcome */
  readonly reconciliationOutcome: 'initiated' | 'step_completed' | 'finalized' | 'not_applicable';
  /** HTTP status returned to the client */
  readonly httpStatus: number;
}

// ─── Telemetry Input Parameters ──────────────────────────────────────────────

/**
 * Parameters for emitting DynamoDB telemetry.
 * Callers provide operation metadata; the emitter constructs the full event.
 */
export interface EmitDynamoDbTelemetryParams {
  /** Correlation ID from TenantContext */
  readonly correlationId: string;
  /** Tenant ID — partition identifier */
  readonly tenantId: string;
  /** Operation ID for idempotent operation tracing */
  readonly operationId?: string;
  /** Domain entity type */
  readonly entityType?: string;
  /** Access pattern ID */
  readonly accessPatternId?: AccessPatternId;
  /** DynamoDB table name */
  readonly tableName: string;
  /** DynamoDB index name */
  readonly indexName?: string;
  /** DynamoDB operation type */
  readonly operation: DynamoDbOperationType;
  /** Read consistency mode */
  readonly consistency: 'strong' | 'eventual';
  /** Number of items returned or written */
  readonly itemCount?: number;
  /** Consumed read/write capacity units (from ReturnConsumedCapacity) */
  readonly consumedCapacityUnits?: number;
  /** Operation duration in milliseconds */
  readonly latencyMs: number;
  /** Conditional write outcome */
  readonly conditionalResult?: 'success' | 'condition_failed' | 'not_applicable';
  /** Transaction outcome */
  readonly transactionResult?: 'success' | 'cancelled' | 'not_applicable';
  /** Number of retries attempted */
  readonly retryCount?: number;
  /** Total backoff time in milliseconds */
  readonly backoffMs?: number;
  /** Throttling cause */
  readonly throttlingReason?: 'table' | 'index' | 'none';
  /** Which table or index resource was throttled */
  readonly throttlingResource?: string;
  /** Reconciliation lifecycle outcome */
  readonly reconciliationOutcome?: 'initiated' | 'step_completed' | 'finalized' | 'not_applicable';
  /** HTTP status returned to the client */
  readonly httpStatus: number;
}
