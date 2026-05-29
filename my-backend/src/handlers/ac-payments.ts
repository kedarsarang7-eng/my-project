// ============================================================================
// ACADEMIC COACHING — ONLINE PAYMENT GATEWAY INTEGRATION
// ============================================================================
// Razorpay integration for online fee payment
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  putItem,
  getItem,
  updateItem,
  queryAllItems,
} from '../config/dynamodb.config';
import crypto from 'crypto';

const AC_PAYMENT_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_FEE_MANAGEMENT,
};

function uid(): string {
  return crypto.randomUUID().replace(/-/g, '').substring(0, 16).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// Razorpay configuration (from environment)
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || '';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || '';
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || '';

// ============================================================================
// PAYMENT ORDER CREATION
// ============================================================================

/**
 * POST /ac/payments/create-order
 * Create Razorpay order for fee payment
 */
export const createPaymentOrder = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { studentId, invoiceIds, amountPaisa, description } = body;

    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      return response.error(503, 'PAYMENT_NOT_CONFIGURED', 'Payment gateway not configured');
    }

    const pk = Keys.tenantPK(auth.tenantId);

    // Verify student exists
    const student = await getItem(pk, Keys.acStudentSK(studentId));
    if (!student) return response.notFound('Student not found');

    // Calculate total amount if invoice IDs provided
    let totalAmount = amountPaisa || 0;
    if (invoiceIds && invoiceIds.length > 0) {
      const invoices = await Promise.all(
        invoiceIds.map((id: string) => getItem(pk, `AC_INVOICE#${id}`))
      );
      totalAmount = invoices.reduce((sum, inv: any) => sum + (inv?.balancePaisa || 0), 0);
    }

    if (totalAmount <= 0) {
      return response.error(400, 'INVALID_AMOUNT', 'Amount must be greater than 0');
    }

    // Create Razorpay order via their API
    const orderId = uid();
    const receipt = `AC-${orderId}`;

    // Create order in our database (pending)
    const paymentOrder = {
      PK: pk,
      SK: `AC_PAYMENT_ORDER#${orderId}`,
      id: orderId,
      studentId,
      invoiceIds: invoiceIds || [],
      amountPaisa: totalAmount,
      amount: totalAmount / 100,
      currency: 'INR',
      description: description || `Fee payment for ${(student as any).firstName} ${(student as any).lastName}`,
      status: 'created',
      gateway: 'razorpay',
      gatewayOrderId: null, // Will be updated after Razorpay call
      receipt,
      notes: {
        tenantId: auth.tenantId,
        studentId,
        invoiceIds: JSON.stringify(invoiceIds || []),
      },
      createdAt: now(),
      expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(), // 30 min expiry
    };

    await putItem(paymentOrder);

    // In production: Call Razorpay API to create actual order
    // For now, simulate the order creation
    const razorpayOrderId = `order_${uid().toLowerCase()}`;
    
    await updateItem(pk, `AC_PAYMENT_ORDER#${orderId}`, {
      updateExpression: 'SET #gatewayOrderId = :gatewayOrderId',
      expressionAttributeNames: { '#gatewayOrderId': 'gatewayOrderId' },
      expressionAttributeValues: { ':gatewayOrderId': razorpayOrderId },
    });

    logger.info('Payment order created', { tenantId: auth.tenantId, orderId, amount: totalAmount });

    return response.success({
      orderId,
      razorpayOrderId,
      amount: totalAmount,
      currency: 'INR',
      key: RAZORPAY_KEY_ID,
      student: {
        name: `${(student as any).firstName} ${(student as any).lastName}`,
        email: (student as any).email,
        phone: (student as any).phone,
      },
    }, 201);
  },
  AC_PAYMENT_OPTS,
);

/**
 * POST /ac/payments/verify
 * Verify Razorpay payment signature
 */
export const verifyPayment = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { orderId, paymentId, signature } = body;

    if (!RAZORPAY_KEY_SECRET) {
      return response.error(503, 'PAYMENT_NOT_CONFIGURED', 'Payment gateway not configured');
    }

    const pk = Keys.tenantPK(auth.tenantId);

    // Get our order
    const order = await getItem<any>(pk, `AC_PAYMENT_ORDER#${orderId}`);
    if (!order) return response.notFound('Order not found');
    if (order.status !== 'created') {
      return response.error(400, 'INVALID_STATUS', 'Order already processed');
    }

    // Verify signature (in production: use Razorpay's verification)
    const expectedSignature = crypto
      .createHmac('sha256', RAZORPAY_KEY_SECRET)
      .update(`${order.gatewayOrderId}|${paymentId}`)
      .digest('hex');

    if (signature !== expectedSignature) {
      return response.error(400, 'INVALID_SIGNATURE', 'Payment signature verification failed');
    }

    const ts = now();

    // Update order as paid
    await updateItem(pk, `AC_PAYMENT_ORDER#${orderId}`, {
      updateExpression: 'SET #status = :status, #paymentId = :paymentId, #signature = :signature, #paidAt = :paidAt, #updatedAt = :updatedAt',
      expressionAttributeNames: {
        '#status': 'status',
        '#paymentId': 'paymentId',
        '#signature': 'signature',
        '#paidAt': 'paidAt',
        '#updatedAt': 'updatedAt',
      },
      expressionAttributeValues: {
        ':status': 'paid',
        ':paymentId': paymentId,
        ':signature': signature,
        ':paidAt': ts,
        ':updatedAt': ts,
      },
    });

    // Record the payment against invoices
    const paymentId2 = uid();
    const payment = {
      PK: pk,
      SK: `AC_PAYMENT#${paymentId2}`,
      id: paymentId2,
      studentId: order.studentId,
      invoiceIds: order.invoiceIds,
      amountPaisa: order.amountPaisa,
      method: 'online',
      gateway: 'razorpay',
      gatewayPaymentId: paymentId,
      gatewayOrderId: order.gatewayOrderId,
      status: 'completed',
      paidAt: ts,
      createdAt: ts,
    };

    await putItem(payment);

    // Update invoice balances
    for (const invoiceId of order.invoiceIds || []) {
      const invoice = await getItem<any>(pk, `AC_INVOICE#${invoiceId}`);
      if (invoice) {
        const newPaidAmount = (invoice.paidAmountPaisa || 0) + order.amountPaisa;
        const newBalance = (invoice.totalAmountPaisa || 0) - newPaidAmount;
        const invoiceStatus = newBalance <= 0 ? 'paid' : 'partial';

        await updateItem(pk, `AC_INVOICE#${invoiceId}`, {
          updateExpression: 'SET #paidAmountPaisa = :paid, #balancePaisa = :balance, #status = :status, #updatedAt = :updatedAt',
          expressionAttributeNames: {
            '#paidAmountPaisa': 'paidAmountPaisa',
            '#balancePaisa': 'balancePaisa',
            '#status': 'status',
            '#updatedAt': 'updatedAt',
          },
          expressionAttributeValues: {
            ':paid': newPaidAmount,
            ':balance': Math.max(0, newBalance),
            ':status': invoiceStatus,
            ':updatedAt': ts,
          },
        });
      }
    }

    logger.info('Payment verified and recorded', { tenantId: auth.tenantId, orderId, paymentId, amount: order.amountPaisa });

    return response.success({
      orderId,
      paymentId: paymentId2,
      status: 'paid',
      amount: order.amountPaisa,
      paidAt: ts,
    });
  },
  AC_PAYMENT_OPTS,
);

/**
 * POST /ac/payments/webhook
 * Razorpay webhook handler (public endpoint)
 */
export const handlePaymentWebhook = async (
  event: any,
  _context: any
): Promise<any> => {
  try {
    const body = typeof event.body === 'string' ? event.body : JSON.stringify(event.body);
    const signature = event.headers?.['x-razorpay-signature'];

    if (!RAZORPAY_WEBHOOK_SECRET) {
      logger.error('Webhook secret not configured');
      return { statusCode: 500, body: 'Not configured' };
    }

    // Verify webhook signature
    const expectedSignature = crypto
      .createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
      .update(body)
      .digest('hex');

    if (signature !== expectedSignature) {
      logger.error('Invalid webhook signature');
      return { statusCode: 400, body: 'Invalid signature' };
    }

    const payload = JSON.parse(body);
    const { event: eventType, payload: eventPayload } = payload;

    logger.info('Payment webhook received', { eventType });

    // Handle different event types
    if (eventType === 'payment.captured') {
      const { payment } = eventPayload;
      // Update payment status if needed
      logger.info('Payment captured', { paymentId: payment.id });
    }

    return { statusCode: 200, body: 'OK' };
  } catch (error) {
    logger.error('Webhook handling failed', { error });
    return { statusCode: 500, body: 'Internal error' };
  }
};

/**
 * GET /ac/payments/history/{studentId}
 * Get payment history for a student
 */
export const getPaymentHistory = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return response.badRequest('Student ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    const payments = await queryAllItems(pk, 'AC_PAYMENT#', {
      filterExpression: 'studentId = :studentId',
      expressionAttributeValues: { ':studentId': studentId },
    });

    // Sort by date desc
    payments.sort((a: any, b: any) => (b.paidAt || '').localeCompare(a.paidAt || ''));

    // Calculate totals
    const totalPaid = payments.reduce((sum: number, p: any) => sum + (p.amountPaisa || 0), 0);

    return response.success({
      payments,
      summary: {
        totalPayments: payments.length,
        totalPaidPaisa: totalPaid,
        totalPaid: totalPaid / 100,
      },
    });
  },
  AC_PAYMENT_OPTS,
);

/**
 * GET /ac/payments/retry/{orderId}
 * Get retry details for failed payment
 */
export const getRetryPayment = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const orderId = event.pathParameters?.orderId;
    if (!orderId) return response.badRequest('Order ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const order = await getItem<any>(pk, `AC_PAYMENT_ORDER#${orderId}`);

    if (!order) return response.notFound('Order not found');

    // Check if expired
    const isExpired = new Date() > new Date(order.expiresAt);
    if (isExpired || order.status === 'failed') {
      // Return status requiring new order creation
      return response.success({
        orderId,
        status: 'expired',
        message: 'Order expired. Please create a new order.',
        requiresNewOrder: true,
        originalAmount: order.amountPaisa,
        studentId: order.studentId,
        invoiceIds: order.invoiceIds,
      });
    }

    return response.success({
      orderId,
      razorpayOrderId: order.gatewayOrderId,
      amount: order.amountPaisa,
      currency: order.currency,
      key: RAZORPAY_KEY_ID,
      status: order.status,
    });
  },
  AC_PAYMENT_OPTS,
);
