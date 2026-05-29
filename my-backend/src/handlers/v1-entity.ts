// ============================================================================
// V1 Entity Lambda Handler — Generic CRUD for 10 Entity Types
// ============================================================================
// Serves: /api/v1/{entity} — customers, products, payments, estimates,
//         journal-entries, stock-movements, backups, businesses,
//         vendor-profiles, connections
//
// Each entity gets: GET /, GET /:id, POST /, PUT /:id, DELETE /:id
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { verifyAuth } from '../middleware/cognito-auth';
import { buildTenantContext } from '../dynamodb/tenant-guard';
import { CrudService } from '../dynamodb/crud-factory';
import {
  customerService,
  productService,
  paymentService,
  estimateService,
  journalEntryService,
  stockMovementService,
  backupService,
  businessService,
  vendorProfileService,
  connectionService,
} from '../dynamodb/entity-services';
import { logger } from '../utils/logger';
import * as response from '../utils/response';

// ---- Service Map ----

const SERVICES: Record<string, { service: CrudService<any>; name: string }> = {
  customers: { service: customerService, name: 'customer' },
  products: { service: productService, name: 'product' },
  payments: { service: paymentService, name: 'payment' },
  estimates: { service: estimateService, name: 'estimate' },
  'journal-entries': { service: journalEntryService, name: 'journalEntry' },
  'stock-movements': { service: stockMovementService, name: 'stockMovement' },
  backups: { service: backupService, name: 'backup' },
  businesses: { service: businessService, name: 'business' },
  'vendor-profiles': { service: vendorProfileService, name: 'vendorProfile' },
  connections: { service: connectionService, name: 'connection' },
};

function extractBusinessId(event: APIGatewayProxyEventV2): string {
  return (
    event.headers?.['x-active-business'] ||
    event.headers?.['x-business-id'] ||
    event.headers?.['x-shop-id'] ||
    ''
  );
}

function getServiceFromPath(event: APIGatewayProxyEventV2): {
  service: CrudService<any>;
  name: string;
} | null {
  // Path format: /api/v1/{entity} or /api/v1/{entity}/{id}
  const rawPath = event.rawPath || '';
  const parts = rawPath.split('/').filter(Boolean);
  // parts = ['api', 'v1', 'customers', 'id?']
  const entitySlug = parts[2]; // 'customers', 'products', etc.
  return SERVICES[entitySlug] || null;
}

// ---- LIST ----
export async function listEntity(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const svc = getServiceFromPath(event);
    if (!svc) return response.error(404, 'NOT_FOUND', 'Unknown entity type');

    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const options: any = {};
    if (event.queryStringParameters?.startDate) options.startDate = event.queryStringParameters.startDate;
    if (event.queryStringParameters?.endDate) options.endDate = event.queryStringParameters.endDate;
    if (event.queryStringParameters?.limit) options.limit = parseInt(event.queryStringParameters.limit, 10);

    const result = await svc.service.list(tenantContext, options);
    return response.success(result);
  } catch (err: any) {
    logger.error('Entity list error', { error: err.message });
    if (err.message?.includes('SECURITY')) return response.error(403, 'ACCESS_DENIED', 'Access denied');
    return response.internalError();
  }
}

// ---- GET ----
export async function getEntity(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const svc = getServiceFromPath(event);
    if (!svc) return response.error(404, 'NOT_FOUND', 'Unknown entity type');

    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const id = event.pathParameters?.id;
    if (!id) return response.error(400, 'MISSING_ID', 'Entity ID required');

    const result = await svc.service.get(tenantContext, id);
    if (!result) return response.error(404, 'NOT_FOUND', `${svc.name} not found`);

    return response.success({ [svc.name]: result });
  } catch (err: any) {
    logger.error('Entity get error', { error: err.message });
    if (err.message?.includes('SECURITY')) return response.error(403, 'ACCESS_DENIED', 'Access denied');
    return response.internalError();
  }
}

// ---- CREATE ----
export async function createEntity(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const svc = getServiceFromPath(event);
    if (!svc) return response.error(404, 'NOT_FOUND', 'Unknown entity type');

    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const body = JSON.parse(event.body || '{}');

    const result = await svc.service.create(tenantContext, body, {
      ipAddress: event.requestContext?.http?.sourceIp || 'unknown',
      userAgent: event.headers?.['user-agent'] || 'unknown',
    });

    return response.success({ success: true, [svc.name]: result }, 201);
  } catch (err: any) {
    if (err.message?.includes('SECURITY')) return response.error(403, 'ACCESS_DENIED', 'Access denied');
    if (err.message?.includes('required')) return response.error(400, 'VALIDATION', err.message);
    logger.error('Entity create error', { error: err.message });
    return response.internalError();
  }
}

// ---- UPDATE ----
export async function updateEntity(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const svc = getServiceFromPath(event);
    if (!svc) return response.error(404, 'NOT_FOUND', 'Unknown entity type');

    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const id = event.pathParameters?.id;
    if (!id) return response.error(400, 'MISSING_ID', 'Entity ID required');

    const body = JSON.parse(event.body || '{}');
    const { version, ...updates } = body;

    const result = await svc.service.update(
      tenantContext,
      id,
      updates,
      version ? parseInt(version, 10) : undefined,
      {
        ipAddress: event.requestContext?.http?.sourceIp || 'unknown',
        userAgent: event.headers?.['user-agent'] || 'unknown',
      },
    );

    return response.success({ success: true, [svc.name]: result });
  } catch (err: any) {
    if (err.message?.includes('SECURITY')) return response.error(403, 'ACCESS_DENIED', 'Access denied');
    if (err.message?.includes('not found')) return response.error(404, 'NOT_FOUND', err.message);
    if (err.name === 'ConditionalCheckFailedException') {
      return response.error(409, 'VERSION_CONFLICT', 'Version conflict. Reload and retry.');
    }
    logger.error('Entity update error', { error: err.message });
    return response.internalError();
  }
}

// ---- DELETE ----
export async function deleteEntity(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const svc = getServiceFromPath(event);
    if (!svc) return response.error(404, 'NOT_FOUND', 'Unknown entity type');

    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const id = event.pathParameters?.id;
    if (!id) return response.error(400, 'MISSING_ID', 'Entity ID required');

    const version = parseInt(event.queryStringParameters?.version || '0', 10);

    await svc.service.softDelete(tenantContext, id, version, {
      ipAddress: event.requestContext?.http?.sourceIp || 'unknown',
      userAgent: event.headers?.['user-agent'] || 'unknown',
    });

    return response.success({ success: true, message: `${svc.name} deleted` });
  } catch (err: any) {
    if (err.message?.includes('SECURITY')) return response.error(403, 'ACCESS_DENIED', 'Access denied');
    if (err.message?.includes('not found')) return response.error(404, 'NOT_FOUND', err.message);
    logger.error('Entity delete error', { error: err.message });
    return response.internalError();
  }
}
