import { configureAwsClient } from '../config/aws.config';
import { PublishCommand, SNSClient } from '@aws-sdk/client-sns';
import { v4 as uuidv4 } from 'uuid';
import { getItem, Keys, putItem, queryAllItems, queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

const sns = new SNSClient(configureAwsClient({ region: config.aws.region }));

interface ReminderCandidate {
    customerId: string;
    customerName: string;
    phone: string | null;
    outstandingCents: number;
    maxAgeDays: number;
    openInvoiceCount: number;
}

export async function runDailyCreditReminders(): Promise<{
    tenants: number;
    remindersSent: number;
    tenantsFailed: number;
}> {
    const tenants = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, { indexName: 'GSI1' });
    let remindersSent = 0;
    let tenantsFailed = 0;

    for (const t of tenants.items) {
        const tenantId = String(t.tenantId || t.id || '');
        if (!tenantId) continue;
        try {
            const sent = await sendCreditRemindersForTenant(tenantId);
            remindersSent += sent;
        } catch (err: any) {
            tenantsFailed += 1;
            logger.warn('credit reminder run failed', { tenantId, error: err?.message });
        }
    }

    return { tenants: tenants.items.length, remindersSent, tenantsFailed };
}

export async function sendCreditRemindersForTenant(tenantId: string): Promise<number> {
    const topicArn = config.creditReminder.snsTopicArn || config.awsSns.securityAlertTopicArn || '';
    const minAgeDays = Number(config.creditReminder.minAgeDays || 15);
    const minBalanceCents = Number(config.creditReminder.minBalanceCents || 100);
    const candidates = await getCandidates(tenantId, minAgeDays, minBalanceCents);

    let sent = 0;
    for (const c of candidates) {
        const now = new Date().toISOString();
        const msg = `Reminder: Rs ${(c.outstandingCents / 100).toFixed(2)} due for ${c.customerName}. Open bills: ${c.openInvoiceCount}, oldest ${Math.floor(c.maxAgeDays)} day(s).`;

        if (topicArn) {
            await sns.send(new PublishCommand({
                TopicArn: topicArn,
                Message: msg,
                Subject: `Credit Reminder - ${tenantId}`,
                MessageAttributes: {
                    tenantId: { DataType: 'String', StringValue: tenantId },
                    customerId: { DataType: 'String', StringValue: c.customerId },
                    phone: { DataType: 'String', StringValue: c.phone || '' },
                },
            }));
        } else {
            logger.info('credit reminder dry-run (SNS topic missing)', {
                tenantId,
                customerId: c.customerId,
                outstandingCents: c.outstandingCents,
            });
        }

        await putItem({
            PK: Keys.tenantPK(tenantId),
            SK: `REMINDERLOG#${now}#${uuidv4()}`,
            entityType: 'CREDIT_REMINDER_LOG',
            tenantId,
            customerId: c.customerId,
            customerName: c.customerName,
            phone: c.phone,
            outstandingCents: c.outstandingCents,
            maxAgeDays: c.maxAgeDays,
            channel: topicArn ? 'sns' : 'log',
            sentAt: now,
            createdAt: now,
        });
        sent += 1;
    }

    return sent;
}

async function getCandidates(
    tenantId: string,
    minAgeDays: number,
    minBalanceCents: number,
): Promise<ReminderCandidate[]> {
    const pk = Keys.tenantPK(tenantId);
    const msPerDay = 86_400_000;
    const now = Date.now();

    const invoices = await queryAllItems<Record<string, unknown>>(pk, 'INVOICE#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
        maxPages: 40,
    });

    const byCustomer = new Map<string, Record<string, unknown>[]>();
    for (const inv of invoices) {
        const row = inv as Record<string, unknown>;
        const balance = Number(row.balanceCents || 0);
        if (balance < minBalanceCents) continue;
        const mode = String(row.paymentMode || '').toLowerCase();
        if (mode !== 'udhar' && mode !== 'credit') continue;
        const st = String(row.status || '');
        if (st === 'voided' || st === 'draft') continue;
        const ref = String(row.saleDate || row.createdAt || '');
        if (!ref) continue;
        const t = new Date(ref).getTime();
        if (Number.isNaN(t)) continue;
        const ageDays = (now - t) / msPerDay;
        if (ageDays < minAgeDays) continue;

        const customerId = String(row.customerId || '');
        if (!customerId) continue;
        const arr = byCustomer.get(customerId) || [];
        arr.push(row);
        byCustomer.set(customerId, arr);
    }

    const out: ReminderCandidate[] = [];
    for (const [customerId, invs] of byCustomer) {
        const customer = await getItem<Record<string, unknown>>(pk, Keys.customerSK(customerId));
        let maxAgeDays = 0;
        let outstandingCents = 0;
        for (const row of invs) {
            outstandingCents += Number(row.balanceCents || 0);
            const ref = String(row.saleDate || row.createdAt || '');
            const age = (now - new Date(ref).getTime()) / msPerDay;
            if (age > maxAgeDays) maxAgeDays = age;
        }
        out.push({
            customerId,
            customerName: customer
                ? String((customer as { name?: string }).name || customerId)
                : customerId,
            phone: customer
                ? (String((customer as { phone?: string }).phone || '') || null)
                : null,
            outstandingCents,
            maxAgeDays,
            openInvoiceCount: invs.length,
        });
    }

    out.sort((a, b) => b.outstandingCents - a.outstandingCents);
    return out;
}
