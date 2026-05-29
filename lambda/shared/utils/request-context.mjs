// ============================================================================
// REQUEST CONTEXT EXTRACTOR - Lambda RID handling
// ============================================================================

import { generateRID, isValidRID, extractTenantIdFromRID } from './rid-generator.mjs';

/**
 * Extract or generate RequestContext from Lambda event
 * NEVER returns null - always generates if missing
 */
export function extractRequestContext(event) {
  const startTime = Date.now();
  
  // Try to extract RID from headers
  let requestId = event.headers?.['x-request-id'] || event.headers?.['X-Request-ID'];
  
  // Extract tenant and user from JWT
  const tenantId = extractTenantId(event) || 'unknown';
  const userId = extractUserId(event) || 'unknown';
  
  // If no RID or invalid, generate fresh one
  if (!requestId || !isValidRID(requestId)) {
    requestId = generateRID(tenantId);
    console.log(`[RID] Generated new RID: ${requestId} (was: ${event.headers?.['x-request-id'] || 'missing'})`);
  } else {
    // Validate tenantId in RID matches JWT tenantId
    const ridTenantId = extractTenantIdFromRID(requestId);
    if (ridTenantId && ridTenantId !== tenantId) {
      console.warn(`[RID] Tenant mismatch! RID: ${ridTenantId}, JWT: ${tenantId}`);
      // Security: Generate new RID with correct tenant
      requestId = generateRID(tenantId);
    }
  }
  
  return {
    requestId,
    tenantId,
    userId,
    startTime,
    sourceIp: event.requestContext?.identity?.sourceIp || event.requestContext?.http?.sourceIp,
    userAgent: event.requestContext?.identity?.userAgent || event.requestContext?.http?.userAgent,
    sessionRid: event.headers?.['x-session-rid'] || event.headers?.['X-Session-RID'],
  };
}

/**
 * Extract tenantId from JWT or event
 */
function extractTenantId(event) {
  // Try header first
  const tenantHeader = event.headers?.['x-tenant-id'] || event.headers?.['X-Tenant-ID'];
  if (tenantHeader) return tenantHeader;
  
  // Try JWT
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (authHeader) {
    try {
      const token = authHeader.replace('Bearer ', '');
      const payload = JSON.parse(
        Buffer.from(token.split('.')[1], 'base64').toString()
      );
      return payload['custom:tenantId'] || payload['custom:tenant_id'] || payload.tenantId || null;
    } catch {
      return null;
    }
  }
  
  return null;
}

/**
 * Extract userId from JWT
 */
function extractUserId(event) {
  const userHeader = event.headers?.['x-user-id'] || event.headers?.['X-User-ID'];
  if (userHeader) return userHeader;
  
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (authHeader) {
    try {
      const token = authHeader.replace('Bearer ', '');
      const payload = JSON.parse(
        Buffer.from(token.split('.')[1], 'base64').toString()
      );
      return payload.sub || payload.userId || payload['cognito:username'] || null;
    } catch {
      return null;
    }
  }
  
  return null;
}

/**
 * Validate tenant isolation
 */
export function validateTenantIsolation(event, context) {
  const jwtTenantId = extractTenantId(event);
  const pathTenantId = extractTenantFromPath(event);
  const bodyTenantId = extractTenantFromBody(event);
  
  // Primary check: JWT tenant must match context tenant
  if (jwtTenantId && jwtTenantId !== context.tenantId) {
    console.error('Tenant mismatch: JWT vs Context', {
      jwtTenantId,
      contextTenantId: context.tenantId,
      requestId: context.requestId,
    });
    return {
      valid: false,
      error: 'Tenant mismatch detected',
      errorCode: 'TENANT_MISMATCH',
    };
  }
  
  // Secondary check: Path tenant must match JWT tenant
  if (pathTenantId && jwtTenantId && pathTenantId !== jwtTenantId) {
    console.error('Tenant mismatch: Path vs JWT', {
      pathTenantId,
      jwtTenantId,
    });
    return {
      valid: false,
      error: 'Tenant ID in path does not match authenticated tenant',
      errorCode: 'TENANT_PATH_MISMATCH',
    };
  }
  
  return { valid: true };
}

function extractTenantFromPath(event) {
  const pathMatch = event.path?.match(/\/tenants\/([^\/]+)/);
  return pathMatch ? pathMatch[1] : null;
}

function extractTenantFromBody(event) {
  try {
    const body = JSON.parse(event.body || '{}');
    return body.tenantId || null;
  } catch {
    return null;
  }
}
