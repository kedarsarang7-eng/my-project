/**
 * MobileShop Observability — Barrel Export
 *
 * Secret-free structured telemetry for DynamoDB operations.
 * Dashboards and alarms consume these fields via CloudWatch
 * Logs Insights and Metric Filters.
 *
 * Requirements: 6.23, 6.37–6.38, 13.6
 */

// Telemetry emitter
export { emitDynamoDbTelemetry } from './telemetry';

// Types
export type {
  DynamoDbTelemetryEvent,
  DynamoDbOperationType,
  EmitDynamoDbTelemetryParams,
} from './telemetry.types';
