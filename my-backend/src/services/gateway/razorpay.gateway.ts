// ============================================================================
// Razorpay Payment Gateway Implementation
// ============================================================================
// Implements the PaymentGateway interface for Razorpay API v1.
//
// API Docs: https://razorpay.com/docs/api/
//
// Flow:
//   1. createOrder → POST /v1/orders + POST /v1/payments/qr_codes
//   2. verifyWebhook → HMAC SHA256 with webhook secret
//   3. getPaymentStatus → GET /v1/orders/{id}
//   4. validateCredentials → GET /v1/payments?count=0
// ============================================================================

import * as crypto from 'crypto';
import { PaymentGateway } from './gateway.interface';
import {
    GatewayCredentials,
    RazorpayCredentials,
    CreateOrderRequest,
    CreateOrderResult,
    WebhookVerificationResult,
    PaymentOrderStatus,
} from '../../types/payment.types';
import { logger } from '../../utils/logger';

const RAZORPAY_API_URL = 'https://api.razorpay.com';

function asRazorpay(credentials: GatewayCredentials): RazorpayCredentials {
    const creds = credentials as RazorpayCredentials;
    if (!creds.keyId || !creds.keySecret) {
        throw new Error('Invalid Razorpay credentials — missing keyId or keySecret');
    }
    return creds;
}

function authHeader(creds: RazorpayCredentials): string {
    return 'Basic ' + Buffer.from(`${creds.keyId}:${creds.keySecret}`).toString('base64');
}

export class RazorpayGateway implements PaymentGateway {

    async createOrder(
        credentials: GatewayCredentials,
        request: CreateOrderRequest
    ): Promise<CreateOrderResult> {
        const creds = asRazorpay(credentials);

        // Step 1: Create Razorpay Order
        const orderPayload = {
            amount: request.amountCents,  // Razorpay expects paise
            currency: request.currency || 'INR',
            receipt: request.invoiceId,
            notes: {
                invoice_id: request.invoiceId,
                order_id: request.orderId,
                customer_name: request.customerName || '',
            },
        };

        const orderResponse = await fetch(`${RAZORPAY_API_URL}/v1/orders`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': authHeader(creds),
            },
            body: JSON.stringify(orderPayload),
        });

        const orderData = await orderResponse.json() as Record<string, any>;

        if (!orderResponse.ok) {
            logger.error('Razorpay createOrder failed', {
                status: orderResponse.status,
                error: orderData.error,
            });
            throw new Error(
                `Razorpay order creation failed: ${orderData.error?.description || orderResponse.statusText}`
            );
        }

        const razorpayOrderId = orderData.id;

        // Step 2: Generate QR Code for the order
        let qrPayload: string | undefined;
        try {
            const qrResponse = await fetch(`${RAZORPAY_API_URL}/v1/payments/qr_codes`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': authHeader(creds),
                },
                body: JSON.stringify({
                    type: 'upi_qr',
                    name: request.description || 'Payment',
                    usage: 'single_use',
                    fixed_amount: true,
                    payment_amount: request.amountCents,
                    description: `Invoice ${request.invoiceId}`,
                    close_by: Math.floor(Date.now() / 1000) + 15 * 60, // 15 min
                    notes: {
                        order_id: razorpayOrderId,
                        invoice_id: request.invoiceId,
                    },
                }),
            });

            const qrData = await qrResponse.json() as Record<string, any>;
            if (qrResponse.ok) {
                qrPayload = qrData.image_url || qrData.id;
            } else {
                logger.warn('Razorpay QR generation failed, falling back to payment link', {
                    error: qrData.error,
                });
            }
        } catch (qrErr) {
            logger.warn('Razorpay QR generation error', { error: (qrErr as Error).message });
        }

        // Fallback: generate UPI intent URL if QR fails
        if (!qrPayload) {
            qrPayload = `upi://pay?pa=${creds.keyId}@razorpay&pn=Merchant&am=${request.amountCents / 100}&tr=${razorpayOrderId}&tn=Payment`;
        }

        return {
            gatewayOrderId: razorpayOrderId,
            qrPayload,
            paymentUrl: orderData.short_url,
            expiresAt: new Date(Date.now() + 15 * 60 * 1000),
            gatewayResponse: orderData,
        };
    }

    verifyWebhook(
        credentials: GatewayCredentials,
        headers: Record<string, string>,
        rawBody: string
    ): WebhookVerificationResult {
        const creds = asRazorpay(credentials);

        try {
            const signature = headers['x-razorpay-signature'] || headers['X-Razorpay-Signature'];
            if (!signature) {
                return { isValid: false, error: 'Missing X-Razorpay-Signature header' };
            }

            // HMAC SHA256 verification
            const expectedSignature = crypto
                .createHmac('sha256', creds.webhookSecret)
                .update(rawBody)
                .digest('hex');

            // FIX (C-2): Constant-time comparison to prevent timing attacks.
            // An attacker measuring response times on `!==` could iteratively
            // discover correct HMAC bytes. timingSafeEqual runs in constant time.
            const sigBuf = Buffer.from(signature, 'hex');
            const expectedBuf = Buffer.from(expectedSignature, 'hex');

            if (sigBuf.length !== expectedBuf.length ||
                !crypto.timingSafeEqual(sigBuf, expectedBuf)) {
                logger.warn('SECURITY: Razorpay webhook signature mismatch', {
                    signatureLength: signature.length,
                    expectedLength: expectedSignature.length,
                });
                return { isValid: false, error: 'HMAC signature verification failed' };
            }

            const body = JSON.parse(rawBody);
            const event = body.event;
            const paymentEntity = body.payload?.payment?.entity;
            const orderEntity = body.payload?.order?.entity;

            // Map Razorpay events to our status
            const statusMap: Record<string, PaymentOrderStatus> = {
                'payment.captured': PaymentOrderStatus.SUCCESS,
                'payment.authorized': PaymentOrderStatus.PENDING,
                'payment.failed': PaymentOrderStatus.FAILED,
                'order.paid': PaymentOrderStatus.SUCCESS,
                'refund.created': PaymentOrderStatus.REFUNDED,
            };

            return {
                isValid: true,
                gatewayOrderId: paymentEntity?.order_id || orderEntity?.id,
                gatewayTransactionId: paymentEntity?.id,
                amountCents: paymentEntity?.amount || orderEntity?.amount,
                status: statusMap[event] || PaymentOrderStatus.PENDING,
                rawPayload: body,
            };

        } catch (err) {
            logger.error('Razorpay webhook verification error', { error: (err as Error).message });
            return { isValid: false, error: (err as Error).message };
        }
    }

    async getPaymentStatus(
        credentials: GatewayCredentials,
        gatewayOrderId: string
    ): Promise<PaymentOrderStatus> {
        const creds = asRazorpay(credentials);

        const response = await fetch(`${RAZORPAY_API_URL}/v1/orders/${gatewayOrderId}`, {
            method: 'GET',
            headers: {
                'Authorization': authHeader(creds),
            },
        });

        const data = await response.json() as Record<string, any>;

        const statusMap: Record<string, PaymentOrderStatus> = {
            'created': PaymentOrderStatus.CREATED,
            'attempted': PaymentOrderStatus.PENDING,
            'paid': PaymentOrderStatus.SUCCESS,
        };

        return statusMap[data.status] || PaymentOrderStatus.PENDING;
    }

    async validateCredentials(credentials: GatewayCredentials): Promise<boolean> {
        const creds = asRazorpay(credentials);

        try {
            // Simple API call to verify credentials
            const response = await fetch(`${RAZORPAY_API_URL}/v1/payments?count=0`, {
                method: 'GET',
                headers: {
                    'Authorization': authHeader(creds),
                },
            });

            if (response.status === 401) {
                return false;
            }

            logger.info('Razorpay credential validation successful', {
                status: response.status,
            });
            return response.ok;

        } catch (err) {
            logger.error('Razorpay credential validation failed', {
                error: (err as Error).message,
            });
            return false;
        }
    }
}
