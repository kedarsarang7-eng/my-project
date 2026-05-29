// ============================================================================
// Lambda — Balance sheet, cash/fund flow, expense register (p12/p13)
// ============================================================================
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseQuery } from '../middleware/validation';
import { Keys, queryAllItems } from '../config/dynamodb.config';
import { AuthContext, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';

const FIN_OPTS = { requiredFeature: FeatureKey.ADVANCED_REPORTS };

const dateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

const rangeQuerySchema = z.object({
    from: dateSchema.optional(),
    to: dateSchema.optional(),
});

const asOfQuerySchema = z.object({
    asOf: dateSchema.optional(),
});

const expenseQuerySchema = rangeQuerySchema.extend({
    category: z.string().max(80).optional(),
});

function endOfDayIso(day: string): string {
    return `${day}T23:59:59.999Z`;
}

function startOfDayIso(day: string): string {
    return `${day}T00:00:00.000Z`;
}

function paymentTimestamp(p: Record<string, unknown>): string {
    return String(p.createdAt || p.paymentDate || p.recordedAt || '');
}

function expenseTimestamp(e: Record<string, unknown>): string {
    return String(e.expenseDate || e.date || e.createdAt || '');
}

function expenseAmountCents(e: Record<string, unknown>): number {
    const n = Number(e.amountCents ?? e.totalCents ?? e.amount ?? 0);
    return Number.isFinite(n) ? n : 0;
}

function isPettyExpense(e: Record<string, unknown>): boolean {
    if (e.isPettyCash === true) return true;
    const t = String(e.expenseType || e.type || '').toLowerCase();
    if (t === 'petty_cash' || t === 'petty') return true;
    const c = String(e.category || '').toLowerCase();
    return c === 'petty_cash' || c === 'petty cash';
}

/**
 * GET /reports/balance-sheet?asOf=YYYY-MM-DD
 * Simplified snapshot: collections to date, AR from open invoice balances, inventory from PRODUCT#.
 */
export const balanceSheetReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(asOfQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const asOf = parsed.data.asOf || new Date().toISOString().substring(0, 10);
        const endIso = endOfDayIso(asOf);
        const pk = Keys.tenantPK(auth.tenantId);

        const [invoices, payments, products, purchaseBills] = await Promise.all([
            queryAllItems<Record<string, unknown>>(pk, 'INVOICE#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
            queryAllItems<Record<string, unknown>>(pk, 'PAYMENT#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
            queryAllItems<Record<string, unknown>>(pk, 'PRODUCT#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
            queryAllItems<Record<string, unknown>>(pk, 'PBILL#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
        ]);

        let collectionsRegisteredCents = 0;
        for (const p of payments) {
            const ts = paymentTimestamp(p);
            if (ts && ts <= endIso) {
                collectionsRegisteredCents += Number(p.amountCents || 0);
            }
        }

        let accountsReceivableCents = 0;
        for (const inv of invoices) {
            const created = String(inv.createdAt || '');
            if (!created || created > endIso) continue;
            const bal = Number(inv.balanceCents || 0);
            const st = String(inv.status || '');
            if (bal > 0 && st !== 'voided' && st !== 'draft') accountsReceivableCents += bal;
        }

        let inventoryBookValueCents = 0;
        for (const pr of products) {
            const qty = Number(pr.currentStock ?? pr.stockQty ?? pr.quantityOnHand ?? 0) || 0;
            const unitCost = Number(pr.purchasePriceCents || pr.costPriceCents || 0) || 0;
            inventoryBookValueCents += Math.round(qty * unitCost);
        }

        // Compute accounts payable from unpaid purchase bills
        let accountsPayableCents = 0;
        for (const pb of purchaseBills) {
            const created = String(pb.createdAt || pb.purchaseDate || '');
            if (!created || created > endIso) continue;
            const st = String(pb.status || '');
            if (st === 'voided' || st === 'cancelled') continue;
            const balance = Number(pb.balanceCents || 0);
            if (balance > 0) accountsPayableCents += balance;
        }

        const totalAssetsCents = collectionsRegisteredCents + accountsReceivableCents + inventoryBookValueCents;
        const totalLiabilitiesCents = accountsPayableCents;
        const netWorthCents = totalAssetsCents - totalLiabilitiesCents;

        const notes = [
            'collectionsRegisteredCents sums PAYMENT# rows with createdAt (or paymentDate) on/before asOf',
            'inventoryBookValueCents uses current PRODUCT# rows (not historical asOf snapshot)',
            'accountsPayableCents sums unpaid PBILL# balances created on/before asOf',
        ];

        return response.success({
            asOf,
            assets: {
                collectionsRegisteredCents,
                accountsReceivableCents,
                inventoryBookValueCents,
                totalAssetsCents,
            },
            liabilities: {
                accountsPayableCents,
                totalLiabilitiesCents,
            },
            netWorthCents,
            notes,
        });
    },
    FIN_OPTS,
);

/**
 * GET /reports/cash-flow?from=&to=
 * Operating: payment inflows vs expense outflows in range.
 */
export const cashFlowReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(rangeQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 30 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const fromIso = startOfDayIso(from);
        const toIso = endOfDayIso(to);
        const pk = Keys.tenantPK(auth.tenantId);

        const [payments, expenses] = await Promise.all([
            queryAllItems<Record<string, unknown>>(pk, 'PAYMENT#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
            queryAllItems<Record<string, unknown>>(pk, 'EXPENSE#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
        ]);

        let operatingInflowsCents = 0;
        const byMode = new Map<string, number>();
        for (const p of payments) {
            const ts = paymentTimestamp(p);
            if (!ts || ts < fromIso || ts > toIso) continue;
            const amt = Number(p.amountCents || 0);
            operatingInflowsCents += amt;
            const mode = String(p.paymentMode || 'unknown');
            byMode.set(mode, (byMode.get(mode) || 0) + amt);
        }

        let operatingOutflowsCents = 0;
        const byCategory = new Map<string, number>();
        for (const e of expenses) {
            const ts = expenseTimestamp(e);
            if (!ts || ts < fromIso || ts > toIso) continue;
            const amt = expenseAmountCents(e);
            operatingOutflowsCents += amt;
            const cat = String(e.category || 'uncategorized');
            byCategory.set(cat, (byCategory.get(cat) || 0) + amt);
        }

        const netOperatingCashCents = operatingInflowsCents - operatingOutflowsCents;

        return response.success({
            period: { from, to },
            operating: {
                inflowsCents: operatingInflowsCents,
                outflowsCents: operatingOutflowsCents,
                netOperatingCashCents,
                inflowsByPaymentMode: Object.fromEntries(byMode),
                outflowsByExpenseCategory: Object.fromEntries(byCategory),
            },
            investing: { note: 'Capex / asset purchases not classified yet' },
            financing: { note: 'Loans / equity movements not tracked yet' },
        });
    },
    FIN_OPTS,
);

/**
 * GET /reports/fund-flow?from=&to=
 * Sources vs applications (same operating window; split for MIS dashboards).
 */
export const fundFlowReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(rangeQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 30 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const fromIso = startOfDayIso(from);
        const toIso = endOfDayIso(to);
        const pk = Keys.tenantPK(auth.tenantId);

        const [payments, expenses] = await Promise.all([
            queryAllItems<Record<string, unknown>>(pk, 'PAYMENT#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
            queryAllItems<Record<string, unknown>>(pk, 'EXPENSE#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                maxPages: 40,
            }),
        ]);

        let sourcesCents = 0;
        for (const p of payments) {
            const ts = paymentTimestamp(p);
            if (!ts || ts < fromIso || ts > toIso) continue;
            sourcesCents += Number(p.amountCents || 0);
        }

        let applicationsCents = 0;
        const applicationsByCategory = new Map<string, number>();
        for (const e of expenses) {
            const ts = expenseTimestamp(e);
            if (!ts || ts < fromIso || ts > toIso) continue;
            const amt = expenseAmountCents(e);
            applicationsCents += amt;
            const cat = String(e.category || 'uncategorized');
            applicationsByCategory.set(cat, (applicationsByCategory.get(cat) || 0) + amt);
        }

        const netFundFlowCents = sourcesCents - applicationsCents;

        return response.success({
            period: { from, to },
            sources: {
                totalCents: sourcesCents,
                note: 'Primarily customer collections (PAYMENT#) in period',
            },
            applications: {
                totalCents: applicationsCents,
                byCategory: Object.fromEntries(applicationsByCategory),
                note: 'Expense rows (EXPENSE#); capex classification future',
            },
            netFundFlowCents,
        });
    },
    FIN_OPTS,
);

/**
 * GET /reports/expense-register?from=&to=&category=
 */
export const expenseRegisterReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(expenseQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 90 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const fromIso = startOfDayIso(from);
        const toIso = endOfDayIso(to);
        const catFilter = parsed.data.category?.toLowerCase();
        const pk = Keys.tenantPK(auth.tenantId);

        const expenses = await queryAllItems<Record<string, unknown>>(pk, 'EXPENSE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        const rows = expenses
            .filter((e) => {
                const ts = expenseTimestamp(e);
                if (!ts || ts < fromIso || ts > toIso) return false;
                if (catFilter) {
                    const c = String(e.category || '').toLowerCase();
                    if (!c.includes(catFilter)) return false;
                }
                return true;
            })
            .sort((a, b) => expenseTimestamp(b).localeCompare(expenseTimestamp(a)))
            .map((e) => ({
                id: e.id,
                expenseDate: expenseTimestamp(e).substring(0, 10),
                category: e.category ?? null,
                amountCents: expenseAmountCents(e),
                paymentMode: e.paymentMode ?? null,
                vendorName: e.vendorName ?? e.vendor ?? null,
                notes: e.notes ?? e.description ?? null,
                expenseType: e.expenseType ?? null,
            }));

        const totalCents = rows.reduce((s, r) => s + r.amountCents, 0);

        return response.success({
            period: { from, to },
            filter: { category: parsed.data.category || null },
            totals: { expenseCount: rows.length, totalCents },
            items: rows,
        });
    },
    FIN_OPTS,
);

/**
 * GET /reports/petty-cash?from=&to=
 * Subset of EXPENSE# flagged petty (category / type / isPettyCash).
 */
export const pettyCashReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(rangeQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 30 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const fromIso = startOfDayIso(from);
        const toIso = endOfDayIso(to);
        const pk = Keys.tenantPK(auth.tenantId);

        const expenses = await queryAllItems<Record<string, unknown>>(pk, 'EXPENSE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        const petty = expenses.filter((e) => {
            const ts = expenseTimestamp(e);
            if (!ts || ts < fromIso || ts > toIso) return false;
            return isPettyExpense(e);
        });

        const items = petty
            .sort((a, b) => expenseTimestamp(b).localeCompare(expenseTimestamp(a)))
            .map((e) => ({
                id: e.id,
                expenseDate: expenseTimestamp(e).substring(0, 10),
                amountCents: expenseAmountCents(e),
                category: e.category ?? null,
                paymentMode: e.paymentMode ?? null,
                notes: e.notes ?? e.description ?? null,
            }));

        const totalCents = items.reduce((s, r) => s + r.amountCents, 0);

        return response.success({
            period: { from, to },
            totals: { transactionCount: items.length, totalCents },
            items,
            matchNote: 'Includes rows with isPettyCash, expenseType petty_cash, or category petty_cash',
        });
    },
    FIN_OPTS,
);
