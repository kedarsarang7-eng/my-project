import { config } from '../../config/environment';
// ============================================================================
// PhonePe Payment Gateway Implementation
// ============================================================================
// Implements the PaymentGateway interface for PhonePe PG API v1.
//
// API Docs: https://developer.phonepe.com/v1/reference/pay-api
//
// Flow:
//   1. createOrder → POST /pg/v1/pay (base64 payload + X-VERIFY checksum)
//   2. verifyWebhook → SHA256(response + /pg/v1/status + saltKey) + ### + saltIndex
//   3. getPaymentStatus → GET /pg/v1/status/{merchantId}/{txnId}
//   4. validateCredentials → GET /pg/v1/status test call
// ============================================================================

import * as crypto from 'crypto';
import { PaymentGateway } from './gateway.interface';
import {
    GatewayCredentials,
    PhonePeCredentials,
    CreateOrderRequest,
    CreateOrderResult,
    WebhookVerificationResult,
    PaymentOrderStatus,
} from '../../types/payment.types';
import { logger } from '../../utils/logger';

// PhonePe API base URLs
const PHONEPE_PROD_URL = 'https://api.phonepe.com/apis/hermes';
const PHONEPE_SANDBOX_URL = 'https://api-preprod.phonepe.com/apis/pg-sandbox';

function getBaseUrl(): string {
    return config.app.env === 'production' ? PHONEPE_PROD_URL : PHONEPE_SANDBOX_URL;
}

function asPhonePe(credentials: GatewayCredentials): PhonePeCredentials {
    const creds = credentials as PhonePeCredentials;
    if (!creds.merchantId || !creds.saltKey || !creds.saltIndex) {
        throw new Error('Invalid PhonePe credentials — missing required fields');
    }
    return creds;
}

export class PhonePeGateway implements PaymentGateway {

    async createOrder(
        credentials: GatewayCredentials,
        request: CreateOrderRequest
    ): Promise<CreateOrderResult> {
        const creds = asPhonePe(credentials);

        const payload = {
            merchantId: creds.merchantId,
            merchantTransactionId: request.orderId,
            merchantUserId: `MUID_${request.orderId.substring(0, 8)}`,
            amount: request.amountCents,  // PhonePe expects paise
            redirectUrl: request.redirectUrl || request.callbackUrl,
            redirectMode: 'POST',
            callbackUrl: request.callbackUrl,
            paymentInstrument: {
                type: 'PAY_PAGE',
            },
        };

        const base64Payload = Buffer.from(JSON.stringify(payload)).toString('base64');
        const checksum = this.generateChecksum(base64Payload, '/pg/v1/pay', creds);

        const url = `${getBaseUrl()}/pg/v1/pay`;

        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-VERIFY': checksum,
            },
            body: JSON.stringify({ request: base64Payload }),
        });

        const data = await response.json() as Record<string, any>;

        if (!response.ok || data.success === false) {
            logger.error('PhonePe createOrder failed', {
                status: response.status,
                code: data.code,
                message: data.message,
            });
            throw new Error(`PhonePe order creation failed: ${data.message || response.statusText}`);
        }

        const instrumentResponse = data.data?.instrumentResponse;
        const qrPayload = instrumentResponse?.qrData
            || `upi://pay?pa=${creds.merchantId}@ybl&pn=Merchant&am=${request.amountCents / 100}&tr=${request.orderId}&tn=Payment`;

        return {
            gatewayOrderId: request.orderId,  // PhonePe uses merchantTransactionId
            qrPayload,
            paymentUrl: instrumentResponse?.redirectInfo?.url,
            expiresAt: new Date(Date.now() + 15 * 60 * 1000), // 15 min default
            gatewayResponse: data,
        };
    }

    verifyWebhook(
        credentials: GatewayCredentials,
        headers: Record<string, string>,
        rawBody: string
    ): WebhookVerificationResult {
        const creds = asPhonePe(credentials);

        try {
            const xVerify = headers['x-verify'] || headers['X-VERIFY'] || headers['X-Verify'];
            if (!xVerify) {
                return { isValid: false, error: 'Missing X-VERIFY header' };
            }

            const body = JSON.parse(rawBody);
            const response = body.response;

            if (!response) {
                return { isValid: false, error: 'Missing response field in webhook body' };
            }

            // Verify checksum: SHA256(response + saltKey) + ### + saltIndex
            const expectedChecksum = crypto
                .createHash('sha256')
                .update(response + creds.saltKey)
                .digest('hex') + '###' + creds.saltIndex;

            // FIX (M-2): Constant-time comparison to prevent timing attacks.
            // Same pattern as Razorpay fix (C-2) for consistent security posture.
            const xVerifyBuf = Buffer.from(xVerify, 'utf-8');
            const expectedBuf = Buffer.from(expectedChecksum, 'utf-8');

            if (xVerifyBuf.length !== expectedBuf.length ||
                !crypto.timingSafeEqual(xVerifyBuf, expectedBuf)) {
                logger.warn('SECURITY: PhonePe webhook checksum mismatch', {
                    checksumLength: xVerify.length,
                    expectedLength: expectedChecksum.length,
                });
                return { isValid: false, error: 'Checksum verification failed' };
            }

            // Decode the base64 response
            const decodedResponse = JSON.parse(
                Buffer.from(response, 'base64').toString('utf-8')
            );

            const statusMap: Record<string, PaymentOrderStatus> = {
                'PAYMENT_SUCCESS': PaymentOrderStatus.SUCCESS,
                'PAYMENT_ERROR': PaymentOrderStatus.FAILED,
                'PAYMENT_DECLINED': PaymentOrderStatus.FAILED,
                'PAYMENT_PENDING': PaymentOrderStatus.PENDING,
            };

            return {
                isValid: true,
                gatewayOrderId: decodedResponse.data?.merchantTransactionId,
                gatewayTransactionId: decodedResponse.data?.transactionId,
                amountCents: decodedResponse.data?.amount,
                status: statusMap[decodedResponse.code] || PaymentOrderStatus.PENDING,
                rawPayload: decodedResponse,
            };

        } catch (err) {
            logger.error('PhonePe webhook verification error', { error: (err as Error).message });
            return { isValid: false, error: (err as Error).message };
        }
    }

    async getPaymentStatus(
        credentials: GatewayCredentials,
        gatewayOrderId: string
    ): Promise<PaymentOrderStatus> {
        const creds = asPhonePe(credentials);
        const path = `/pg/v1/status/${creds.merchantId}/${gatewayOrderId}`;
        const checksum = this.generateChecksum('', path, creds);

        const url = `${getBaseUrl()}${path}`;
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'X-VERIFY': checksum,
                'X-MERCHANT-ID': creds.merchantId,
            },
        });

        const data = await response.json() as Record<string, any>;

        const statusMap: Record<string, PaymentOrderStatus> = {
            'PAYMENT_SUCCESS': PaymentOrderStatus.SUCCESS,
            'PAYMENT_ERROR': PaymentOrderStatus.FAILED,
            'PAYMENT_DECLINED': PaymentOrderStatus.FAILED,
            'PAYMENT_PENDING': PaymentOrderStatus.PENDING,
            'BAD_REQUEST': PaymentOrderStatus.FAILED,
        };

        return statusMap[data.code] || PaymentOrderStatus.PENDING;
    }

    async validateCredentials(credentials: GatewayCredentials): Promise<boolean> {
        const creds = asPhonePe(credentials);

        try {
            // Make a status check call with a dummy transaction ID
            // If credentials are valid, PhonePe will return a proper error (not auth failure)
            const path = `/pg/v1/status/${creds.merchantId}/VALIDATE_TEST_${Date.now()}`;
            const checksum = this.generateChecksum('', path, creds);

            const url = `${getBaseUrl()}${path}`;
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    'X-VERIFY': checksum,
                    'X-MERCHANT-ID': creds.merchantId,
                },
            });

            const data = await response.json() as Record<string, any>;

            // If we get a proper PhonePe response (even error), credentials are valid
            // Invalid credentials would cause an auth error (401/403)
            if (response.status === 401 || response.status === 403) {
                return false;
            }

            // Valid credentials — PhonePe recognized the merchant
            logger.info('PhonePe credential validation successful', {
                responseCode: data.code,
            });
            return true;

        } catch (err) {
            logger.error('PhonePe credential validation failed', {
                error: (err as Error).message,
            });
            return false;
        }
    }

    // ── Private Helpers ─────────────────────────────────────────────────────

    private generateChecksum(
        payload: string,
        apiPath: string,
        creds: PhonePeCredentials
    ): string {
        const dataToHash = payload + apiPath + creds.saltKey;
        return crypto.createHash('sha256').update(dataToHash).digest('hex')
            + '###' + creds.saltIndex;
    }
}
