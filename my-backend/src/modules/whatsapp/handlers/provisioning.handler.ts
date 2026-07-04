// ============================================================================
// WhatsApp Module — OpenWA Provisioning Handler (Task 4)
// ============================================================================
// Endpoints:
//   POST   /whatsapp/provisioning         — save credentials (pending_verification)
//   GET    /whatsapp/provisioning         — get status (no secrets returned)
//   POST   /whatsapp/provisioning/verify  — verify session + register webhook, activate
//   DELETE /whatsapp/provisioning         — remove credentials + registered webhook
//
// SECURITY:
// - Only Owner/Admin can manage OpenWA provisioning (mirrors payment-config.ts)
// - BusinessID is session-derived ONLY (Req 12.4) — never client input
// - Credentials (apiKey, webhookSecret) are NEVER returned in API responses
//
// Requirements: 8.4, 8.5, 10.1, 10.4, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 13.7
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError, AuthError } from '../../../utils/errors';
import { buildTenantContext } from '../../../dynamodb/tenant-guard';
import { logger } from '../../../utils/logger';
import { FeatureKey } from '../../../config/plan-feature-registry';
import { saveProvisioningConfigSchema } from '../schemas/provisioning.schema';
import {
  createOpenWaProvisioningService,
  buildWebhookCallbackUrl,
} from '../services/openwa-provisioning.service';

// ── Constants ─────────────────────────────────────────────────────────────────

/** Roles allowed to manage OpenWA provisioning (mirrors payment-config.ts). */
const ALLOWED_ROLES: UserRole[] = [UserRole.OWNER, UserRole.ADMIN];

/** Feature key that gates WhatsApp automation configuration. */
const REQUIRED_FEATURE = FeatureKey.WA_CORE;

// ── Instances ─────────────────────────────────────────────────────────────────

const provisioningService = createOpenWaProvisioningService();

// ── POST /whatsapp/provisioning ───────────────────────────────────────────────

/**
 * Save OpenWA credentials for the authenticated business.
 * Leaves the config in `pending_verification` — call `verifyConfig` next.
 */
export const saveProvisioningConfig = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveTenantScope(event, auth);
    const body = parseJsonBody(event);

    const parsed = saveProvisioningConfigSchema.safeParse(body);
    if (!parsed.success) {
      return response.badRequest('Provisioning config validation failed', parsed.error.flatten());
    }

    const saved = await provisioningService.saveConfig(tenantId, businessId, parsed.data);

    logger.info('[ProvisioningHandler] Config saved', { tenantId, businessId });
    return response.success(toPublicView(saved), 201);
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── GET /whatsapp/provisioning ────────────────────────────────────────────────

/** Get OpenWA provisioning status for the authenticated business (no secrets). */
export const getProvisioningConfig = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveTenantScope(event, auth);
    const status = await provisioningService.getStatus(tenantId, businessId);

    if (!status) {
      return response.notFound('OpenWA provisioning config');
    }
    return response.success(toPublicView(status));
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── POST /whatsapp/provisioning/verify ────────────────────────────────────────

/**
 * Verify the saved credentials against the real OpenWA gateway (GET
 * /api/sessions/:sessionId), register our webhook, and activate the config.
 */
export const verifyProvisioningConfig = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveTenantScope(event, auth);

    const domainName = event.requestContext?.domainName;
    const stage = (event.requestContext as unknown as { stage?: string })?.stage;
    const webhookCallbackUrl = buildWebhookCallbackUrl(domainName, stage);

    const activated = await provisioningService.verifyAndActivate(
      tenantId,
      businessId,
      webhookCallbackUrl,
    );

    logger.info('[ProvisioningHandler] Config verified', { tenantId, businessId });
    return response.success(toPublicView(activated));
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── DELETE /whatsapp/provisioning ─────────────────────────────────────────────

/** Remove OpenWA credentials and the registered webhook for the business. */
export const deleteProvisioningConfig = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveTenantScope(event, auth);
    await provisioningService.deleteConfig(tenantId, businessId);

    logger.info('[ProvisioningHandler] Config deleted', { tenantId, businessId });
    return response.success({ message: 'OpenWA provisioning config removed' });
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── Unified router entry (mirrors config.handler.ts usage pattern) ──────────

/**
 * Lambda handler for /whatsapp/provisioning and /whatsapp/provisioning/verify.
 * Routed here from handlers/index.ts based on path + method.
 */
export async function provisioningHandler(
  event: APIGatewayProxyEventV2,
  context: Context,
): Promise<APIGatewayProxyResultV2> {
  const path = event.rawPath || '';
  const method = (event.requestContext?.http?.method || 'GET').toUpperCase();

  if (path.endsWith('/verify') && method === 'POST') {
    return verifyProvisioningConfig(event, context);
  }
  if (method === 'POST') {
    return saveProvisioningConfig(event, context);
  }
  if (method === 'GET') {
    return getProvisioningConfig(event, context);
  }
  if (method === 'DELETE') {
    return deleteProvisioningConfig(event, context);
  }
  return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed on ${path}`);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Strip nothing sensitive is stored on this record in the first place (the
 * repository never persists apiKey/webhookSecret), but keep an explicit
 * projection so future fields default to NOT exposed unless added here.
 */
function toPublicView(cfg: {
  id: string;
  businessId: string;
  sessionId: string;
  baseUrl: string;
  status: string;
  displayName?: string;
  webhookId?: string;
  lastError?: string;
  verifiedAt?: string;
  createdAt: string;
  updatedAt: string;
}): Record<string, unknown> {
  return {
    id: cfg.id,
    businessId: cfg.businessId,
    sessionId: cfg.sessionId,
    baseUrl: cfg.baseUrl,
    status: cfg.status,
    displayName: cfg.displayName,
    webhookRegistered: !!cfg.webhookId,
    lastError: cfg.lastError,
    verifiedAt: cfg.verifiedAt,
    createdAt: cfg.createdAt,
    updatedAt: cfg.updatedAt,
  };
}

/**
 * Resolve BusinessID exclusively from the authenticated session
 * (Req 12.4) — mirrors config.handler.ts / customer.handler.ts.
 */
async function resolveTenantScope(
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

function parseJsonBody(event: APIGatewayProxyEventV2): Record<string, unknown> {
  if (!event.body) {
    throw new ValidationError('Request body is required');
  }
  try {
    const parsed = JSON.parse(event.body) as unknown;
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      throw new ValidationError('Request body must be a JSON object');
    }
    return parsed as Record<string, unknown>;
  } catch (err) {
    if (err instanceof ValidationError) throw err;
    throw new ValidationError('Request body is not valid JSON');
  }
}
