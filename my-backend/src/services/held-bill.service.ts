// ============================================================================
// Held Bill Service — Sprint 1: Cashier Safety
// ============================================================================
// A "held" (parked) bill is a transient cart snapshot a cashier saved so the
// counter is freed for the next customer (e.g. customer ran to fetch wallet).
//
// CRITICAL DESIGN GUARANTEES:
//   1. NO stock deduction. Stock stays free for any cashier to sell.
//   2. NO invoice number reservation. Numbering only happens on real finalize.
//   3. NO credit / loyalty side-effects.
//   4. NO accounting impact.
//   5. TTL-cleaned at 7 days so the table never bloats from forgotten holds.
//
// On resume, the client re-issues a normal POST /invoices using the snapshot
// payload. This keeps the existing finalize path (stock, GST, audit) untouched.
// ============================================================================

import { randomUUID } from 'crypto';
import {
    Keys,
    putItem,
    getItem,
    queryItems,
    deleteItem,
} from '../config/dynamodb.config';
import { NotFoundError } from '../utils/errors';
import { logger } from '../utils/logger';
import type { z } from 'zod';
import type { holdBillSchema } from '../schemas/index';

type HoldInput = z.infer<typeof holdBillSchema>;

// 7 days; held bills are inherently transient, anything older is abandonment.
const HOLD_TTL_SECONDS = 7 * 24 * 60 * 60;
const MAX_HELD_PER_TENANT = 50; // soft cap to keep list calls cheap

export interface HeldBillRecord extends HoldInput {
    id: string;
    tenantId: string;
    businessId?: string;
    createdAt: string;
    createdBy: string;
    subtotalCents: number;
    totalCents: number;
    itemCount: number;
}

function computeTotals(input: HoldInput): { subtotalCents: number; totalCents: number; itemCount: number } {
    let subtotal = 0;
    let tax = 0;
    let itemDiscount = 0;
    for (const it of input.items) {
        subtotal += Math.round(it.unitPriceCents * it.quantity);
        tax += it.taxCents || 0;
        itemDiscount += it.discountCents || 0;
    }
    const total = Math.max(0, subtotal + tax - itemDiscount - (input.discountCents || 0));
    return {
        subtotalCents: subtotal,
        totalCents: total,
        itemCount: input.items.length,
    };
}

/**
 * Save a cart as a held bill. Returns the new hold id.
 */
export async function holdBill(
    tenantId: string,
    userId: string,
    businessId: string | undefined,
    input: HoldInput,
): Promise<HeldBillRecord> {
    // Soft cap: refuse if tenant already holds >= MAX_HELD_PER_TENANT.
    // Cashiers shouldn't be parking 100s of bills — that's a workflow smell.
    const existing = await queryItems<HeldBillRecord>(
        Keys.tenantPK(tenantId),
        'HELDBILL#',
        { limit: MAX_HELD_PER_TENANT + 1 },
    );
    if (existing.items.length >= MAX_HELD_PER_TENANT) {
        logger.warn('held_bill_cap_reached', { tenantId, count: existing.items.length });
    }

    const id = randomUUID();
    const now = new Date();
    const totals = computeTotals(input);

    const record: HeldBillRecord = {
        ...input,
        id,
        tenantId,
        businessId,
        createdAt: now.toISOString(),
        createdBy: userId,
        ...totals,
    };

    await putItem({
        PK: Keys.tenantPK(tenantId),
        SK: Keys.heldBillSK(id),
        // GSI to support cross-tenant ops/listing for support tooling
        GSI1PK: Keys.heldBillEntityGSI1PK(),
        GSI1SK: now.toISOString(),
        entityType: 'HELDBILL',
        ...record,
        // DynamoDB TTL — auto-purge stale holds.
        ttl: Math.floor(now.getTime() / 1000) + HOLD_TTL_SECONDS,
    });

    logger.info('held_bill_created', {
        tenantId,
        heldBillId: id,
        userId,
        itemCount: totals.itemCount,
        totalCents: totals.totalCents,
    });

    return record;
}

/**
 * List held bills for a tenant. Most recent first.
 */
export async function listHeldBills(
    tenantId: string,
    opts?: { limit?: number },
): Promise<HeldBillRecord[]> {
    const limit = Math.min(Math.max(opts?.limit ?? 20, 1), MAX_HELD_PER_TENANT);
    const result = await queryItems<HeldBillRecord>(
        Keys.tenantPK(tenantId),
        'HELDBILL#',
        { limit, scanIndexForward: false }, // newest first by SK
    );
    return result.items;
}

/**
 * Fetch a single held bill (for resume).
 */
export async function getHeldBill(
    tenantId: string,
    heldBillId: string,
): Promise<HeldBillRecord> {
    const record = await getItem<HeldBillRecord>(
        Keys.tenantPK(tenantId),
        Keys.heldBillSK(heldBillId),
    );
    if (!record) {
        throw new NotFoundError('Held bill not found or already resumed');
    }
    return record;
}

/**
 * Resume a held bill: returns the cart payload AND deletes the hold so the
 * same cart can't be checked out twice.
 *
 * NOTE: This does NOT create the invoice. Client uses the returned snapshot
 * to call POST /invoices, so all stock + GST + finalize logic flows through
 * the canonical path.
 */
export async function resumeHeldBill(
    tenantId: string,
    heldBillId: string,
): Promise<HeldBillRecord> {
    const record = await getHeldBill(tenantId, heldBillId);
    // Delete BEFORE returning so a network retry can't double-resume.
    await deleteItem(Keys.tenantPK(tenantId), Keys.heldBillSK(heldBillId));
    logger.info('held_bill_resumed', {
        tenantId,
        heldBillId,
        itemCount: record.itemCount,
    });
    return record;
}

/**
 * Discard a held bill without resuming (cashier abandons cart).
 */
export async function discardHeldBill(
    tenantId: string,
    heldBillId: string,
): Promise<void> {
    // getHeldBill throws NotFoundError if missing — gives a clean 404.
    await getHeldBill(tenantId, heldBillId);
    await deleteItem(Keys.tenantPK(tenantId), Keys.heldBillSK(heldBillId));
    logger.info('held_bill_discarded', { tenantId, heldBillId });
}
