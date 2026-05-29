import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';

import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody, parseQuery, parsePagination } from '../middleware/validation';
import { Keys, getItem, putItem, queryAllItems, queryItems, updateItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { recordRevision } from '../services/revision-history.service';

const SUPPLIER_OPTS = {
    requiredFeature: FeatureKey.HARDWARE_CONTRACTOR_CREDIT,
};

// NOTE: Fields named *Cents in this file store values in paise (Indian subunit ÷100 = ₹).
// The naming predates the project-wide *Paisa convention. Wire format is unchanged.

const createSupplierSchema = z.object({
    name: z.string().min(1).max(200).trim(),
    phone: z.string().max(20).optional(),
    email: z.string().email().max(200).optional(),
    gstin: z.string().max(15).optional(),
    address: z.string().max(500).optional(),
    city: z.string().max(100).optional(),
    state: z.string().max(100).optional(),
    pincode: z.string().max(10).optional(),
    openingBalanceCents: z.number().int().min(0).default(0),
    paymentTermDays: z.number().int().min(0).max(365).optional(),
    notes: z.string().max(1000).optional(),
});

const updateSupplierSchema = createSupplierSchema.partial();

const listSupplierSchema = z.object({
    search: z.string().max(100).optional(),
});

const recordSupplierPaymentSchema = z.object({
    supplierId: z.string().uuid(),
    amountCents: z.number().int().positive(),
    paymentMode: z.enum(['cash', 'upi', 'bank_transfer', 'card', 'cheque']).default('cash'),
    referenceNo: z.string().max(100).optional(),
    notes: z.string().max(500).optional(),
});

const supplierAgeingQuerySchema = z.object({
    asOf: z.string().optional(),
});

const supplierLedgerQuerySchema = z.object({
    limit: z.coerce.number().int().min(1).max(500).optional(),
});

const supplierReminderQuerySchema = z.object({
    minAgeDays: z.coerce.number().int().min(1).max(730).optional(),
    minOutstandingCents: z.coerce.number().int().min(0).optional(),
});

const supplierReminderTriggerSchema = z.object({
    minAgeDays: z.number().int().min(1).max(730).default(30),
    minOutstandingCents: z.number().int().min(0).default(1000),
    dryRun: z.boolean().default(true),
    channels: z.array(z.enum(['whatsapp', 'email'])).default(['whatsapp']),
    quietHoursStart: z.number().int().min(0).max(23).default(22),
    quietHoursEnd: z.number().int().min(0).max(23).default(7),
});

async function computeSupplierReminderCandidates(
    tenantId: string,
    minAgeDays: number,
    minOutstandingCents: number,
): Promise<Array<{
    supplierId: string;
    name: string;
    phone: string | null;
    outstandingPayableCents: number;
    oldestOutstandingAgeDays: number;
}>> {
    const pk = Keys.tenantPK(tenantId);
    const asOf = Date.now();
    const msPerDay = 86_400_000;
    const suppliers = await queryAllItems<Record<string, any>>(pk, 'VENDOR#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
        maxPages: 20,
    });
    const purchases = await queryAllItems<Record<string, any>>(pk, 'PURCHASE#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
        maxPages: 40,
    });

    const oldestBySupplier = new Map<string, number>();
    for (const p of purchases) {
        const supplierId = String(p.vendorId || '');
        if (!supplierId) continue;
        const total = Number(p.totalAmount || 0);
        const paid = Number(p.paidAmount || 0);
        if (total - paid <= 0) continue;
        const d = new Date(String(p.purchaseDate || p.createdAt || '')).getTime();
        if (Number.isNaN(d)) continue;
        const age = Math.floor((asOf - d) / msPerDay);
        const prev = oldestBySupplier.get(supplierId) ?? -1;
        if (age > prev) oldestBySupplier.set(supplierId, age);
    }

    return suppliers
        .map((s) => {
            const outstandingCents = Number(s.outstandingPayableCents || 0);
            const oldestAgeDays = oldestBySupplier.get(String(s.id || '')) ?? 0;
            return {
                supplierId: String(s.id || ''),
                name: String(s.name || ''),
                phone: s.phone || null,
                outstandingPayableCents: outstandingCents,
                oldestOutstandingAgeDays: oldestAgeDays,
            };
        })
        .filter((x) =>
            x.outstandingPayableCents >= minOutstandingCents &&
            x.oldestOutstandingAgeDays >= minAgeDays,
        )
        .sort((a, b) => b.outstandingPayableCents - a.outstandingPayableCents);
}

function supplierToDto(s: Record<string, any>): Record<string, any> {
    return {
        id: s.id,
        name: s.name,
        phone: s.phone || null,
        email: s.email || null,
        gstin: s.gstin || null,
        address: s.address || null,
        city: s.city || null,
        state: s.state || null,
        pincode: s.pincode || null,
        openingBalanceCents: Number(s.openingBalanceCents || 0),
        outstandingPayableCents: Number(s.outstandingPayableCents || 0),
        paymentTermDays: Number(s.paymentTermDays || 0),
        notes: s.notes || null,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
    };
}

export const createSupplier = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createSupplierSchema, event);
        if (!parsed.success) return parsed.error;
        const data = parsed.data;

        const now = new Date().toISOString();
        const id = uuidv4();
        const pk = Keys.tenantPK(auth.tenantId);
        const sk = Keys.vendorSK(id);

        await putItem({
            PK: pk,
            SK: sk,
            entityType: 'VENDOR',
            id,
            tenantId: auth.tenantId,
            name: data.name,
            phone: data.phone || null,
            email: data.email || null,
            gstin: data.gstin || null,
            address: data.address || null,
            city: data.city || null,
            state: data.state || null,
            pincode: data.pincode || null,
            openingBalanceCents: data.openingBalanceCents || 0,
            outstandingPayableCents: data.openingBalanceCents || 0,
            paymentTermDays: data.paymentTermDays || 0,
            notes: data.notes || null,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        }, 'attribute_not_exists(PK)');

        await recordRevision(
            auth.tenantId,
            'suppliers',
            id,
            'create',
            auth.sub,
            null,
            { name: data.name, openingBalanceCents: data.openingBalanceCents || 0 },
            { source: 'suppliers.createSupplier' },
        );

        return response.success({ id }, 201);
    },
    SUPPLIER_OPTS,
);

export const updateSupplier = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const supplierId = event.pathParameters?.id;
        if (!supplierId) return response.badRequest('Missing supplier id');
        const parsed = parseBody(updateSupplierSchema, event);
        if (!parsed.success) return parsed.error;

        const pk = Keys.tenantPK(auth.tenantId);
        const sk = Keys.vendorSK(supplierId);
        const existing = await getItem<Record<string, any>>(pk, sk);
        if (!existing || existing.isDeleted) return response.notFound('Supplier');

        const data = parsed.data;
        const names: Record<string, string> = {};
        const values: Record<string, unknown> = { ':now': new Date().toISOString() };
        const sets: string[] = ['updatedAt = :now'];

        const writable = [
            'name',
            'phone',
            'email',
            'gstin',
            'address',
            'city',
            'state',
            'pincode',
            'paymentTermDays',
            'notes',
        ] as const;

        for (const field of writable) {
            if (data[field] === undefined) continue;
            names[`#${field}`] = field;
            values[`:${field}`] = data[field];
            sets.push(`#${field} = :${field}`);
        }
        if (data.openingBalanceCents !== undefined) {
            names['#openingBalanceCents'] = 'openingBalanceCents';
            values[':openingBalanceCents'] = data.openingBalanceCents;
            sets.push('#openingBalanceCents = :openingBalanceCents');
        }

        const updated = await updateItem(pk, sk, {
            updateExpression: `SET ${sets.join(', ')}`,
            expressionAttributeValues: values,
            expressionAttributeNames: Object.keys(names).length ? names : undefined,
            conditionExpression: 'attribute_exists(PK)',
        });

        await recordRevision(
            auth.tenantId,
            'suppliers',
            supplierId,
            'update',
            auth.sub,
            existing,
            updated || null,
            { source: 'suppliers.updateSupplier' },
        );

        return response.success({ id: supplierId });
    },
    SUPPLIER_OPTS,
);

export const listSuppliers = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const queryParsed = parseQuery(listSupplierSchema, event);
        if (!queryParsed.success) return queryParsed.error;
        const { page, limit, offset } = parsePagination(event);
        const search = (queryParsed.data.search || '').toLowerCase().trim();

        const all = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'VENDOR#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            scanIndexForward: false,
            maxPages: 20,
        });

        const filtered = all.filter((s) => {
            if (!search) return true;
            const haystack = `${s.name || ''} ${s.phone || ''} ${s.gstin || ''}`.toLowerCase();
            return haystack.includes(search);
        });
        filtered.sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')));

        const paged = filtered.slice(offset, offset + limit).map(supplierToDto);
        return response.paginated(paged, filtered.length, page, limit);
    },
    SUPPLIER_OPTS,
);

export const getSupplierPayablesSummary = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const suppliers = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'VENDOR#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            limit: 500,
            scanIndexForward: false,
        });

        const items = suppliers.items.map(supplierToDto).sort((a, b) =>
            Number(b.outstandingPayableCents || 0) - Number(a.outstandingPayableCents || 0),
        );

        const totalOutstandingPayableCents = items.reduce((sum, it) =>
            sum + Number(it.outstandingPayableCents || 0), 0);

        return response.success({
            items,
            totals: {
                supplierCount: items.length,
                totalOutstandingPayableCents,
            },
        });
    },
    SUPPLIER_OPTS,
);

export const recordSupplierPayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(recordSupplierPaymentSchema, event);
        if (!parsed.success) return parsed.error;
        const { supplierId, amountCents, paymentMode, referenceNo, notes } = parsed.data;

        const pk = Keys.tenantPK(auth.tenantId);
        const supplierSk = Keys.vendorSK(supplierId);
        const supplier = await getItem<Record<string, any>>(pk, supplierSk);
        if (!supplier || supplier.isDeleted) return response.notFound('Supplier');

        const currentOutstanding = Number(supplier.outstandingPayableCents || 0);
        if (amountCents > currentOutstanding) {
            return response.error(
                409,
                'SUPPLIER_OVERPAYMENT',
                `Payment exceeds outstanding payable (${currentOutstanding} cents)`,
            );
        }

        const paymentId = uuidv4();
        const now = new Date().toISOString();
        const newOutstanding = Math.max(currentOutstanding - amountCents, 0);

        await putItem({
            PK: pk,
            SK: `SUPPAY#${paymentId}`,
            entityType: 'SUPPLIER_PAYMENT',
            id: paymentId,
            tenantId: auth.tenantId,
            supplierId,
            supplierName: supplier.name || null,
            amountCents,
            paymentMode,
            referenceNo: referenceNo || null,
            notes: notes || null,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });

        const updated = await updateItem(pk, supplierSk, {
            updateExpression: 'SET outstandingPayableCents = :newOutstanding, updatedAt = :now',
            expressionAttributeValues: {
                ':newOutstanding': newOutstanding,
                ':now': now,
            },
            conditionExpression: 'attribute_exists(PK)',
        });

        await recordRevision(
            auth.tenantId,
            'suppliers',
            supplierId,
            'update',
            auth.sub,
            { outstandingPayableCents: currentOutstanding },
            { outstandingPayableCents: newOutstanding },
            { source: 'suppliers.recordSupplierPayment', paymentId, amountCents },
        );
        await recordRevision(
            auth.tenantId,
            'supplier_payments',
            paymentId,
            'create',
            auth.sub,
            null,
            {
                supplierId,
                amountCents,
                paymentMode,
                referenceNo: referenceNo || null,
                createdAt: now,
            },
            { source: 'suppliers.recordSupplierPayment' },
        );

        return response.success({
            id: paymentId,
            supplierId,
            amountCents,
            paymentMode,
            outstandingPayableCents: Number(updated?.outstandingPayableCents || newOutstanding),
        });
    },
    SUPPLIER_OPTS,
);

export const getSupplierPayableAgeing = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseQuery(supplierAgeingQuerySchema, event);
        if (!parsed.success) return parsed.error;
        const asOf = parsed.data.asOf ? new Date(parsed.data.asOf) : new Date();
        if (Number.isNaN(asOf.getTime())) return response.badRequest('Invalid asOf date');

        const purchases = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'PURCHASE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 20,
        });

        const buckets = {
            current: 0,
            d1to30: 0,
            d31to60: 0,
            d61to90: 0,
            d90plus: 0,
        };

        for (const p of purchases) {
            const total = Number(p.totalAmount || 0);
            const paid = Number(p.paidAmount || 0);
            const due = Math.max(total - paid, 0);
            if (due <= 0) continue;

            const dateStr = String(p.createdAt || p.orderDate || '');
            const createdAt = new Date(dateStr);
            if (Number.isNaN(createdAt.getTime())) continue;
            const ageDays = Math.floor((asOf.getTime() - createdAt.getTime()) / 86_400_000);
            const dueCents = Math.round(due * 100);

            if (ageDays <= 0) buckets.current += dueCents;
            else if (ageDays <= 30) buckets.d1to30 += dueCents;
            else if (ageDays <= 60) buckets.d31to60 += dueCents;
            else if (ageDays <= 90) buckets.d61to90 += dueCents;
            else buckets.d90plus += dueCents;
        }

        const totalCents =
            buckets.current +
            buckets.d1to30 +
            buckets.d31to60 +
            buckets.d61to90 +
            buckets.d90plus;

        return response.success({
            asOf: asOf.toISOString(),
            buckets,
            totalCents,
        });
    },
    SUPPLIER_OPTS,
);

export const getSupplierLedger = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const supplierId = event.pathParameters?.id;
        if (!supplierId) return response.badRequest('Missing supplier id');
        const queryParsed = parseQuery(supplierLedgerQuerySchema, event);
        if (!queryParsed.success) return queryParsed.error;
        const limit = queryParsed.data.limit ?? 200;

        const pk = Keys.tenantPK(auth.tenantId);
        const supplier = await getItem<Record<string, any>>(pk, Keys.vendorSK(supplierId));
        if (!supplier || supplier.isDeleted) return response.notFound('Supplier');

        const purchases = await queryAllItems<Record<string, any>>(pk, 'PURCHASE#', {
            filterExpression:
                '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND vendorId = :supplierId',
            expressionAttributeValues: {
                ':false': false,
                ':supplierId': supplierId,
            },
            maxPages: 30,
        });

        const payments = await queryAllItems<Record<string, any>>(pk, 'SUPPAY#', {
            filterExpression:
                '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND supplierId = :supplierId',
            expressionAttributeValues: {
                ':false': false,
                ':supplierId': supplierId,
            },
            maxPages: 30,
        });

        const entries: Array<Record<string, unknown>> = [];
        for (const p of purchases) {
            const total = Number(p.totalAmount || 0);
            const paid = Number(p.paidAmount || 0);
            const balanceRs = Math.max(total - paid, 0);
            entries.push({
                type: 'purchase_bill',
                id: String(p.id || ''),
                referenceNo: p.invoiceNumber || p.id || null,
                date: p.purchaseDate || p.createdAt || null,
                debitCents: Math.round(total * 100),
                creditCents: 0,
                balanceImpactCents: Math.round(balanceRs * 100),
                notes: p.notes || null,
            });
        }
        for (const p of payments) {
            entries.push({
                type: 'payment',
                id: String(p.id || ''),
                referenceNo: p.referenceNo || p.id || null,
                date: p.createdAt || null,
                debitCents: 0,
                creditCents: Number(p.amountCents || 0),
                balanceImpactCents: -Number(p.amountCents || 0),
                notes: p.notes || null,
                paymentMode: p.paymentMode || null,
            });
        }

        entries.sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')));
        const paged = entries.slice(0, limit);

        const totalPurchaseCents = entries
            .filter((e) => e.type === 'purchase_bill')
            .reduce((s, e) => s + Number(e.debitCents || 0), 0);
        const totalPaidCents = entries
            .filter((e) => e.type === 'payment')
            .reduce((s, e) => s + Number(e.creditCents || 0), 0);

        return response.success({
            supplier: supplierToDto(supplier),
            items: paged,
            totals: {
                totalPurchaseCents,
                totalPaidCents,
                outstandingPayableCents: Number(supplier.outstandingPayableCents || 0),
            },
            count: entries.length,
        });
    },
    SUPPLIER_OPTS,
);

export const getSupplierReminderCandidates = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseQuery(supplierReminderQuerySchema, event);
        if (!parsed.success) return parsed.error;
        const minAgeDays = parsed.data.minAgeDays ?? 30;
        const minOutstandingCents = parsed.data.minOutstandingCents ?? 1000;

        const items = await computeSupplierReminderCandidates(auth.tenantId, minAgeDays, minOutstandingCents);

        return response.success({
            criteria: { minAgeDays, minOutstandingCents },
            totals: {
                supplierCount: items.length,
                totalOutstandingPayableCents: items.reduce((s, x) => s + x.outstandingPayableCents, 0),
            },
            items,
        });
    },
    SUPPLIER_OPTS,
);

export const triggerSupplierReminders = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(supplierReminderTriggerSchema, event);
        if (!parsed.success) return parsed.error;
        const { minAgeDays, minOutstandingCents, dryRun, channels, quietHoursStart, quietHoursEnd } = parsed.data;

        const items = await computeSupplierReminderCandidates(auth.tenantId, minAgeDays, minOutstandingCents);

        let sent = 0;
        const failures: Array<{ supplierId: string; reason: string }> = [];
        if (!dryRun) {
            const hour = new Date().getUTCHours();
            const inQuietHours = quietHoursStart > quietHoursEnd
                ? (hour >= quietHoursStart || hour < quietHoursEnd)
                : (hour >= quietHoursStart && hour < quietHoursEnd);
            if (inQuietHours) {
                return response.success({
                    dryRun,
                    criteria: { minAgeDays, minOutstandingCents },
                    candidates: items.length,
                    sent: 0,
                    failures: [],
                    skipped: 'QUIET_HOURS',
                });
            }
            const whatsapp = await import('../services/whatsapp.service');
            for (const c of items) {
                const amount = Number(c.outstandingPayableCents || 0) / 100;
                if (channels.includes('whatsapp')) {
                    const phone = String(c.phone || '').trim();
                    if (!phone) {
                        failures.push({ supplierId: String(c.supplierId), reason: 'MISSING_PHONE' });
                    } else {
                        const ok = await whatsapp.sendTextMessage(
                            phone,
                            `Reminder: Outstanding payable Rs ${amount.toFixed(2)} pending. Kindly share payment timeline.`,
                        );
                        if (ok) sent += 1;
                        else failures.push({ supplierId: String(c.supplierId), reason: 'SEND_FAILED_WHATSAPP' });
                    }
                }
                if (channels.includes('email')) {
                    const supplier = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), Keys.vendorSK(String(c.supplierId)));
                    const email = String(supplier?.email || '').trim();
                    if (!email) {
                        failures.push({ supplierId: String(c.supplierId), reason: 'MISSING_EMAIL' });
                    } else {
                        // Placeholder adapter: mark as sent until SES adapter is wired.
                        sent += 1;
                    }
                }
            }
        }

        return response.success({
            dryRun,
            criteria: { minAgeDays, minOutstandingCents },
            channels,
            quietHoursStart,
            quietHoursEnd,
            candidates: items.length,
            sent,
            failures,
            items: dryRun ? items : undefined,
        });
    },
    SUPPLIER_OPTS,
);
