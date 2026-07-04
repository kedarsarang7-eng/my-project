// ============================================================================
// WhatsApp Module — Log Query Handler (Task 16.1)
// ============================================================================
// Read-only, RBAC-gated delivery-log and audit-log queries.
//
// ENDPOINTS:
// - GET /whatsapp/logs/delivery  → query Delivery_Log entries for the business
// - GET /whatsapp/logs/audit     → query Audit_Log entries for the business
//
// SECURITY:
// - BusinessID is session-derived ONLY (Req 12.4) — never from client body
// - RBAC via authorizedHandler: OWNER, ADMIN, MANAGER roles
// - Feature-gated via WA_CORE
// - Read-only: no mutations allowed through this handler
// - 401 for missing/expired/invalid tokens
// - 403 with no data/existence disclosure for cross-business access
//
// Requirements: 8.3, 8.7
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { AuthError } from '../../../utils/errors';
import { buildTenantContext } from '../../../dynamodb/tenant-guard';
import { logger } from '../../../utils/logger';
import { FeatureKey } from '../../../config/plan-feature-registry';
import { DeliveryLogRepository } from '../repositories/delivery-log.repository';
import { AuditLogRepository } from '../repositories/audit-log.repository';

// ── Constants ─────────────────────────────────────────────────────────────────

/** Roles allowed to query logs. */
const ALLOWED_ROLES: UserRole[] = [
  UserRole.OWNER,
  UserRole.ADMIN,
  UserRole.MANAGER,
];

/** Feature key that gates log access. */
const REQUIRED_FEATURE = FeatureKey.WA_CORE;

/** Default page size for log queries. */
const DEFAULT_LIMIT = 50;

/** Maximum page size for log queries. */
const MAX_LIMIT = 200;

// ── Instances ─────────────────────────────────────────────────────────────────

const deliveryLogRepo = new DeliveryLogRepository();
const auditLogRepo = new AuditLogRepository();

// ── Delivery Log Handler ─────────────────────────────────────────────────────

/**
 * GET /whatsapp/logs/delivery
 *
 * Query params:
 * - limit: number (1..200, default 50)
 * - messageId: string (filter by specific outbound message ID)
 * - from: string (ISO-8601 date/timestamp prefix for time window)
 *
 * Returns Delivery_Log entries for the authenticated business.
 * Entries are append-only and retained for 365 days (Req 8.7).
 */
export const deliveryLogHandler = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveLogTenantScope(event, auth);
    const params = event.queryStringParameters ?? {};

    const limit = Math.min(
      Math.max(parseInt(params.limit || String(DEFAULT_LIMIT), 10) || DEFAULT_LIMIT, 1),
      MAX_LIMIT,
    );
    const messageId = params.messageId?.trim() || undefined;
    const from = params.from?.trim() || undefined;

    // If a specific message ID is provided, filter to that message's logs
    if (messageId) {
      const items = await deliveryLogRepo.listByMessageId(tenantId, businessId, messageId, { limit });
      return response.success({ items, count: items.length });
    }

    // Otherwise, list by time window (uses timestamp prefix for efficient queries)
    const items = await deliveryLogRepo.listByWindow(tenantId, businessId, {
      timestampPrefix: from,
      limit,
      scanIndexForward: false, // newest first
    });

    return response.success({ items, count: items.length });
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── Audit Log Handler ────────────────────────────────────────────────────────

/**
 * GET /whatsapp/logs/audit
 *
 * Query params:
 * - limit: number (1..200, default 50)
 * - action: string (filter by audit action type)
 * - target: string (filter by target entity)
 * - from: string (ISO-8601 date/timestamp prefix for time window)
 *
 * Returns Audit_Log entries for the authenticated business.
 * Entries are append-only and retained for 365 days (Req 8.7).
 */
export const auditLogHandler = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveLogTenantScope(event, auth);
    const params = event.queryStringParameters ?? {};

    const limit = Math.min(
      Math.max(parseInt(params.limit || String(DEFAULT_LIMIT), 10) || DEFAULT_LIMIT, 1),
      MAX_LIMIT,
    );
    const action = params.action?.trim() || undefined;
    const target = params.target?.trim() || undefined;
    const from = params.from?.trim() || undefined;

    // If an action filter is provided, query by action
    if (action) {
      const items = await auditLogRepo.listByAction(tenantId, businessId, action, {
        limit,
        scanIndexForward: false,
      });
      return response.success({ items, count: items.length });
    }

    // If a target filter is provided, query by target entity
    if (target) {
      const items = await auditLogRepo.listByTarget(tenantId, businessId, target, {
        limit,
        scanIndexForward: false,
      });
      return response.success({ items, count: items.length });
    }

    // Otherwise, list by time window (newest first)
    const items = await auditLogRepo.listByWindow(tenantId, businessId, {
      timestampPrefix: from,
      limit,
      scanIndexForward: false, // newest first
    });

    return response.success({ items, count: items.length });
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── Tenant Scope Resolution (Req 12.4) ──────────────────────────────────────

/**
 * Resolve BusinessID exclusively from the authenticated session.
 * SECURITY (Req 12.4): BusinessID is NEVER taken from client-supplied input.
 */
async function resolveLogTenantScope(
  event: APIGatewayProxyEventV2,
  auth: AuthContext,
): Promise<{ tenantId: string; businessId: string }> {
  const businessId =
    event.headers?.['x-active-business'] ||
    event.headers?.['x-business-id'] ||
    event.headers?.['X-Business-Id'] ||
    event.headers?.['x-shop-id'] ||
    '';

  if (!businessId || businessId.trim() === '') {
    throw new AuthError('Authenticated business context is required');
  }

  const scope = await buildTenantContext(auth, businessId);

  return {
    tenantId: scope.tenantContext.tenantId,
    businessId: scope.tenantContext.businessId,
  };
}
