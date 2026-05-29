import { randomUUID } from 'crypto';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { getItem, putItem, queryAllItems, queryItems, updateItem } from '../config/dynamodb.config';
import * as response from '../utils/response';

function parseJsonBody(event: { body?: string | null }): Record<string, any> {
  if (!event.body) return {};
  try {
    return JSON.parse(event.body) as Record<string, any>;
  } catch {
    return {};
  }
}

function mapUserProfile(item: Record<string, any> | null, auth: { sub: string; email?: string; role: string; tenantId: string }) {
  return {
    id: auth.sub,
    uid: auth.sub,
    email: item?.email || auth.email || '',
    name: item?.name || '',
    phone: item?.phone || '',
    role: item?.role || auth.role,
    tenantId: auth.tenantId,
    profileImageUrl: item?.profileImageUrl || null,
    preferredBusinessId: item?.preferredBusinessId || null,
    updatedAt: item?.updatedAt || null,
    createdAt: item?.createdAt || null,
  };
}

export const getProfile = authorizedHandler([], async (_event, _context, auth) => {
  const profile = await getItem<Record<string, any>>(`TENANT#${auth.tenantId}`, `USER#${auth.sub}`);
  return response.success(mapUserProfile(profile, auth));
});

export const putProfile = authorizedHandler([], async (event, _context, auth) => {
  const body = parseJsonBody(event);
  const existing = await getItem<Record<string, any>>(`TENANT#${auth.tenantId}`, `USER#${auth.sub}`);
  const now = new Date().toISOString();
  const item = {
    PK: `TENANT#${auth.tenantId}`,
    SK: `USER#${auth.sub}`,
    entityType: 'USER_PROFILE',
    id: auth.sub,
    tenantId: auth.tenantId,
    email: body.email ?? existing?.email ?? auth.email ?? '',
    name: body.name ?? existing?.name ?? '',
    phone: body.phone ?? existing?.phone ?? '',
    role: existing?.role ?? auth.role,
    profileImageUrl: body.profileImageUrl ?? existing?.profileImageUrl ?? null,
    preferredBusinessId: body.preferredBusinessId ?? existing?.preferredBusinessId ?? null,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };
  await putItem(item);
  return response.success(mapUserProfile(item, auth));
});

export const getUsersMe = authorizedHandler([], async (_event, _context, auth) => {
  const profile = await getItem<Record<string, any>>(`TENANT#${auth.tenantId}`, `USER#${auth.sub}`);
  return response.success(mapUserProfile(profile, auth));
});

export const putUsersMe = authorizedHandler([], async (event, _context, auth) => {
  const body = parseJsonBody(event);
  const existing = await getItem<Record<string, any>>(`TENANT#${auth.tenantId}`, `USER#${auth.sub}`);
  const now = new Date().toISOString();
  const item = {
    PK: `TENANT#${auth.tenantId}`,
    SK: `USER#${auth.sub}`,
    entityType: 'USER_PROFILE',
    id: auth.sub,
    tenantId: auth.tenantId,
    email: body.email ?? existing?.email ?? auth.email ?? '',
    name: body.name ?? existing?.name ?? '',
    phone: body.phone ?? existing?.phone ?? '',
    role: existing?.role ?? auth.role,
    profileImageUrl: body.profileImageUrl ?? existing?.profileImageUrl ?? null,
    preferredBusinessId: body.preferredBusinessId ?? existing?.preferredBusinessId ?? null,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };
  await putItem(item);
  return response.success(mapUserProfile(item, auth));
});

export const putUsersMeShop = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER],
  async (event, _context, auth) => {
  const body = parseJsonBody(event);
  const businessId = body.businessId ?? body.shopId ?? body.activeBusinessId;
  if (!businessId) return response.badRequest('Missing businessId');

  await updateItem(`TENANT#${auth.tenantId}`, `USER#${auth.sub}`, {
    updateExpression: 'SET preferredBusinessId = :bid, updatedAt = :now',
    expressionAttributeValues: {
      ':bid': businessId,
      ':now': new Date().toISOString(),
    },
  });

  return response.success({ preferredBusinessId: businessId });
});

export const syncUser = authorizedHandler([], async (event, _context, auth) => {
  const body = parseJsonBody(event);
  // SECURITY: syncUser is self-service only. Never trust body.uid/id for IDOR.
  const userId = auth.sub;
  const now = new Date().toISOString();
  const item = {
    PK: `TENANT#${auth.tenantId}`,
    SK: `USER#${userId}`,
    entityType: 'USER_PROFILE',
    id: userId,
    tenantId: auth.tenantId,
    email: body.email ?? '',
    name: body.name ?? '',
    phone: body.phone ?? '',
    role: auth.role,
    preferredBusinessId: body.tenantId ?? body.businessId ?? null,
    createdAt: now,
    updatedAt: now,
  };
  await putItem(item);
  return response.success(item, 201);
});

export const createStockTransaction = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _context, auth) => {
  const body = parseJsonBody(event);
  const id = body.id ?? randomUUID();
  const now = new Date().toISOString();
  const item = {
    PK: `TENANT#${auth.tenantId}`,
    SK: `STOCKTXN#${id}`,
    entityType: 'STOCK_TRANSACTION',
    id,
    tenantId: auth.tenantId,
    productId: body.productId ?? null,
    type: body.type ?? 'adjustment',
    quantity: Number(body.quantity ?? 0),
    notes: body.notes ?? null,
    createdAt: now,
    updatedAt: now,
  };
  await putItem(item);
  return response.success(item, 201);
});

export const listStockTransactions = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (_event, _context, auth) => {
  const items = await queryAllItems<Record<string, any>>(`TENANT#${auth.tenantId}`, 'STOCKTXN#', { maxPages: 5 });
  return response.success({ items });
});

export const getVendorSnapshot = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _context, auth) => {
  const vendorId = event.pathParameters?.vendorId;
  if (!vendorId) return response.badRequest('Missing vendorId');
  const item = await getItem<Record<string, any>>(`TENANT#${auth.tenantId}`, `VENDORSNAPSHOT#${vendorId}`);
  if (!item) return response.notFound('Vendor snapshot');
  return response.success(item);
});

export const putVendorSnapshot = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _context, auth) => {
  const vendorId = event.pathParameters?.vendorId;
  if (!vendorId) return response.badRequest('Missing vendorId');
  const body = parseJsonBody(event);
  const now = new Date().toISOString();
  const existing = await getItem<Record<string, any>>(`TENANT#${auth.tenantId}`, `VENDORSNAPSHOT#${vendorId}`);
  const item = {
    PK: `TENANT#${auth.tenantId}`,
    SK: `VENDORSNAPSHOT#${vendorId}`,
    entityType: 'VENDOR_SNAPSHOT',
    vendorId,
    tenantId: auth.tenantId,
    snapshot: body.snapshot ?? body,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };
  await putItem(item);
  return response.success(item);
});

export const createTrustedDevice = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER],
  async (event, _context, auth) => {
  const body = parseJsonBody(event);
  const id = body.id ?? randomUUID();
  const now = new Date().toISOString();

  // SECURITY: device trusted-state is user-owned. Block overwriting other users' trusted devices.
  const existing = await getItem<Record<string, any>>(
    `TENANT#${auth.tenantId}`,
    `TRUSTEDDEVICE#${id}`
  );
  if (existing && existing.userId && existing.userId !== auth.sub) {
    return response.forbidden('Trusted device belongs to another user');
  }

  const item = {
    PK: `TENANT#${auth.tenantId}`,
    SK: `TRUSTEDDEVICE#${id}`,
    entityType: 'TRUSTED_DEVICE',
    id,
    tenantId: auth.tenantId,
    userId: auth.sub,
    deviceName: body.deviceName ?? body.name ?? 'Unknown Device',
    deviceId: body.deviceId ?? id,
    isTrusted: body.isTrusted ?? true,
    createdAt: now,
    updatedAt: now,
  };
  await putItem(item);
  return response.success(item, 201);
});

export const listTrustedDevices = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER],
  async (_event, _context, auth) => {
  const result = await queryItems<Record<string, any>>(`TENANT#${auth.tenantId}`, 'TRUSTEDDEVICE#', {
    filterExpression: 'userId = :uid',
    expressionAttributeValues: { ':uid': auth.sub },
    limit: 200,
  });
  return response.success({ items: result.items });
});

export const updateTrustedDevice = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER],
  async (event, _context, auth) => {
  const id = event.pathParameters?.deviceId;
  if (!id) return response.badRequest('Missing deviceId');

  // SECURITY: block IDOR. User can only update their own trusted devices.
  const existing = await getItem<Record<string, any>>(
    `TENANT#${auth.tenantId}`,
    `TRUSTEDDEVICE#${id}`
  );
  if (!existing) return response.notFound('Trusted device');
  if (existing.userId && existing.userId !== auth.sub) {
    return response.forbidden('Insufficient permissions for this trusted device');
  }

  const body = parseJsonBody(event);
  const updated = await updateItem(`TENANT#${auth.tenantId}`, `TRUSTEDDEVICE#${id}`, {
    updateExpression: 'SET isTrusted = :trusted, deviceName = :name, updatedAt = :now',
    expressionAttributeValues: {
      ':trusted': body.isTrusted ?? true,
      ':name': body.deviceName ?? body.name ?? 'Unknown Device',
      ':now': new Date().toISOString(),
    },
  });
  return response.success(updated ?? {});
});

export const getBillingSummary = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CHARTERED_ACCOUNTANT],
  async (_event, _context, auth) => {
  const invoices = await queryAllItems<Record<string, any>>(`TENANT#${auth.tenantId}`, 'INVOICE#', { maxPages: 8 });
  const payments = await queryAllItems<Record<string, any>>(`TENANT#${auth.tenantId}`, 'PAYMENT#', { maxPages: 8 });

  const totalRevenueCents = invoices.reduce((s, i) => s + (Number(i.totalCents) || 0), 0);
  const totalPaidCents = invoices.reduce((s, i) => s + (Number(i.paidCents) || 0), 0);
  const totalOutstandingCents = invoices.reduce((s, i) => s + (Number(i.balanceCents) || 0), 0);

  return response.success({
    invoiceCount: invoices.length,
    paymentCount: payments.length,
    totalRevenueCents,
    totalPaidCents,
    totalOutstandingCents,
  });
  },
);

export const getGstr2aCompat = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
  async () => {
    return response.success({
      summary: {
        totalInvoices: 0,
        totalTaxableValueCents: 0,
        totalInputTaxCreditCents: 0,
      },
      invoices: [],
      note: 'GSTR-2A integration pending. Returning compatible empty payload.',
    });
  },
);

export const sendWhatsappInvoiceCompat = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _context, auth) => {
  const body = parseJsonBody(event);
  const id = randomUUID();
  const now = new Date().toISOString();
  await putItem({
    PK: `TENANT#${auth.tenantId}`,
    SK: `WHATSAPPMSG#${id}`,
    entityType: 'WHATSAPP_MESSAGE',
    id,
    tenantId: auth.tenantId,
    invoiceId: body.invoiceId ?? null,
    phone: body.phone ?? null,
    invoiceUrl: body.invoiceUrl ?? null,
    status: 'queued',
    createdAt: now,
    updatedAt: now,
  });

  return response.success({
    queued: true,
    messageId: id,
  });
});

