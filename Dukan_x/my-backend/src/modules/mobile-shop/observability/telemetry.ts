/**
 * Structured DynamoDB Telemetry Emitter
 *
 * Emits secret-free structured CloudWatch log lines for every DynamoDB
 * operation. Uses `console.log(JSON.stringify(fields))` so CloudWatch
 * can parse and filter JSON fields for dashboards and alarms.
 *
 * Critical rule: This module MUST NOT emit:
 * - DynamoDB item content (no record data)
 * - User names, emails, phone numbers
 * - IMEI numbers (PII in some jurisdictions)
 * - Authentication tokens
 * - Partition key values that embed secrets
 * - Request/response bodies
 *
 * Requirements: 6.23, 6.37–6.38, 13.6
 */

import type {
  DynamoDbTelemetryEvent,
  EmitDynamoDbTelemetryParams,
} from './telemetry.types';

// ─── Telemetry Emitter ───────────────────────────────────────────────────────

/**
 * Emits a structured, secret-free DynamoDB telemetry event to CloudWatch.
 *
 * The output is a single-line JSON log entry containing only operational
 * metadata. CloudWatch Logs Insights and Metric Filters can query these
 * fields for dashboards and alarms covering:
 * - Throttles by table/index
 * - Consumed capacity
 * - Errors and conditional failures
 * - p95 latency
 * - Transaction cancellation causes
 * - Retry counts and backoff
 * - Reconciliation age/depth
 * - Idempotency hits/mismatches
 *
 * @param params - Operation metadata to emit
 */
export function emitDynamoDbTelemetry(params: EmitDynamoDbTelemetryParams): void {
  const event: DynamoDbTelemetryEvent = {
    eventType: 'DYNAMODB_OPERATION',
    timestamp: new Date().toISOString(),
    correlationId: params.correlationId,
    tenantId: params.tenantId,
    operationId: params.operationId,
    entityType: params.entityType,
    accessPatternId: params.accessPatternId,
    tableName: params.tableName,
    indexName: params.indexName,
    operation: params.operation,
    consistency: params.consistency,
    itemCount: params.itemCount,
    consumedCapacityUnits: params.consumedCapacityUnits,
    latencyMs: params.latencyMs,
    conditionalResult: params.conditionalResult ?? 'not_applicable',
    transactionResult: params.transactionResult ?? 'not_applicable',
    retryCount: params.retryCount ?? 0,
    backoffMs: params.backoffMs ?? 0,
    throttlingReason: params.throttlingReason ?? 'none',
    throttlingResource: params.throttlingResource,
    reconciliationOutcome: params.reconciliationOutcome ?? 'not_applicable',
    httpStatus: params.httpStatus,
  };

  // Emit as single-line JSON for CloudWatch structured log parsing
  // eslint-disable-next-line no-console
  console.log(JSON.stringify(event));
}
