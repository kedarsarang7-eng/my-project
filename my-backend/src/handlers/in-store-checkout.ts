// ============================================================================
// Lambda Handler � In-Store Checkout, Payment & Exit QR
// ============================================================================
// POST /in-store/session/{sessionId}/checkout  � create order + payment order
// POST /in-store/verify-exit                   � staff exit QR verification
// POST /in-store/session/{sessionId}/exit-qr/refresh � regenerate expired QR
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import {
    Keys, putItem, getItem, updateItem, queryItems, transactWrite, TABLE_NAME,
} from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { UserRole, AuthContext } from '../types/tenant.types';
import {
    InStoreSession, InStoreSessionStatus, InStoreOrder,
    InStoreOrderType, ExitQRPayload,
} from '../types/in-store.types';
import { calcCartSummary } from './in-store-session';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
import crypto from 'crypto';
import {
    SecretsManagerClient,
    GetSecretValueCommand,
} from '@aws-sdk/client-secrets-manager';
import { config } from '../config/environment';

const secretsClient = new SecretsManagerClient(configureAwsClient({ region: config.aws.region }));

const EXIT_QR_TTL_MINUTES = 20;
const PAYMENT_GATEWAY = config.extendedPayment.gateway || 'razorpay'; // razorpay | cashfree

function sessionPK(id: string) { return `SESSION#${id}`; }
function sessionSK(id: string) { return `SESSION#${id}`; }
function orderPK(tenantId: string) { return Keys.tenantPK(tenantId); }
function orderSK(orderId: string) { return `INSTORE_ORDER#${orderId}`; }

// -- Secrets Manager: per-tenant HMAC secret ----------------------------------

async function getTenantHmacSecret(tenantId: string): Promise<string> {
    const secretName = `dukanx/${config.app.stage || 'prod'}/tenant/${tenantId}/qr-secret`;
    try {
        const result = await secretsClient.send(
            new GetSecretValueCommand({ SecretId: secretName })
        );
        return result.SecretString || '';
    } catch {
        // Fallback: derive from tenant ID + master secret (not ideal, use only in dev)
        const master = config.extendedSecrets.qrMasterSecret || 'CHANGE_ME_IN_PROD';
        return crypto.createHmac('sha256', master).update(tenantId).digest('hex');
    }
}

// -- Exit QR generation -------------------------------------------------------

async function generateExitQR(
    orderId: string,
    sessionId: string,
    storeId: string,
    tenantId: string,
    totalItems: number,
    totalAmount: number,
    paidAt: string
): Promise<ExitQRPayload> {
    const expiresAt = new Date(Date.now() + EXIT_QR_TTL_MINUTES * 60 * 1000).toISOString();

    const payloadWithoutSig = JSON.stringify({
        orderId, sessionId, storeId, tenantId,
        totalItems, totalAmount, paidAt, expiresAt,
    });

    const secret = await getTenantHmacSecret(tenantId);
    const signature = crypto
        .createHmac('sha256', secret)
        .update(payloadWithoutSig)
        .digest('hex');

    return { orderId, sessionId, storeId, tenantId, totalItems, totalAmount, paidAt, expiresAt, signature };
}

// -- POST /in-store/session/{sessionId}/checkout -------------------------------

export const checkout = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const sessionId = event.pathParameters?.sessionId;
        if (!sessionId) return response.badRequest('sessionId required');

        const session = await getItem<InStoreSession>(sessionPK(sessionId), sessionSK(sessionId));
        if (!session) return response.notFound('Session');
        if (session.tenantId !== auth.tenantId) return response.forbidden('Access denied');
        if (session.customerId !== auth.sub) return response.forbidden('Access denied');
        if (session.status !== InStoreSessionStatus.ACTIVE) {
            return response.badRequest(`Session is ${session.status}`);
        }
        if (session.cartItems.length === 0) {
            return response.badRequest('Cart is empty');
        }

        const tenantPK = Keys.tenantPK(auth.tenantId);

        // Re-validate stock for every item at checkout time (server-side, never trust client)
        const stockErrors: string[] = [];
        for (const item of session.cartItems) {
            const product = await getItem<Record<string, any>>(tenantPK, Keys.productSK(item.productId));
            if (!product || product.isDeleted || !product.isActive) {
                stockErrors.push(`${item.name} is no longer available`);
                continue;
            }
            const stock = Number(product.stockQuantity ?? product.quantity ?? 0);
            if (stock < item.quantity) {
                stockErrors.push(`${item.name}: only ${stock} in stock, you have ${item.quantity} in cart`);
            }
        }

        if (stockErrors.length > 0) {
            return response.badRequest('Stock validation failed', { outOfStock: stockErrors });
        }

        const summary = calcCartSummary(session.cartItems);
        const orderId = `INSTORE-${Date.now()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
        const now = new Date().toISOString();

        // Create gateway payment order
        let paymentOrderId = '';
        let gatewayKey = '';
        try {
            const gatewayResult = await createGatewayOrder(orderId, summary.totalCents, auth.tenantId);
            paymentOrderId = gatewayResult.paymentOrderId;
            gatewayKey = gatewayResult.gatewayKey;
        } catch (err: any) {
            logger.error('Gateway order creation failed', { error: err.message, orderId });
            return response.internalError('Payment gateway unavailable. Please try again.');
        }

        // Create InStoreOrder record
        const order: InStoreOrder = {
            orderId,
            sessionId,
            customerId: auth.sub,
            tenantId: auth.tenantId,
            storeId: session.storeId,
            orderType: InStoreOrderType.IN_STORE_SCAN,
            cartItems: session.cartItems,
            subtotalCents: summary.subtotalCents,
            discountCents: summary.discountCents,
            gstBreakup: summary.gstBreakup,
            totalGstCents: summary.totalGstCents,
            totalCents: summary.totalCents,
            status: 'PAYMENT_PENDING',
            paymentOrderId,
            paymentGateway: PAYMENT_GATEWAY,
            createdAt: now,
            updatedAt: now,
        };

        await putItem({
            PK: orderPK(auth.tenantId),
            SK: orderSK(orderId),
            entityType: 'INSTORE_ORDER',
            ...(order as unknown as Record<string, unknown>),
        });

        // Update session status to reflect checkout initiated
        await updateItem(sessionPK(sessionId), sessionSK(sessionId), {
            updateExpression: 'SET currentOrderId = :oid, updatedAt = :now',
            expressionAttributeValues: { ':oid': orderId, ':now': now },
        });

        logger.info('InStore checkout initiated', { orderId, sessionId, totalCents: summary.totalCents });

        return response.success({
            orderId,
            paymentOrderId,
            amount: summary.totalCents / 100,
            currency: 'INR',
            gatewayKey,
            summary,
        }, 201);
    }
);

// -- Payment gateway order creation -------------------------------------------

async function createGatewayOrder(
    orderId: string,
    amountCents: number,
    tenantId: string
): Promise<{ paymentOrderId: string; gatewayKey: string }> {
    // Razorpay integration � fetches per-tenant credentials from Secrets Manager
    const secretName = `dukanx/${config.app.stage || 'prod'}/tenant/${tenantId}/razorpay`;
    let keyId = config.payment.razorpay.keyId || '';
    let keySecret = config.payment.razorpay.keySecret || '';

    try {
        const secret = await secretsClient.send(new GetSecretValueCommand({ SecretId: secretName }));
        const creds = JSON.parse(secret.SecretString || '{}');
        keyId = creds.keyId || keyId;
        keySecret = creds.keySecret || keySecret;
    } catch {
        // Fall back to env vars (shared credentials for demo)
    }

    if (!keyId || !keySecret) {
        throw new Error('Payment gateway credentials not configured for this tenant');
    }

    const razorpayResponse = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64'),
        },
        body: JSON.stringify({
            amount: amountCents,
            currency: 'INR',
            receipt: orderId,
            notes: { orderId, source: 'IN_STORE_SCAN' },
        }),
    });

    if (!razorpayResponse.ok) {
        const err = await razorpayResponse.text();
        throw new Error(`Razorpay order creation failed: ${err}`);
    }

    const data = await razorpayResponse.json() as { id: string };
    return { paymentOrderId: data.id, gatewayKey: keyId };
}

// -- POST /in-store/confirm-payment (called by webhook handler) ---------------

export async function confirmInStorePayment(
    orderId: string,
    tenantId: string,
    paymentId: string
): Promise<void> {
    const tenantPK = Keys.tenantPK(tenantId);

    const order = await getItem<InStoreOrder>(tenantPK, orderSK(orderId));
    if (!order) {
        logger.error('confirmInStorePayment: order not found', { orderId, tenantId });
        return;
    }

    if (order.status !== 'PAYMENT_PENDING') {
        logger.warn('confirmInStorePayment: order already processed', { orderId, status: order.status });
        return;
    }

    const now = new Date().toISOString();
    const summary = calcCartSummary(order.cartItems);

    // Generate Exit QR
    const exitQRPayload = await generateExitQR(
        orderId,
        order.sessionId,
        order.storeId,
        tenantId,
        summary.itemCount,
        summary.totalCents / 100,
        now
    );

    const exitQRJson = JSON.stringify(exitQRPayload);

    // Atomic: update order to CONFIRMED + store exit QR
    await updateItem(tenantPK, orderSK(orderId), {
        updateExpression: 'SET #status = :confirmed, exitQR = :qr, paymentId = :pid, updatedAt = :now',
        expressionAttributeNames: { '#status': 'status' },
        expressionAttributeValues: {
            ':confirmed': 'CONFIRMED',
            ':qr': {
                payload: exitQRJson,
                signature: exitQRPayload.signature,
                expiresAt: exitQRPayload.expiresAt,
                verified: false,
            },
            ':pid': paymentId,
            ':now': now,
        },
    });

    // Update session to COMPLETED
    await updateItem(sessionPK(order.sessionId), sessionSK(order.sessionId), {
        updateExpression: 'SET #status = :completed, completedAt = :now',
        expressionAttributeNames: { '#status': 'status' },
        expressionAttributeValues: {
            ':completed': InStoreSessionStatus.COMPLETED,
            ':now': now,
        },
    });

    // Push exit QR to customer via WebSocket
    wsService.broadcastToCustomer(tenantId, order.customerId, WSEventName.PAYMENT_SUCCESS, {
        orderId,
        exitQR: exitQRJson,
        totalAmount: summary.totalCents / 100,
        totalItems: summary.itemCount,
    }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

    logger.info('InStore payment confirmed', { orderId, tenantId, sessionId: order.sessionId });
}

// -- POST /in-store/verify-exit (staff endpoint) -------------------------------

export const verifyExitQR = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        let body: { qrPayload: string };
        try {
            body = JSON.parse(event.body || '{}');
        } catch {
            return response.badRequest('Invalid JSON body');
        }

        if (!body.qrPayload) return response.badRequest('qrPayload required');

        let qrData: ExitQRPayload;
        try {
            qrData = JSON.parse(body.qrPayload);
        } catch {
            return response.success({ valid: false, reason: 'QR data is malformed' });
        }

        // Tenant isolation � QR must belong to this tenant
        if (qrData.tenantId !== auth.tenantId) {
            return response.success({ valid: false, reason: 'QR does not belong to this store' });
        }

        // Check expiry
        if (new Date(qrData.expiresAt) < new Date()) {
            return response.success({ valid: false, reason: 'QR expired' });
        }

        // Verify HMAC signature
        const secret = await getTenantHmacSecret(auth.tenantId);
        const { signature, ...payloadWithoutSig } = qrData;
        const expectedSig = crypto
            .createHmac('sha256', secret)
            .update(JSON.stringify(payloadWithoutSig))
            .digest('hex');

        if (!crypto.timingSafeEqual(Buffer.from(signature, 'hex'), Buffer.from(expectedSig, 'hex'))) {
            logger.warn('Exit QR signature mismatch', { orderId: qrData.orderId, tenantId: auth.tenantId });
            return response.success({ valid: false, reason: 'QR signature invalid � possible tampering' });
        }

        // Fetch order and check one-time use � atomic conditional update
        const tenantPK = Keys.tenantPK(auth.tenantId);
        const order = await getItem<InStoreOrder>(tenantPK, orderSK(qrData.orderId));

        if (!order) {
            return response.success({ valid: false, reason: 'Order not found' });
        }
        if (order.status !== 'CONFIRMED') {
            return response.success({ valid: false, reason: `Order status is ${order.status}` });
        }
        if (order.exitQR?.verified) {
            return response.success({ valid: false, reason: 'QR already scanned � cannot exit again' });
        }

        // Atomic mark-as-verified with condition to prevent race condition
        try {
            await updateItem(tenantPK, orderSK(qrData.orderId), {
                updateExpression: 'SET exitQR.verified = :t, exitQR.verifiedAt = :now, exitQR.verifiedBy = :by',
                conditionExpression: 'exitQR.verified = :f',
                expressionAttributeValues: {
                    ':t': true,
                    ':f': false,
                    ':now': new Date().toISOString(),
                    ':by': auth.sub,
                },
            });
        } catch (err: unknown) {
            if ((err as { name?: string }).name === 'ConditionalCheckFailedException') {
                return response.success({ valid: false, reason: 'QR already scanned (race condition caught)' });
            }
            throw err;
        }

        // Fetch customer name
        const customerUser = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            Keys.userSK(order.customerId)
        );
        const customerName = customerUser?.fullName || customerUser?.name || 'Customer';

        logger.info('Exit QR verified', {
            orderId: qrData.orderId,
            verifiedBy: auth.sub,
            tenantId: auth.tenantId,
        });

        const minutesAgo = Math.round(
            (Date.now() - new Date(qrData.paidAt).getTime()) / 60000
        );

        return response.success({
            valid: true,
            order: {
                orderId: order.orderId,
                customerName,
                totalItems: qrData.totalItems,
                totalAmount: qrData.totalAmount,
                paidAt: qrData.paidAt,
                minutesAgo,
            },
        });
    }
);

// -- POST /in-store/session/{sessionId}/exit-qr/refresh ------------------------

export const refreshExitQR = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const sessionId = event.pathParameters?.sessionId;
        if (!sessionId) return response.badRequest('sessionId required');

        const session = await getItem<InStoreSession>(sessionPK(sessionId), sessionSK(sessionId));
        if (!session) return response.notFound('Session');
        if (session.tenantId !== auth.tenantId) return response.forbidden('Access denied');
        if (session.customerId !== auth.sub) return response.forbidden('Access denied');

        // Find the confirmed order for this session
        const tenantPK = Keys.tenantPK(auth.tenantId);
        const orders = await queryItems<InStoreOrder>(
            tenantPK,
            'INSTORE_ORDER#',
            {
                filterExpression: 'sessionId = :sid AND #status = :confirmed',
                expressionAttributeNames: { '#status': 'status' },
                expressionAttributeValues: { ':sid': sessionId, ':confirmed': 'CONFIRMED' },
                limit: 1,
            }
        );

        if (orders.items.length === 0) {
            return response.badRequest('No confirmed order found for this session');
        }

        const order = orders.items[0];

        if (order.exitQR?.verified) {
            return response.badRequest('Exit QR already used � order is complete');
        }

        const summary = calcCartSummary(order.cartItems);
        const newQR = await generateExitQR(
            order.orderId,
            sessionId,
            order.storeId,
            auth.tenantId,
            summary.itemCount,
            summary.totalCents / 100,
            order.createdAt
        );

        await updateItem(tenantPK, orderSK(order.orderId), {
            updateExpression: 'SET exitQR = :qr, updatedAt = :now',
            expressionAttributeValues: {
                ':qr': {
                    payload: JSON.stringify(newQR),
                    signature: newQR.signature,
                    expiresAt: newQR.expiresAt,
                    verified: false,
                },
                ':now': new Date().toISOString(),
            },
        });

        return response.success({ exitQR: JSON.stringify(newQR) });
    }
);

// -- GET /in-store/orders/today ------------------------------------------------

export const listTodayOrders = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const tenantPK = Keys.tenantPK(auth.tenantId);
        const storeId = event.queryStringParameters?.storeId;

        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);

        const filterParts = ['entityType = :et', 'createdAt >= :today'];
        const exprValues: Record<string, unknown> = {
            ':et': 'INSTORE_ORDER',
            ':today': todayStart.toISOString(),
        };

        if (storeId) {
            filterParts.push('storeId = :sid');
            exprValues[':sid'] = storeId;
        }

        const result = await queryItems<InStoreOrder>(
            tenantPK,
            'INSTORE_ORDER#',
            {
                filterExpression: filterParts.join(' AND '),
                expressionAttributeValues: exprValues,
                limit: 200,
                scanIndexForward: false,
            }
        );

        const orders = result.items.map(o => ({
            orderId: o.orderId,
            sessionId: o.sessionId,
            customerId: o.customerId,
            storeId: o.storeId,
            status: o.status,
            totalCents: o.totalCents,
            itemCount: o.cartItems?.length ?? 0,
            exitVerified: o.exitQR?.verified ?? false,
            createdAt: o.createdAt,
        }));

        return response.success({ orders, count: orders.length });
    }
);
