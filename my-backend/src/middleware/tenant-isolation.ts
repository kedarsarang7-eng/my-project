// ============================================================================
// Tenant Isolation Layer — Extract, Validate, and Enforce Tenant Boundaries
// ============================================================================
// Provides tenant ID extraction from Cognito JWT claims and format validation.
// Used by the handler-wrapper and repository layer to enforce tenant scoping.
// ============================================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { logger } from '../utils/logger';

// ── Interfaces ───────────────────────────────────────────────────────────────

export interface TenantValidation {
  valid: boolean;
  tenantId?: string;
  error?: string;
}

export interface SecurityEvent {
  type: 'missing_tenant_id' | 'invalid_tenant_format' | 'cross_tenant_access';
  authenticatedTenantId?: string;
  targetResourceId?: string;
  operationType?: string;
  attemptedValue?: string;
  timestamp: string;
}

// ── Constants ────────────────────────────────────────────────────────────────

/**
 * Tenant ID format: non-empty, max 128 chars, alphanumeric + hyphens + underscores.
 * Matches requirement 9.2.
 */
export const TENANT_ID_PATTERN = /^[a-zA-Z0-9_-]{1,128}$/;

// ── Functions ────────────────────────────────────────────────────────────────

/**
 * Validates a tenant ID string against the format rules:
 * - Non-empty
 * - Max 128 characters
 * - Only contains [a-zA-Z0-9_-]
 */
export function validateTenantIdFormat(tenantId: string): boolean {
  if (!tenantId) return false;
  return TENANT_ID_PATTERN.test(tenantId);
}

/**
 * Extracts and validates the tenant ID from a Lambda event's JWT claims.
 *
 * Checks multiple Cognito JWT claim locations:
 * 1. event.requestContext.authorizer.claims['custom:tenantId']
 * 2. event.requestContext.authorizer.claims['custom:tenant_id']
 * 3. event.requestContext.authorizer.jwt.claims['custom:tenantId']
 * 4. event.requestContext.authorizer.jwt.claims['custom:tenant_id']
 * 5. event.requestContext.authorizer.jwt.claims.tenantId
 *
 * Returns { valid: true, tenantId } on success.
 * Returns { valid: false, error } on failure (triggers HTTP 403).
 */
export function extractTenantId(event: any): TenantValidation {
  const authorizer = event?.requestContext?.authorizer;

  if (!authorizer) {
    logSecurityEvent({
      type: 'missing_tenant_id',
      attemptedValue: undefined,
      timestamp: new Date().toISOString(),
    });
    return { valid: false, error: 'No authorizer context found' };
  }

  // Try extracting from various Cognito JWT claim locations
  const tenantId = extractFromClaims(authorizer);

  // Case: tenant ID is absent or empty
  if (!tenantId || tenantId.trim() === '') {
    logSecurityEvent({
      type: 'missing_tenant_id',
      attemptedValue: tenantId || undefined,
      timestamp: new Date().toISOString(),
    });
    return { valid: false, error: 'Tenant ID is absent or empty in JWT claims' };
  }

  // Case: tenant ID fails format validation
  if (!validateTenantIdFormat(tenantId)) {
    logSecurityEvent({
      type: 'invalid_tenant_format',
      attemptedValue: maskTenantId(tenantId),
      timestamp: new Date().toISOString(),
    });
    return {
      valid: false,
      error: 'Tenant ID format is invalid. Expected: non-empty, max 128 chars, [a-zA-Z0-9_-]+',
    };
  }

  return { valid: true, tenantId };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Tries multiple claim paths to find the tenant ID.
 * Cognito can place custom attributes in different locations depending on
 * the authorizer type (REST API vs HTTP API, Lambda authorizer vs JWT authorizer).
 */
function extractFromClaims(authorizer: any): string | undefined {
  // Path 1: REST API with Cognito authorizer → authorizer.claims
  const claims = authorizer.claims;
  if (claims) {
    const fromClaims =
      claims['custom:tenantId'] ||
      claims['custom:tenant_id'] ||
      claims['tenantId'] ||
      claims['tenant_id'];
    if (fromClaims) return String(fromClaims);
  }

  // Path 2: HTTP API with JWT authorizer → authorizer.jwt.claims
  const jwtClaims = authorizer.jwt?.claims;
  if (jwtClaims) {
    const fromJwt =
      jwtClaims['custom:tenantId'] ||
      jwtClaims['custom:tenant_id'] ||
      jwtClaims['tenantId'] ||
      jwtClaims['tenant_id'];
    if (fromJwt) return String(fromJwt);
  }

  // Path 3: Lambda authorizer may put tenantId directly on authorizer
  if (authorizer.tenantId) return String(authorizer.tenantId);
  if (authorizer.tenant_id) return String(authorizer.tenant_id);

  return undefined;
}

/**
 * Masks a tenant ID for logging — shows first 4 chars only to avoid
 * leaking the full value in logs while still being useful for debugging.
 */
function maskTenantId(value: string): string {
  if (!value || value.length <= 4) return '****';
  return `${value.slice(0, 4)}****`;
}

/**
 * Logs a security event for tenant isolation violations.
 */
export function logSecurityEvent(event: SecurityEvent): void {
  logger.warn('TENANT_ISOLATION_SECURITY_EVENT', {
    eventType: event.type,
    authenticatedTenantId: event.authenticatedTenantId,
    targetResourceId: event.targetResourceId,
    operationType: event.operationType,
    attemptedValue: event.attemptedValue,
    timestamp: event.timestamp,
  });
}

// ── Tenant Scoping ───────────────────────────────────────────────────────────

/**
 * Injects tenant ID into DynamoDB operation parameters to enforce tenant scoping.
 *
 * Behavior by operation type (determined by presence of specific keys in params):
 * - **Query/Get**: Adds tenantId condition to KeyConditionExpression / FilterExpression
 * - **Put**: Adds tenantId field to the Item being written
 * - **Update/Delete**: Adds tenantId condition to ConditionExpression to ensure
 *   the item belongs to the tenant before modification
 *
 * Returns a new params object — does not mutate the original.
 */
export function scopeToTenant(
  params: Record<string, any>,
  tenantId: string,
): Record<string, any> {
  const scoped = { ...params };

  // Determine operation type from the shape of the params
  if ('KeyConditionExpression' in params) {
    // Query operation — inject tenant into key condition
    scoped.KeyConditionExpression = appendCondition(
      params.KeyConditionExpression,
      'tenantId = :_tenantId',
    );
    scoped.ExpressionAttributeValues = {
      ...params.ExpressionAttributeValues,
      ':_tenantId': tenantId,
    };
  } else if ('Item' in params) {
    // Put operation — add tenantId to the item
    scoped.Item = { ...params.Item, tenantId };
  } else if ('Key' in params && 'UpdateExpression' in params) {
    // Update operation — add condition to ensure tenant ownership
    scoped.ConditionExpression = appendCondition(
      params.ConditionExpression,
      'tenantId = :_tenantId',
    );
    scoped.ExpressionAttributeValues = {
      ...params.ExpressionAttributeValues,
      ':_tenantId': tenantId,
    };
  } else if ('Key' in params && !('UpdateExpression' in params) && !('Item' in params)) {
    // Get or Delete operation — add filter/condition for tenant scoping
    if ('FilterExpression' in params || 'KeyConditionExpression' in params) {
      // Get with filter — append tenant condition
      scoped.FilterExpression = appendCondition(
        params.FilterExpression,
        'tenantId = :_tenantId',
      );
    } else {
      // Plain Get/Delete — add ConditionExpression for tenant check
      scoped.ConditionExpression = appendCondition(
        params.ConditionExpression,
        'tenantId = :_tenantId',
      );
    }
    scoped.ExpressionAttributeValues = {
      ...params.ExpressionAttributeValues,
      ':_tenantId': tenantId,
    };
  }

  return scoped;
}

/**
 * Verifies that a resource belongs to the authenticated tenant.
 *
 * Returns true if resourceTenantId matches authTenantId.
 * Returns false and logs a security event if they don't match.
 */
export function verifyOwnership(
  resourceTenantId: string,
  authTenantId: string,
): boolean {
  if (resourceTenantId === authTenantId) {
    return true;
  }

  logSecurityEvent({
    type: 'cross_tenant_access',
    authenticatedTenantId: authTenantId,
    targetResourceId: resourceTenantId,
    operationType: 'resource_access',
    timestamp: new Date().toISOString(),
  });

  return false;
}

// ── Internal Helpers ─────────────────────────────────────────────────────────

/**
 * Appends a condition clause to an existing expression with AND.
 * If the existing expression is falsy, returns just the new condition.
 */
function appendCondition(existing: string | undefined, condition: string): string {
  if (!existing) return condition;
  return `${existing} AND ${condition}`;
}
