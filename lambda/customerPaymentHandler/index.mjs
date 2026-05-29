/**
 * customerPaymentHandler/index.mjs
 * Customer-facing payment routes:
 *   POST /customer/v1/payments        - record a payment
 *   GET  /customer/v1/payments        - payment history, optional ?vendorId=
 */

import { randomUUID } from 'crypto';
import {
  success,
  error,
  extractUserContext,
  getItem,
  putItem,
  queryItems,
  logAuditEvent,
} from '../shared/utils.mjs';

const PAYMENTS_TABLE = process.env.PAYMENTS_TABLE || process.env.INVOICES_TABLE;
const USERS_TABLE = process.env.USERS_TABLE;
const LEDGER_TABLE = process.env.LEDGER_TABLE || process.env.INVOICES_TABLE;

const VALID_METHODS = ['cash', 'upi', 'bankTransfer', 'cheque', 'card', 'other'];

export const handler = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.requestContext.http.path;
  const ctx = await extractUserContext(event);

  if (!ctx || ctx.role !== 'customer') {
    return error(403, 'Forbidden', 'FORBIDDEN');
  }

  try {
    if (method === 'POST' && path.endsWith('/payments')) {
      return recordPayment(ctx, JSON.parse(event.body || '{}'));
    }
    if (method === 'GET' && path.endsWith('/payments')) {
      const vendorId = event.queryStringParameters?.vendorId || null;
      return getPayments(ctx, vendorId);
    }
    return error(404, 'Route not found', 'NOT_FOUND');
  } catch (e) {
    console.error('customerPaymentHandler error:', e);
    return error(500, 'Internal server error', 'INTERNAL_ERROR');
  }
};

async function recordPayment(ctx, body) {
  const { vendorId, amount, paymentMethod, notes, referenceNumber, paymentDate } = body;

  if (!vendorId || typeof vendorId !== 'string') {
    return error(400, 'vendorId is required', 'INVALID_REQUEST');
  }
  if (!amount || typeof amount !== 'number' || amount <= 0) {
    return error(400, 'amount must be a positive number', 'INVALID_REQUEST');
  }
  if (!VALID_METHODS.includes(paymentMethod)) {
    return error(400, `paymentMethod must be one of: ${VALID_METHODS.join(', ')}`, 'INVALID_REQUEST');
  }

  // Verify the customer has a connection to this vendor
  const connection = await getItem(USERS_TABLE, {
    PK: `USER#${ctx.userId}`,
    SK: `CONNECTION#${vendorId}`,
  });

  if (!connection || connection.status !== 'active') {
    return error(403, 'No active connection to this vendor', 'FORBIDDEN');
  }

  const paymentId = randomUUID();
  const now = new Date().toISOString();
  const effectiveDate = paymentDate || now;

  // 1. Persist payment record
  await putItem(PAYMENTS_TABLE, {
    PK: `PAYMENT#${paymentId}`,
    SK: 'METADATA',
    paymentId,
    tenantId: vendorId,
    customerId: ctx.userId,
    vendorId,
    vendorName: connection.vendorName || vendorId,
    amount,
    paymentMethod,
    referenceNumber: referenceNumber || null,
    notes: notes || null,
    paymentDate: effectiveDate,
    createdAt: now,
    // GSI keys
    GSI_Customer_PK: ctx.userId,
    GSI_Customer_SK: now,
    GSI_Vendor_PK: vendorId,
    GSI_Vendor_SK: now,
  });

  // 2. Write ledger credit entry
  const entryId = randomUUID();
  await putItem(LEDGER_TABLE, {
    PK: `LEDGER#${ctx.userId}`,
    SK: `VENDOR#${vendorId}#${now}#${entryId}`,
    entryId,
    tenantId: vendorId,
    customerId: ctx.userId,
    vendorId,
    vendorName: connection.vendorName || vendorId,
    entryType: 'credit',
    amount,
    referenceType: 'payment',
    referenceId: paymentId,
    description: `Payment via ${paymentMethod}`,
    notes: notes || null,
    entryDate: effectiveDate,
    createdAt: now,
    // GSI keys
    GSI_CustomerLedger_PK: ctx.userId,
    GSI_CustomerLedger_SK: now,
  });

  // 3. Audit log
  await logAuditEvent({
    action: 'CUSTOMER_PAYMENT_RECORDED',
    userId: ctx.userId,
    resourceId: paymentId,
    details: { vendorId, amount, paymentMethod },
  });

  return success({ paymentId, message: 'Payment recorded successfully' }, 201);
}

async function getPayments(ctx, vendorId) {
  let keyCondition = 'GSI_Customer_PK = :cid';
  const exprValues = { ':cid': ctx.userId };

  if (vendorId) {
    // Filter in application layer (no compound GSI available)
    const items = await queryItems(
      PAYMENTS_TABLE,
      keyCondition,
      exprValues,
      { IndexName: 'GSI_Customer', ScanIndexForward: false },
    );
    const filtered = items.filter((i) => i.vendorId === vendorId);
    return success({ payments: filtered.map(mapPayment) });
  }

  const items = await queryItems(
    PAYMENTS_TABLE,
    keyCondition,
    exprValues,
    { IndexName: 'GSI_Customer', ScanIndexForward: false },
  );

  return success({ payments: items.map(mapPayment) });
}

function mapPayment(item) {
  return {
    id: item.paymentId,
    customerId: item.customerId,
    vendorId: item.vendorId,
    vendorName: item.vendorName,
    amount: item.amount,
    paymentMethod: item.paymentMethod,
    referenceNumber: item.referenceNumber || null,
    notes: item.notes || null,
    paymentDate: item.paymentDate,
    createdAt: item.createdAt,
  };
}
