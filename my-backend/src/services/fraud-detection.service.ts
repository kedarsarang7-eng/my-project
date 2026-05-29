// ============================================================================
// Fraud Detection Service — Payment Anomaly & Abuse Prevention (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { config } from '../config/environment';

const cloudwatchClient = new CloudWatchClient({ region: config.aws.region });
const snsClient = new SNSClient({ region: config.aws.region });

const FRAUD_CONFIG = {
    velocityMaxPerHour: 50,
    maxConsecutiveFailures: 10,
    failureWindowMinutes: 30,
    amountAnomalyStdDevs: 3,
    minTransactionsForStats: 10,
};

export interface FraudCheckContext { tenantId: string; amountCents: number; invoiceId: string; sourceIp?: string; }
export interface FraudCheckResult { blocked: boolean; reasons: string[]; severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'; checks: FraudRuleResult[]; }
interface FraudRuleResult { rule: string; flagged: boolean; severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'; reason?: string; details?: Record<string, unknown>; }

export async function checkPaymentFraud(ctx: FraudCheckContext): Promise<FraudCheckResult> {
    const checks: FraudRuleResult[] = [];
    const [velocityResult, dupResult, failureResult, amountResult] = await Promise.allSettled([
        checkVelocity(ctx), checkDuplicatePayment(ctx), checkFailureThreshold(ctx), checkAmountAnomaly(ctx),
    ]);

    if (velocityResult.status === 'fulfilled') checks.push(velocityResult.value);
    if (dupResult.status === 'fulfilled') checks.push(dupResult.value);
    if (failureResult.status === 'fulfilled') checks.push(failureResult.value);
    if (amountResult.status === 'fulfilled') checks.push(amountResult.value);

    [velocityResult, dupResult, failureResult, amountResult].forEach((result, idx) => {
        if (result.status === 'rejected') logger.warn('Fraud check failed (fail-open)', { rule: ['velocity', 'duplicate', 'failures', 'amount'][idx], error: result.reason?.message });
    });

    const flaggedChecks = checks.filter(c => c.flagged);
    const hasHighSeverity = flaggedChecks.some(c => c.severity === 'HIGH' || c.severity === 'CRITICAL');
    const result: FraudCheckResult = {
        blocked: hasHighSeverity, reasons: flaggedChecks.map(c => c.reason || c.rule),
        severity: hasHighSeverity ? 'HIGH' : flaggedChecks.length > 0 ? 'MEDIUM' : 'LOW', checks,
    };
    if (flaggedChecks.length > 0) await emitFraudAlert(ctx, result);
    return result;
}

async function checkVelocity(ctx: FraudCheckContext): Promise<FraudRuleResult> {
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const result = await queryItems<Record<string, any>>(Keys.tenantPK(ctx.tenantId), 'PAYORDER#', {
        filterExpression: 'createdAt > :cutoff',
        expressionAttributeValues: { ':cutoff': oneHourAgo },
    });
    const count = result.items.length;
    const flagged = count >= FRAUD_CONFIG.velocityMaxPerHour;
    return { rule: 'velocity_check', flagged, severity: flagged ? 'HIGH' : 'LOW', reason: flagged ? `Payment velocity exceeded: ${count} in last hour` : undefined, details: { count, threshold: FRAUD_CONFIG.velocityMaxPerHour } };
}

async function checkDuplicatePayment(ctx: FraudCheckContext): Promise<FraudRuleResult> {
    const oneMinAgo = new Date(Date.now() - 60 * 1000).toISOString();
    const result = await queryItems<Record<string, any>>(Keys.tenantPK(ctx.tenantId), 'PAYORDER#', {
        filterExpression: 'invoiceId = :iid AND amountCents = :amt AND #s = :success AND createdAt > :cutoff',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: { ':iid': ctx.invoiceId, ':amt': ctx.amountCents, ':success': 'success', ':cutoff': oneMinAgo },
    });
    const flagged = result.items.length > 0;
    return { rule: 'duplicate_payment', flagged, severity: flagged ? 'HIGH' : 'LOW', reason: flagged ? 'Duplicate payment within 60 seconds' : undefined };
}

async function checkFailureThreshold(ctx: FraudCheckContext): Promise<FraudRuleResult> {
    const cutoff = new Date(Date.now() - FRAUD_CONFIG.failureWindowMinutes * 60 * 1000).toISOString();
    const result = await queryItems<Record<string, any>>(Keys.tenantPK(ctx.tenantId), 'PAYORDER#', {
        filterExpression: '#s = :failed AND createdAt > :cutoff',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: { ':failed': 'failed', ':cutoff': cutoff },
    });
    const count = result.items.length;
    const flagged = count >= FRAUD_CONFIG.maxConsecutiveFailures;
    return { rule: 'failure_threshold', flagged, severity: flagged ? 'HIGH' : 'LOW', reason: flagged ? `Too many failures: ${count}` : undefined };
}

async function checkAmountAnomaly(ctx: FraudCheckContext): Promise<FraudRuleResult> {
    const result = await queryItems<Record<string, any>>(Keys.tenantPK(ctx.tenantId), 'PAYORDER#', {
        filterExpression: '#s = :success',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: { ':success': 'success' },
    });
    const amounts = result.items.map(i => Number(i.amountCents));
    if (amounts.length < FRAUD_CONFIG.minTransactionsForStats) return { rule: 'amount_anomaly', flagged: false, severity: 'LOW' };

    const avg = amounts.reduce((a, b) => a + b, 0) / amounts.length;
    const stddev = Math.sqrt(amounts.reduce((sum, val) => sum + Math.pow(val - avg, 2), 0) / amounts.length);
    const threshold = avg + FRAUD_CONFIG.amountAnomalyStdDevs * stddev;
    const flagged = ctx.amountCents > threshold && threshold > 0;

    return { rule: 'amount_anomaly', flagged, severity: flagged ? 'MEDIUM' : 'LOW', reason: flagged ? `Unusual amount: ?${(ctx.amountCents / 100).toFixed(2)} > threshold ?${(threshold / 100).toFixed(2)}` : undefined };
}

async function emitFraudAlert(ctx: FraudCheckContext, result: FraudCheckResult): Promise<void> {
    try {
        await cloudwatchClient.send(new PutMetricDataCommand({ Namespace: 'DukanX/Security', MetricData: [{ MetricName: 'FraudCheckFlagged', Value: result.blocked ? 1 : 0, Unit: 'Count', Dimensions: [{ Name: 'TenantId', Value: ctx.tenantId }, { Name: 'Severity', Value: result.severity }] }] }));
    } catch (err) { logger.warn('Failed to emit fraud metric', { error: (err as Error).message }); }

    if (result.severity === 'HIGH' || result.severity === 'CRITICAL') {
        const topicArn = config.awsSns.securityAlertTopicArn;
        if (topicArn) {
            try { await snsClient.send(new PublishCommand({ TopicArn: topicArn, Subject: `FRAUD ALERT: ${result.severity} — ${ctx.tenantId}`, Message: JSON.stringify({ tenantId: ctx.tenantId, amountCents: ctx.amountCents, invoiceId: ctx.invoiceId, severity: result.severity, blocked: result.blocked, reasons: result.reasons, timestamp: new Date().toISOString() }, null, 2) })); }
            catch (err) { logger.warn('Failed to send fraud SNS alert', { error: (err as Error).message }); }
        }
    }
    logger.warn('Fraud detection flagged', { tenantId: ctx.tenantId, blocked: result.blocked, severity: result.severity, reasons: result.reasons });
}
