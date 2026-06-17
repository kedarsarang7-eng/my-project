// ============================================================================
// Payment Order Service — QR Generation & Order Lifecycle (DynamoDB)
// ============================================================================
// Migrated from PostgreSQL to DynamoDB single-table design.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { v4 as uuidv4 } from 'uuid';
import * as crypto from 'crypto';
import {
    Keys,
    getItem, putItem, queryItems, updateItem,
} from '../config/dynamodb.config';
import * as paymentConfigService from './payment-config.service';
import * as kmsService from './kms.service';
import { getGateway } from './gateway/gateway.factory';
import {
    GatewayType, PaymentOrderStatus, PaymentOrder,
    WebhookVerificationResult, PaymentAuditEntry,
} from '../types/payment.types';
import { logger } from '../utils/logger';
import { AppError, NotFoundError, ConflictError } from '../utils/errors';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import * as fraudDetectionService from './fraud-detection.service';
import { recordRevision } from './revision-history.service';
import { config } from '../config/environment';

const cloudwatchClient = new CloudWatchClient(configureAwsClient({ region: config.aws.region }));

const VALID_TRANSITIONS: Record<PaymentOrderStatus, PaymentOrderStatus[]> = {
    [PaymentOrderStatus.CREATED]: [PaymentOrderStatus.QR_GENERATED, PaymentOrderStatus.FAILED, PaymentOrderStatus.EXPIRED],
    [PaymentOrderStatus.QR_GENERATED]: [PaymentOrderStatus.PENDING, PaymentOrderStatus.FAILED, PaymentOrderStatus.EXPIRED],
    [PaymentOrderStatus.PENDING]: [PaymentOrderStatus.SUCCESS, PaymentOrderStatus.FAILED, PaymentOrderStatus.EXPIRED],
    [PaymentOrderStatus.SUCCESS]: [PaymentOrderStatus.REFUNDED],
    [PaymentOrderStatus.FAILED]: [],
    [PaymentOrderStatus.EXPIRED]: [],
    [PaymentOrderStatus.REFUNDED]: [],
};

function validateTransition(current: PaymentOrderStatus, next: PaymentOrderStatus): void {
    const allowed = VALID_TRANSITIONS[current];
    if (!allowed || !allowed.includes(next)) {
        throw new ConflictError(`Invalid payment state transition: ${current} → ${next}`);
    }
}

const RAZORPAY_WEBHOOK_IPS = new Set(['52.66.86.93', '52.66.160.183', '52.66.186.128', '3.7.74.219', '3.7.72.235', '3.6.91.58', '3.6.244.23', '3.6.4.168']);
const WEBHOOK_TIMESTAMP_MAX_DRIFT_MS = 5 * 60 * 1000;

function validateWebhookSourceIP(sourceIp: string | undefined, gatewayType: GatewayType): void {
    if (!sourceIp || gatewayType !== GatewayType.RAZORPAY) return;
    if (!RAZORPAY_WEBHOOK_IPS.has(sourceIp)) {
        logger.error('SECURITY: Webhook from unknown IP', { sourceIp, gatewayType });
        throw new AppError('Webhook source IP not whitelisted', 403, 'WEBHOOK_IP_BLOCKED');
    }
}

function validateWebhookTimestamp(headers: Record<string, string>, gatewayType: GatewayType): void {
    let timestamp: number | null = null;
    if (gatewayType === GatewayType.RAZORPAY) {
        const tsHeader = headers['x-razorpay-event-timestamp'];
        if (tsHeader) timestamp = parseInt(tsHeader, 10) * 1000;
    }
    if (timestamp !== null && Math.abs(Date.now() - timestamp) > WEBHOOK_TIMESTAMP_MAX_DRIFT_MS) {
        throw new AppError('Webhook timestamp expired', 400, 'WEBHOOK_TIMESTAMP_DRIFT');
    }
}

function computeWebhookSignatureHash(rawBody: string, gatewayType: GatewayType): string {
    return crypto.createHash('sha256').update(`${gatewayType}:${rawBody}`).digest('hex');
}

async function checkAndStoreWebhookNonce(signatureHash: string, gatewayType: GatewayType, tenantId: string): Promise<boolean> {
    const existing = await getItem(`WEBHOOKNONCE#${signatureHash}`, 'META');
    if (existing) return true;
    await putItem({
        PK: `WEBHOOKNONCE#${signatureHash}`, SK: 'META',
        entityType: 'WEBHOOK_NONCE', signatureHash, gatewayType, tenantId,
        createdAt: new Date().toISOString(), ttl: Math.floor(Date.now() / 1000) + 86400,
    });
    return false;
}

async function emitSecurityMetric(metricName: string, value = 1, dimensions?: { Name: string; Value: string }[]): Promise<void> {
    try {
        await cloudwatchClient.send(new PutMetricDataCommand({
            Namespace: 'DukanX/Payments',
            MetricData: [{ MetricName: metricName, Value: value, Unit: 'Count', Dimensions: dimensions || [] }],
        }));
    } catch (err) { logger.warn('Failed to emit metric', { metricName, error: (err as Error).message }); }
}

export interface CreatePaymentOrderInput { invoiceId: string; gatewayType?: GatewayType; }
export interface CreatePaymentOrderResult { orderId: string; gatewayOrderId: string; qrPayload?: string; paymentUrl?: string; expiresAt?: Date; status: PaymentOrderStatus; }

export async function createPaymentOrder(
    tenantId: string, input: CreatePaymentOrderInput, callbackBaseUrl: string
): Promise<CreatePaymentOrderResult> {
    const invoice = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.invoiceSK(input.invoiceId));
    if (!invoice || invoice.isDeleted) throw new NotFoundError('Invoice');
    if (invoice.status === 'paid') throw new AppError('Invoice already paid', 400, 'INVOICE_ALREADY_PAID');
    if (invoice.status === 'voided') throw new AppError('Cannot pay voided invoice', 400, 'INVOICE_VOIDED');

    const amountCents = invoice.balanceCents > 0 ? invoice.balanceCents : invoice.totalCents;
    const fraudResult = await fraudDetectionService.checkPaymentFraud({ tenantId, amountCents, invoiceId: input.invoiceId });
    if (fraudResult.blocked) throw new AppError('Payment blocked by security checks', 403, 'FRAUD_DETECTED');

    let gatewayType = input.gatewayType;
    if (!gatewayType) {
        const active = await paymentConfigService.getActiveGateway(tenantId);
        if (!active) throw new AppError('No active payment gateway', 400, 'NO_GATEWAY_CONFIGURED');
        gatewayType = active.gatewayType;
    }

    // Idempotency check
    const idempotencyKey = `${tenantId}:${input.invoiceId}:${gatewayType}`;
    const existingOrders = await queryItems<Record<string, any>>(
        Keys.tenantPK(tenantId), 'PAYORDER#',
        {
            filterExpression: 'idempotencyKey = :ik AND #s IN (:c, :qr, :p)',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':ik': idempotencyKey, ':c': 'created', ':qr': 'qr_generated', ':p': 'pending' },
        },
    );
    if (existingOrders.items.length > 0) {
        const existing = existingOrders.items[0];
        return { orderId: existing.id, gatewayOrderId: existing.gatewayOrderId, qrPayload: existing.qrPayload, paymentUrl: existing.paymentUrl, expiresAt: existing.expiresAt ? new Date(existing.expiresAt) : undefined, status: existing.status };
    }

    const { config, credentials } = await paymentConfigService.getDecryptedConfig(tenantId, gatewayType);
    let gatewayResult;
    try {
        const orderId = uuidv4();
        const callbackUrl = `${callbackBaseUrl}/payment/webhook/${gatewayType}`;
        const gateway = getGateway(gatewayType);
        gatewayResult = await gateway.createOrder(credentials, { orderId, invoiceId: input.invoiceId, amountCents, currency: 'INR', customerName: invoice.customerName, customerPhone: invoice.customerPhone, callbackUrl, description: `Invoice ${invoice.invoiceNumber}` });

        await putItem({
            PK: Keys.tenantPK(tenantId), SK: `PAYORDER#${orderId}`,
            entityType: 'PAYMENT_ORDER', id: orderId, tenantId, invoiceId: input.invoiceId,
            configId: config.id, gatewayType, gatewayOrderId: gatewayResult.gatewayOrderId,
            amountCents, currency: 'INR', status: 'qr_generated',
            qrPayload: gatewayResult.qrPayload || null, paymentUrl: gatewayResult.paymentUrl || null,
            idempotencyKey, gatewayResponse: gatewayResult.gatewayResponse,
            expiresAt: gatewayResult.expiresAt?.toISOString() || null,
            webhookVerified: false, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
            GSI1PK: `GATEWAYORDER#${gatewayResult.gatewayOrderId}`, GSI1SK: `${gatewayType}`,
        });

        await logAuditEvent({ tenantId, paymentOrderId: orderId, invoiceId: input.invoiceId, eventType: 'qr_generated', eventData: { gatewayType, amountCents, gatewayOrderId: gatewayResult.gatewayOrderId } });
        return { orderId, gatewayOrderId: gatewayResult.gatewayOrderId, qrPayload: gatewayResult.qrPayload, paymentUrl: gatewayResult.paymentUrl, expiresAt: gatewayResult.expiresAt, status: PaymentOrderStatus.QR_GENERATED };
    } finally {
        kmsService.secureWipeString(JSON.stringify(credentials));
    }
}

export async function handleWebhook(
    gatewayType: GatewayType, headers: Record<string, string>, rawBody: string, sourceIp?: string
): Promise<{ success: boolean; orderId?: string; status?: string; tenantId?: string }> {
    try { validateWebhookSourceIP(sourceIp, gatewayType); }
    catch { await emitSecurityMetric('WebhookFailureCount', 1, [{ Name: 'Reason', Value: 'IP_BLOCKED' }]); return { success: false }; }
    try { validateWebhookTimestamp(headers, gatewayType); }
    catch { await emitSecurityMetric('WebhookFailureCount', 1, [{ Name: 'Reason', Value: 'TIMESTAMP_DRIFT' }]); return { success: false }; }

    let parsedBody: Record<string, any>;
    try { parsedBody = JSON.parse(rawBody); } catch { return { success: false }; }

    let gatewayOrderId: string | undefined;
    if (gatewayType === GatewayType.PHONEPE) {
        try { const decoded = JSON.parse(Buffer.from(parsedBody.response || '', 'base64').toString('utf-8')); gatewayOrderId = decoded.data?.merchantTransactionId; } catch {}
    } else if (gatewayType === GatewayType.RAZORPAY) {
        gatewayOrderId = parsedBody.payload?.payment?.entity?.order_id || parsedBody.payload?.order?.entity?.id;
    }
    if (!gatewayOrderId) return { success: false };

    // Lookup order via GSI1 (gateway order ID)
    const orderResult = await queryItems<Record<string, any>>(`GATEWAYORDER#${gatewayOrderId}`, gatewayType, { indexName: 'GSI1', limit: 1 });
    if (orderResult.items.length === 0) { logger.warn('Webhook: order not found', { gatewayOrderId }); return { success: false }; }

    const order = orderResult.items[0];
    const tenantId = order.tenantId;

    if (order.webhookVerified) return { success: true, orderId: order.id, status: order.status };

    const signatureHash = computeWebhookSignatureHash(rawBody, gatewayType);
    if (await checkAndStoreWebhookNonce(signatureHash, gatewayType, tenantId)) return { success: true, orderId: order.id, status: order.status };

    let verification: WebhookVerificationResult;
    try {
        const { credentials } = await paymentConfigService.getDecryptedConfig(tenantId, gatewayType);
        try { const gateway = getGateway(gatewayType); verification = gateway.verifyWebhook(credentials, headers, rawBody); }
        finally { kmsService.secureWipeString(JSON.stringify(credentials)); }
    } catch { return { success: false }; }

    if (!verification.isValid) { await emitSecurityMetric('InvalidSignatureCount', 1); return { success: false }; }
    if (verification.amountCents && verification.amountCents !== order.amountCents) { await emitSecurityMetric('WebhookFailureCount', 1, [{ Name: 'Reason', Value: 'AMOUNT_MISMATCH' }]); return { success: false }; }

    const newStatus = verification.status || PaymentOrderStatus.SUCCESS;
    try { validateTransition(order.status as PaymentOrderStatus, newStatus); } catch { return { success: false }; }

    const now = new Date().toISOString();
    const previousOrderState = { ...order };
    await updateItem(order.PK, order.SK, {
        updateExpression: 'SET #s = :status, gatewayTransactionId = :gtid, webhookReceivedAt = :now, webhookVerified = :true, webhookRaw = :raw, updatedAt = :now',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: { ':status': newStatus, ':gtid': verification.gatewayTransactionId || null, ':now': now, ':true': true, ':raw': verification.rawPayload || {} },
    });
    await recordRevision(
        tenantId,
        'payment_orders',
        String(order.id || ''),
        'status_change',
        'system',
        previousOrderState,
        {
            ...previousOrderState,
            status: newStatus,
            gatewayTransactionId: verification.gatewayTransactionId || null,
            webhookReceivedAt: now,
            webhookVerified: true,
            updatedAt: now,
        },
        { source: 'payment-order.handleWebhook', gatewayOrderId },
    );

    if (newStatus === PaymentOrderStatus.SUCCESS) {
        const inv = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.invoiceSK(order.invoiceId));
        if (inv && inv.status !== 'voided') {
            const newPaid = Math.min((inv.paidCents || 0) + order.amountCents, inv.totalCents);
            const newBalance = Math.max(inv.totalCents - newPaid, 0);
            const invStatus = newPaid >= inv.totalCents ? 'paid' : newPaid > 0 ? 'partially_paid' : inv.status;
            await updateItem(Keys.tenantPK(tenantId), Keys.invoiceSK(order.invoiceId), {
                updateExpression: 'SET paidCents = :paid, balanceCents = :bal, #s = :status, paymentMode = :upi, updatedAt = :now',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':paid': newPaid, ':bal': newBalance, ':status': invStatus, ':upi': 'upi', ':now': now },
            });
            await recordRevision(
                tenantId,
                'transactions',
                String(order.invoiceId || ''),
                'status_change',
                'system',
                inv,
                {
                    ...inv,
                    paidCents: newPaid,
                    balanceCents: newBalance,
                    status: invStatus,
                    paymentMode: 'upi',
                    updatedAt: now,
                },
                { source: 'payment-order.handleWebhook', paymentOrderId: order.id },
            );
        }
    }

    // In-Store Self Scan: confirm order and generate exit QR
    if (newStatus === PaymentOrderStatus.SUCCESS && order.receipt && String(order.receipt).startsWith('INSTORE-')) {
        try {
            const { confirmInStorePayment } = await import('../handlers/in-store-checkout');
            await confirmInStorePayment(String(order.receipt), tenantId, String(verification.gatewayTransactionId || ''));
        } catch (inStoreErr: unknown) {
            logger.error('In-store order confirmation failed', {
                receipt: order.receipt,
                error: (inStoreErr as Error).message,
            });
        }
    }

    await logAuditEvent({ tenantId, paymentOrderId: order.id, invoiceId: order.invoiceId, eventType: newStatus === PaymentOrderStatus.SUCCESS ? 'payment_success' : 'webhook_verified', eventData: { status: newStatus, gatewayOrderId } });
    return { success: true, orderId: order.id, status: newStatus, tenantId };
}

export async function getOrderStatus(tenantId: string, orderId: string): Promise<PaymentOrder | null> {
    const item = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), `PAYORDER#${orderId}`);
    return item ? mapOrderItem(item) : null;
}

export async function getOrderByInvoice(tenantId: string, invoiceId: string): Promise<PaymentOrder | null> {
    const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PAYORDER#', {
        filterExpression: 'invoiceId = :iid',
        expressionAttributeValues: { ':iid': invoiceId },
        limit: 1,
    });
    return result.items.length > 0 ? mapOrderItem(result.items[0]) : null;
}

export async function reconcilePendingOrders(tenantId: string): Promise<{ reconciled: number; updated: string[] }> {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const pendingOrders = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PAYORDER#', {
        filterExpression: '#s IN (:c, :qr, :p) AND webhookVerified = :false AND createdAt > :cutoff',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: { ':c': 'created', ':qr': 'qr_generated', ':p': 'pending', ':false': false, ':cutoff': cutoff },
    });

    const updated: string[] = [];
    for (const order of pendingOrders.items) {
        try {
            if (!order.gatewayOrderId) continue;
            let credentials;
            try { const decrypted = await paymentConfigService.getDecryptedConfig(tenantId, order.gatewayType as GatewayType); credentials = decrypted.credentials; }
            catch { continue; }

            let status: PaymentOrderStatus;
            try { const gateway = getGateway(order.gatewayType as GatewayType); status = await gateway.getPaymentStatus(credentials, order.gatewayOrderId); }
            finally { kmsService.secureWipeString(JSON.stringify(credentials)); }

            if (status !== PaymentOrderStatus.PENDING && status !== PaymentOrderStatus.CREATED) {
                try { validateTransition(order.status as PaymentOrderStatus, status); } catch { continue; }
                const now = new Date().toISOString();
                const previousOrderState = { ...order };
                await updateItem(order.PK, order.SK, {
                    updateExpression: 'SET #s = :status, updatedAt = :now',
                    expressionAttributeNames: { '#s': 'status' },
                    expressionAttributeValues: { ':status': status, ':now': now },
                });
                await recordRevision(
                    tenantId,
                    'payment_orders',
                    String(order.id || ''),
                    'status_change',
                    'system',
                    previousOrderState,
                    { ...previousOrderState, status, updatedAt: now },
                    { source: 'payment-order.reconcilePendingOrders' },
                );
                if (status === PaymentOrderStatus.SUCCESS) {
                    const inv = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), Keys.invoiceSK(order.invoiceId));
                    if (inv) {
                        const newPaid = Math.min((inv.paidCents || 0) + order.amountCents, inv.totalCents);
                        const newBalance = Math.max(inv.totalCents - newPaid, 0);
                        const newStatus = newPaid >= inv.totalCents ? 'paid' : 'partially_paid';
                        await updateItem(Keys.tenantPK(tenantId), Keys.invoiceSK(order.invoiceId), {
                            updateExpression: 'SET paidCents = :paid, balanceCents = :bal, #s = :status, updatedAt = :now',
                            expressionAttributeNames: { '#s': 'status' },
                            expressionAttributeValues: { ':paid': newPaid, ':bal': newBalance, ':status': newStatus, ':now': now },
                        });
                        await recordRevision(
                            tenantId,
                            'transactions',
                            String(order.invoiceId || ''),
                            'status_change',
                            'system',
                            inv,
                            {
                                ...inv,
                                paidCents: newPaid,
                                balanceCents: newBalance,
                                status: newStatus,
                                updatedAt: now,
                            },
                            { source: 'payment-order.reconcilePendingOrders', paymentOrderId: order.id },
                        );
                    }
                }
                updated.push(order.id);
            }
        } catch (err) { logger.error('Reconciliation error', { orderId: order.id, error: (err as Error).message }); }
    }
    return { reconciled: updated.length, updated };
}

async function logAuditEvent(entry: PaymentAuditEntry): Promise<void> {
    try {
        const now = new Date().toISOString();
        let previousHash = 'GENESIS';
        try {
            const prevResult = await queryItems<Record<string, any>>(
                Keys.tenantPK(entry.tenantId), 'PAYAUDIT#',
                { scanIndexForward: false, limit: 1 },
            );
            if (prevResult.items.length > 0 && prevResult.items[0].hash) previousHash = prevResult.items[0].hash;
        } catch {}

        const eventHash = crypto.createHash('sha256')
            .update(previousHash + JSON.stringify(entry.eventData) + entry.eventType + entry.tenantId)
            .digest('hex');

        await putItem({
            PK: Keys.tenantPK(entry.tenantId),
            SK: `PAYAUDIT#${now}#${uuidv4().substring(0, 8)}`,
            entityType: 'PAYMENT_AUDIT',
            tenantId: entry.tenantId,
            paymentOrderId: entry.paymentOrderId || null,
            invoiceId: entry.invoiceId || null,
            eventType: entry.eventType,
            eventData: entry.eventData,
            hash: eventHash,
            previousHash,
            createdAt: now,
        });
    } catch (err) { logger.error('Failed to write audit log', { eventType: entry.eventType, error: (err as Error).message }); }
}

function mapOrderItem(row: any): PaymentOrder {
    return {
        id: row.id, tenantId: row.tenantId, invoiceId: row.invoiceId,
        configId: row.configId, gatewayType: row.gatewayType as GatewayType,
        gatewayOrderId: row.gatewayOrderId, amountCents: Number(row.amountCents),
        currency: row.currency, status: row.status as PaymentOrderStatus,
        qrPayload: row.qrPayload, paymentUrl: row.paymentUrl,
        idempotencyKey: row.idempotencyKey, gatewayResponse: row.gatewayResponse || {},
        webhookReceivedAt: row.webhookReceivedAt ? new Date(row.webhookReceivedAt) : undefined,
        webhookVerified: row.webhookVerified,
        gatewayTransactionId: row.gatewayTransactionId,
        expiresAt: row.expiresAt ? new Date(row.expiresAt) : undefined,
        createdAt: new Date(row.createdAt), updatedAt: new Date(row.updatedAt),
    };
}
