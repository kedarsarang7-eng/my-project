// ============================================================================
// WhatsApp Module — Automation Rule CRUD Handler (Task 8.1)
// ============================================================================
// Handles /whatsapp/rules routes (POST, GET, PUT, PATCH) with:
//   • Tenant scoping (BusinessID from session ONLY — never client input, Req 12.4)
//   • CRUD + enable/disable for Automation_Rules (Req 7.5)
//   • Cross-business denial: reject operations targeting another BusinessID with
//     an authorization error and no data disclosure (Req 7.5)
//   • Audit_Log entries on create/update/enable/disable (Req 7.6)
//   • Input validation using Zod schemas
//
// Requirements: 7.5, 7.6
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError, AuthError } from '../../../utils/errors';
import { buildTenantContext } from '../../../dynamodb/tenant-guard';
import { logger } from '../../../utils/logger';
import { AutomationRuleRepository } from '../repositories/automation-rule.repository';
import { WaAuditService } from '../services/wa-audit.service';
import { FeatureKey } from '../../../config/plan-feature-registry';
import type { AutomationRule } from '../schemas/entities';
import { idRefSchema, messageCategorySchema } from '../schemas/entities';

// ── Constants ─────────────────────────────────────────────────────────────────

/** Roles allowed to manage automation rules. */
const ALLOWED_ROLES: UserRole[] = [
  UserRole.OWNER,
  UserRole.ADMIN,
  UserRole.MANAGER,
];

/** The WA_AUTOMATION feature key gates rule management access. */
const REQUIRED_FEATURE = FeatureKey.WA_AUTOMATION;

// ── Zod Schemas for Request Validation ────────────────────────────────────────

const ruleConditionSchema = z.object({
  field: z.string().trim().min(1).max(200),
  operator: z.enum(['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'in', 'not_in', 'exists', 'not_exists']),
  value: z.unknown().optional(),
});

const recipientSpecSchema = z.object({
  type: z.enum(['customer', 'supplier', 'staff', 'segment']),
  id: idRefSchema.optional(),
  segmentFilter: z.record(z.string(), z.unknown()).optional(),
});

const scheduleSchema = z.object({
  delaySeconds: z.number().int().min(1).max(31536000).optional(), // 1s..365d
  at: z.string().trim().min(1).refine((v) => !isNaN(Date.parse(v)), {
    message: 'must be a valid ISO-8601 timestamp',
  }).optional(),
});

const ruleCreateSchema = z.object({
  branchId: idRefSchema.optional(),
  eventType: z.string().trim().min(1).max(200),
  conditions: z.array(ruleConditionSchema).default([]),
  templateId: idRefSchema,
  recipients: recipientSpecSchema,
  schedule: scheduleSchema.optional(),
  category: messageCategorySchema,
  maxReminders: z.number().int().min(1).max(100).optional(),
  enabled: z.boolean().default(true),
});

const ruleUpdateSchema = z.object({
  branchId: idRefSchema.optional(),
  eventType: z.string().trim().min(1).max(200).optional(),
  conditions: z.array(ruleConditionSchema).optional(),
  templateId: idRefSchema.optional(),
  recipients: recipientSpecSchema.optional(),
  schedule: scheduleSchema.optional(),
  category: messageCategorySchema.optional(),
  maxReminders: z.number().int().min(1).max(100).optional(),
  enabled: z.boolean().optional(),
});

const ruleToggleSchema = z.object({
  enabled: z.boolean(),
});

// ── Instances ─────────────────────────────────────────────────────────────────

const ruleRepo = new AutomationRuleRepository();
const auditService = new WaAuditService();

// ── Main Handler ──────────────────────────────────────────────────────────────

/**
 * Lambda handler for /whatsapp/rules and /whatsapp/rules/{id}.
 * Also handles /whatsapp/rules/{id}/enable and /whatsapp/rules/{id}/disable
 * for toggle operations.
 */
export const ruleHandler = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveWhatsappTenantScope(event, auth);
    const method = httpMethod(event);
    const id = pathId(event);

    // Detect toggle endpoints: /rules/{id}/enable or /rules/{id}/disable
    const isEnableEndpoint = event.rawPath?.endsWith('/enable');
    const isDisableEndpoint = event.rawPath?.endsWith('/disable');

    switch (method) {
      case 'POST':
        if (isEnableEndpoint && id) {
          return handleEnable(tenantId, businessId, id, auth);
        }
        if (isDisableEndpoint && id) {
          return handleDisable(tenantId, businessId, id, auth);
        }
        return handleCreate(tenantId, businessId, event, auth);
      case 'GET':
        return id
          ? handleGet(tenantId, businessId, id)
          : handleList(tenantId, businessId);
      case 'PUT':
        return handleUpdate(tenantId, businessId, requireId(id), event, auth);
      case 'PATCH':
        // PATCH can be used for toggle or partial update
        if (id && (isEnableEndpoint || isDisableEndpoint)) {
          return isEnableEndpoint
            ? handleEnable(tenantId, businessId, id, auth)
            : handleDisable(tenantId, businessId, id, auth);
        }
        return handleToggle(tenantId, businessId, requireId(id), event, auth);
      case 'DELETE':
        return handleDeactivate(tenantId, businessId, requireId(id), auth);
      default:
        return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed`);
    }
  },
  { requiredFeature: REQUIRED_FEATURE },
);

// ── Create ──────────────────────────────────────────────────────────────────

async function handleCreate(
  tenantId: string,
  businessId: string,
  event: APIGatewayProxyEventV2,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  const body = parseJsonBody(event);
  const parsed = ruleCreateSchema.parse(body);

  const rule = await ruleRepo.create(tenantId, businessId, {
    branchId: parsed.branchId,
    eventType: parsed.eventType,
    conditions: parsed.conditions,
    templateId: parsed.templateId,
    recipients: parsed.recipients,
    schedule: parsed.schedule,
    category: parsed.category,
    maxReminders: parsed.maxReminders,
    enabled: parsed.enabled,
  });

  // Req 7.6: Audit log on rule creation
  await auditService.recordRuleChange(
    { tenantId, businessId, actor: auth.sub },
    {
      ruleId: rule.id,
      action: 'created',
      before: undefined,
      after: rule,
    },
  );

  return response.success(rule, 201);
}

// ── Get single ──────────────────────────────────────────────────────────────

async function handleGet(
  tenantId: string,
  businessId: string,
  id: string,
): Promise<APIGatewayProxyResultV2> {
  const rule = await ruleRepo.get(tenantId, businessId, id);

  // Req 7.5: Cross-business denial — if rule not found under this business,
  // return authorization error with no data disclosure.
  if (!rule) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  return response.success(rule);
}

// ── List ────────────────────────────────────────────────────────────────────

async function handleList(
  tenantId: string,
  businessId: string,
): Promise<APIGatewayProxyResultV2> {
  const rules = await ruleRepo.list(tenantId, businessId);
  return response.success(rules);
}

// ── Update ──────────────────────────────────────────────────────────────────

async function handleUpdate(
  tenantId: string,
  businessId: string,
  id: string,
  event: APIGatewayProxyEventV2,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  const body = parseJsonBody(event);
  const parsed = ruleUpdateSchema.parse(body);

  // Fetch the current rule to confirm it belongs to this business
  const current = await ruleRepo.get(tenantId, businessId, id);

  // Req 7.5: Cross-business denial — reject if not found under this business
  if (!current) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // Build update fields
  const updateFields: Record<string, unknown> = {};
  if (parsed.branchId !== undefined) updateFields.branchId = parsed.branchId;
  if (parsed.eventType !== undefined) updateFields.eventType = parsed.eventType;
  if (parsed.conditions !== undefined) updateFields.conditions = parsed.conditions;
  if (parsed.templateId !== undefined) updateFields.templateId = parsed.templateId;
  if (parsed.recipients !== undefined) updateFields.recipients = parsed.recipients;
  if (parsed.schedule !== undefined) updateFields.schedule = parsed.schedule;
  if (parsed.category !== undefined) updateFields.category = parsed.category;
  if (parsed.maxReminders !== undefined) updateFields.maxReminders = parsed.maxReminders;
  if (parsed.enabled !== undefined) updateFields.enabled = parsed.enabled;

  if (Object.keys(updateFields).length === 0) {
    throw new ValidationError('No updatable fields provided');
  }

  const updated = await ruleRepo.update(tenantId, businessId, id, updateFields);
  if (!updated) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // Req 7.6: Audit log on rule update
  // Determine if this is an enable/disable action or a general update
  const auditAction = determineAuditAction(current, parsed);
  await auditService.recordRuleChange(
    { tenantId, businessId, actor: auth.sub },
    {
      ruleId: id,
      action: auditAction,
      before: current,
      after: updated,
    },
  );

  return response.success(updated);
}

// ── Toggle (PATCH with {enabled: boolean}) ──────────────────────────────────

async function handleToggle(
  tenantId: string,
  businessId: string,
  id: string,
  event: APIGatewayProxyEventV2,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  const body = parseJsonBody(event);
  const parsed = ruleToggleSchema.parse(body);

  // Fetch current rule to verify ownership
  const current = await ruleRepo.get(tenantId, businessId, id);

  // Req 7.5: Cross-business denial
  if (!current) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // No-op if state unchanged
  if (current.enabled === parsed.enabled) {
    return response.success(current);
  }

  const updated = await ruleRepo.setEnabled(tenantId, businessId, id, parsed.enabled);
  if (!updated) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // Req 7.6: Audit log on enable/disable
  await auditService.recordRuleChange(
    { tenantId, businessId, actor: auth.sub },
    {
      ruleId: id,
      action: parsed.enabled ? 'enabled' : 'disabled',
      before: { enabled: current.enabled },
      after: { enabled: parsed.enabled },
    },
  );

  return response.success(updated);
}

// ── Enable ──────────────────────────────────────────────────────────────────

async function handleEnable(
  tenantId: string,
  businessId: string,
  id: string,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  // Fetch current rule to verify ownership
  const current = await ruleRepo.get(tenantId, businessId, id);

  // Req 7.5: Cross-business denial
  if (!current) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // No-op if already enabled
  if (current.enabled) {
    return response.success(current);
  }

  const updated = await ruleRepo.setEnabled(tenantId, businessId, id, true);
  if (!updated) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // Req 7.6: Audit log on enable
  await auditService.recordRuleChange(
    { tenantId, businessId, actor: auth.sub },
    {
      ruleId: id,
      action: 'enabled',
      before: { enabled: false },
      after: { enabled: true },
    },
  );

  return response.success(updated);
}

// ── Disable ─────────────────────────────────────────────────────────────────

async function handleDisable(
  tenantId: string,
  businessId: string,
  id: string,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  // Fetch current rule to verify ownership
  const current = await ruleRepo.get(tenantId, businessId, id);

  // Req 7.5: Cross-business denial
  if (!current) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // No-op if already disabled
  if (!current.enabled) {
    return response.success(current);
  }

  const updated = await ruleRepo.setEnabled(tenantId, businessId, id, false);
  if (!updated) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // Req 7.6: Audit log on disable
  await auditService.recordRuleChange(
    { tenantId, businessId, actor: auth.sub },
    {
      ruleId: id,
      action: 'disabled',
      before: { enabled: true },
      after: { enabled: false },
    },
  );

  return response.success(updated);
}

// ── Deactivate (soft-delete) ────────────────────────────────────────────────

async function handleDeactivate(
  tenantId: string,
  businessId: string,
  id: string,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  // Fetch current rule to verify ownership
  const current = await ruleRepo.get(tenantId, businessId, id);

  // Req 7.5: Cross-business denial
  if (!current) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  const success = await ruleRepo.deactivate(tenantId, businessId, id);
  if (!success) {
    throw new AuthError(
      'The requested resource is not accessible',
      403,
    );
  }

  // Req 7.6: Audit log on deactivation (treated as disable)
  await auditService.recordRuleChange(
    { tenantId, businessId, actor: auth.sub },
    {
      ruleId: id,
      action: 'disabled',
      before: current,
      after: { ...current, enabled: false, isDeleted: true },
    },
  );

  return response.success({ id, deactivated: true });
}

// ── Audit Action Determination ──────────────────────────────────────────────

/**
 * Determines the appropriate audit action based on what changed.
 * If only 'enabled' changed, record it as enable/disable; otherwise 'updated'.
 */
function determineAuditAction(
  current: AutomationRule,
  update: Record<string, unknown>,
): 'created' | 'updated' | 'enabled' | 'disabled' {
  const keys = Object.keys(update).filter((k) => update[k] !== undefined);

  // If the only meaningful change is 'enabled', record as enable/disable
  if (keys.length === 1 && keys[0] === 'enabled') {
    return update.enabled ? 'enabled' : 'disabled';
  }

  // If 'enabled' changed along with other fields, still track as 'updated'
  return 'updated';
}

// ── Tenant Scope Resolution (Req 12.4) ──────────────────────────────────────

/**
 * Resolve the BusinessID exclusively from the authenticated session.
 * SECURITY (Req 12.4): BusinessID is NEVER taken from client-supplied input.
 * It comes only from the session headers set by the authenticated gateway.
 */
async function resolveWhatsappTenantScope(
  event: APIGatewayProxyEventV2,
  auth: AuthContext,
): Promise<{ tenantId: string; businessId: string }> {
  // Extract BusinessID from session headers only (Req 12.4)
  const businessId =
    event.headers?.['x-active-business'] ||
    event.headers?.['x-business-id'] ||
    event.headers?.['X-Business-Id'] ||
    event.headers?.['x-shop-id'] ||
    '';

  if (!businessId || businessId.trim() === '') {
    throw new AuthError('Authenticated business context is required');
  }

  // Validate business belongs to the authenticated tenant
  const scope = await buildTenantContext(auth, businessId);

  // Defense-in-depth: reject if client supplied a conflicting businessId in body
  const bodyBusinessId = extractBodyBusinessId(event);
  if (
    bodyBusinessId &&
    bodyBusinessId !== scope.tenantContext.businessId &&
    !scope.tenantContext.hasCrossBusinessAccess
  ) {
    logger.error('SECURITY: Client-supplied businessId mismatch (whatsapp/rules)', {
      userId: auth.sub,
      tenantId: auth.tenantId,
      sessionBusinessId: scope.tenantContext.businessId,
      bodyBusinessId,
      path: event.rawPath,
    });
    throw new AuthError('Cross-business access denied — this incident has been logged', 403);
  }

  return {
    tenantId: scope.tenantContext.tenantId,
    businessId: scope.tenantContext.businessId,
  };
}

// ── HTTP Helpers ─────────────────────────────────────────────────────────────

function httpMethod(event: APIGatewayProxyEventV2): string {
  return (event.requestContext?.http?.method || 'GET').toUpperCase();
}

function pathId(event: APIGatewayProxyEventV2): string | undefined {
  return event.pathParameters?.id;
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

function requireId(id: string | undefined): string {
  if (!id || id.trim() === '') {
    throw new ValidationError("Path parameter 'id' is required");
  }
  return id;
}

function extractBodyBusinessId(event: APIGatewayProxyEventV2): string | undefined {
  if (!event.body) return undefined;
  try {
    const parsed = JSON.parse(event.body) as Record<string, unknown>;
    const raw = parsed?.businessId ?? parsed?.business_id;
    return typeof raw === 'string' && raw.trim() !== '' ? raw : undefined;
  } catch {
    return undefined;
  }
}
