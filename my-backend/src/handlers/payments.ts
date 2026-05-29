// ============================================================================
// Lambda Handler — Payments (Record & Retrieve) (DynamoDB)
// ============================================================================
// AUDIT FIXES APPLIED:
//   C-6: recordPayment is now fully atomic (single transactWrite)
//   H-6: listPayments uses DynamoDB-level pagination (cursor-based)
//   M-9: WebSocket event emitted after payment recording
//   H-9: Dashboard cache invalidated after payment
//   H-2: Audit logging for payment operations
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { Keys, queryItems, getItem, updateItem, transactWrite, TABLE_NAME } from '../config/dynamodb.config';
import { parseBody, parsePagination } from '../middleware/validation';
import { recordPaymentSchema } from '../schemas';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { withIdempotency } from '../middleware/idempotency';
import { logAudit } from '../middleware/audit';
import { invalidateCache } from '../utils/cache';
import { filterByUserAccess } from '../middleware/user-scope-guard';
import { recordRevision } from '../services/revision-history.service';
// UNS event_bus — task 14.9 migration of T-PAY-2 producer
import { emitUnsEvent } from '../notifications/event-bus';

/**
 * GET /payments?page=1&limit=20&status=&cursor=
 * H-6 FIX: Uses DynamoDB-level pagination via cursor instead of loading everything.
 */
export const listPayments = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CHARTERED_ACCOUNTANT, UserRole.CASHIER, UserRole.STAFF],
    async (event, _context, auth) => {
    const { page, limit } = parsePagination(event);
    const params = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    // Build filter expression
    const filterParts: string[] = ['(attribute_not_exists(isDeleted) OR isDeleted = :false)'];
    const exprValues: Record<string, any> = { ':false': false };
    const exprNames: Record<string, string> = {};

    if (params.status) {
        filterParts.push('#s = :status');
        exprValues[':status'] = params.status;
        exprNames['#s'] = 'status';
    }

    // Parse cursor from query params for DynamoDB pagination
    let exclusiveStartKey: Record<string, unknown> | undefined;
    if (params.cursor) {
        try {
            exclusiveStartKey = JSON.parse(Buffer.from(params.cursor, 'base64url').toString());
        } catch {
            return response.badRequest('Invalid cursor format');
        }
    }

    const result = await queryItems<Record<string, any>>(pk, 'INVOICE#', {
        filterExpression: filterParts.join(' AND '),
        expressionAttributeValues: exprValues,
        expressionAttributeNames: Object.keys(exprNames).length > 0 ? exprNames : undefined,
        limit: limit + 1, // Fetch one extra to detect if there's a next page
        exclusiveStartKey,
        scanIndexForward: false, // Newest first (SK is INVOICE#{id}, so approximate)
    });

    const items = result.items.slice(0, limit);

    // POST-REMEDIATION FIX #7: Cashiers see only their own invoices
    const scopedItems = filterByUserAccess(auth, items, 'createdBy');

    const hasMore = result.items.length > limit || !!result.lastKey;

    // Encode next cursor for the client
    let nextCursor: string | null = null;
    if (hasMore && result.lastKey) {
        nextCursor = Buffer.from(JSON.stringify(result.lastKey)).toString('base64url');
    }

    const rows = scopedItems.map(t => ({
        id: t.id, invoiceNumber: t.invoiceNumber, customerName: t.customerName,
        customerPhone: t.customerPhone, totalCents: t.totalCents, paidCents: t.paidCents,
        balanceCents: t.balanceCents, paymentMode: t.paymentMode, status: t.status,
        createdAt: t.createdAt,
    }));

    return response.success({
        items: rows,
        pagination: {
            page,
            limit,
            hasMore,
            nextCursor,
        },
    });
    },
);

/**
 * GET /payments/{id}
 */
export const getPayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CHARTERED_ACCOUNTANT, UserRole.CASHIER, UserRole.STAFF],
    async (event, _context, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Missing payment id');

    const pk = Keys.tenantPK(auth.tenantId);
    const invoice = await getItem<Record<string, any>>(pk, Keys.invoiceSK(id));

    if (!invoice || invoice.isDeleted) {
        return response.notFound('Payment');
    }

    // Fetch line items
    const lineItems = await queryItems<Record<string, any>>(Keys.invoiceLineItemPK(id), 'LINEITEM#');

    return response.success({
        ...invoice,
        items: lineItems.items.map(li => ({
            id: li.id, name: li.name, quantity: li.quantity,
            unit: li.unit, unitPriceCents: li.unitPriceCents,
            totalCents: li.totalCents, discountCents: li.discountCents || 0,
            taxCents: li.taxCents || 0,
        })),
    });
    },
);

/**
 * POST /payments — Record a payment against an existing invoice
 * C-6 FIX: Uses transactWrite for atomic paidCents + balanceCents + status update
 * M-9: Emits WebSocket event after payment
 * H-9: Invalidates dashboard cache
 */
export const recordPayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    withIdempotency(async (event, _context, auth) => {
        const parsed = parseBody(recordPaymentSchema, event);
        if (!parsed.success) return parsed.error;

        const { invoiceId, amountCents, paymentMode, notes } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);

        // Get current invoice
        const invoice = await getItem<Record<string, any>>(pk, Keys.invoiceSK(invoiceId));
        if (!invoice || invoice.isDeleted) {
            return response.notFound('Invoice');
        }

        if (invoice.status === 'paid') {
            return response.error(409, 'ALREADY_PAID', 'Invoice is already fully paid');
        }

        const totalCents = Number(invoice.totalCents) || 0;
        const currentPaid = Number(invoice.paidCents) || 0;
        const newPaid = currentPaid + amountCents;

        // Validate: prevent overpayment
        if (newPaid > totalCents) {
            return response.error(409, 'OVERPAYMENT',
                `Payment of ${amountCents} paise would exceed outstanding balance of ${totalCents - currentPaid} paise`);
        }

        const newBalance = Math.max(totalCents - newPaid, 0);
        let newStatus = 'pending';
        if (newPaid >= totalCents) newStatus = 'paid';
        else if (newPaid > 0) newStatus = 'partially_paid';

        const now = new Date().toISOString();
        const tableName = TABLE_NAME;
        const customerId: string | null = invoice.customerId || null;
        const udharTxnId = `udhar-${invoiceId}-${Date.now()}`;
        const paymentRecordId = `pay-${invoiceId}-${Date.now()}`;

        // BUG-CREDIT-LEDGER FIX: Single atomic transaction now also:
        //   1. Writes a UDHARTXN# 'received' entry tied to the invoice/customer
        //   2. Updates customer aggregate outstandingCents/outstandingBalanceCents/totalPaidCents
        //   3. Writes a PAYMENT# audit row so collections show on the payments register
        const transactItems: any[] = [
            {
                Update: {
                    TableName: tableName,
                    Key: { PK: pk, SK: Keys.invoiceSK(invoiceId) },
                    UpdateExpression:
                        'SET paidCents = :newPaid, balanceCents = :newBal, #s = :newStatus, ' +
                        'paymentMode = if_not_exists(paymentMode, :pm), updatedAt = :now' +
                        (notes ? ', notes = list_append(if_not_exists(notes, :emptyList), :noteItem)' : ''),
                    ConditionExpression:
                        '(attribute_not_exists(isDeleted) OR isDeleted = :false) ' +
                        'AND paidCents = :currentPaid',
                    ExpressionAttributeNames: { '#s': 'status' },
                    ExpressionAttributeValues: {
                        ':newPaid': newPaid,
                        ':newBal': newBalance,
                        ':newStatus': newStatus,
                        ':pm': paymentMode || 'cash',
                        ':now': now,
                        ':false': false,
                        ':currentPaid': currentPaid,
                        ...(notes ? { ':noteItem': [notes], ':emptyList': [] } : {}),
                    },
                },
            },
            {
                Put: {
                    TableName: tableName,
                    Item: {
                        PK: pk,
                        SK: `PAYMENT#${paymentRecordId}`,
                        entityType: 'PAYMENT',
                        id: paymentRecordId,
                        tenantId: auth.tenantId,
                        invoiceId,
                        customerId,
                        amountCents,
                        paymentMode: paymentMode || 'cash',
                        notes: notes || null,
                        status: 'posted',
                        recordedBy: auth.sub,
                        createdAt: now,
                        updatedAt: now,
                        isDeleted: false,
                    },
                },
            },
        ];

        if (customerId) {
            transactItems.push({
                Put: {
                    TableName: tableName,
                    Item: {
                        PK: pk,
                        SK: `UDHARTXN#${udharTxnId}`,
                        entityType: 'UDHAR_TXN',
                        id: udharTxnId,
                        tenantId: auth.tenantId,
                        udharPersonId: customerId,
                        type: 'received',
                        amountCents,
                        transactionDate: now,
                        notes: `Payment received against ${invoice.invoiceNumber || invoiceId}`,
                        relatedTransactionId: invoiceId,
                        relatedPaymentId: paymentRecordId,
                        createdBy: auth.sub,
                        isDeleted: false,
                        createdAt: now,
                    },
                },
            });
            transactItems.push({
                Update: {
                    TableName: tableName,
                    Key: { PK: pk, SK: Keys.customerSK(customerId) },
                    UpdateExpression:
                        'SET outstandingCents = if_not_exists(outstandingCents, :zero) - :amt, ' +
                        'outstandingBalanceCents = if_not_exists(outstandingBalanceCents, :zero) - :amt, ' +
                        'totalPaidCents = if_not_exists(totalPaidCents, :zero) + :amt, ' +
                        'lastPaymentAt = :now, updatedAt = :now',
                    ConditionExpression: 'attribute_exists(PK)',
                    ExpressionAttributeValues: {
                        ':amt': amountCents,
                        ':now': now,
                        ':zero': 0,
                    },
                },
            });
        }

        try {
            await transactWrite(transactItems);
        } catch (err: any) {
            if (err.name === 'TransactionCanceledException') {
                return response.error(409, 'CONCURRENT_MODIFICATION',
                    'Payment was modified by another request. Please refresh and retry.');
            }
            throw err;
        }
        await recordRevision(
            auth.tenantId,
            'payments',
            paymentRecordId,
            'create',
            auth.sub,
            null,
            {
                id: paymentRecordId,
                invoiceId,
                customerId,
                amountCents,
                paymentMode: paymentMode || 'cash',
                status: 'posted',
                createdAt: now,
            },
            { source: 'payments.recordPayment' },
        );
        await recordRevision(
            auth.tenantId,
            'transactions',
            invoiceId,
            'update',
            auth.sub,
            invoice,
            {
                ...invoice,
                paidCents: newPaid,
                balanceCents: newBalance,
                status: newStatus,
                updatedAt: now,
            },
            { source: 'payments.recordPayment' },
        );

        // M-9: Emit WebSocket event for payment recorded
        try {
            const wsService = await import('../services/websocket.service');
            const { WSEventName } = await import('../types/websocket.types');
            wsService.emitEvent(auth.tenantId, WSEventName.PAYMENT_SUCCESS, {
                invoiceId,
                invoiceNumber: invoice.invoiceNumber,
                amountCents,
                newPaidCents: newPaid,
                newStatus,
                paymentMode: paymentMode || 'cash',
            }).catch(err => logger.warn('WS payment broadcast failed', { error: (err as Error).message }));
        } catch { /* WebSocket not critical */ }

        // UNS canonical emit (T-PAY-2: payment.invoice.received)
        emitUnsEvent({
            eventName: 'payment.invoice.received',
            category: 'payments',
            subCategory: 'invoice',
            priority: 'normal',
            actorId: auth.sub,
            targetId: invoiceId,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
                ...(customerId ? [{ user_id: customerId, role: 'customer' as const }] : []),
            ],
            payload: {
                tenantId: auth.tenantId,
                invoiceId,
                invoiceNumber: invoice.invoiceNumber,
                customerId: customerId ?? null,
                amountCents,
                newPaidCents: newPaid,
                newStatus,
                paymentMode: paymentMode || 'cash',
                paymentRecordId,
            },
            sourceModule: 'my-backend/src/handlers/payments.ts',
            dedupScopeFields: ['paymentRecordId'],
        }).catch(() => { /* non-fatal during migration window */ });

        // H-9: Invalidate dashboard cache
        invalidateCache(`dashboard:${auth.tenantId}`);

        // H-2: Audit log
        logAudit({
            action: 'PAYMENT_RECORDED',
            resource: 'payment',
            resourceId: invoiceId,
            metadata: { amountCents, newPaid, newStatus, paymentMode: paymentMode || 'cash' },
        }).catch(() => { });

        logger.info('Payment recorded', { invoiceId, amountCents, newPaid, newStatus });

        // H2 FIX: Calculate cash change if cashTenderedCents provided
        const body = JSON.parse(event.body || '{}');
        const cashTenderedCents = Number(body.cashTenderedCents) || 0;
        const changeDueCents = cashTenderedCents > amountCents
            ? cashTenderedCents - amountCents
            : 0;

        return response.success({
            id: invoiceId, invoiceNumber: invoice.invoiceNumber,
            status: newStatus, totalCents, paidCents: newPaid, balanceCents: newBalance,
            ...(cashTenderedCents > 0 ? { cashTenderedCents, changeDueCents } : {}),
        });
    })
);

