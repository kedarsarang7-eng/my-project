import { randomUUID } from 'crypto';
import { success, error, verifyToken, getItem, putItem, updateItem, deleteItem, queryItems, scanItems, validateTenantAccess, requireAdminRole, logAuditEvent, getPaginationParams, createPaginationResponse } from '../shared/utils.mjs';

// Schema drift protection — normalize DynamoDB items with defaults
function mapTenantFromDynamoDB(item) {
  if (!item) return null;
  return {
    ...item,
    plan: item.plan || 'basic',
    status: item.status || 'active',
    maxUsers: item.maxUsers ?? 5,
    storageGb: item.storageGb ?? 1,
    settings: item.settings || {},
    createdAt: item.createdAt || null,
    updatedAt: item.updatedAt || null,
  };
}

// POST /tenants
export async function createTenant(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const { name, slug, plan = 'basic' } = JSON.parse(event.body || '{}');

    if (!name || !slug) {
      return error('Name and slug are required', 400);
    }

    // Check if slug is unique
    const existing = await queryItems(
      process.env.DYNAMODB_TABLE_TENANTS,
      'slug = :slug',
      { ':slug': slug },
      'attribute_not_exists(deletedAt)',
      { IndexName: 'GSI_Slug' }
    );

    if (existing.length > 0) {
      return error('Slug already exists', 409);
    }

    const tenantId = randomUUID();
    const now = new Date().toISOString();

    const tenant = {
      tenantId,
      name,
      slug,
      plan,
      status: 'active',
      ownerUserId: decoded.sub,
      createdAt: now,
      updatedAt: now,
      settings: {},
      maxUsers: { basic: 5, pro: 25, premium: 100, enterprise: 500 }[plan] || 5,
      storageGb: { basic: 1, pro: 10, premium: 50, enterprise: 500 }[plan] || 1,
    };

    await putItem(process.env.DYNAMODB_TABLE_TENANTS, tenant);

    await logAuditEvent(
      tenantId,
      decoded.sub,
      'CREATE_TENANT',
      'tenant',
      tenantId,
      { name, slug, plan },
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success(tenant, 201);
  } catch (err) {
    console.error('Create tenant error:', err);
    return error('Failed to create tenant', 500);
  }
}

// GET /tenants
export async function listTenants(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    const { limit, nextToken } = getPaginationParams(event);
    const queryParams = event.queryStringParameters || {};

    let tenants;
    let lastEvaluatedKey;

    if (queryParams.plan) {
      // Query by plan using GSI_Plan
      const result = await queryItems(
        process.env.DYNAMODB_TABLE_TENANTS,
        '#p = :plan',
        { ':plan': queryParams.plan },
        'attribute_not_exists(deletedAt)',
        { IndexName: 'GSI_Plan', ExpressionAttributeNames: { '#p': 'plan' } }
      );
      tenants = result.slice(0, limit);
    } else {
      // Query owner's tenants using GSI_Owner
      const result = await queryItems(
        process.env.DYNAMODB_TABLE_TENANTS,
        'ownerUserId = :owner',
        { ':owner': decoded.sub },
        'attribute_not_exists(deletedAt)',
        { IndexName: 'GSI_Owner' }
      );
      tenants = result.slice(0, limit);
    }

    return success(createPaginationResponse(tenants, limit, lastEvaluatedKey));
  } catch (err) {
    console.error('List tenants error:', err);
    return error('Failed to list tenants', 500);
  }
}

// GET /tenants/{tenantId}
export async function getTenant(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    const tenantId = event.pathParameters.tenantId;
    const userTenantId = validateTenantAccess(decoded.tenantId, tenantId);

    const raw = await getItem(process.env.DYNAMODB_TABLE_TENANTS, { tenantId: userTenantId });
    const tenant = mapTenantFromDynamoDB(raw);

    if (!tenant || tenant.status === 'deleted') {
      return error('Tenant not found', 404);
    }

    return success(tenant);
  } catch (err) {
    console.error('Get tenant error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to get tenant', 500);
  }
}

// PATCH /tenants/{tenantId}
export async function updateTenant(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const tenantId = event.pathParameters.tenantId;
    const userTenantId = validateTenantAccess(decoded.tenantId, tenantId);

    const updates = JSON.parse(event.body || '{}');
    const allowedFields = ['name', 'settings'];
    const filteredUpdates = Object.fromEntries(
      Object.entries(updates).filter(([key]) => allowedFields.includes(key))
    );

    if (Object.keys(filteredUpdates).length === 0) {
      return error('No valid fields to update', 400);
    }

    filteredUpdates.updatedAt = new Date().toISOString();

    const tenant = await updateItem(
      process.env.DYNAMODB_TABLE_TENANTS,
      { tenantId: userTenantId },
      filteredUpdates
    );

    await logAuditEvent(
      userTenantId,
      decoded.sub,
      'UPDATE_TENANT',
      'tenant',
      userTenantId,
      filteredUpdates,
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success(tenant);
  } catch (err) {
    console.error('Update tenant error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to update tenant', 500);
  }
}

// DELETE /tenants/{tenantId}
export async function deleteTenant(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const tenantId = event.pathParameters.tenantId;
    const userTenantId = validateTenantAccess(decoded.tenantId, tenantId);

    // Soft delete with TTL
    const deleteAt = Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60); // 30 days
    await updateItem(
      process.env.DYNAMODB_TABLE_TENANTS,
      { tenantId: userTenantId },
      {
        status: 'deleted',
        deletedAt: new Date().toISOString(),
        deleteAt,
      }
    );

    await logAuditEvent(
      userTenantId,
      decoded.sub,
      'DELETE_TENANT',
      'tenant',
      userTenantId,
      { status: 'deleted' },
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success({ message: 'Tenant deleted successfully' });
  } catch (err) {
    console.error('Delete tenant error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to delete tenant', 500);
  }
}

// GET /admin/tenants
export async function adminListAllTenants(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    requireAdminRole(decoded.role);

    const { limit, nextToken } = getPaginationParams(event);

    const tenants = await scanItems(
      process.env.DYNAMODB_TABLE_TENANTS,
      'attribute_not_exists(deletedAt)'
    );

    return success(createPaginationResponse(tenants.slice(0, limit), limit));
  } catch (err) {
    console.error('Admin list tenants error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to list tenants', 500);
  }
}

// PATCH /admin/tenants/{id}
export async function adminUpdateTenant(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    requireAdminRole(decoded.role);

    const tenantId = event.pathParameters.id;
    const updates = JSON.parse(event.body || '{}');

    const allowedFields = ['name', 'plan', 'status', 'maxUsers', 'storageGb'];
    const filteredUpdates = Object.fromEntries(
      Object.entries(updates).filter(([key]) => allowedFields.includes(key))
    );

    if (Object.keys(filteredUpdates).length === 0) {
      return error('No valid fields to update', 400);
    }

    filteredUpdates.updatedAt = new Date().toISOString();

    const tenant = await updateItem(
      process.env.DYNAMODB_TABLE_TENANTS,
      { tenantId },
      filteredUpdates
    );

    await logAuditEvent(
      tenantId,
      decoded.sub,
      'ADMIN_UPDATE_TENANT',
      'tenant',
      tenantId,
      filteredUpdates,
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success(tenant);
  } catch (err) {
    console.error('Admin update tenant error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to update tenant', 500);
  }
}

// DELETE /admin/tenants/{id}
export async function adminDeleteTenant(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    requireAdminRole(decoded.role);

    const tenantId = event.pathParameters.id;

    // Hard delete
    await deleteItem(process.env.DYNAMODB_TABLE_TENANTS, { tenantId });

    await logAuditEvent(
      tenantId,
      decoded.sub,
      'ADMIN_DELETE_TENANT',
      'tenant',
      tenantId,
      { action: 'hard_delete' },
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success({ message: 'Tenant permanently deleted' });
  } catch (err) {
    console.error('Admin delete tenant error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to delete tenant', 500);
  }
}

export async function handler(event) {
  const method = event.requestContext?.http?.method || event.httpMethod || '';
  const path = event.requestContext?.http?.path || event.rawPath || '';
  const route = `${method.toUpperCase()} ${path}`;

  switch (route) {
    case 'POST /tenants':
      return createTenant(event);
    case 'GET /tenants':
      return listTenants(event);
    case 'GET /tenants/{tenantId}':
    case 'GET /tenants/' + (event.pathParameters?.tenantId || ''):
      return getTenant(event);
    case 'PATCH /tenants/{tenantId}':
    case 'PATCH /tenants/' + (event.pathParameters?.tenantId || ''):
      return updateTenant(event);
    case 'DELETE /tenants/{tenantId}':
    case 'DELETE /tenants/' + (event.pathParameters?.tenantId || ''):
      return deleteTenant(event);
    case 'GET /admin/tenants':
      return adminListAllTenants(event);
    case 'PATCH /admin/tenants/{id}':
    case 'PATCH /admin/tenants/' + (event.pathParameters?.id || ''):
      return adminUpdateTenant(event);
    case 'DELETE /admin/tenants/{id}':
    case 'DELETE /admin/tenants/' + (event.pathParameters?.id || ''):
      return adminDeleteTenant(event);
    default:
      return error(`Unsupported tenant route: ${route}`, 404);
  }
}