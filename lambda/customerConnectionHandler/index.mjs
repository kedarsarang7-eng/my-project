/**
 * customerConnectionHandler/index.mjs
 * Manages customer ↔ vendor link requests:
 *   POST   /customer/v1/connections/request   - customer requests to link to a vendor
 *   DELETE /customer/v1/connections/:vendorId  - customer unlinks from a vendor
 */

import { randomUUID } from 'crypto';
import {
  success,
  error,
  extractUserContext,
  getItem,
  putItem,
  updateItem,
  queryItems,
  logAuditEvent,
} from '../shared/utils.mjs';

const USERS_TABLE = process.env.USERS_TABLE;
const TENANTS_TABLE = process.env.TENANTS_TABLE;

export const handler = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.requestContext.http.path;
  const ctx = await extractUserContext(event);

  if (!ctx || ctx.role !== 'customer') {
    return error(403, 'Forbidden', 'FORBIDDEN');
  }

  try {
    if (method === 'POST' && path.endsWith('/connections/request')) {
      return requestConnection(ctx, JSON.parse(event.body || '{}'));
    }

    const deleteMatch = path.match(/\/connections\/([^/]+)$/);
    if (method === 'DELETE' && deleteMatch) {
      return unlinkConnection(ctx, deleteMatch[1]);
    }

    return error(404, 'Route not found', 'NOT_FOUND');
  } catch (e) {
    console.error('customerConnectionHandler error:', e);
    return error(500, 'Internal server error', 'INTERNAL_ERROR');
  }
};

async function requestConnection(ctx, body) {
  const { vendorId, vendorPhone } = body;

  if (!vendorId && !vendorPhone) {
    return error(400, 'Provide vendorId or vendorPhone', 'INVALID_REQUEST');
  }

  let resolvedVendorId = vendorId;

  // Resolve vendor by phone if vendorId not given
  if (!resolvedVendorId && vendorPhone) {
    const tenants = await queryItems(
      TENANTS_TABLE,
      'GSI_Phone_PK = :phone',
      { ':phone': vendorPhone },
      { IndexName: 'GSI_Phone' },
    );
    if (!tenants.length) {
      return error(404, 'Vendor not found', 'NOT_FOUND');
    }
    resolvedVendorId = tenants[0].tenantId;
  }

  // Check vendor exists
  const vendor = await getItem(TENANTS_TABLE, {
    PK: `TENANT#${resolvedVendorId}`,
    SK: 'METADATA',
  });
  if (!vendor) return error(404, 'Vendor not found', 'NOT_FOUND');

  // Check existing connection
  const existing = await getItem(USERS_TABLE, {
    PK: `USER#${ctx.userId}`,
    SK: `CONNECTION#${resolvedVendorId}`,
  });

  if (existing && existing.status === 'active') {
    return error(409, 'Already connected to this vendor', 'CONFLICT');
  }

  const connectionId = existing?.connectionId || randomUUID();
  const now = new Date().toISOString();

  await putItem(USERS_TABLE, {
    PK: `USER#${ctx.userId}`,
    SK: `CONNECTION#${resolvedVendorId}`,
    connectionId,
    customerId: ctx.userId,
    vendorId: resolvedVendorId,
    vendorName: vendor.ownerName || resolvedVendorId,
    status: 'pending',
    totalDue: 0,
    totalPaid: 0,
    pendingInvoiceCount: 0,
    connectedAt: now,
    updatedAt: now,
  });

  await logAuditEvent({
    action: 'CUSTOMER_CONNECTION_REQUESTED',
    userId: ctx.userId,
    resourceId: connectionId,
    details: { vendorId: resolvedVendorId },
  });

  return success({ connectionId, status: 'pending' }, 201);
}

async function unlinkConnection(ctx, vendorId) {
  const connection = await getItem(USERS_TABLE, {
    PK: `USER#${ctx.userId}`,
    SK: `CONNECTION#${vendorId}`,
  });

  if (!connection) {
    return error(404, 'Connection not found', 'NOT_FOUND');
  }

  const now = new Date().toISOString();
  await updateItem(
    USERS_TABLE,
    { PK: `USER#${ctx.userId}`, SK: `CONNECTION#${vendorId}` },
    'SET #status = :status, updatedAt = :now',
    { '#status': 'status' },
    { ':status': 'rejected', ':now': now },
  );

  await logAuditEvent({
    action: 'CUSTOMER_CONNECTION_REMOVED',
    userId: ctx.userId,
    resourceId: connection.connectionId,
    details: { vendorId },
  });

  return success({ message: 'Connection removed' });
}
