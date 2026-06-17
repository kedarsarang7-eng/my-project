import { config } from '../config/environment';
// ============================================================================
// Lambda Handler — Payment (QR Generation & Status)
// ============================================================================
// Endpoints:
//   POST /payment/initiate          — Generate QR / payment link (multi-tenant)
//   GET  /payment/status            — Check payment order status
//   POST /payment/reconcile         — Reconcile pending orders (offline recovery)
//
// REPLACES the old single-tenant PhonePe-only handler.
// Now fully gateway-agnostic and multi-tenant.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { GatewayType } from '../types/payment.types';
import { parseBody } from '../middleware/validation';
import {
    initiatePaymentOrderSchema,
    getPaymentOrderStatusSchema,
} from '../schemas/payment.schema';
import * as paymentOrderService from '../services/payment-order.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /payment/initiate
 * Create a payment order and generate QR code / payment link.
 *
 * Flow:
 *   1. Validate JWT → extract tenant_id
 *   2. Validate invoice belongs to tenant
 *   3. Fetch & decrypt merchant credentials (KMS)
 *   4. Call gateway API to create order + QR
 *   5. Store payment order in DB
 *   6. Return QR data to desktop/mobile client
 *
 * Desktop NEVER sees merchant secrets.
 */
export const initiatePayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        const parsed = parseBody(initiatePaymentOrderSchema, event);
        if (!parsed.success) return parsed.error;

        const { invoiceId, gatewayType } = parsed.data;

        // Derive callback base URL from the API Gateway domain
        const domainName = event.requestContext?.domainName;
        const stage = (event.requestContext as any)?.stage;
        const callbackBaseUrl = domainName
            ? `https://${domainName}${stage && stage !== '$default' ? `/${stage}` : ''}`
            : (config.extendedApp.slsBackendUrl || (() => { throw new Error('API_BASE_URL is required when domainName is unavailable'); })());

        const result = await paymentOrderService.createPaymentOrder(
            auth.tenantId,
            {
                invoiceId,
                gatewayType: gatewayType as GatewayType | undefined,
            },
            callbackBaseUrl
        );

        logger.info('Payment initiated', {
            tenantId: auth.tenantId,
            orderId: result.orderId,
            invoiceId,
        });

        return response.success(result);
    }
);

/**
 * GET /payment/status?orderId=xxx OR ?invoiceId=xxx
 * Check the current status of a payment order.
 */
export const getPaymentStatus = authorizedHandler(
    [],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const orderId = params.orderId || event.pathParameters?.orderId;
        const invoiceId = params.invoiceId;

        if (!orderId && !invoiceId) {
            return response.badRequest('Either orderId or invoiceId query parameter is required');
        }

        let order;
        if (orderId) {
            order = await paymentOrderService.getOrderStatus(auth.tenantId, orderId);
        } else {
            order = await paymentOrderService.getOrderByInvoice(auth.tenantId, invoiceId!);
        }

        if (!order) {
            return response.notFound('Payment order');
        }

        return response.success({
            orderId: order.id,
            invoiceId: order.invoiceId,
            gatewayType: order.gatewayType,
            status: order.status,
            amountCents: order.amountCents,
            qrPayload: order.qrPayload,
            paymentUrl: order.paymentUrl,
            gatewayTransactionId: order.gatewayTransactionId,
            expiresAt: order.expiresAt,
            createdAt: order.createdAt,
        });
    }
);

/**
 * POST /payment/reconcile
 * Reconcile pending payment orders by polling the gateway.
 * Used when webhook delivery fails or desktop was offline.
 */
export const reconcilePayments = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (_event, _context, auth) => {
        const result = await paymentOrderService.reconcilePendingOrders(auth.tenantId);

        return response.success({
            reconciled: result.reconciled,
            updatedOrderIds: result.updated,
        });
    }
);
