import { config } from '../config/environment';
// ============================================================================
// Lambda Handler — Staff Sale Entry & QR Payment (DynamoDB)
// ============================================================================
// AUDIT FIXES APPLIED:
//   C-7: Staff sales now atomically deduct stock + create line items
//   BUG-PP-003: Server-side fuel price validation
//   BUG-PP-008: Credit limit enforcement for udhar sales
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, putItem, updateItem, getItem, transactWrite, TABLE_NAME } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType } from '../types/tenant.types';
import { staffSaleSchema, staffSaleQrSchema, staffSaleHistoryQuerySchema } from '../schemas/mobile.schema';
import * as response from '../utils/response';
import * as paymentOrderService from '../services/payment-order.service';
import { PriceValidationError, CreditLimitExceededError, NotFoundError } from '../utils/errors';
import { enforceUdharCreditLimit } from '../utils/credit-check.util';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
import { logAudit } from '../middleware/audit';
import { invalidateCache } from '../utils/cache';
import { normalizeVehicleNumber } from '../utils/vehicle.util';
import { recordRevision } from '../services/revision-history.service';

const PUMP_OPTS = { requiredBusinessType: BusinessType.PETROL_PUMP, requiredFeature: FeatureKey.PETROL_BASIC_SHIFT_ENTRY };

/**
 * POST /staff/sale — Record a fuel sale (cash, online, or udhar)
 * C-7 FIX: Now creates line items and deducts stock atomically via transactWrite.
 * BUG-PP-003 FIX: Server-side price validation for fuel types.
 * BUG-PP-008 FIX: Credit limit enforcement for udhar (credit) sales.
 */
export const createSale = authorizedHandler([], async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const valid = parseBody(staffSaleSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const tableName = TABLE_NAME;

    try {
        const saleId = crypto.randomUUID();
        const txnId = crypto.randomUUID();
        const lineItemId = crypto.randomUUID();
        let nextNum: number;
        try {
            const counterResult = await updateItem(
                pk,
                'COUNTER#INVOICE',
                {
                    updateExpression: 'SET #val = if_not_exists(#val, :zero) + :one, updatedAt = :now',
                    expressionAttributeNames: { '#val': 'counterValue' },
                    expressionAttributeValues: { ':zero': 0, ':one': 1, ':now': now },
                },
            );
            nextNum = (counterResult as any)?.counterValue;
        } catch (err) {
            throw new Error('Failed to generate invoice number');
        }
        const invoiceNumber = `INV-${nextNum.toString().padStart(6, '0')}`;
        const deviceId = event.headers?.['x-device-id'] || null;
        const paymentStatus = body.paymentMode === 'cash' ? 'paid' : (body.paymentMode === 'udhar' ? 'credit' : 'pending');

        // Look up staff name
        const user = await getItem<Record<string, any>>(pk, Keys.userSK(auth.sub));
        const staffName = user?.fullName || user?.name || auth.email || '';

        // C-7: Look up product for stock deduction (if productId is available in body)
        let productName = body.productType || 'fuel_sale';
        let productId: string | null = null;

        let cgstBp = 0, sgstBp = 0, igstBp = 0;

        // Try to find the fuel product by type for stock deduction + price validation
        let productQueryResult: { items: Record<string, any>[] } = { items: [] };
        if (body.nozzleId || body.productType) {
            productQueryResult = await queryItems<Record<string, any>>(pk, 'PRODUCT#', {
                filterExpression: 'productType = :pt AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':pt': body.productType || 'fuel', ':false': false },
                limit: 1,
            });
            if (productQueryResult.items.length > 0) {
                const p = productQueryResult.items[0];
                productId = p.id;
                productName = p.name || productName;
                cgstBp = Number(p.cgstRateBp) || 0;
                sgstBp = Number(p.sgstRateBp) || 0;
                igstBp = Number(p.igstRateBp) || 0;
            }
        }

        // ================================================================
        // BUG-PP-003: Server-side price validation for fuel product types
        // Validates amountCents against volumeLiters × salePriceCents ± ₹1
        // ================================================================
        const FUEL_TYPES = ['petrol', 'diesel', 'cng'];
        if (FUEL_TYPES.includes(body.productType) && body.volumeLiters && productQueryResult.items.length > 0) {
            const product = productQueryResult.items[0];
            const canonicalPriceCents = Number(product.salePriceCents || 0);

            if (canonicalPriceCents > 0) {
                const PRICE_TOLERANCE_CENTS = 100; // ±₹1
                const expectedTotalCents = Math.round(body.volumeLiters * canonicalPriceCents);

                if (Math.abs(body.amountCents - expectedTotalCents) > PRICE_TOLERANCE_CENTS) {
                    throw new PriceValidationError(
                        `Price mismatch: expected ₹${(expectedTotalCents / 100).toFixed(2)} ` +
                        `(${body.volumeLiters}L × ₹${(canonicalPriceCents / 100).toFixed(2)}/L), ` +
                        `received ₹${(body.amountCents / 100).toFixed(2)}.`,
                        {
                            expectedCents: expectedTotalCents,
                            receivedCents: body.amountCents,
                            toleranceCents: PRICE_TOLERANCE_CENTS,
                        },
                    );
                }
            }
        }

        // ================================================================
        // BUG-PP-008: Credit limit check for udhar sales
        // ================================================================
        if (body.paymentMode === 'udhar' && body.customerId) {
            await enforceUdharCreditLimit(auth.tenantId, body.customerId, body.amountCents);
        }

        // C-3 FIX: Calculate tax backward from the inclusive amount
        const totalTaxBp = cgstBp + sgstBp + igstBp;
        let taxableValueCents = body.amountCents;
        let cgstCents = 0, sgstCents = 0, igstCents = 0, taxCents = 0;

        if (totalTaxBp > 0) {
            taxableValueCents = Math.round(body.amountCents / (1 + (totalTaxBp / 10000)));
            cgstCents = Math.round(taxableValueCents * cgstBp / 10000);
            sgstCents = Math.round(taxableValueCents * sgstBp / 10000);
            igstCents = Math.round(taxableValueCents * igstBp / 10000);
            taxCents = cgstCents + sgstCents + igstCents;
            // Adjust to ensure exact total after rounding
            taxableValueCents = body.amountCents - taxCents;
        }

        // Build atomic transaction items
        const transactItems: any[] = [];

        // 1. Staff sale record
        transactItems.push({
            Put: {
                TableName: tableName,
                Item: {
                    PK: pk, SK: `STAFFSALE#${saleId}`,
                    entityType: 'STAFF_SALE', id: saleId, tenantId: auth.tenantId,
                    staffId: auth.sub, staffName, productType: body.productType,
                    amountCents: body.amountCents, paymentMode: body.paymentMode,
                    paymentStatus, vehicleNumber: body.vehicleNumber ? normalizeVehicleNumber(body.vehicleNumber) : null,
                    customerName: body.customerName || null, customerId: body.customerId || null,
                    nozzleId: body.nozzleId || null,
                    notes: body.notes || null, invoiceNumber, deviceId,
                    transactionId: txnId,
                    isDeleted: false, createdAt: now, updatedAt: now,
                },
            },
        });

        // 2. Invoice record (for unified reporting)
        transactItems.push({
            Put: {
                TableName: tableName,
                Item: {
                    PK: pk, SK: Keys.invoiceSK(txnId),
                    entityType: 'INVOICE', id: txnId, tenantId: auth.tenantId,
                    invoiceNumber, type: 'sale',
                    status: paymentStatus === 'paid' ? 'paid' : (body.paymentMode === 'udhar' ? 'completed' : 'draft'),
                    subtotalCents: taxableValueCents,
                    taxCents, cgstCents, sgstCents, igstCents,
                    discountCents: 0, roundOffCents: 0,
                    totalCents: body.amountCents,
                    paidCents: paymentStatus === 'paid' ? body.amountCents : 0,
                    balanceCents: paymentStatus === 'paid' ? 0 : body.amountCents,
                    paymentMode: body.paymentMode === 'cash' ? 'cash' : (body.paymentMode === 'udhar' ? 'udhar' : 'upi'),
                    customerId: body.customerId || null,
                    customerName: body.customerName || body.vehicleNumber || 'Walk-in',
                    createdBy: auth.sub, isDeleted: false,
                    vehicleNumber: body.vehicleNumber ? normalizeVehicleNumber(body.vehicleNumber) : null,
                    saleDate: now.substring(0, 10),
                    fuelType: body.productType,
                    volumeLiters: body.volumeLiters ?? null,
                    metadata: { source: 'staff_sale', staffSaleId: saleId, productType: body.productType, vehicleNumber: body.vehicleNumber },
                    createdAt: now, updatedAt: now,
                },
            },
        });

        // 3. C-7 FIX: Create line item (for unified report breakdowns)
        transactItems.push({
            Put: {
                TableName: tableName,
                Item: {
                    PK: Keys.invoiceLineItemPK(txnId),
                    SK: Keys.lineItemSK(lineItemId),
                    entityType: 'LINE_ITEM',
                    tenantId: auth.tenantId,
                    transactionId: txnId,
                    itemId: productId || saleId,
                    name: productName,
                    quantity: 1,
                    unit: body.productType === 'lub_oil' ? 'ltr' : 'ltr',
                    unitPriceCents: taxableValueCents,
                    totalCents: body.amountCents,
                    discountCents: 0,
                    taxableValueCents,
                    taxCents, cgstCents, sgstCents, igstCents,
                    hsnCode: null,
                    createdAt: now,
                },
            },
        });

        // 4. C-7 FIX: Stock deduction if product found
        if (productId) {
            transactItems.push({
                Update: {
                    TableName: tableName,
                    Key: { PK: pk, SK: Keys.productSK(productId) },
                    UpdateExpression: 'SET currentStock = currentStock - :qty, updatedAt = :now',
                    ConditionExpression: 'attribute_exists(PK) AND currentStock >= :qty',
                    ExpressionAttributeValues: { ':qty': 1, ':now': now },
                },
            });
        }

        // 5. BUG-PP-008 FIX: Udhar ledger entry (atomically with sale)
        if (body.paymentMode === 'udhar' && body.customerId) {
            transactItems.push({
                Put: {
                    TableName: tableName,
                    Item: {
                        PK: pk, SK: `UDHARTXN#${crypto.randomUUID()}`,
                        entityType: 'UDHAR_TXN', tenantId: auth.tenantId,
                        udharPersonId: body.customerId, type: 'given',
                        amountCents: body.amountCents, transactionDate: now,
                        notes: `Staff Sale - ${body.productType} ${body.vehicleNumber || ''}`.trim(),
                        relatedTransactionId: txnId, isDeleted: false, createdAt: now,
                    },
                },
            });
        }

        // Execute atomic transaction
        try {
            await transactWrite(transactItems);
        } catch (err: any) {
            if (err.name === 'TransactionCanceledException') {
                logger.warn('Staff sale transaction failed — possibly insufficient stock', { saleId, productId });
                return response.error(409, 'STOCK_INSUFFICIENT', 'Insufficient stock for this product');
            }
            throw err;
        }
        await recordRevision(
            auth.tenantId,
            'staff_sales_details',
            saleId,
            'create',
            auth.sub,
            null,
            {
                id: saleId,
                invoiceNumber,
                transactionId: txnId,
                amountCents: body.amountCents,
                paymentMode: body.paymentMode,
                paymentStatus,
                productType: body.productType,
                createdAt: now,
            },
            { source: 'staff-sale.createSale' },
        );
        await recordRevision(
            auth.tenantId,
            'transactions',
            txnId,
            'create',
            auth.sub,
            null,
            {
                id: txnId,
                invoiceNumber,
                totalCents: body.amountCents,
                paidCents: paymentStatus === 'paid' ? body.amountCents : 0,
                balanceCents: paymentStatus === 'paid' ? 0 : body.amountCents,
                status: paymentStatus === 'paid' ? 'paid' : (body.paymentMode === 'udhar' ? 'completed' : 'draft'),
                paymentMode: body.paymentMode === 'cash' ? 'cash' : (body.paymentMode === 'udhar' ? 'udhar' : 'upi'),
                createdAt: now,
            },
            { source: 'staff-sale.createSale' },
        );

        // Audit log
        logAudit({
            action: 'STAFF_SALE_CREATED',
            resource: 'staff_sale',
            resourceId: saleId,
            metadata: { invoiceNumber, amountCents: body.amountCents, productType: body.productType, paymentMode: body.paymentMode },
        }).catch(() => { });

        // Invalidate dashboard cache
        invalidateCache(`dashboard:${auth.tenantId}`);

        logger.info('Staff sale recorded', { tenantId: auth.tenantId, staffId: auth.sub, saleId, productType: body.productType, amountCents: body.amountCents, paymentMode: body.paymentMode });

        wsService.broadcastToBusiness(auth.tenantId, WSEventName.STAFF_SALE_CREATED, {
            saleId, staffId: auth.sub, productType: body.productType,
            amountCents: body.amountCents, paymentMode: body.paymentMode,
            vehicleNumber: body.vehicleNumber, invoiceNumber,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        return response.success({ transactionId: saleId, invoiceNumber, paymentStatus, createdAt: now }, 201);
    } catch (err) {
        // Re-throw domain errors for proper HTTP responses
        if (err instanceof PriceValidationError || err instanceof CreditLimitExceededError || err instanceof NotFoundError) {
            throw err;
        }
        logger.error('Failed to record staff sale', { error: err });
        return response.internalError('Failed to record sale');
    }
}, PUMP_OPTS);

/**
 * POST /staff/sale/generate-qr — Generate payment QR
 */
export const generateSaleQr = authorizedHandler([], async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const valid = parseBody(staffSaleQrSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        const saleId = crypto.randomUUID();
        let nextNum: number;
        try {
            const counterResult = await updateItem(
                pk,
                'COUNTER#INVOICE',
                {
                    updateExpression: 'SET #val = if_not_exists(#val, :zero) + :one, updatedAt = :now',
                    expressionAttributeNames: { '#val': 'counterValue' },
                    expressionAttributeValues: { ':zero': 0, ':one': 1, ':now': now },
                },
            );
            nextNum = (counterResult as any)?.counterValue;
        } catch (err) {
            throw new Error('Failed to generate invoice number');
        }
        const invoiceNumber = `INV-QR-${nextNum.toString().padStart(6, '0')}`;
        const deviceId = event.headers?.['x-device-id'] || null;

        // Create pending staff sale
        await putItem({
            PK: pk, SK: `STAFFSALE#${saleId}`,
            entityType: 'STAFF_SALE', id: saleId, tenantId: auth.tenantId,
            staffId: auth.sub, staffName: auth.email,
            productType: body.productType, amountCents: body.amountCents,
            paymentMode: 'online', paymentStatus: 'pending',
            vehicleNumber: body.vehicleNumber || null,
            customerName: body.customerName || null,
            invoiceNumber, deviceId,
            isDeleted: false, createdAt: now, updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'staff_sales_details',
            saleId,
            'create',
            auth.sub,
            null,
            {
                id: saleId,
                invoiceNumber,
                amountCents: body.amountCents,
                paymentMode: 'online',
                paymentStatus: 'pending',
                productType: body.productType,
                createdAt: now,
            },
            { source: 'staff-sale.generateSaleQr.pendingSale' },
        );

        // Create pending invoice
        const txnId = crypto.randomUUID();
        await putItem({
            PK: pk, SK: Keys.invoiceSK(txnId),
            entityType: 'INVOICE', id: txnId, tenantId: auth.tenantId,
            invoiceNumber, type: 'sale', status: 'draft',
            totalCents: body.amountCents, paidCents: 0, balanceCents: body.amountCents,
            paymentMode: 'upi', createdBy: auth.sub, isDeleted: false,
            metadata: { source: 'staff_sale_qr', staffSaleId: saleId, productType: body.productType },
            createdAt: now, updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'transactions',
            txnId,
            'create',
            auth.sub,
            null,
            {
                id: txnId,
                invoiceNumber,
                totalCents: body.amountCents,
                paidCents: 0,
                balanceCents: body.amountCents,
                status: 'draft',
                paymentMode: 'upi',
                createdAt: now,
            },
            { source: 'staff-sale.generateSaleQr.pendingInvoice' },
        );

        // Link
        const staffSaleBeforeLink = await getItem<Record<string, any>>(pk, `STAFFSALE#${saleId}`);
        await updateItem(pk, `STAFFSALE#${saleId}`, {
            updateExpression: 'SET transactionId = :txnId',
            expressionAttributeValues: { ':txnId': txnId },
        });
        await recordRevision(
            auth.tenantId,
            'staff_sales_details',
            saleId,
            'update',
            auth.sub,
            staffSaleBeforeLink || null,
            {
                ...(staffSaleBeforeLink || {}),
                transactionId: txnId,
                updatedAt: now,
            },
            { source: 'staff-sale.generateSaleQr.linkTransaction' },
        );

        // Generate QR
        const domainName = event.requestContext?.domainName;
        const stage = (event.requestContext as any)?.stage;
        const callbackBaseUrl = domainName
            ? `https://${domainName}${stage && stage !== '$default' ? `/${stage}` : ''}`
            : (config.app.slsBackendUrl || '');

        let qrResult: any;
        try {
            qrResult = await paymentOrderService.createPaymentOrder(auth.tenantId, { invoiceId: txnId }, callbackBaseUrl);
        } catch (payErr: any) {
            logger.warn('Payment QR generation failed', { error: payErr.message, saleId });
            return response.success({
                transactionId: saleId, invoiceNumber, paymentStatus: 'pending',
                qrPayload: null, paymentUrl: null, expiresAt: null,
                message: 'Sale created but QR generation failed. Configure payment gateway first.',
            }, 201);
        }

        // Store payment info
        await putItem({
            PK: pk, SK: `STAFFSALEPAYMENT#${crypto.randomUUID()}`,
            entityType: 'STAFF_SALE_PAYMENT', tenantId: auth.tenantId,
            staffSaleId: saleId, paymentOrderId: qrResult.orderId,
            qrPayload: qrResult.qrPayload || null,
            paymentUrl: qrResult.paymentUrl || null,
            gatewayType: qrResult.gatewayType || 'phonepe',
            status: 'pending', expiresAt: qrResult.expiresAt || null,
            createdAt: now,
        });

        // Update sale with order ID
        await updateItem(pk, `STAFFSALE#${saleId}`, {
            updateExpression: 'SET paymentOrderId = :orderId',
            expressionAttributeValues: { ':orderId': qrResult.orderId },
        });
        await recordRevision(
            auth.tenantId,
            'staff_sales_details',
            saleId,
            'update',
            auth.sub,
            {
                ...(staffSaleBeforeLink || {}),
                transactionId: txnId,
                updatedAt: now,
            },
            {
                ...(staffSaleBeforeLink || {}),
                transactionId: txnId,
                paymentOrderId: qrResult.orderId,
                updatedAt: now,
            },
            { source: 'staff-sale.generateSaleQr.attachPaymentOrder' },
        );

        logger.info('Staff sale QR generated', { tenantId: auth.tenantId, saleId, orderId: qrResult.orderId });

        return response.success({
            transactionId: saleId, invoiceNumber, paymentStatus: 'pending',
            orderId: qrResult.orderId, qrPayload: qrResult.qrPayload,
            paymentUrl: qrResult.paymentUrl, expiresAt: qrResult.expiresAt,
        }, 201);
    } catch (err) {
        logger.error('Failed to generate staff sale QR', { error: err });
        return response.internalError('Failed to generate payment QR');
    }
}, PUMP_OPTS);

/**
 * GET /staff/sale/history — Staff's own sale history
 */
export const getMyHistory = authorizedHandler([], async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const params = event.queryStringParameters || {};
    const limit = Math.min(parseInt(params.limit || '50', 10), 100);
    const offset = Math.max(parseInt(params.offset || '0', 10), 0);
    const pk = Keys.tenantPK(auth.tenantId);

    const sales = await queryItems<Record<string, any>>(pk, 'STAFFSALE#', {
        filterExpression: 'staffId = :staffId AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':staffId': auth.sub, ':false': false },
    });

    let items = sales.items;
    if (params.dateFrom) items = items.filter(i => (i.createdAt || '') >= params.dateFrom!);
    if (params.dateTo) items = items.filter(i => (i.createdAt || '') <= params.dateTo!);
    if (params.productType) items = items.filter(i => i.productType === params.productType);

    items.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    const total = items.length;
    const paged = items.slice(offset, offset + limit).map(s => ({
        id: s.id, productType: s.productType, amountCents: s.amountCents,
        paymentMode: s.paymentMode, paymentStatus: s.paymentStatus,
        vehicleNumber: s.vehicleNumber, customerName: s.customerName,
        invoiceNumber: s.invoiceNumber, notes: s.notes, createdAt: s.createdAt,
    }));

    return response.paginated(paged, total, Math.floor(offset / limit) + 1, limit);
}, PUMP_OPTS);

/**
 * GET /staff/sale/daily-summary — Today's totals
 */
export const getDailySummary = authorizedHandler([], async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const params = event.queryStringParameters || {};
    const date = params.date || new Date().toISOString().split('T')[0];
    const pk = Keys.tenantPK(auth.tenantId);

    const sales = await queryItems<Record<string, any>>(pk, 'STAFFSALE#', {
        filterExpression: 'staffId = :staffId AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':staffId': auth.sub, ':false': false },
    });

    // Filter by date
    const daySales = sales.items.filter(s =>
        (s.createdAt || '').startsWith(date) &&
        ['paid', 'pending'].includes(s.paymentStatus || '')
    );

    const totalTransactions = daySales.length;
    const totalAmountCents = daySales.reduce((s, i) => s + (Number(i.amountCents) || 0), 0);
    const cashSales = daySales.filter(s => s.paymentMode === 'cash');
    const onlineSales = daySales.filter(s => s.paymentMode === 'online');

    return response.success({
        date, staffId: auth.sub,
        totalTransactions,
        totalAmountCents,
        cashAmountCents: cashSales.reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
        onlineAmountCents: onlineSales.reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
        cashCount: cashSales.length,
        onlineCount: onlineSales.length,
        byProduct: {
            petrol: daySales.filter(s => s.productType === 'petrol').reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
            diesel: daySales.filter(s => s.productType === 'diesel').reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
            lubOil: daySales.filter(s => s.productType === 'lub_oil').reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
            other: daySales.filter(s => !['petrol', 'diesel', 'lub_oil'].includes(s.productType)).reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
        },
    });
}, PUMP_OPTS);
