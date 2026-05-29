import { config } from '../../config/environment';
// ============================================================================
// Lambda: razorpayWebhookHandler
// Purpose: Process Razorpay webhooks with signature verification & idempotency
// Route: POST /billing/webhook/razorpay (Public, signature verified)
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { createHmac, timingSafeEqual } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import {
    docClient, TABLE_NAMES, PaymentKeys, Bill, PaymentEvent, PaymentStatus
} from '../../config/payment-tables.config';
import { GetCommand, PutCommand, UpdateCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { logger } from '../../utils/logger';

// ============================================================================
// Environment Configuration
// ============================================================================

const RAZORPAY_WEBHOOK_SECRET = config.payment.razorpay.webhookSecret || '';

// ============================================================================
// Type Definitions
// ============================================================================

interface RazorpayWebhookPayload {
    event: 'payment.captured' | 'payment.failed' | 'qr_code.closed' | 'order.paid' | string;
    payload: {
        payment?: {
            entity: {
                id: string;
                order_id?: string;
                status: 'captured' | 'failed';
                amount: number;
                method: string;
                captured_at?: number;
                error_code?: string;
                error_description?: string;
                notes?: Record<string, string>;
            };
        };
        qr_code?: {
            entity: {
                id: string;
                order_id?: string;
                status: string;
                close_reason?: string;
            };
        };
        order?: {
            entity: {
                id: string;
                status: string;
                receipt?: string;
                notes?: Record<string, string>;
            };
        };
    };
    created_at: number;
}

// ============================================================================
// Utility Functions
// ============================================================================

function errorResponse(statusCode: number, message: string): APIGatewayProxyResult {
    return {
        statusCode,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ success: false, error: message }),
    };
}

function successResponse(): APIGatewayProxyResult {
    return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ success: true }),
    };
}

// ============================================================================
// Signature Verification
// ============================================================================

function verifyWebhookSignature(body: string, signature: string): boolean {
    if (!RAZORPAY_WEBHOOK_SECRET) {
        logger.error('RAZORPAY_WEBHOOK_SECRET not configured', { handler: 'razorpayWebhook' });
        return false;
    }
    
    const expectedSignature = createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
        .update(body, 'utf8')
        .digest('hex');
    
    try {
        // Timing-safe comparison
        const sigBuf = Buffer.from(signature, 'hex');
        const expectedBuf = Buffer.from(expectedSignature, 'hex');
        
        if (sigBuf.length !== expectedBuf.length) {
            return false;
        }
        
        return timingSafeEqual(sigBuf, expectedBuf);
    } catch {
        return false;
    }
}

// ============================================================================
// Idempotency Check
// ============================================================================

async function checkIdempotency(razorpayEventId: string): Promise<boolean> {
    const result = await docClient.send(new QueryCommand({
        TableName: TABLE_NAMES.PAYMENT_EVENTS,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :gsi1pk AND GSI1SK = :gsi1sk',
        ExpressionAttributeValues: {
            ':gsi1pk': `RAZORPAY#${razorpayEventId}`,
            ':gsi1sk': 'EVENT#' + razorpayEventId,
        },
        Limit: 1,
    }));
    
    return (result.Items?.length ?? 0) > 0;
}

// ============================================================================
// DynamoDB Operations
// ============================================================================

async function getBillByOrderId(orderId: string): Promise<Bill | null> {
    const result = await docClient.send(new QueryCommand({
        TableName: TABLE_NAMES.BILLS,
        IndexName: 'GSI2',
        KeyConditionExpression: 'GSI2PK = :gsi2pk',
        ExpressionAttributeValues: {
            ':gsi2pk': PaymentKeys.gsi2Order(orderId),
        },
        Limit: 1,
    }));
    
    return result.Items?.[0] as Bill | null;
}

async function updateBillPaymentStatus(
    billId: string,
    status: PaymentStatus,
    updates: {
        razorpayPaymentId?: string;
        paidAt?: string;
        actualPaymentMethod?: string;
        failureReason?: string;
        failureCode?: string;
    }
): Promise<void> {
    const now = new Date().toISOString();
    
    let updateExpr = 'SET paymentStatus = :status, updatedAt = :now, GSI3PK = :gsi3pk';
    const values: Record<string, unknown> = {
        ':status': status,
        ':now': now,
        ':gsi3pk': PaymentKeys.gsi3Status(status),
    };
    
    if (updates.razorpayPaymentId) {
        updateExpr += ', razorpayPaymentId = :paymentId';
        values[':paymentId'] = updates.razorpayPaymentId;
    }
    if (updates.paidAt) {
        updateExpr += ', paidAt = :paidAt';
        values[':paidAt'] = updates.paidAt;
    }
    if (updates.actualPaymentMethod) {
        updateExpr += ', actualPaymentMethod = :method';
        values[':method'] = updates.actualPaymentMethod;
    }
    if (updates.failureReason) {
        updateExpr += ', failureReason = :reason';
        values[':reason'] = updates.failureReason;
    }
    if (updates.failureCode) {
        updateExpr += ', failureCode = :code';
        values[':code'] = updates.failureCode;
    }
    
    await docClient.send(new UpdateCommand({
        TableName: TABLE_NAMES.BILLS,
        Key: { PK: PaymentKeys.billPK(billId), SK: PaymentKeys.billSK() },
        UpdateExpression: updateExpr,
        ExpressionAttributeValues: values,
    }));
}

async function logPaymentEvent(
    billId: string,
    eventType: 'CREATED' | 'CAPTURED' | 'FAILED' | 'EXPIRED',
    razorpayEventId: string,
    rawPayload: Record<string, unknown>
): Promise<void> {
    const eventId = uuidv4();
    const now = new Date();
    
    const event: PaymentEvent = {
        PK: PaymentKeys.eventPK(eventId),
        SK: PaymentKeys.eventSK(billId),
        eventId,
        billId,
        eventType,
        razorpayEventId,
        rawPayload,
        processedAt: now.toISOString(),
        processedBy: 'webhook-handler',
        TTL: Math.floor(now.getTime() / 1000) + (90 * 24 * 60 * 60),
        GSI1PK: `RAZORPAY#${razorpayEventId}`,
        GSI1SK: PaymentKeys.gsi1EventTime(now.toISOString()),
    };
    
    await docClient.send(new PutCommand({
        TableName: TABLE_NAMES.PAYMENT_EVENTS,
        Item: event,
    }));
}

// ============================================================================
// Event Handlers
// ============================================================================

async function handlePaymentCaptured(payload: RazorpayWebhookPayload['payload']): Promise<void> {
    const payment = payload.payment?.entity;
    if (!payment || !payment.order_id) return;
    
    const orderId = payment.order_id;
    const razorpayPaymentId = payment.id;
    
    logger.info('Payment captured', { razorpayPaymentId, orderId, handler: 'razorpayWebhook' });
    
    // Find bill by order ID
    const bill = await getBillByOrderId(orderId);
    if (!bill) {
        logger.error('Bill not found for order', { orderId, handler: 'razorpayWebhook' });
        return;
    }
    
    // Skip if already paid
    if (bill.paymentStatus === 'PAID') {
        logger.info('Bill already paid, skipping', { billId: bill.billId, handler: 'razorpayWebhook' });
        return;
    }
    
    // Update bill status
    const paidAt = payment.captured_at 
        ? new Date(payment.captured_at * 1000).toISOString()
        : new Date().toISOString();
    
    await updateBillPaymentStatus(bill.billId, 'PAID', {
        razorpayPaymentId,
        paidAt,
        actualPaymentMethod: payment.method,
    });
    
    logger.info('Bill marked as PAID', { billId: bill.billId, handler: 'razorpayWebhook' });
}

async function handlePaymentFailed(payload: RazorpayWebhookPayload['payload']): Promise<void> {
    const payment = payload.payment?.entity;
    if (!payment || !payment.order_id) return;
    
    const orderId = payment.order_id;
    const razorpayPaymentId = payment.id;
    
    logger.info('Payment failed', { razorpayPaymentId, orderId, handler: 'razorpayWebhook' });
    
    const bill = await getBillByOrderId(orderId);
    if (!bill) {
        logger.error('Bill not found for order', { orderId, handler: 'razorpayWebhook' });
        return;
    }
    
    // Skip if already resolved
    if (bill.paymentStatus === 'PAID' || bill.paymentStatus === 'FAILED') {
        return;
    }
    
    await updateBillPaymentStatus(bill.billId, 'FAILED', {
        razorpayPaymentId,
        failureReason: payment.error_description || 'Payment failed',
        failureCode: payment.error_code || 'PAYMENT_FAILED',
    });
    
    logger.info('Bill marked as FAILED', { billId: bill.billId, handler: 'razorpayWebhook' });
}

async function handleQRClosed(payload: RazorpayWebhookPayload['payload']): Promise<void> {
    const qrCode = payload.qr_code?.entity;
    if (!qrCode || !qrCode.order_id) return;
    
    const orderId = qrCode.order_id;
    logger.info('QR closed', { qrCodeId: qrCode.id, orderId, reason: qrCode.close_reason, handler: 'razorpayWebhook' });
    
    const bill = await getBillByOrderId(orderId);
    if (!bill) return;
    
    // Only mark as expired if still pending
    if (bill.paymentStatus === 'PENDING') {
        await updateBillPaymentStatus(bill.billId, 'EXPIRED', {
            failureReason: qrCode.close_reason || 'QR code expired',
            failureCode: 'QR_EXPIRED',
        });
        logger.info('Bill marked as EXPIRED', { billId: bill.billId, handler: 'razorpayWebhook' });
    }
}

// ============================================================================
// Main Handler
// ============================================================================

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const requestId = uuidv4();
    logger.info('Webhook received', { requestId, eventId: event.headers['X-Razorpay-Event-Id'] || 'unknown', handler: 'razorpayWebhook' });
    
    try {
        // Get raw body
        const body = event.body || '';
        
        // Get signature from header
        const signature = event.headers['X-Razorpay-Signature'] || event.headers['x-razorpay-signature'];
        if (!signature) {
            logger.error('Missing webhook signature', { requestId, handler: 'razorpayWebhook' });
            return errorResponse(401, 'Missing signature');
        }
        
        // Verify signature
        if (!verifyWebhookSignature(body, signature)) {
            logger.error('Invalid webhook signature', { requestId, handler: 'razorpayWebhook' });
            return errorResponse(401, 'Invalid signature');
        }
        
        // Parse payload
        let payload: RazorpayWebhookPayload;
        try {
            payload = JSON.parse(body);
        } catch {
            return errorResponse(400, 'Invalid JSON payload');
        }
        
        const eventType = payload.event;
        const razorpayEventId = event.headers['X-Razorpay-Event-Id'] || event.headers['x-razorpay-event-id'];
        if (!razorpayEventId) {
            logger.error('Missing X-Razorpay-Event-Id header', { requestId, handler: 'razorpayWebhook' });
            return errorResponse(400, 'Missing X-Razorpay-Event-Id header');
        }
        
        logger.info('Processing webhook', { requestId, eventType, razorpayEventId, handler: 'razorpayWebhook' });
        
        // Check idempotency
        const isDuplicate = await checkIdempotency(razorpayEventId);
        if (isDuplicate) {
            logger.info('Duplicate webhook, skipping', { requestId, razorpayEventId, handler: 'razorpayWebhook' });
            return successResponse();
        }
        
        // Process event
        switch (eventType) {
            case 'payment.captured':
                await handlePaymentCaptured(payload.payload);
                await logPaymentEvent(
                    payload.payload.payment?.entity?.notes?.billId || 'unknown',
                    'CAPTURED',
                    razorpayEventId,
                    payload.payload as Record<string, unknown>
                );
                break;
                
            case 'payment.failed':
                await handlePaymentFailed(payload.payload);
                await logPaymentEvent(
                    payload.payload.payment?.entity?.notes?.billId || 'unknown',
                    'FAILED',
                    razorpayEventId,
                    payload.payload as Record<string, unknown>
                );
                break;
                
            case 'qr_code.closed':
                await handleQRClosed(payload.payload);
                await logPaymentEvent(
                    'unknown',
                    'EXPIRED',
                    razorpayEventId,
                    payload.payload as Record<string, unknown>
                );
                break;
                
            case 'order.paid':
                // Order.paid is typically followed by payment.captured
                // We can handle it similarly if needed
                logger.info('Order paid event received, will be handled by payment.captured', { requestId, handler: 'razorpayWebhook' });
                break;
                
            default:
                logger.info('Unhandled event type', { requestId, eventType, handler: 'razorpayWebhook' });
        }
        
        // Always return 200 to Razorpay
        return successResponse();
        
    } catch (error) {
        logger.error('Webhook processing error', { requestId, error: error instanceof Error ? error.message : String(error), handler: 'razorpayWebhook' });
        // Return 200 anyway to prevent Razorpay from retrying indefinitely
        // The event will be logged and can be reconciled manually
        return successResponse();
    }
};

export default handler;
