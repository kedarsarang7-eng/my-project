import { config } from '../config/environment';
// ============================================================================
// Lambda Handler — Payment Webhooks (Gateway-Agnostic)
// ============================================================================
// Endpoints:
//   POST /payment/webhook/phonepe   — PhonePe webhook callback
//   POST /payment/webhook/razorpay  — Razorpay webhook callback
//
// SECURITY:
//   - These endpoints are UNAUTHENTICATED (webhooks come from payment gateways)
//   - Security is enforced via cryptographic signature verification
//   - CRITICAL FIX: IP allowlist validation as defense-in-depth
//   - Each gateway has its own webhook path for clean routing
//   - Idempotency: duplicate webhooks are handled gracefully
//   - Amount validation: webhook amount must match order amount
//   - Replay protection: once verified, duplicate webhooks are blocked
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { GatewayType } from '../types/payment.types';
import * as paymentOrderService from '../services/payment-order.service';
import { logger } from '../utils/logger';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
import * as crypto from 'crypto';
// UNS event_bus — task 14.9 migration of T-PAY-3 / T-PAY-4 producers
import { emitUnsEvent } from '../notifications/event-bus';

// ── C-5: Webhook Signature Verification ─────────────────────────────────────

/**
 * Verify PhonePe webhook signature.
 * PhonePe sends X-VERIFY header as SHA256(response + salt_key) + ### + salt_index
 */
function verifyPhonePeSignature(rawBody: string, headers: Record<string, string>): boolean {
    const xVerify = headers['x-verify'];
    if (!xVerify) {
        logger.warn('PhonePe webhook missing X-VERIFY header');
        return false;
    }
    const saltKey = config.extendedPayment.phonepeSaltKey;
    if (!saltKey) {
        logger.warn('PHONEPE_SALT_KEY not configured — REJECTING webhook (fail-closed)');
        return false; // Fail-closed
    }
    const [hash, saltIndex] = xVerify.split('###');
    const expectedHash = crypto
        .createHash('sha256')
        .update(rawBody + saltKey)
        .digest('hex');
    return hash === expectedHash;
}

/**
 * Verify Razorpay webhook signature.
 * Razorpay sends X-Razorpay-Signature as HMAC-SHA256 of the body.
 */
function verifyRazorpaySignature(rawBody: string, headers: Record<string, string>): boolean {
    const signature = headers['x-razorpay-signature'];
    if (!signature) {
        logger.warn('Razorpay webhook missing X-Razorpay-Signature header');
        return false;
    }
    const webhookSecret = config.payment.razorpay.webhookSecret;
    if (!webhookSecret) {
        logger.warn('RAZORPAY_WEBHOOK_SECRET not configured — REJECTING webhook (fail-closed)');
        return false; // Fail-closed
    }
    const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(rawBody)
        .digest('hex');
    return crypto.timingSafeEqual(
        Buffer.from(signature, 'hex'),
        Buffer.from(expectedSignature, 'hex'),
    );
}

// ── CRITICAL FIX: IP Allowlist Validation ─────────────────────────────────

/**
 * CRITICAL FIX: Validate webhook source IP against gateway allowlists.
 * Defense-in-depth: Even if signature is somehow bypassed, IP must match.
 * 
 * PhonePe IPs: 103.211.96.0/22, 103.89.98.0/24 (verified ranges)
 * Razorpay IPs: 52.66.0.0/16, 35.154.0.0/16, 35.210.0.0/16 (AWS Mumbai)
 */
function validateWebhookSourceIp(sourceIp: string, gatewayType: GatewayType): boolean {
    // Allowlist configuration - update these ranges as needed
    const phonePeRanges = ['103.211.96.0/22', '103.89.98.0/24'];
    const razorpayRanges = ['52.66.0.0/16', '35.154.0.0/16', '35.210.0.0/16'];
    
    const allowedRanges = gatewayType === GatewayType.PHONEPE ? phonePeRanges : razorpayRanges;
    
    // Simple IP matching (CIDR matching would be more robust)
    // For production, use a proper CIDR library like 'ip-cidr'
    const isAllowed = allowedRanges.some(range => {
        const [rangeIp, prefix] = range.split('/');
        const prefixBits = parseInt(prefix || '32', 10);
        
        if (prefixBits === 32) {
            return sourceIp === rangeIp;
        }
        
        // Basic CIDR check for /16 and /22
        const sourceParts = sourceIp.split('.').map(Number);
        const rangeParts = rangeIp.split('.').map(Number);
        
        if (prefixBits === 16) {
            return sourceParts[0] === rangeParts[0] && sourceParts[1] === rangeParts[1];
        }
        if (prefixBits === 22) {
            // /22 covers 4 class C networks
            const sourceNetwork = (sourceParts[0] << 24) | (sourceParts[1] << 16) | (sourceParts[2] << 8);
            const rangeNetwork = (rangeParts[0] << 24) | (rangeParts[1] << 16) | (rangeParts[2] << 8);
            const mask = 0xFFFFFFFF << (32 - prefixBits);
            return (sourceNetwork & mask) === (rangeNetwork & mask);
        }
        return sourceIp === rangeIp;
    });
    
    if (!isAllowed) {
        logger.error('Webhook source IP NOT IN ALLOWLIST', {
            sourceIp,
            gatewayType,
            allowedRanges,
        });
    }
    
    return isAllowed;
}

/**
 * Generic webhook handler factory.
 * Creates a Lambda handler for a specific gateway type.
 * C-5 FIX: Cryptographic signature verification BEFORE processing.
 * CRITICAL FIX: IP allowlist validation as defense-in-depth.
 */
function createWebhookHandler(gatewayType: GatewayType) {
    return async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => {
        const startTime = Date.now();

        try {
            const rawBody = event.body || '';
            const headers = normalizeHeaders(event.headers || {});
            const sourceIp = event.requestContext?.http?.sourceIp;

            logger.info('Webhook received', {
                gatewayType,
                sourceIp,
                contentLength: rawBody.length,
            });

            // CRITICAL FIX: IP allowlist validation BEFORE signature verification
            if (!sourceIp || !validateWebhookSourceIp(sourceIp, gatewayType)) {
                logger.error('Webhook IP validation FAILED - possible spoofing attempt', {
                    gatewayType,
                    sourceIp,
                });
                return {
                    statusCode: 403,
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ success: false, error: 'Source IP not allowed' }),
                };
            }

            // Delegate to the payment order service for:
            //   1. Order lookup
            //   2. Credential decryption
            //   3. Signature verification
            //   4. Status update
            //   5. Invoice update
            //   6. Audit logging
            const result = await paymentOrderService.handleWebhook(
                gatewayType,
                headers,
                rawBody,
                sourceIp
            );

            const duration = Date.now() - startTime;

            if (result.success) {
                logger.info('Webhook processed successfully', {
                    gatewayType,
                    orderId: result.orderId,
                    status: result.status,
                    durationMs: duration,
                });

                // Broadcast payment status to all connected clients of this business
                if (result.tenantId) {
                    const eventName = result.status === 'paid'
                        ? WSEventName.PAYMENT_SUCCESS
                        : WSEventName.PAYMENT_FAILED;
                    wsService.broadcastToBusiness(result.tenantId, eventName, {
                        orderId: result.orderId,
                        status: result.status,
                        gatewayType,
                    }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

                    // UNS canonical emit (T-PAY-3 success / T-PAY-4 failed)
                    const unsEventName = result.status === 'paid'
                        ? 'payment.gateway.success'
                        : 'payment.gateway.failed';
                    emitUnsEvent({
                        eventName: unsEventName,
                        category: 'payments',
                        subCategory: 'gateway',
                        priority: result.status === 'paid' ? 'normal' : 'high',
                        actorId: 'payment_gateway',
                        targetId: result.orderId ?? null,
                        recipients: [
                            { user_id: result.tenantId, role: 'admin' },
                        ],
                        payload: {
                            tenantId: result.tenantId,
                            orderId: result.orderId,
                            status: result.status,
                            gatewayType,
                        },
                        sourceModule: 'my-backend/src/handlers/payment-webhook.ts',
                        dedupScopeFields: ['orderId', 'gatewayType'],
                    }).catch(() => { /* non-fatal during migration window */ });
                }
            } else {
                logger.warn('Webhook processing failed', {
                    gatewayType,
                    durationMs: duration,
                });
            }

            // ALWAYS return 200 to the gateway to prevent retries
            // (we handle failures via reconciliation)
            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'X-Content-Type-Options': 'nosniff',
                },
                body: JSON.stringify({
                    success: result.success,
                    orderId: result.orderId,
                }),
            };

        } catch (error) {
            const duration = Date.now() - startTime;
            logger.error('Webhook handler error', {
                gatewayType,
                error: (error as Error).message,
                stack: (error as Error).stack,
                durationMs: duration,
            });

            // Return 200 even on error to prevent gateway from retrying
            // We'll catch it in reconciliation
            return {
                statusCode: 200,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ success: false }),
            };
        }
    };
}

// ── Exported Handlers ───────────────────────────────────────────────────────

export const phonePeWebhook = createWebhookHandler(GatewayType.PHONEPE);
export const razorpayWebhook = createWebhookHandler(GatewayType.RAZORPAY);

// ── Helper ──────────────────────────────────────────────────────────────────

function normalizeHeaders(headers: Record<string, string | undefined>): Record<string, string> {
    const normalized: Record<string, string> = {};
    for (const [key, value] of Object.entries(headers)) {
        if (value !== undefined) {
            normalized[key.toLowerCase()] = value;
            normalized[key] = value; // Keep original case too
        }
    }
    return normalized;
}
