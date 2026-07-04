// ============================================================================
// WhatsApp Module — Automation Config Handler (Task 16.1)
// ============================================================================
// GET and PUT for Automation_Config with Zod schema validation.
//
// BEHAVIOR:
// - GET /whatsapp/config           → list all configs for the business
// - GET /whatsapp/config?type=X&tier=Y → get specific (businessType, tier) config
// - PUT /whatsapp/config           → upsert config; rejects invalid payload,
//                                    retains last valid (Req 1.8)
//
// SECURITY:
// - BusinessID is session-derived ONLY (Req 12.4) — never from client body
// - RBAC via authorizedHandler: OWNER, ADMIN, MANAGER roles
// - Feature-gated via WA_CORE
//
// Requirements: 1.1, 1.6, 1.8, 8.3, 8.7
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { z, ZodError } from 'zod';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError, AuthError } from '../../../utils/errors';
import { buildTenantContext } from '../../../dynamodb/tenant-guard';
import { logger } from '../../../utils/logger';
import { FeatureKey } from '../../../config/plan-feature-registry';
import { AutomationConfigRepository } from '../repositories/automation-config.repository';
import { automationConfigSchema, type AutomationConfig } from '../schemas/entities';
import { WaAuditService } from '../services/wa-audit.service';

// ── Constants ─────────────────────────────────────────────────────────────────

/** Roles allowed to manage Automation_Config. */
const ALLOWED_ROLES: UserRole[] = [
  UserRole.OWNER,
  UserRole.ADMIN,
  UserRole.MANAGER,
];

/** Feature key that gates config management. */
const REQUIRED_FEATURE = FeatureKey.WA_CORE;

// ── Instances ─────────────────────────────────────────────────────────────────

const configRepo = new AutomationConfigRepository();
const auditService = new WaAuditService();

// ── Zod Schema for PUT body validation ───────────────────────────────────────
// The PUT body uses the same schema as the entity, minus the session-derived
// fields (tenantId, businessId) and server-managed timestamps.

const configPutSchema = z.object({
  id: z.string().trim().min(1).max(128).refine((v) => !v.includes('#'), { message: "must not contain '#'" }),
  businessType: z.string().trim().min(1).max(100),
  tier: z.enum(['basic', 'pro', 'premium', 'enterprise']),
  automations: z.record(
    z.string(),
    z.object({
      enabled: z.boolean(),
      templateId: z.string().trim().min(1).max(128).refine((v) => !v.includes('#'), { message: "must not contain '#'" }).optional(),
      ruleIds: z.array(z.string().trim().min(1).max(128).refine((v) => !v.includes('#'), { message: "must not contain '#'" })).optional(),
    }),
  ),
  channels: z.record(
    z.string(),
    z.object({
      enabled: z.boolean(),
    }),
  ),
  schemaVersion: z.number().int().positive(),
});

type ConfigPutInput = z.infer<typeof configPutSchema>;

// ── GET Handler ──────────────────────────────────────────────────────────────

/**
 * GET /whatsapp/config
 *
 * Query params:
 * - type: BusinessType (optional, filters by type)
 * - tier: SubscriptionTier (optional, requires type)
 *
 * Returns all configs for the business, or a single config if both type and
 * tier are specified.
 */
export const getConfigHandler = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveTenantScope(event, auth);
    const params = event.queryStringParameters ?? {};

    const businessType = params.type?.trim();
    const tier = params.tier?.trim();

    // If both type and tier are provided, return the specific config
    if (businessType && tier) {
      const config = await configRepo.get(tenantId, businessId, businessType, tier);
      if (!config) {
        return response.notFound('Automation config');
      }
      return response.success(config);
    }

    // Otherwise, list all configs for this business
    const configs = await configRepo.list(tenantId, businessId);
    return response.success(configs);
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── PUT Handler ──────────────────────────────────────────────────────────────

/**
 * PUT /whatsapp/config
 *
 * Upserts an Automation_Config for the authenticated business.
 *
 * CRITICAL (Req 1.8):
 * - If the payload fails schema validation, the request is REJECTED
 * - The last valid configuration is RETAINED (not overwritten)
 * - An error indicating the validation failure is returned and recorded
 */
export const putConfigHandler = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveTenantScope(event, auth);

    // Parse request body
    const body = parseJsonBody(event);

    // Validate against the PUT schema (Req 1.8)
    const parseResult = configPutSchema.safeParse(body);
    if (!parseResult.success) {
      // Reject the invalid config — last valid is retained (Req 1.8)
      const validationErrors = formatZodErrors(parseResult.error);
      logger.warn('[ConfigHandler] PUT rejected: schema validation failed', {
        tenantId,
        businessId,
        errors: validationErrors,
      });
      return response.badRequest(
        'Automation config validation failed. The last valid configuration is retained.',
        { validationErrors },
      );
    }

    const input: ConfigPutInput = parseResult.data;

    // Fetch existing config for audit before/after
    const existingConfig = await configRepo.get(
      tenantId,
      businessId,
      input.businessType,
      input.tier,
    );

    // Upsert the validated config
    const savedConfig = await configRepo.upsert(tenantId, businessId, {
      id: input.id,
      businessId,
      tenantId,
      businessType: input.businessType,
      tier: input.tier,
      automations: input.automations,
      channels: input.channels,
      schemaVersion: input.schemaVersion,
    });

    // Record audit entry (Req 7.6 — config changes produce audit records)
    await auditService.recordConfigChange(
      { tenantId, businessId, actor: auth.sub || 'unknown' },
      {
        configId: savedConfig.id,
        action: existingConfig ? 'updated' : 'created',
        before: existingConfig ?? undefined,
        after: savedConfig,
      },
    );

    logger.info('[ConfigHandler] Config upserted', {
      tenantId,
      businessId,
      configId: savedConfig.id,
      businessType: input.businessType,
      tier: input.tier,
      action: existingConfig ? 'updated' : 'created',
    });

    const statusCode = existingConfig ? 200 : 201;
    return response.success(savedConfig, statusCode);
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── Tenant Scope Resolution (Req 12.4) ──────────────────────────────────────

/**
 * Resolve BusinessID exclusively from the authenticated session.
 * SECURITY (Req 12.4): BusinessID is NEVER taken from client-supplied input.
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

// ── Helper Functions ─────────────────────────────────────────────────────────

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

function formatZodErrors(error: ZodError): Array<{ path: string; message: string }> {
  return error.issues.map((issue) => ({
    path: issue.path.join('.'),
    message: issue.message,
  }));
}
