// ============================================================================
// CloudWatch Structured Logger Middleware
// ============================================================================
// Emits structured JSON logs and CloudWatch metrics for every API request.
// Logs include: client_id (tenant_id), user_id, path, method, status,
// latency, and correlation_id for full traceability.
//
// Wired into authorizedHandler — automatically runs for every request.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { CloudWatchClient, PutMetricDataCommand, StandardUnit } from '@aws-sdk/client-cloudwatch';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

const cloudwatchClient = new CloudWatchClient(configureAwsClient({ region: config.aws.region }));

// ── Types ───────────────────────────────────────────────────────────────────

export interface RequestLogEntry {
    client_id: string;
    user_id: string;
    path: string;
    method: string;
    status_code: number;
    latency_ms: number;
    correlation_id: string;
    user_agent?: string;
    source_ip?: string;
    role?: string;
    business_type?: string;
}

// ── Log Request ─────────────────────────────────────────────────────────────

/**
 * Log a structured API request entry.
 * Emits both a CloudWatch log (via structured console output picked up by
 * Lambda → CloudWatch Logs) and a custom metric for monitoring.
 */
export async function logRequest(entry: RequestLogEntry): Promise<void> {
    // Structured log (picked up by CloudWatch Logs Insights automatically)
    logger.info('API_REQUEST', {
        client_id: entry.client_id,
        user_id: entry.user_id,
        path: entry.path,
        method: entry.method,
        status_code: entry.status_code,
        latency_ms: entry.latency_ms,
        correlation_id: entry.correlation_id,
        user_agent: entry.user_agent,
        source_ip: entry.source_ip,
        role: entry.role,
        business_type: entry.business_type,
    });

    // Emit CloudWatch custom metric (async, non-blocking)
    emitRequestMetric(entry).catch((err) => {
        logger.warn('Failed to emit request metric', { error: (err as Error).message });
    });
}

// ── Log Auth Failure ────────────────────────────────────────────────────────

/**
 * Log an authentication failure event.
 */
export function logAuthFailure(
    path: string,
    method: string,
    sourceIp: string | undefined,
    reason: string,
    correlationId: string,
): void {
    logger.warn('AUTH_FAILURE', {
        path,
        method,
        source_ip: sourceIp,
        reason,
        correlation_id: correlationId,
    });

    // Emit auth failure metric (fire-and-forget)
    emitAuthFailureMetric(sourceIp).catch(() => { /* non-critical */ });
}

// ── Log Payment Request ─────────────────────────────────────────────────────

/**
 * Log a payment request event with tenant context.
 */
export function logPaymentRequest(
    clientId: string,
    gatewayType: string,
    amountCents: number,
    correlationId: string,
): void {
    logger.info('PAYMENT_REQUEST', {
        client_id: clientId,
        gateway_type: gatewayType,
        amount_cents: amountCents,
        correlation_id: correlationId,
    });

    emitPaymentMetric(clientId, gatewayType).catch(() => { /* non-critical */ });
}

// ── CloudWatch Metrics ──────────────────────────────────────────────────────

async function emitRequestMetric(entry: RequestLogEntry): Promise<void> {
    const isError = entry.status_code >= 400;

    await cloudwatchClient.send(new PutMetricDataCommand({
        Namespace: 'DukanX/API',
        MetricData: [
            {
                MetricName: 'RequestCount',
                Value: 1,
                Unit: StandardUnit.Count,
                Dimensions: [
                    { Name: 'TenantId', Value: entry.client_id },
                    { Name: 'Path', Value: entry.path },
                ],
            },
            {
                MetricName: 'RequestLatency',
                Value: entry.latency_ms,
                Unit: StandardUnit.Milliseconds,
                Dimensions: [
                    { Name: 'TenantId', Value: entry.client_id },
                ],
            },
            ...(isError ? [{
                MetricName: 'ErrorCount',
                Value: 1,
                Unit: StandardUnit.Count,
                Dimensions: [
                    { Name: 'TenantId', Value: entry.client_id },
                    { Name: 'StatusCode', Value: String(entry.status_code) },
                ],
            }] : []),
        ],
    }));
}

async function emitAuthFailureMetric(sourceIp?: string): Promise<void> {
    await cloudwatchClient.send(new PutMetricDataCommand({
        Namespace: 'DukanX/Security',
        MetricData: [{
            MetricName: 'AuthFailureCount',
            Value: 1,
            Unit: StandardUnit.Count,
            Dimensions: sourceIp ? [
                { Name: 'SourceIP', Value: sourceIp },
            ] : [],
        }],
    }));
}

async function emitPaymentMetric(clientId: string, gatewayType: string): Promise<void> {
    await cloudwatchClient.send(new PutMetricDataCommand({
        Namespace: 'DukanX/Payments',
        MetricData: [{
            MetricName: 'PaymentRequestCount',
            Value: 1,
            Unit: StandardUnit.Count,
            Dimensions: [
                { Name: 'TenantId', Value: clientId },
                { Name: 'GatewayType', Value: gatewayType },
            ],
        }],
    }));
}
