/**
 * customerHandler/index.mjs
 * Handles all customer-facing API routes:
 *   GET  /customer/v1/profile
 *   PATCH /customer/v1/profile
 *   GET  /customer/v1/summary
 *   GET  /customer/v1/connections
 */

import {
  success,
  error,
  extractUserContext,
  getItem,
  putItem,
  updateItem,
  queryItems,
} from '../shared/utils.mjs';

const USERS_TABLE = process.env.USERS_TABLE;
const TENANTS_TABLE = process.env.TENANTS_TABLE;

export const handler = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.requestContext.http.path;
  const ctx = await extractUserContext(event);

  if (!ctx || ctx.role !== 'customer') {
    return error(403, 'Forbidden: customer role required', 'FORBIDDEN');
  }

  try {
    if (method === 'GET' && path.endsWith('/profile')) {
      return getProfile(ctx);
    }
    if (method === 'PATCH' && path.endsWith('/profile')) {
      return updateProfile(ctx, JSON.parse(event.body || '{}'));
    }
    if (method === 'GET' && path.endsWith('/summary')) {
      return getSummary(ctx);
    }
    if (method === 'GET' && path.endsWith('/connections')) {
      return getConnections(ctx);
    }
    return error(404, 'Route not found', 'NOT_FOUND');
  } catch (e) {
    console.error('customerHandler error:', e);
    return error(500, 'Internal server error', 'INTERNAL_ERROR');
  }
};

async function getProfile(ctx) {
  const item = await getItem(USERS_TABLE, {
    PK: `USER#${ctx.userId}`,
    SK: 'PROFILE',
  });

  if (!item) return error(404, 'Profile not found', 'NOT_FOUND');

  return success({
    id: item.userId,
    customerId: item.userId,
    phone: item.phone,
    email: item.email,
    displayName: item.displayName || item.name || '',
    photoUrl: item.photoUrl || null,
    address: item.address || null,
    city: item.city || null,
    state: item.state || null,
    pincode: item.pincode || null,
    totalDue: item.totalDue || 0,
    totalPaid: item.totalPaid || 0,
    linkedShopsCount: item.linkedShopsCount || 0,
    lastActiveAt: item.lastActiveAt || null,
    createdAt: item.createdAt,
  });
}

async function updateProfile(ctx, body) {
  const allowed = ['displayName', 'email', 'address', 'city', 'state', 'pincode'];
  const updates = {};
  for (const key of allowed) {
    if (body[key] !== undefined) updates[key] = body[key];
  }

  if (Object.keys(updates).length === 0) {
    return error(400, 'No valid fields to update', 'INVALID_REQUEST');
  }

  updates.updatedAt = new Date().toISOString();

  const expressionParts = [];
  const attrNames = {};
  const attrValues = {};

  for (const [k, v] of Object.entries(updates)) {
    expressionParts.push(`#${k} = :${k}`);
    attrNames[`#${k}`] = k;
    attrValues[`:${k}`] = v;
  }

  await updateItem(
    USERS_TABLE,
    { PK: `USER#${ctx.userId}`, SK: 'PROFILE' },
    `SET ${expressionParts.join(', ')}`,
    attrNames,
    attrValues,
  );

  // Return updated profile
  return getProfile(ctx);
}

async function getSummary(ctx) {
  // Aggregate across all vendor connections for this customer
  const connections = await queryItems(
    USERS_TABLE,
    'PK = :pk AND begins_with(SK, :prefix)',
    { ':pk': `USER#${ctx.userId}`, ':prefix': 'CONNECTION#' },
  );

  let totalDue = 0;
  let totalPaid = 0;
  let pendingInvoiceCount = 0;

  for (const conn of connections) {
    totalDue += conn.totalDue || 0;
    totalPaid += conn.totalPaid || 0;
    pendingInvoiceCount += conn.pendingInvoiceCount || 0;
  }

  return success({
    totalDue,
    totalPaid,
    linkedShopsCount: connections.length,
    pendingInvoiceCount,
  });
}

async function getConnections(ctx) {
  const connections = await queryItems(
    USERS_TABLE,
    'PK = :pk AND begins_with(SK, :prefix)',
    { ':pk': `USER#${ctx.userId}`, ':prefix': 'CONNECTION#' },
  );

  const vendorIds = [...new Set(connections.map((c) => c.vendorId))];
  const vendorMap = {};

  // Batch fetch vendor tenant names (up to 25 at once)
  for (let i = 0; i < vendorIds.length; i += 25) {
    const batch = vendorIds.slice(i, i + 25);
    await Promise.all(
      batch.map(async (vendorId) => {
        const tenant = await getItem(TENANTS_TABLE, {
          PK: `TENANT#${vendorId}`,
          SK: 'METADATA',
        });
        if (tenant) vendorMap[vendorId] = tenant;
      }),
    );
  }

  const result = connections
    .filter((c) => c.status !== 'rejected')
    .map((c) => {
      const vendor = vendorMap[c.vendorId] || {};
      return {
        id: c.connectionId,
        customerId: ctx.userId,
        vendorId: c.vendorId,
        vendorName: vendor.ownerName || c.vendorId,
        vendorBusinessName: vendor.businessName || null,
        vendorPhone: vendor.phone || null,
        businessType: vendor.businessType || null,
        logoUrl: vendor.logoUrl || null,
        status: c.status || 'active',
        outstandingBalance: (c.totalDue || 0) - (c.totalPaid || 0),
        connectedAt: c.connectedAt,
        lastTransactionAt: c.lastTransactionAt || null,
      };
    });

  return success({ connections: result });
}
