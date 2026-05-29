// ============================================================================
// Lambda Handler — Customers (CRUD + List + Ledger) (DynamoDB)
// ============================================================================
// C5 FIX: Customers are now first-class DynamoDB entities with dedicated CRUD.
// PK=TENANT#{tenantId}, SK=CUSTOMER#{uuid}
// GSI1PK=TENANT#{tenantId}, GSI1SK=PHONE#{phone}  — for phone lookup
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { parseBody, parseQuery } from '../middleware/validation';
import { createCustomerSchema, updateCustomerSchema } from '../schemas';
import { Keys, getItem, putItem, updateItem, queryItems, queryAllItems } from '../config/dynamodb.config';
import { parsePagination } from '../middleware/validation';
import * as response from '../utils/response';
import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import { recordRevision } from '../services/revision-history.service';

const reminderCandidatesQuerySchema = z.object({
    minAgeDays: z.coerce.number().int().min(1).max(730).optional(),
    minBalanceCents: z.coerce.number().int().min(0).optional(),
});

/**
 * POST /customers
 * Create a new customer entity in DynamoDB.
 */
export const createCustomer = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        const parsed = parseBody(createCustomerSchema, event);
        if (!parsed.success) return parsed.error;

        const { name, phone, email, gstin, address, city, state, pincode, creditLimitCents, notes } = parsed.data;

        // Check for duplicate phone number if provided
        if (phone) {
            const existing = await queryItems(
                Keys.tenantPK(auth.tenantId),
                'CUSTOMER#',
                {
                    filterExpression: 'phone = :phone AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                    expressionAttributeValues: { ':phone': phone, ':false': false },
                    limit: 1,
                }
            );
            if (existing.items.length > 0) {
                return response.error(409, 'DUPLICATE_PHONE', `Customer with phone ${phone} already exists`);
            }
        }

        const customerId = uuid();
        const now = new Date().toISOString();
        const pk = Keys.tenantPK(auth.tenantId);
        const sk = Keys.customerSK(customerId);

        const customer = {
            PK: pk,
            SK: sk,
            entityType: 'CUSTOMER',
            id: customerId,
            tenantId: auth.tenantId,
            name,
            phone: phone || null,
            email: email || null,
            gstin: gstin || null,
            address: address || null,
            city: city || null,
            state: state || null,
            pincode: pincode || null,
            creditLimitCents: creditLimitCents || 0,
            // Mirror the same value in both legacy and new field names so credit
            // enforcement can read either one without silent drift.
            outstandingCents: 0,
            outstandingBalanceCents: 0,
            totalBilledCents: 0,
            totalPaidCents: 0,
            // Optional rolling-window credit policy (BUG-CREDIT-LIMIT-DAYS/BILLS FIX)
            creditMaxAgeDays: parsed.data.creditMaxAgeDays ?? null,
            creditMaxOpenBills: parsed.data.creditMaxOpenBills ?? null,
            notes: notes || null,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
            // GSI1 for phone lookup
            ...(phone ? {
                GSI1PK: pk,
                GSI1SK: Keys.phoneGSI1SK(phone),
            } : {}),
        };

        await putItem(customer, 'attribute_not_exists(PK)');
        await recordRevision(
            auth.tenantId,
            'customers',
            customerId,
            'create',
            auth.sub,
            null,
            customer,
            { source: 'customers.createCustomer' },
        );

        return response.success({
            id: customerId,
            name,
            phone,
            email,
            gstin,
            address,
            city,
            state,
            pincode,
            creditLimitCents: creditLimitCents || 0,
            outstandingCents: 0,
            createdAt: now,
        }, 201);
    }
);

/**
 * PUT /customers/{id}
 * Update an existing customer.
 */
export const updateCustomer = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const customerId = event.pathParameters?.id;
        if (!customerId) return response.badRequest('Missing customer id');

        const parsed = parseBody(updateCustomerSchema, event);
        if (!parsed.success) return parsed.error;

        const pk = Keys.tenantPK(auth.tenantId);
        const sk = Keys.customerSK(customerId);

        // Verify customer exists
        const existing = await getItem<Record<string, any>>(pk, sk);
        if (!existing || existing.isDeleted) {
            return response.notFound('Customer');
        }

        // Build dynamic update expression
        const updates: string[] = ['updatedAt = :now'];
        const values: Record<string, any> = { ':now': new Date().toISOString(), ':false': false };
        const names: Record<string, string> = {};

        const fields = ['name', 'phone', 'email', 'gstin', 'address', 'city', 'state', 'pincode', 'creditLimitCents', 'notes'] as const;
        for (const field of fields) {
            if (parsed.data[field] !== undefined) {
                const key = `#${field}`;
                const val = `:${field}`;
                names[key] = field;
                values[val] = parsed.data[field];
                updates.push(`${key} = ${val}`);
            }
        }

        // Update GSI1 if phone changed
        if (parsed.data.phone !== undefined) {
            updates.push('GSI1PK = :gsi1pk', 'GSI1SK = :gsi1sk');
            values[':gsi1pk'] = pk;
            values[':gsi1sk'] = Keys.phoneGSI1SK(parsed.data.phone);
        }

        const result = await updateItem(pk, sk, {
            updateExpression: `SET ${updates.join(', ')}`,
            expressionAttributeValues: values,
            expressionAttributeNames: Object.keys(names).length > 0 ? names : undefined,
            conditionExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
        });
        await recordRevision(
            auth.tenantId,
            'customers',
            customerId,
            'update',
            auth.sub,
            existing,
            result || null,
            { source: 'customers.updateCustomer' },
        );

        return response.success(result);
    }
);

/**
 * GET /customers/{id}
 * Get a single customer by ID.
 */
export const getCustomer = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER, UserRole.STAFF], async (event, _context, auth) => {
    const customerId = event.pathParameters?.id;
    if (!customerId) return response.badRequest('Missing customer id');

    const customer = await getItem<Record<string, any>>(
        Keys.tenantPK(auth.tenantId),
        Keys.customerSK(customerId)
    );
    if (!customer || customer.isDeleted) {
        return response.notFound('Customer');
    }

    return response.success({
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        gstin: customer.gstin,
        address: customer.address,
        city: customer.city,
        state: customer.state,
        pincode: customer.pincode,
        creditLimitCents: customer.creditLimitCents || 0,
        outstandingCents: customer.outstandingCents || 0,
        totalBilledCents: customer.totalBilledCents || 0,
        totalPaidCents: customer.totalPaidCents || 0,
        notes: customer.notes,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
    });
});

/**
 * DELETE /customers/{id}
 * Soft-delete a customer.
 * CRITICAL FIX: Added existence check (404), cascade protection, and audit trail.
 */
export const deleteCustomer = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        const customerId = event.pathParameters?.id;
        if (!customerId) return response.badRequest('Missing customer id');

        const pk = Keys.tenantPK(auth.tenantId);
        const sk = Keys.customerSK(customerId);

        // CRITICAL FIX: 404 for non-existent or already-deleted customer (idempotent)
        const before = await getItem<Record<string, any>>(pk, sk);
        if (!before || before.isDeleted) {
            return response.notFound('Customer');
        }

        // CRITICAL FIX: Cascade protection - check for unpaid invoices
        const unpaidInvoices = await queryItems<Record<string, any>>(
            pk, 'INVOICE#',
            {
                filterExpression: 'customerId = :cid AND #status <> :paid AND #status <> :voided AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: {
                    ':cid': customerId,
                    ':paid': 'paid',
                    ':voided': 'voided',
                    ':false': false,
                },
                expressionAttributeNames: { '#status': 'status' },
                limit: 1,
            }
        );
        if (unpaidInvoices.items.length > 0) {
            return response.error(
                409,
                'CUSTOMER_HAS_UNPAID_INVOICES',
                'Cannot delete customer with unpaid invoices. Please settle all invoices first.',
                { hasUnpaidInvoices: true }
            );
        }

        // CRITICAL FIX: Check for outstanding credit balance
        const outstandingCents = (before.outstandingCents || before.outstandingBalanceCents || 0);
        if (outstandingCents > 0) {
            return response.error(
                409,
                'CUSTOMER_HAS_OUTSTANDING_BALANCE',
                `Cannot delete customer with outstanding balance of ₹${(outstandingCents / 100).toFixed(2)}.`,
                { outstandingCents }
            );
        }

        await updateItem(pk, sk, {
            updateExpression: 'SET isDeleted = :true, deletedAt = :now, deletedBy = :actor',
            expressionAttributeValues: {
                ':true': true,
                ':now': new Date().toISOString(),
                ':false': false,
                ':actor': auth.sub,
            },
            conditionExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
        });
        await recordRevision(
            auth.tenantId,
            'customers',
            customerId,
            'delete',
            auth.sub,
            before,
            { ...before, isDeleted: true, deletedBy: auth.sub },
            { source: 'customers.deleteCustomer' },
        );

        return response.success({ deleted: true, customerId });
    }
);

/**
 * GET /customers
 * List all customers — uses CUSTOMER# entities (not invoice aggregation).
 * Falls back to invoice-based aggregation if no customer entities exist yet.
 */
export const listCustomers = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER, UserRole.STAFF], async (event, _context, auth) => {
    const { page, limit, offset } = parsePagination(event);
    const params = event.queryStringParameters || {};
    const search = (params.search || '').toLowerCase();

    // PRIMARY: Query dedicated CUSTOMER# entities
    const customers = await queryAllItems<Record<string, any>>(
        Keys.tenantPK(auth.tenantId), 'CUSTOMER#', {
            filterExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
            expressionAttributeValues: { ':false': false },
        }
    );

    let filtered = customers;
    if (search) {
        filtered = customers.filter(c =>
            (c.name || '').toLowerCase().includes(search) ||
            (c.phone || '').toLowerCase().includes(search) ||
            (c.email || '').toLowerCase().includes(search)
        );
    }

    // Sort by name
    filtered.sort((a, b) => (a.name || '').localeCompare(b.name || ''));

    const paged = filtered.slice(offset, offset + limit);
    return response.paginated(
        paged.map(c => ({
            id: c.id,
            name: c.name,
            phone: c.phone,
            email: c.email,
            gstin: c.gstin,
            creditLimitCents: c.creditLimitCents || 0,
            outstandingCents: c.outstandingCents || 0,
            totalBilledCents: c.totalBilledCents || 0,
            totalPaidCents: c.totalPaidCents || 0,
            createdAt: c.createdAt,
        })),
        filtered.length, page, limit
    );
});

/**
 * GET /customers/{id}/ledger
 * Customer ledger — all invoices for a specific customer.
 * FEATURE-E: Cursor-based pagination with full summary computation.
 */
export const getCustomerLedger = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER], async (event, _context, auth) => {
    const customerId = event.pathParameters?.id;
    if (!customerId) return response.badRequest('Missing customer id');
    const params = event.queryStringParameters || {};
    const limit = Math.min(Math.max(1, parseInt(params.limit || '20', 10) || 20), 200);

    const invoices = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'INVOICE#', {
        filterExpression: '(customerId = :cid OR customerPhone = :cid) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':cid': customerId, ':false': false },
    });

    // Sort newest first (descending by createdAt)
    const sorted = invoices.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    // Compute full summary from ALL invoices (not just current page)
    let totalBilled = 0, totalPaid = 0, totalBalance = 0;
    for (const inv of sorted) {
        totalBilled += Number(inv.totalCents || 0);
        totalPaid += Number(inv.paidCents || 0);
        totalBalance += Number(inv.balanceCents || 0);
    }

    // Cursor-based pagination: decode cursor to find start position
    let startIdx = 0;
    if (params.cursor) {
        try {
            const decoded = JSON.parse(Buffer.from(params.cursor, 'base64url').toString());
            const cursorId = decoded.id;
            const cursorDate = decoded.createdAt;
            const idx = sorted.findIndex(
                inv => inv.id === cursorId && inv.createdAt === cursorDate
            );
            if (idx >= 0) startIdx = idx + 1;
        } catch {
            return response.badRequest('Invalid cursor format');
        }
    }

    const paged = sorted.slice(startIdx, startIdx + limit);
    const hasMore = startIdx + limit < sorted.length;

    // Encode next cursor
    let nextCursor: string | null = null;
    if (hasMore && paged.length > 0) {
        const lastItem = paged[paged.length - 1];
        nextCursor = Buffer.from(JSON.stringify({
            id: lastItem.id,
            createdAt: lastItem.createdAt,
        })).toString('base64url');
    }

    return response.success({
        ledger: paged.map(i => ({
            id: i.id, invoice_number: i.invoiceNumber, customer_name: i.customerName,
            status: i.status, total_cents: i.totalCents, paid_cents: i.paidCents,
            balance_cents: i.balanceCents, payment_mode: i.paymentMode,
            created_at: i.createdAt, notes: i.notes,
        })),
        summary: {
            total_billed_cents: totalBilled,
            total_paid_cents: totalPaid,
            outstanding_cents: totalBalance,
        },
        pagination: {
            limit,
            hasMore,
            nextCursor,
            total: sorted.length,
        },
    });
});

/**
 * GET /customers/credit/consolidated?month=YYYY-MM
 * Monthly consolidated credit bills by customer/party.
 */
export const getMonthlyCreditConsolidated = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CHARTERED_ACCOUNTANT], async (event, _context, auth) => {
    const month = event.queryStringParameters?.month || new Date().toISOString().slice(0, 7);
    if (!/^\d{4}-\d{2}$/.test(month)) {
        return response.badRequest('Invalid month format. Use YYYY-MM');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    const invoices = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
        filterExpression: 'paymentMode IN (:udhar, :credit) AND begins_with(createdAt, :month) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: {
            ':udhar': 'udhar',
            ':credit': 'credit',
            ':month': month,
            ':false': false,
        },
    });

    const byCustomer = new Map<string, {
        customerId: string;
        customerName: string;
        customerPhone: string | null;
        invoiceCount: number;
        totalBilledCents: number;
        totalPaidCents: number;
        outstandingCents: number;
        invoices: Array<{
            id: string;
            invoiceNumber: string;
            createdAt: string;
            totalCents: number;
            paidCents: number;
            balanceCents: number;
        }>;
    }>();

    for (const inv of invoices) {
        const customerId = String(inv.customerId || inv.customerPhone || 'unknown');
        const current = byCustomer.get(customerId) || {
            customerId,
            customerName: String(inv.customerName || customerId),
            customerPhone: inv.customerPhone || null,
            invoiceCount: 0,
            totalBilledCents: 0,
            totalPaidCents: 0,
            outstandingCents: 0,
            invoices: [] as Array<{
                id: string;
                invoiceNumber: string;
                createdAt: string;
                totalCents: number;
                paidCents: number;
                balanceCents: number;
            }>,
        };

        const totalCents = Number(inv.totalCents || 0);
        const paidCents = Number(inv.paidCents || 0);
        const balanceCents = Number(inv.balanceCents || 0);
        current.invoiceCount += 1;
        current.totalBilledCents += totalCents;
        current.totalPaidCents += paidCents;
        current.outstandingCents += balanceCents;
        current.invoices.push({
            id: String(inv.id),
            invoiceNumber: String(inv.invoiceNumber || inv.id),
            createdAt: String(inv.createdAt || ''),
            totalCents,
            paidCents,
            balanceCents,
        });
        byCustomer.set(customerId, current);
    }

    const items = Array.from(byCustomer.values()).sort((a, b) => b.outstandingCents - a.outstandingCents);
    const totals = items.reduce((acc, item) => {
        acc.partyCount += 1;
        acc.invoiceCount += item.invoiceCount;
        acc.totalBilledCents += item.totalBilledCents;
        acc.totalPaidCents += item.totalPaidCents;
        acc.outstandingCents += item.outstandingCents;
        return acc;
    }, { partyCount: 0, invoiceCount: 0, totalBilledCents: 0, totalPaidCents: 0, outstandingCents: 0 });

    return response.success({
        month,
        items,
        totals,
    });
});

/**
 * GET /customers/credit/reminder-candidates?minAgeDays=15&minBalanceCents=100
 * Lists credit/udhar parties with at least one open invoice aged ≥ threshold (p20 — data for SMS/cron).
 */
export const getCreditReminderCandidates = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER],
    async (event, _context, auth) => {
        const parsed = parseQuery(reminderCandidatesQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const minAgeDays = parsed.data.minAgeDays ?? 15;
        const minBalanceCents = parsed.data.minBalanceCents ?? 1;
        const pk = Keys.tenantPK(auth.tenantId);
        const msPerDay = 86_400_000;
        const now = Date.now();

        const invoices = await queryAllItems<Record<string, unknown>>(pk, 'INVOICE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        const agedOpen: Record<string, unknown>[] = [];
        for (const inv of invoices) {
            const row = inv as Record<string, unknown>;
            const bal = Number(row.balanceCents || 0);
            if (bal < minBalanceCents) continue;
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
            agedOpen.push(row);
        }

        const byCustomer = new Map<string, Record<string, unknown>[]>();
        for (const inv of agedOpen) {
            const cid = String((inv as { customerId?: string }).customerId || '');
            if (!cid) continue;
            const arr = byCustomer.get(cid) || [];
            arr.push(inv);
            byCustomer.set(cid, arr);
        }

        const items: Array<Record<string, unknown>> = [];
        for (const [customerId, invs] of byCustomer) {
            const customer = await getItem<Record<string, unknown>>(pk, Keys.customerSK(customerId));
            const outstandingCents = invs.reduce((s, i) => s + Number((i as { balanceCents?: number }).balanceCents || 0), 0);
            let maxAgeDays = 0;
            const invoiceRows = invs.map((i) => {
                const row = i as Record<string, unknown>;
                const ref = String(row.saleDate || row.createdAt || '');
                const dayAge = (now - new Date(ref).getTime()) / msPerDay;
                if (dayAge > maxAgeDays) maxAgeDays = dayAge;
                return {
                    id: row.id,
                    invoiceNumber: row.invoiceNumber ?? null,
                    balanceCents: Number(row.balanceCents || 0),
                    saleDate: row.saleDate ?? null,
                    createdAt: row.createdAt ?? null,
                    ageDays: Math.round(dayAge * 100) / 100,
                };
            });

            items.push({
                customerId,
                customerName: customer ? String((customer as { name?: string }).name || '') : null,
                phone: customer ? ((customer as { phone?: string }).phone ?? null) : null,
                outstandingCents,
                openInvoiceCount: invs.length,
                oldestOpenInvoiceAgeDays: Math.round(maxAgeDays * 100) / 100,
                invoices: invoiceRows.sort((a, b) => b.ageDays - a.ageDays),
            });
        }

        items.sort((a, b) => Number(b.outstandingCents || 0) - Number(a.outstandingCents || 0));

        const totalOutstandingCents = items.reduce((s, x) => s + Number(x.outstandingCents || 0), 0);

        return response.success({
            criteria: { minAgeDays, minBalanceCents },
            note: 'SMS/email scheduler not included — integrate with EventBridge + SNS/SES using this payload',
            totals: {
                partyCount: items.length,
                totalOutstandingCents,
            },
            items,
        });
    },
);
