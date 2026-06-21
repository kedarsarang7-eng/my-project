// ============================================================================
// Lambda Handler — DynamoDB Streams: Customer Balance Rollup (Part 2)
// ============================================================================
// Maintains the rolled-up BALANCE item (SK = CUSTOMER#{cid}#BALANCE) for each
// customer so the profile/summary screens read instantly without recomputing
// from the ledger on every open.
//
// Design decisions (see approved plan):
//   • Read-optimization CACHE only. Credit enforcement
//     (credit-check.util.ts) keeps recomputing from UDHARTXN# as the
//     authoritative source, so a stale/failed rollup can never wrongly block
//     a valid sale.
//   • On every relevant stream record we recompute from a bounded scan of that
//     customer's INVOICE# + PAYMENT# items and putItem the BALANCE item. Full
//     recompute is simple and correct; it self-heals any drift.
//   • Each record is processed in its own try/catch (mirrors in-store-streams.ts
//     fan-out isolation) so one bad record never throws out of the handler and
//     poisons the shard.
//
// Triggered by: DukanXTable stream (NEW_AND_OLD_IMAGES), INSERT + MODIFY.
// ============================================================================

import { DynamoDBStreamEvent, DynamoDBRecord } from 'aws-lambda';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import { AttributeValue } from '@aws-sdk/client-dynamodb';
import {
    Keys,
    putItem,
    queryAllItems,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';

// ── Types ───────────────────────────────────────────────────────────────────

export interface CustomerBalance {
    PK: string;
    SK: string;
    entityType: 'CUSTOMER_BALANCE';
    customerId: string;
    tenantId: string;
    totalBilledCents: number;
    totalPaidCents: number;
    outstandingCents: number;
    invoiceCount: number;
    paymentCount: number;
    lastInvoiceAt: string | null;
    lastPaymentAt: string | null;
    updatedAt: string;
}

/** Shape of an INVOICE# item relevant to the rollup. */
interface InvoiceRow {
    totalCents?: number;
    paidCents?: number;
    balanceCents?: number;
    createdAt?: string;
    status?: string;
    isDeleted?: boolean;
}

/** Shape of a PAYMENT# item relevant to the rollup. */
interface PaymentRow {
    amountCents?: number;
    createdAt?: string;
    isDeleted?: boolean;
}

export const DELETED_INVOICE_STATUSES = new Set(['voided', 'draft']);

// ── Pure recompute (exported for unit testing) ──────────────────────────────

/**
 * Aggregate a customer's balance summary from raw invoice + payment rows.
 * Pure function — no I/O — so it is exhaustively unit-testable.
 *
 * Rules:
 *   • totalBilled = Σ invoice.totalCents (excludes voided/draft/deleted).
 *   • totalPaid   = Σ invoice.paidCents (single source of paid truth — a payment
 *     always lands on its invoice's paidCents). PAYMENT rows are NOT summed to
 *     avoid double-counting; their count is tracked separately for activity.
 *   • outstanding = Σ invoice.balanceCents, floored at 0 (no negative dues).
 *   • lastInvoiceAt / lastPaymentAt track the most recent activity timestamps.
 */
export function computeBalanceFromRows(
    tenantId: string,
    customerId: string,
    invoices: InvoiceRow[],
    payments: PaymentRow[],
    now: string,
): CustomerBalance {
    let totalBilledCents = 0;
    let totalPaidCents = 0;
    let outstandingCents = 0;
    let invoiceCount = 0;
    let lastInvoiceAt: string | null = null;

    for (const inv of invoices) {
        if (inv.isDeleted) continue;
        if (DELETED_INVOICE_STATUSES.has(String(inv.status || '').toLowerCase())) continue;

        totalBilledCents += Number(inv.totalCents || 0);
        totalPaidCents += Number(inv.paidCents || 0);
        outstandingCents += Number(inv.balanceCents || 0);
        invoiceCount += 1;

        const ts = inv.createdAt;
        if (ts && (!lastInvoiceAt || ts > lastInvoiceAt)) lastInvoiceAt = ts;
    }

    // Never show negative outstanding dues (overpayment / data drift).
    if (outstandingCents < 0) outstandingCents = 0;

    let paymentCount = 0;
    let lastPaymentAt: string | null = null;
    for (const pay of payments) {
        if (pay.isDeleted) continue;
        paymentCount += 1;
        const ts = pay.createdAt;
        if (ts && (!lastPaymentAt || ts > lastPaymentAt)) lastPaymentAt = ts;
    }

    return {
        PK: Keys.tenantPK(tenantId),
        SK: Keys.customerBalanceSK(customerId),
        entityType: 'CUSTOMER_BALANCE',
        customerId,
        tenantId,
        totalBilledCents,
        totalPaidCents,
        outstandingCents,
        invoiceCount,
        paymentCount,
        lastInvoiceAt,
        lastPaymentAt,
        updatedAt: now,
    };
}

// ── Recompute (I/O) ─────────────────────────────────────────────────────────

/**
 * Fetch this customer's INVOICE# + PAYMENT# rows and write a fresh BALANCE item.
 * Returns the computed balance, or null if the customer has no tenant context.
 */
export async function recomputeCustomerBalance(
    tenantId: string,
    customerId: string,
    now: string = new Date().toISOString(),
): Promise<CustomerBalance | null> {
    const pk = Keys.tenantPK(tenantId);

    const [invoices, payments] = await Promise.all([
        queryAllItems<InvoiceRow>(pk, 'INVOICE#', {
            filterExpression:
                'customerId = :cid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':cid': customerId, ':false': false },
            maxPages: 20,
        }),
        queryAllItems<PaymentRow>(pk, 'PAYMENT#', {
            filterExpression:
                'customerId = :cid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':cid': customerId, ':false': false },
            maxPages: 20,
        }),
    ]);

    const balance = computeBalanceFromRows(tenantId, customerId, invoices, payments, now);
    await putItem(balance as unknown as Record<string, unknown>);
    return balance;
}

// ── Stream handler ──────────────────────────────────────────────────────────

/**
 * Extract tenantId + customerId from a stream record image.
 * Customer ledger rows are written by multiple services and some carry
 * customerId but not tenantId; fall back to the tenant encoded in PK.
 */
function extractContext(image: Record<string, unknown>): {
    tenantId: string | null;
    customerId: string | null;
} {
    const tenantId =
        (image.tenantId as string | undefined) ||
        (() => {
            const pk = image.PK as string | undefined;
            return pk && pk.startsWith('TENANT#') ? pk.slice('TENANT#'.length) : null;
        })();
    // customerId may live directly on the record (INVOICE#/PAYMENT#) or under
    // udharPersonId (UDHAR_TXN#) — the latter isn't processed here but we guard.
    const customerId =
        (image.customerId as string | undefined) ||
        (image.udharPersonId as string | undefined) ||
        null;
    return { tenantId: tenantId || null, customerId: customerId || null };
}

/**
 * Decide whether a stream record is one we should roll up.
 * Only INVOICE# and PAYMENT# writes that carry a customerId affect balances.
 */
function shouldProcess(image: Record<string, unknown>): boolean {
    const entityType = String(image.entityType || '');
    if (entityType !== 'INVOICE' && entityType !== 'PAYMENT') return false;
    const { tenantId, customerId } = extractContext(image);
    return Boolean(tenantId && customerId);
}

export const handler = async (event: DynamoDBStreamEvent): Promise<void> => {
    for (const record of event.Records) {
        // Isolation per record: never let one failure abort the batch.
        try {
            await processRecord(record);
        } catch (err) {
            logger.error('customer-rollup-stream: record failed', {
                eventName: record.eventName,
                error: (err as Error).message,
            });
        }
    }
};

async function processRecord(record: DynamoDBRecord): Promise<void> {
    if (record.eventName !== 'INSERT' && record.eventName !== 'MODIFY') return;

    const newImage = record.dynamodb?.NewImage
        ? unmarshall(record.dynamodb.NewImage as Record<string, AttributeValue>)
        : null;
    if (!newImage || !shouldProcess(newImage)) return;

    const { tenantId, customerId } = extractContext(newImage);
    if (!tenantId || !customerId) return;

    logger.info('customer-rollup-stream: recomputing balance', {
        tenantId,
        customerId,
        entityType: newImage.entityType,
        eventName: record.eventName,
    });

    await recomputeCustomerBalance(tenantId, customerId);
}
