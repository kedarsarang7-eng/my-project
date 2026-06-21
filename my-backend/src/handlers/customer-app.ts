// ============================================================================
// Lambda Handler — Customer Companion App (DynamoDB)
// ============================================================================
// Part 4 — Customer Mobile App Integration.
//
// SECURITY: every handler here is restricted to UserRole.CUSTOMER — a dedicated
// Cognito group separate from business-owner/staff roles. The calling customer
// is identified SOLELY from the verified JWT (auth.sub → linked customer via
// phone). No client-supplied customerId is ever trusted for authorization.
// All queries are scoped to the customer's tenant partition AND filtered to
// records belonging to that customer only.
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, queryItems, queryAllItems, putItem, getItem, updateItem } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, UserRole } from '../types/tenant.types';
import * as schemas from '../schemas/mobile.schema';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
import { StorageService } from '../services/storage.service';

/**
 * Resolve the linked CUSTOMER# entity (if any) for the authenticated app user.
 *
 * The link is by phone number (the user's Cognito account phone ↔ the shop's
 * customer record phone). Returns the customer record or null. The returned
 * customerId is the ONLY trusted identity for downstream queries — it is never
 * read from client input.
 */
async function resolveLinkedCustomer(
    pk: string,
    auth: AuthContext,
): Promise<Record<string, any> | null> {
    const user = await getItem<Record<string, any>>(pk, Keys.userSK(auth.sub));
    const phone = user?.phone;
    if (!phone) return null;

    const customers = await queryItems<Record<string, any>>(pk, 'CUSTOMER#', {
        filterExpression: 'phone = :phone AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':phone': phone, ':false': false },
        limit: 1,
    });
    return customers.items.length > 0 ? customers.items[0] : null;
}

/**
 * GET /customer/ledger — Udhar balance
 */
export const getMyLedger = authorizedHandler([UserRole.CUSTOMER], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);

    // Find linked udhar account by user sub
    const user = await getItem<Record<string, any>>(pk, Keys.userSK(auth.sub));
    if (!user?.phone) return response.success({ balanceCents: 0, transactions: [] });

    // Find udhar person by phone
    const udharPeople = await queryItems<Record<string, any>>(pk, 'UDHARPERSON#', {
        filterExpression: 'phone = :phone AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':phone': user.phone, ':true': true, ':false': false },
        limit: 1,
    });

    if (!udharPeople.items.length) return response.success({ balanceCents: 0, transactions: [] });

    const udharPerson = udharPeople.items[0];

    // Fetch transactions
    const txns = await queryItems<Record<string, any>>(pk, `UDHARTXN#`, {
        filterExpression: 'udharPersonId = :uid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':uid': udharPerson.id, ':false': false },
    });

    const sortedTxns = txns.items
        .sort((a, b) => (b.transactionDate || '').localeCompare(a.transactionDate || ''))
        .slice(0, 50)
        .map(t => ({
            id: t.id, type: t.type, amountCents: t.amountCents,
            transactionDate: t.transactionDate, notes: t.notes,
        }));

    return response.success({
        balanceCents: udharPerson.totalBalanceCents || 0,
        transactions: sortedTxns,
    });
});

/**
 * POST /customer/orders — Place order
 */
export const placeOrder = authorizedHandler([UserRole.CUSTOMER], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.customerOrderSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        let totalCents = 0;
        const txnId = crypto.randomUUID();
        const invoiceNumber = `ORD-${Date.now().toString().slice(-6)}`;

        // Calculate totals and create line items
        for (const item of body.items) {
            const product = await getItem<Record<string, any>>(pk, Keys.productSK(item.inventoryId));
            if (!product || !product.isActive || product.isDeleted) throw new Error(`Item ${item.inventoryId} unavailable`);

            const price = Number(product.salePriceCents) || 0;
            const lineTotal = price * item.quantity;
            totalCents += lineTotal;

            await putItem({
                PK: Keys.invoiceLineItemPK(txnId), SK: Keys.lineItemSK(crypto.randomUUID()),
                entityType: 'LINEITEM', tenantId: auth.tenantId, transactionId: txnId,
                name: product.name, inventoryId: item.inventoryId,
                quantity: item.quantity, unitPriceCents: price, totalCents: lineTotal,
                createdAt: now,
            });
        }

        // Create invoice
        await putItem({
            PK: pk, SK: Keys.invoiceSK(txnId),
            entityType: 'INVOICE', id: txnId, tenantId: auth.tenantId,
            invoiceNumber, type: 'sale', status: 'pending',
            totalCents, paidCents: 0, balanceCents: totalCents,
            paymentMode: 'cash', customerId: auth.sub,
            createdBy: 'CUSTOMER_APP', isDeleted: false,
            createdAt: now, updatedAt: now,
        });

        // Create booking
        await putItem({
            PK: pk, SK: `BOOKING#${crypto.randomUUID()}`,
            entityType: 'BOOKING', tenantId: auth.tenantId,
            customerId: auth.sub, bookingDate: now, bookingType: 'delivery',
            status: 'pending', totalAmountCents: totalCents,
            notes: body.orderNotes || `Deliver to: ${body.deliveryAddress}`,
            createdAt: now,
        });

        // Broadcast
        wsService.broadcastToStaff(auth.tenantId, WSEventName.ORDER_CREATED, {
            orderId: txnId, invoiceNumber, totalAmountCents: totalCents,
            customerId: auth.sub, itemCount: body.items.length,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        return response.success({ message: 'Order placed successfully', orderId: txnId, totalAmountCents: totalCents }, 201);
    } catch (err: any) {
        logger.error('Order placement failed', { error: err.message });
        return response.internalError(err.message || 'Failed to place order');
    }
});

/**
 * GET /customer/prescriptions
 */
export const getMyPrescriptions = authorizedHandler([UserRole.CUSTOMER], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);

    try {
        // Find patient by user phone
        const user = await getItem<Record<string, any>>(pk, Keys.userSK(auth.sub));
        if (!user?.phone) return response.success([]);

        const patients = await queryItems<Record<string, any>>(pk, 'PATIENT#', {
            filterExpression: 'phone = :phone AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':phone': user.phone, ':false': false },
            limit: 1,
        });

        if (!patients.items.length) return response.success([]);
        const patientId = patients.items[0].id;

        // Get prescriptions for this patient
        const prescriptions = await queryItems<Record<string, any>>(pk, 'PRESCRIPTION#', {
            filterExpression: 'patientId = :pid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':pid': patientId, ':false': false },
        });

        // Enrich with visit/doctor info
        const result = await Promise.all(prescriptions.items.map(async p => {
            const visit = p.visitId ? await getItem<Record<string, any>>(pk, `VISIT#${p.visitId}`) : null;
            let doctorName = '';
            if (visit?.doctorId) {
                const doctor = await getItem<Record<string, any>>(pk, `DOCTOR#${visit.doctorId}`);
                doctorName = doctor?.name || '';
            }
            return {
                prescriptionId: p.id, visitId: p.visitId, notes: p.notes,
                nextVisitDate: p.nextVisitDate, visitDate: visit?.visitDate,
                doctorName,
            };
        }));

        result.sort((a, b) => (b.visitDate || '').localeCompare(a.visitDate || ''));
        return response.success(result);
    } catch (err) {
        logger.error('Failed to fetch prescriptions', { error: err });
        return response.internalError();
    }
});

/**
 * GET /customer/fuel-fills — pump fill history for mobile (linked CUSTOMER by phone)
 */
export const getMyFillHistory = authorizedHandler([UserRole.CUSTOMER], async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const user = await getItem<Record<string, unknown>>(pk, Keys.userSK(auth.sub));
    const phoneRaw = user && typeof user === 'object' && 'phone' in user ? (user as { phone?: string }).phone : undefined;
    if (!phoneRaw) return response.success({ items: [], total: 0 });

    const limit = Math.min(200, Math.max(1, parseInt(event.queryStringParameters?.limit || '50', 10) || 50));

    const customers = await queryItems<Record<string, unknown>>(pk, 'CUSTOMER#', {
        filterExpression: 'phone = :phone AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':phone': phoneRaw, ':false': false },
        limit: 1,
    });
    if (!customers.items.length) return response.success({ items: [], total: 0 });

    const customerId = String((customers.items[0] as { id?: string }).id || '');
    const phone = String(phoneRaw);

    const invoices = await queryAllItems<Record<string, unknown>>(pk, 'INVOICE#', {
        filterExpression: '(customerId = :cid OR customerPhone = :phone) AND #t = :sale AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeNames: { '#t': 'type' },
        expressionAttributeValues: { ':cid': customerId, ':phone': phone, ':sale': 'sale', ':false': false },
    });

    const sorted = invoices
        .filter((inv) => {
            const row = inv as Record<string, unknown>;
            return Number(row.volumeLiters || 0) > 0;
        })
        .sort((a, b) => {
            const da = String((a as { saleDate?: string }).saleDate || (a as { createdAt?: string }).createdAt || '');
            const db = String((b as { saleDate?: string }).saleDate || (b as { createdAt?: string }).createdAt || '');
            return db.localeCompare(da);
        });

    const fills = sorted.slice(0, limit).map((inv) => {
        const row = inv as Record<string, unknown>;
        const meta = row.metadata as Record<string, unknown> | undefined;
        return {
            id: row.id,
            invoiceNumber: row.invoiceNumber ?? null,
            saleDate: row.saleDate || (typeof row.createdAt === 'string' ? row.createdAt.substring(0, 10) : null),
            fuelType: String(row.fuelType || row.productType || meta?.productType || ''),
            volumeLiters: Math.round(Number(row.volumeLiters || 0) * 1000) / 1000,
            vehicleNumber: row.vehicleNumber ?? null,
            totalCents: Number(row.totalCents || 0),
            paymentMode: row.paymentMode ?? null,
        };
    });

    return response.success({ items: fills, total: sorted.length });
});

// ============================================================================
// Part 4 — Customer invoice & statement access (mobile app integration)
// ============================================================================

/**
 * GET /customer/invoices — list the calling customer's OWN invoices + dues.
 *
 * The customer identity is resolved from the JWT (auth.sub → linked customer).
 * Invoices are filtered to that customerId only — a customer can never see
 * another customer's invoices even within the same tenant.
 */
export const getMyInvoices = authorizedHandler([UserRole.CUSTOMER], async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const customer = await resolveLinkedCustomer(pk, auth);
    if (!customer) return response.success({ items: [], summary: { outstandingCents: 0, totalBilledCents: 0, totalPaidCents: 0 } });

    const limit = Math.min(100, Math.max(1, parseInt(event.queryStringParameters?.limit || '50', 10) || 50));
    const customerId = String(customer.id);
    const phone = String(customer.phone || '');

    const invoices = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
        filterExpression: '(customerId = :cid OR customerPhone = :phone) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':cid': customerId, ':phone': phone, ':false': false },
        maxPages: 10,
    });

    const sorted = invoices
        .filter((inv) => String(inv.status || '').toLowerCase() !== 'voided')
        .sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));

    let totalBilled = 0, totalPaid = 0, outstanding = 0;
    for (const inv of invoices) {
        totalBilled += Number(inv.totalCents || 0);
        totalPaid += Number(inv.paidCents || 0);
        outstanding += Number(inv.balanceCents || 0);
    }
    if (outstanding < 0) outstanding = 0;

    const items = sorted.slice(0, limit).map((inv) => ({
        id: inv.id,
        invoiceNumber: inv.invoiceNumber ?? null,
        createdAt: inv.createdAt ?? null,
        status: inv.status ?? 'pending',
        totalCents: Number(inv.totalCents || 0),
        paidCents: Number(inv.paidCents || 0),
        balanceCents: Number(inv.balanceCents || 0),
        paymentMode: inv.paymentMode ?? null,
        hasPdf: Boolean(inv.pdfKey),
    }));

    return response.success({
        items,
        summary: { outstandingCents: outstanding, totalBilledCents: totalBilled, totalPaidCents: totalPaid },
    });
});

/**
 * GET /customer/invoices/{id}/pdf — short-lived pre-signed S3 URL for the
 * calling customer's OWN invoice PDF.
 *
 * CRITICAL: ownership is verified before signing. The invoice must belong to
 * the resolved customer (customerId match). A customer requesting another
 * customer's invoice id gets 404, never a URL. S3 access is only ever via
 * these time-limited (5-min) pre-signed URLs scoped to the owned object.
 */
export const getMyInvoicePdf = authorizedHandler([UserRole.CUSTOMER], async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const invoiceId = event.pathParameters?.id;
    if (!invoiceId) return response.badRequest('Missing invoice id');

    const pk = Keys.tenantPK(auth.tenantId);
    const customer = await resolveLinkedCustomer(pk, auth);
    if (!customer) return response.notFound('Invoice');

    const customerId = String(customer.id);
    const phone = String(customer.phone || '');

    const invoice = await getItem<Record<string, any>>(pk, Keys.invoiceSK(invoiceId));
    // Ownership gate: the invoice must belong to THIS customer.
    const owned =
        invoice &&
        !invoice.isDeleted &&
        (String(invoice.customerId || '') === customerId ||
            (phone && String(invoice.customerPhone || '') === phone));
    if (!owned) return response.notFound('Invoice');

    // No PDF generated yet → tell the client (it can request generation).
    const pdfKey = invoice.pdfKey;
    if (!pdfKey) {
        return response.success({ url: null, reason: 'PDF_NOT_GENERATED', expiresIn: 0 });
    }

    const storage = new StorageService();
    const url = await storage.getDownloadUrl(String(pdfKey));
    return response.success({ url, expiresIn: 300 }); // 5 minutes
});
