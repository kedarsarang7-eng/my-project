/**
 * customerLedgerHandler/index.mjs
 * Customer-facing ledger routes:
 *   GET  /customer/v1/ledger          - list entries, optional ?vendorId=
 *   GET  /customer/v1/ledger/balance  - balance summary, optional ?vendorId=
 */

import {
  success,
  error,
  extractUserContext,
  queryItems,
} from '../shared/utils.mjs';

const LEDGER_TABLE = process.env.LEDGER_TABLE || process.env.INVOICES_TABLE;

export const handler = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.requestContext.http.path;
  const ctx = await extractUserContext(event);

  if (!ctx || ctx.role !== 'customer') {
    return error(403, 'Forbidden', 'FORBIDDEN');
  }

  try {
    if (method === 'GET' && path.endsWith('/ledger/balance')) {
      const vendorId = event.queryStringParameters?.vendorId || null;
      return getLedgerBalance(ctx, vendorId);
    }

    if (method === 'GET' && path.endsWith('/ledger')) {
      const vendorId = event.queryStringParameters?.vendorId || null;
      return getLedgerEntries(ctx, vendorId);
    }

    return error(404, 'Route not found', 'NOT_FOUND');
  } catch (e) {
    console.error('customerLedgerHandler error:', e);
    return error(500, 'Internal server error', 'INTERNAL_ERROR');
  }
};

async function getLedgerEntries(ctx, vendorId) {
  let keyCondition = 'customerId = :cid';
  const exprValues = { ':cid': ctx.userId };

  if (vendorId) {
    keyCondition += ' AND begins_with(SK, :vendorPrefix)';
    exprValues[':vendorPrefix'] = `VENDOR#${vendorId}#`;
  }

  const items = await queryItems(
    LEDGER_TABLE,
    keyCondition,
    exprValues,
    {
      IndexName: 'GSI_CustomerLedger',
      ScanIndexForward: false,
    },
  );

  const entries = items.map((item) => ({
    id: item.entryId,
    customerId: item.customerId,
    vendorId: item.vendorId,
    vendorName: item.vendorName || '',
    entryType: item.entryType || 'debit',
    amount: item.amount || 0,
    runningBalance: item.runningBalance || 0,
    referenceType: item.referenceType || null,
    referenceId: item.referenceId || null,
    referenceNumber: item.referenceNumber || null,
    description: item.description || null,
    notes: item.notes || null,
    entryDate: item.entryDate,
    createdAt: item.createdAt,
  }));

  return success({ entries });
}

async function getLedgerBalance(ctx, vendorId) {
  let keyCondition = 'customerId = :cid';
  const exprValues = { ':cid': ctx.userId };

  if (vendorId) {
    keyCondition += ' AND begins_with(SK, :vendorPrefix)';
    exprValues[':vendorPrefix'] = `VENDOR#${vendorId}#`;
  }

  const items = await queryItems(
    LEDGER_TABLE,
    keyCondition,
    exprValues,
    { IndexName: 'GSI_CustomerLedger' },
  );

  let totalDebit = 0;
  let totalCredit = 0;

  for (const item of items) {
    if (item.entryType === 'credit' || item.entryType === 'opening') {
      totalCredit += item.amount || 0;
    } else {
      totalDebit += item.amount || 0;
    }
  }

  return success({
    totalDebit: Math.round(totalDebit * 100) / 100,
    totalCredit: Math.round(totalCredit * 100) / 100,
    netBalance: Math.round((totalDebit - totalCredit) * 100) / 100,
  });
}
