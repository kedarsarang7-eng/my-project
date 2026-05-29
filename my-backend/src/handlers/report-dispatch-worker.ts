// ============================================================================
// Scheduled worker � processes REPORTDISPATCH rows (queue + scheduled + retry).
// Trigger: EventBridge rate rule. Optional SNS / WhatsApp webhook via env.
// ============================================================================

import { EventBridgeEvent } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { PublishCommand, SNSClient } from '@aws-sdk/client-sns';
import { Keys, getItem, queryItems } from '../config/dynamodb.config';
import { buildReportExportPayload, applyReportDispatchOutcome } from './reports';
import { logger } from '../utils/logger';
import dayjs from 'dayjs';
import { config } from '../config/environment';

type DispatchRow = Record<string, any>;

const sns = new SNSClient({ region: config.aws.region });

/** Exported for unit tests � whether a row should run on this tick. */
export function isReportDispatchDue(row: DispatchRow, now: Date = new Date()): boolean {
    const st = String(row.status || '').toLowerCase();
    if (st === 'sent' || st === 'cancelled' || st === 'failed') return false;
    const d = dayjs(now);
    if (st === 'scheduled') {
        const sa = row.scheduleAt;
        if (!sa) return false;
        return !dayjs(sa).isAfter(d);
    }
    if (st === 'queued') {
        const nr = row.nextRetryAt;
        if (nr && dayjs(nr).isAfter(d)) return false;
        return true;
    }
    return false;
}

async function deliverReportDispatch(
    job: DispatchRow,
    built: { body: string; contentType: string; contentDisposition: string },
): Promise<{ ok: boolean; error?: string }> {
    const arn = config.awsSns.reportDispatchTopicArn || '';
    const waUrl = config.whatsapp.reportDispatchWebhookUrl || '';
    const channels = (Array.isArray(job.channels) ? job.channels : [])
        .map((c: string) => String(c).toLowerCase());
    let notified = false;

    if (channels.includes('email') && arn) {
        await sns.send(
            new PublishCommand({
                TopicArn: arn,
                Subject: `Report ${job.reportType} (${job.id})`,
                Message: JSON.stringify({
                    kind: 'report_dispatch',
                    tenantId: job.tenantId,
                    dispatchId: job.id,
                    reportType: job.reportType,
                    format: job.format,
                    period: job.period,
                    recipients: job.recipients,
                    attachmentBytes: built.body.length,
                }),
            }),
        );
        notified = true;
    }

    if (channels.includes('whatsapp') && waUrl) {
        const res = await fetch(waUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                tenantId: job.tenantId,
                dispatchId: job.id,
                channels,
                recipients: job.recipients,
                meta: { reportType: job.reportType, format: job.format },
            }),
        });
        if (!res.ok) return { ok: false, error: `WHATSAPP_WEBHOOK_${res.status}` };
        notified = true;
    }

    if (!notified) {
        logger.info('REPORT_DISPATCH_DRY_RUN', {
            tenantId: job.tenantId,
            dispatchId: job.id,
            channels,
            bytes: built.body.length,
        });
    }

    return { ok: true };
}

async function loadCandidateDispatches(): Promise<DispatchRow[]> {
    const gsiPk = Keys.entityGSI1PK('REPORTDISPATCH');
    const collected: DispatchRow[] = [];
    let lastKey: Record<string, unknown> | undefined;

    for (let page = 0; page < 8; page++) {
        const r = await queryItems<DispatchRow>(gsiPk, undefined, {
            indexName: 'GSI1',
            limit: 80,
            scanIndexForward: true,
            exclusiveStartKey: lastKey,
        });
        collected.push(...r.items);
        lastKey = r.lastKey;
        if (!lastKey) break;
    }
    return collected;
}

/**
 * One worker run: find due jobs, build export, deliver, mark attempt.
 */
export async function runReportDispatchWorkerTick(): Promise<{
    scanned: number;
    due: number;
    processed: number;
    skipped: boolean;
}> {
    const workerEnabled = process.env.REPORT_DISPATCH_WORKER_ENABLED ?? config.whatsapp.reportDispatchWorkerEnabled;
    if (workerEnabled !== 'true') {
        return { scanned: 0, due: 0, processed: 0, skipped: true };
    }

    const now = new Date();
    const rows = await loadCandidateDispatches();
    const dueRows = rows.filter((row) => isReportDispatchDue(row, now));
    dueRows.sort((a, b) => String(a.GSI1SK || '').localeCompare(String(b.GSI1SK || '')));

    const batch = dueRows.slice(0, 25);
    let processed = 0;

    for (const snapshot of batch) {
        const tenantId = String(snapshot.tenantId || '');
        const dispatchId = String(snapshot.id || '');
        if (!tenantId || !dispatchId) continue;

        const pk = Keys.tenantPK(tenantId);
        const sk = `REPORTDISPATCH#${dispatchId}`;
        const fresh = await getItem<DispatchRow>(pk, sk);
        if (!fresh || !isReportDispatchDue(fresh, now)) continue;

        const period = fresh.period || {};
        const fromDate = String(period.from || '');
        const toDate = String(period.to || '');
        const reportType = String(fresh.reportType || 'sales').toLowerCase() as 'sales' | 'gstr1' | 'gstr3b';
        const format = String(fresh.format || 'csv').toLowerCase() as 'csv' | 'json' | 'excel';

        try {
            const built = await buildReportExportPayload({
                tenantId,
                fromDate,
                toDate,
                exportType: reportType,
                exportFormat: format,
            });
            if (!built.ok) {
                const r = await applyReportDispatchOutcome(tenantId, dispatchId, {
                    outcome: 'failed',
                    errorMessage: built.error,
                    requestSource: 'report-dispatch-worker',
                });
                if (r.ok) processed += 1;
                continue;
            }

            const del = await deliverReportDispatch(fresh, built);
            if (!del.ok) {
                const r = await applyReportDispatchOutcome(tenantId, dispatchId, {
                    outcome: 'failed',
                    errorMessage: del.error || 'DELIVERY_FAILED',
                    requestSource: 'report-dispatch-worker',
                });
                if (r.ok) processed += 1;
                continue;
            }

            const r = await applyReportDispatchOutcome(tenantId, dispatchId, {
                outcome: 'sent',
                requestSource: 'report-dispatch-worker',
            });
            if (r.ok) processed += 1;
        } catch (e: any) {
            logger.error('report dispatch worker job failed', {
                tenantId,
                dispatchId,
                error: e?.message,
            });
            const r = await applyReportDispatchOutcome(tenantId, dispatchId, {
                outcome: 'failed',
                errorMessage: e?.message || 'WORKER_EXCEPTION',
                requestSource: 'report-dispatch-worker',
            });
            if (r.ok) processed += 1;
        }
    }

    return { scanned: rows.length, due: dueRows.length, processed, skipped: false };
}

/**
 * Lambda entry for EventBridge schedule.
 */
export async function reportDispatchWorkerHandler(
    _event: EventBridgeEvent<'Scheduled Event', unknown>,
): Promise<{ statusCode: number; body: string }> {
    const correlationId = randomUUID();
    try {
        const summary = await runReportDispatchWorkerTick();
        logger.info('reportDispatchWorkerHandler done', { ...summary, correlationId });
        return { statusCode: 200, body: JSON.stringify({ ...summary, correlationId }) };
    } catch (err: any) {
        logger.error('reportDispatchWorkerHandler fatal', { error: err?.message, correlationId });
        return { statusCode: 500, body: JSON.stringify({ error: err?.message, correlationId }) };
    }
}
