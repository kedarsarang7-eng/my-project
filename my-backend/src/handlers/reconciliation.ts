// ============================================================================
// DukanX Daily Reconciliation Lambda Handler (DynamoDB)
// ============================================================================
// Triggered daily via EventBridge (cron). Runs financial integrity checks
// against the DynamoDB single-table, publishes critical errors to SNS,
// stores report snapshot in S3.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

const region = config.aws.region;
const snsClient = new SNSClient(configureAwsClient({ region }));
const s3Client = new S3Client(configureAwsClient({ region }));
const cwClient = new CloudWatchClient(configureAwsClient({ region }));

const SNS_TOPIC_ARN = config.awsSns.reconciliationTopicArn || '';
const S3_BUCKET = config.extendedS3.reconciliationBucket || '';

interface ViolationRow { violation: string; tenant_id?: string; drift_paise?: number; [key: string]: unknown; }
interface ReconciliationResult { phase: string; check: string; severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW'; violations: ViolationRow[]; count: number; }

export async function handler(): Promise<{ statusCode: number; body: string }> {
    const results: ReconciliationResult[] = [];
    const startTime = Date.now();
    let criticalCount = 0;

    try {
        // Get all tenants
        const tenants = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, { indexName: 'GSI1' });

        for (const tenant of tenants.items) {
            const tenantId = tenant.tenantId || tenant.id;
            const pk = `TENANT#${tenantId}`;

            // Fetch all invoices for this tenant
            const invoices = await queryItems<Record<string, any>>(pk, 'INVOICE#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
            });

            // Check 1.1: Header Arithmetic (subtotal + tax + roundOff == total)
            for (const inv of invoices.items) {
                const sub = Number(inv.subtotalCents || 0);
                const tax = Number(inv.taxCents || 0);
                const round = Number(inv.roundOffCents || 0);
                const total = Number(inv.totalCents || 0);
                if (sub + tax + round !== total) {
                    results.push({ phase: 'PHASE1', check: '1.1 Header Arithmetic', severity: 'CRITICAL', violations: [{ violation: 'subtotal+tax+round?total', tenant_id: tenantId, drift_paise: (sub + tax + round) - total }], count: 1 });
                    criticalCount++;
                }
            }

            // Check 1.4: Balance Invariant (paid + balance == total)
            for (const inv of invoices.items) {
                const paid = Number(inv.paidCents || 0);
                const balance = Number(inv.balanceCents || 0);
                const total = Number(inv.totalCents || 0);
                if (paid + balance !== total) {
                    results.push({ phase: 'PHASE1', check: '1.4 Balance Invariant', severity: 'CRITICAL', violations: [{ violation: 'paid+balance?total', tenant_id: tenantId, drift_paise: (paid + balance) - total }], count: 1 });
                    criticalCount++;
                }
            }

            // Check 1.5: Overpayments (paid > total)
            for (const inv of invoices.items) {
                if (Number(inv.paidCents || 0) > Number(inv.totalCents || 0)) {
                    results.push({ phase: 'PHASE1', check: '1.5 Overpayments', severity: 'CRITICAL', violations: [{ violation: 'paid>total', tenant_id: tenantId }], count: 1 });
                    criticalCount++;
                }
            }

            // Check 1.6: Negative Balance
            for (const inv of invoices.items) {
                if (Number(inv.balanceCents || 0) < 0) {
                    results.push({ phase: 'PHASE1', check: '1.6 Negative Balance', severity: 'CRITICAL', violations: [{ violation: 'negative balance', tenant_id: tenantId }], count: 1 });
                    criticalCount++;
                }
            }
        }

        const durationMs = Date.now() - startTime;
        const report = {
            timestamp: new Date().toISOString(), durationMs,
            totalChecks: results.length, criticalViolations: criticalCount,
            totalViolations: results.reduce((s, r) => s + Math.max(r.count, 0), 0),
            results,
        };

        // Upload to S3
        if (S3_BUCKET) {
            const dateStr = new Date().toISOString().slice(0, 10);
            await s3Client.send(new PutObjectCommand({ Bucket: S3_BUCKET, Key: `reconciliation/${dateStr}/report.json`, Body: JSON.stringify(report, null, 2), ContentType: 'application/json' }));
        }

        // Publish CRITICAL alerts to SNS
        if (criticalCount > 0 && SNS_TOPIC_ARN) {
            const criticalResults = results.filter(r => r.severity === 'CRITICAL' && r.count > 0);
            await snsClient.send(new PublishCommand({ TopicArn: SNS_TOPIC_ARN, Subject: `?? DukanX CRITICAL: ${criticalCount} violations`, Message: JSON.stringify({ alert: 'FINANCIAL_INTEGRITY_VIOLATION', criticalCount, details: criticalResults.slice(0, 10).map(r => ({ check: r.check, count: r.count, sample: r.violations.slice(0, 3) })) }) }));
        }

        // Emit CloudWatch metrics
        await cwClient.send(new PutMetricDataCommand({ Namespace: 'DukanX/Reconciliation', MetricData: [{ MetricName: 'CriticalViolations', Value: criticalCount, Unit: 'Count' }, { MetricName: 'TotalViolations', Value: report.totalViolations, Unit: 'Count' }, { MetricName: 'ReconciliationDurationMs', Value: durationMs, Unit: 'Milliseconds' }] }));

        return { statusCode: 200, body: JSON.stringify(report) };
    } catch (err) {
        logger.error('[Reconciliation] Failed', { error: (err as Error).message });
        return { statusCode: 500, body: JSON.stringify({ error: (err as Error).message }) };
    }
}
