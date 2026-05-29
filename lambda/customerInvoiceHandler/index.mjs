/**
 * customerInvoiceHandler/index.mjs
 * Customer-facing invoice routes:
 *   GET  /customer/v1/invoices          - list with optional ?status= filter
 *   GET  /customer/v1/invoices/:id      - single invoice detail
 */

import {
  success,
  error,
  extractUserContext,
  getItem,
  queryItems,
} from '../shared/utils.mjs';

const INVOICES_TABLE = process.env.INVOICES_TABLE;
const USERS_TABLE = process.env.USERS_TABLE;

export const handler = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.requestContext.http.path;
  const ctx = await extractUserContext(event);

  if (!ctx || ctx.role !== 'customer') {
    return error(403, 'Forbidden', 'FORBIDDEN');
  }

  try {
    // GET /customer/v1/invoices/:id
    const singleMatch = path.match(/\/customer\/v1\/invoices\/([^/]+)$/);
    if (method === 'GET' && singleMatch) {
      return getInvoiceDetail(ctx, singleMatch[1]);
    }

    // GET /customer/v1/invoices
    if (method === 'GET' && path.endsWith('/invoices')) {
      const statusFilter = event.queryStringParameters?.status || null;
      return listInvoices(ctx, statusFilter);
    }

    return error(404, 'Route not found', 'NOT_FOUND');
  } catch (e) {
    console.error('customerInvoiceHandler error:', e);
    return error(500, 'Internal server error', 'INTERNAL_ERROR');
  }
};

async function listInvoices(ctx, statusFilter) {
  // Query GSI: GSI_Customer (customerId + createdAt)
  const keyCondition = 'customerId = :cid';
  const exprValues = { ':cid': ctx.userId };
  let filterExpression;

  if (statusFilter) {
    filterExpression = '#status = :status';
    exprValues[':status'] = statusFilter;
  }

  const items = await queryItems(
    INVOICES_TABLE,
    keyCondition,
    exprValues,
    {
      IndexName: 'GSI_Customer',
      ScanIndexForward: false,
      FilterExpression: filterExpression,
      ExpressionAttributeNames: filterExpression
        ? { '#status': 'status' }
        : undefined,
    },
  );

  const invoices = items.map(mapInvoice);
  return success({ invoices });
}

async function getInvoiceDetail(ctx, invoiceId) {
  const item = await getItem(INVOICES_TABLE, {
    PK: `INVOICE#${invoiceId}`,
    SK: 'METADATA',
  });

  if (!item) return error(404, 'Invoice not found', 'NOT_FOUND');

  // Enforce tenant isolation: customer can only see their own invoices
  if (item.customerId !== ctx.userId) {
    return error(403, 'Forbidden', 'FORBIDDEN');
  }

  return success(mapInvoice(item));
}

function mapInvoice(item) {
  return {
    id: item.invoiceId,
    invoiceNumber: item.invoiceNumber,
    tenantId: item.tenantId,
    customerId: item.customerId,
    vendorId: item.tenantId,
    vendorName: item.vendorName || '',
    vendorPhone: item.vendorPhone || null,
    vendorBusinessName: item.vendorBusinessName || null,
    invoiceDate: item.invoiceDate,
    dueDate: item.dueDate || null,
    status: item.status || 'unpaid',
    subtotal: item.subtotal || 0,
    discountAmount: item.discountAmount || 0,
    taxAmount: item.taxAmount || 0,
    totalAmount: item.totalAmount || 0,
    paidAmount: item.paidAmount || 0,
    balanceDue: item.balanceDue || 0,
    notes: item.notes || null,
    pdfUrl: item.pdfUrl || null,
    items: item.lineItems || [],
    createdAt: item.createdAt,
    updatedAt: item.updatedAt || item.createdAt,
  };
}
