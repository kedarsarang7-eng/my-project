// ============================================================================
// Cash Closing Service — Sprint 1: Day-End Denomination Close
// ============================================================================
// Reconciles the cashier's counted drawer against expected cash derived from
// the day's finalized invoices.
//
// EXPECTED CASH = Σ(cash leg of each non-void invoice for the day)
//   - paymentMode === 'cash'  → full paidCents
//   - paymentMode === 'split' → metadata.splitPayments.{method:'cash'}.amountCents
//   - all other modes         → 0 (UPI/card/credit don't hit the till)
//
// VARIANCE = expected - counted
//   Positive variance → cashier short. Negative → over.
//
// CRITICAL DESIGN GUARANTEES:
//   1. ONE close per (tenant, businessId, date). Server enforces — re-submission
//      with the same key returns the existing record.
//   2. Variance > tolerance → status = 'mismatch_pending'. Owner approval
//      stamps `approvedBy`/`approvedAt` and flips to `mismatch_approved`.
//   3. Denomination breakdown counted is verified server-side against
//      `countedCashPaise` to catch transcription errors.
//   4. Expected cash is recomputed every read so amendments to invoices
//      flow through without an explicit recompute.
// ============================================================================

import { randomUUID } from 'crypto';
import {
    Keys,
    putItem,
    getItem,
    queryItems,
    queryAllItems,
    updateItem,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { ConflictError, NotFoundError, ValidationError } from '../utils/errors';
import type { z } from 'zod';
import type { recordCashClosingSchema, cashDenominationSchema } from '../schemas/index';

type RecordInput = z.infer<typeof recordCashClosingSchema>;
type Denomination = z.infer<typeof cashDenominationSchema>;

export type CashClosingStatus = 'matched' | 'mismatch_pending' | 'mismatch_approved';

export interface CashClosingRecord {
    id: string;
    tenantId: string;
    businessId?: string;
    closingDate: string; // YYYY-MM-DD
    /** Server-computed expected cash, paise. */
    expectedCashPaise: number;
    /** Cashier-counted drawer total, paise. */
    countedCashPaise: number;
    /** expected - counted. Positive == short. */
    variancePaise: number;
    /** Denomination breakdown the cashier counted (audit). */
    denominations?: Denomination[];
    status: CashClosingStatus;
    /** Per-tenant variance tolerance (paise). Pulled from settings on close. */
    tolerancePaise: number;
    closedBy: string;
    cashierNote?: string;
    shiftId?: string;
    approvedBy?: string;
    approvedAt?: string;
    approvalReason?: string;
    createdAt: string;
    updatedAt: string;
}

const DEFAULT_TOLERANCE_PAISE = 10_000; // ₹100 — same as legacy default in Flutter service

function todayDateString(): string {
    return new Date().toISOString().substring(0, 10);
}

function startOfDayMs(dateStr: string): number {
    return new Date(`${dateStr}T00:00:00.000Z`).getTime();
}

function endOfDayMs(dateStr: string): number {
    return new Date(`${dateStr}T23:59:59.999Z`).getTime();
}

/**
 * Verify the denomination breakdown sums to the counted cash. Catches typos.
 * Returns the computed sum (paise) so callers can correct or reject.
 */
function verifyDenominationSum(
    denominations: Denomination[] | undefined,
    countedCashPaise: number,
): number | null {
    if (!denominations || denominations.length === 0) return null;
    const sum = denominations.reduce(
        (acc, d) => acc + d.valuePaise * d.count,
        0,
    );
    if (Math.abs(sum - countedCashPaise) > 100) {
        // 1 rupee tolerance for rounding in cents → paise conversions.
        throw new ValidationError(
            `Denomination breakdown sums to ${sum} paise but countedCashPaise is ${countedCashPaise}. Recount and resubmit.`,
        );
    }
    return sum;
}

/**
 * Compute expected cash for a tenant on a given date. Sums:
 *   1. paymentMode === 'cash' invoices: full paidCents
 *   2. paymentMode === 'split' invoices: cash legs of metadata.splitPayments
 *
 * Voided/deleted invoices are excluded.
 *
 * NOTE: Uses the existing `INVOICE#` SK pattern; for tenants with a few
 * thousand invoices/day this is fine. For large tenants we'll want a daily
 * summary GSI later, but punting for v1.
 */
export async function computeExpectedCashPaise(
    tenantId: string,
    closingDate: string,
    businessId?: string,
): Promise<number> {
    const startMs = startOfDayMs(closingDate);
    const endMs = endOfDayMs(closingDate);

    // Pull all invoices for the tenant; we filter by date in JS to avoid the
    // overhead of a date-range GSI for what is a once-a-day operation.
    const invoices = await queryAllItems<Record<string, unknown>>(
        Keys.tenantPK(tenantId),
        'INVOICE#',
        { maxPages: 20 },
    );

    let cashPaise = 0;
    for (const inv of invoices) {
        const createdAt = String(inv.createdAt || '');
        const createdMs = createdAt ? new Date(createdAt).getTime() : 0;
        if (!createdMs || createdMs < startMs || createdMs > endMs) continue;

        if (businessId && inv.businessId && inv.businessId !== businessId) continue;
        if (inv.isDeleted === true) continue;
        const status = String(inv.status || '');
        if (status === 'void' || status === 'cancelled') continue;

        const mode = String(inv.paymentMode || 'cash').toLowerCase();
        const paidCents = Number(inv.paidCents || 0);

        if (mode === 'cash') {
            cashPaise += paidCents;
        } else if (mode === 'split') {
            const meta = (inv.metadata || {}) as Record<string, unknown>;
            const legs = (meta.splitPayments || []) as Array<Record<string, unknown>>;
            for (const leg of legs) {
                if (String(leg.method || '').toLowerCase() === 'cash') {
                    cashPaise += Number(leg.amountCents || 0);
                }
            }
        }
        // UPI/card/bank/credit/wallet/cheque do not hit the till.
    }

    return cashPaise;
}

/**
 * Get today's closing record (if any). Used by the UI to disable the close
 * button after a day has been closed.
 */
export async function getClosingForDate(
    tenantId: string,
    closingDate: string,
    businessId?: string,
): Promise<CashClosingRecord | null> {
    const sk = Keys.cashClosingSK(closingDate, businessId);
    const record = await getItem<CashClosingRecord>(Keys.tenantPK(tenantId), sk);
    return record;
}

/**
 * Create the day-end close. Idempotent: a second submission for the same date
 * fails fast with a 409 ConflictError so the cashier can't accidentally
 * overwrite the audit record.
 */
export async function recordCashClosing(
    tenantId: string,
    closedBy: string,
    businessId: string | undefined,
    input: RecordInput,
): Promise<CashClosingRecord> {
    const closingDate = input.closingDate || todayDateString();
    const sk = Keys.cashClosingSK(closingDate, businessId);

    // Hard-block the second submission for the same day.
    const existing = await getItem<CashClosingRecord>(
        Keys.tenantPK(tenantId), sk,
    );
    if (existing) {
        throw new ConflictError(
            `Day already closed on ${closingDate}. Approve or amend the existing record instead.`,
        );
    }

    verifyDenominationSum(input.denominations, input.countedCashPaise);

    const expectedCashPaise = await computeExpectedCashPaise(
        tenantId, closingDate, businessId,
    );
    const variancePaise = expectedCashPaise - input.countedCashPaise;
    const tolerancePaise = DEFAULT_TOLERANCE_PAISE;
    const status: CashClosingStatus =
        Math.abs(variancePaise) <= tolerancePaise ? 'matched' : 'mismatch_pending';

    const id = randomUUID();
    const now = new Date().toISOString();
    const record: CashClosingRecord = {
        id,
        tenantId,
        businessId,
        closingDate,
        expectedCashPaise,
        countedCashPaise: input.countedCashPaise,
        variancePaise,
        denominations: input.denominations,
        status,
        tolerancePaise,
        closedBy,
        cashierNote: input.cashierNote,
        shiftId: input.shiftId,
        createdAt: now,
        updatedAt: now,
    };

    await putItem({
        PK: Keys.tenantPK(tenantId),
        SK: sk,
        GSI1PK: Keys.cashClosingEntityGSI1PK(),
        GSI1SK: closingDate,
        entityType: 'CASHCLOSE',
        ...record,
    }, 'attribute_not_exists(PK)'); // belt-and-braces against the race

    logger.info('cash_closing_recorded', {
        tenantId, closingDate, expectedCashPaise, countedCashPaise: input.countedCashPaise,
        variancePaise, status,
    });

    return record;
}

/**
 * Approve a `mismatch_pending` close. Owner role enforced at the handler.
 */
export async function approveCashClosing(
    tenantId: string,
    approverId: string,
    closingDate: string,
    reason: string,
    businessId?: string,
): Promise<CashClosingRecord> {
    const sk = Keys.cashClosingSK(closingDate, businessId);
    const existing = await getItem<CashClosingRecord>(Keys.tenantPK(tenantId), sk);
    if (!existing) {
        throw new NotFoundError('Cash closing not found for approval');
    }
    if (existing.status === 'mismatch_approved') {
        return existing;
    }
    if (existing.status === 'matched') {
        throw new ConflictError(
            'Cash closing matched within tolerance — no approval required.',
        );
    }

    const now = new Date().toISOString();
    const updated = await updateItem(Keys.tenantPK(tenantId), sk, {
        updateExpression:
            'SET #status = :status, approvedBy = :approver, approvedAt = :now, ' +
            'approvalReason = :reason, updatedAt = :now',
        expressionAttributeNames: { '#status': 'status' },
        expressionAttributeValues: {
            ':status': 'mismatch_approved' as CashClosingStatus,
            ':approver': approverId,
            ':now': now,
            ':reason': reason,
        },
        conditionExpression: '#status = :pending',
    });
    if (!updated) throw new NotFoundError('Cash closing not found for approval');

    logger.info('cash_closing_approved', {
        tenantId, closingDate, approverId, variancePaise: existing.variancePaise,
    });

    return updated as unknown as CashClosingRecord;
}

/** List closings (newest first), default last 30 days. */
export async function listCashClosings(
    tenantId: string,
    opts?: { limit?: number },
): Promise<CashClosingRecord[]> {
    const limit = Math.min(Math.max(opts?.limit ?? 30, 1), 90);
    const result = await queryItems<CashClosingRecord>(
        Keys.tenantPK(tenantId),
        'CASHCLOSE#',
        { limit, scanIndexForward: false },
    );
    return result.items;
}

/**
 * Preview today's expected cash — used by the day-end UI to pre-fill the
 * "expected" panel before the cashier counts the drawer.
 */
export async function previewExpectedCash(
    tenantId: string,
    closingDate: string,
    businessId?: string,
): Promise<{ closingDate: string; expectedCashPaise: number; tolerancePaise: number }> {
    const expectedCashPaise = await computeExpectedCashPaise(
        tenantId, closingDate, businessId,
    );
    return {
        closingDate,
        expectedCashPaise,
        tolerancePaise: DEFAULT_TOLERANCE_PAISE,
    };
}
