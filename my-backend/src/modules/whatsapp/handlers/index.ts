// ============================================================================
// WhatsApp Module — Unified API Handler Entry Point (Task 16.2)
// ============================================================================
// Single Lambda handler that routes all /whatsapp/* API Gateway requests
// (except the webhook which has its own Lambda) to the correct sub-handler.
//
// AUTH FLOW:
// 1. API Gateway verifies the Cognito JWT (returns 401 if invalid/expired)
// 2. This handler dispatches to the correct sub-handler based on path + method
// 3. Each sub-handler calls `authorizedHandler` which enforces RBAC roles,
//    derives BusinessID from session, and calls `checkPermission` fail-closed
// 4. Cross-business access returns 403 with no data/existence disclosure
//
// SECURITY:
// - 401: missing, expired, or invalid Cognito token (handled by API GW + handler)
// - 403: insufficient role OR cross-business access (no data disclosure)
// - BusinessID is session-authoritative — never from client input (Req 12.4)
//
// Requirements: 12.2, 12.3, 13.2
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import * as response from '../../../utils/response';
import { logger } from '../../../utils/logger';

// Import all sub-handlers
import { customerHandler } from './customer.handler';
import { templateHandler } from './template.handler';
import { ruleHandler } from './rule.handler';
import { getConfigHandler, putConfigHandler } from './config.handler';
import { deliveryLogHandler, auditLogHandler } from './log.handler';
import { inboundHandler } from './inbound.handler';
import {
  saveProvisioningConfig,
  getProvisioningConfig,
  verifyProvisioningConfig,
  deleteProvisioningConfig,
} from './provisioning.handler';

// ── Route Matcher ─────────────────────────────────────────────────────────────

/**
 * Unified Lambda handler for all authenticated /whatsapp/* routes.
 *
 * API Gateway dispatches all whatsappApi events here. The handler inspects
 * the raw path and HTTP method to delegate to the appropriate sub-handler.
 *
 * Each sub-handler already wraps its logic in `authorizedHandler`, which:
 * - Validates Cognito JWT claims
 * - Enforces RBAC role requirements
 * - Derives BusinessID from the session only (Req 12.4)
 * - Calls `checkPermission` fail-closed (Req 12.2)
 * - Returns 403 without data/existence disclosure on cross-business (Req 12.3)
 */
export async function handler(
  event: APIGatewayProxyEventV2,
  context: Context,
): Promise<APIGatewayProxyResultV2> {
  const path = event.rawPath || '';
  const method = (event.requestContext?.http?.method || 'GET').toUpperCase();

  logger.info('[WhatsAppRouter] Incoming request', {
    path,
    method,
    requestId: event.requestContext?.requestId,
  });

  try {
    // ── Config routes ───────────────────────────────────────────────────────
    if (path === '/whatsapp/config') {
      if (method === 'GET') return await getConfigHandler(event, context);
      if (method === 'PUT') return await putConfigHandler(event, context);
      return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed on /whatsapp/config`);
    }

    // ── Provisioning routes ─────────────────────────────────────────────────
    if (path === '/whatsapp/provisioning/verify') {
      if (method === 'POST') return await verifyProvisioningConfig(event, context);
      return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed on /whatsapp/provisioning/verify`);
    }
    if (path === '/whatsapp/provisioning') {
      if (method === 'POST') return await saveProvisioningConfig(event, context);
      if (method === 'GET') return await getProvisioningConfig(event, context);
      if (method === 'DELETE') return await deleteProvisioningConfig(event, context);
      return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed on /whatsapp/provisioning`);
    }

    // ── Log routes ──────────────────────────────────────────────────────────
    if (path === '/whatsapp/logs/delivery') {
      if (method === 'GET') return await deliveryLogHandler(event, context);
      return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed on /whatsapp/logs/delivery`);
    }
    if (path === '/whatsapp/logs/audit') {
      if (method === 'GET') return await auditLogHandler(event, context);
      return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed on /whatsapp/logs/audit`);
    }

    // ── Inbound route ───────────────────────────────────────────────────────
    if (path === '/whatsapp/inbound') {
      if (method === 'POST') return await inboundHandler(event, context);
      return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed on /whatsapp/inbound`);
    }

    // ── Customer routes ─────────────────────────────────────────────────────
    if (path.startsWith('/whatsapp/customers')) {
      return await customerHandler(event, context);
    }

    // ── Template routes ─────────────────────────────────────────────────────
    if (path.startsWith('/whatsapp/templates')) {
      return await templateHandler(event, context);
    }

    // ── Rule routes ─────────────────────────────────────────────────────────
    if (path.startsWith('/whatsapp/rules')) {
      return await ruleHandler(event, context);
    }

    // ── Fallback: route not found ───────────────────────────────────────────
    logger.warn('[WhatsAppRouter] No matching route', { path, method });
    return response.error(404, 'ROUTE_NOT_FOUND', `Route ${method} ${path} not found`);
  } catch (err) {
    // Unexpected errors are caught here as a safety net. Each sub-handler
    // has its own error handling via `authorizedHandler`, so this should rarely
    // fire. If it does, return a generic 500 without leaking internals.
    const message = err instanceof Error ? err.message : 'Internal server error';
    logger.error('[WhatsAppRouter] Unhandled error', {
      path,
      method,
      error: message,
    });
    return response.error(500, 'INTERNAL_ERROR', 'An unexpected error occurred');
  }
}

// Re-export individual handlers for direct Lambda invocation or testing
export { customerHandler } from './customer.handler';
export { templateHandler } from './template.handler';
export { ruleHandler } from './rule.handler';
export { getConfigHandler, putConfigHandler } from './config.handler';
export { deliveryLogHandler, auditLogHandler } from './log.handler';
export { inboundHandler } from './inbound.handler';
export { webhookHandler } from './webhook.handler';
export {
  saveProvisioningConfig,
  getProvisioningConfig,
  verifyProvisioningConfig,
  deleteProvisioningConfig,
} from './provisioning.handler';
