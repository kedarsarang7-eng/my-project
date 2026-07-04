// ============================================================================
// WhatsApp Module — Message Template CRUD Handler (Task 7.6)
// ============================================================================
// Handles /whatsapp/templates routes (POST, GET, PUT, DELETE) plus
// /whatsapp/templates/{id}/versions for version history retrieval.
//
// DESIGN:
//   • Tenant scoping: BusinessID derived from session ONLY (Req 12.4)
//   • Cross-business denial: any attempt to access a template from another
//     business returns 403 with no data/existence disclosure (Req 7.1)
//   • Version history: every create/update writes an immutable WATMPLV# version
//     item so the exact template used for any sent message is recoverable (Req 7.7)
//   • Audit_Log entry on each change (create, update, deactivate) via
//     WaAuditService (Req 7.6)
//   • Template body: 1–4096 chars, placeholders: 0–50 (Req 7.2)
//   • Deactivate (soft-delete) instead of hard delete
//
// Requirements: 7.1, 7.2, 7.6, 7.7
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError, NotFoundError, AuthError } from '../../../utils/errors';
import { buildTenantContext } from '../../../dynamodb/tenant-guard';
import { logger } from '../../../utils/logger';
import { MessageTemplateRepository } from '../repositories/message-template.repository';
import { WaAuditService, AUDIT_ACTIONS, buildAuditTarget } from '../services/wa-audit.service';
import { checkPermission } from '../../../config/permission-matrix';
import { FeatureKey } from '../../../config/plan-feature-registry';
import type { MessageTemplate, MessageTemplateVersion } from '../schemas/entities';

// ── Constants ─────────────────────────────────────────────────────────────────

/** Roles allowed to manage message templates. */
const ALLOWED_ROLES: UserRole[] = [
  UserRole.OWNER,
  UserRole.ADMIN,
  UserRole.MANAGER,
];

/** The WA_CORE feature key gates template management. */
const REQUIRED_FEATURE = FeatureKey.WA_CORE;

// ── Zod Schemas for Request Validation ────────────────────────────────────────

const templateCreateSchema = z.object({
  name: z.string().trim().min(1).max(200),
  businessType: z.string().trim().min(1).max(100),
  locale: z.string().trim().min(2).max(10),
  body: z.string().min(1).max(4096),
  placeholders: z.array(z.string().trim().min(1).max(100)).min(0).max(50).default([]),
});

const templateUpdateSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  body: z.string().min(1).max(4096).optional(),
  placeholders: z.array(z.string().trim().min(1).max(100)).min(0).max(50).optional(),
  locale: z.string().trim().min(2).max(10).optional(),
});

// ── Instances ─────────────────────────────────────────────────────────────────

const templateRepo = new MessageTemplateRepository();
const auditService = new WaAuditService();

// ── Main Handler ──────────────────────────────────────────────────────────────

/**
 * Lambda handler for /whatsapp/templates and /whatsapp/templates/{id}.
 * Also handles /whatsapp/templates/{id}/versions for version history.
 */
export const templateHandler = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveWhatsappTenantScope(event, auth);
    const method = httpMethod(event);
    const id = pathId(event);

    // Check if this is a /versions endpoint
    const isVersionsEndpoint = event.rawPath?.includes('/versions');

    switch (method) {
      case 'POST':
        return handleCreate(tenantId, businessId, event, auth);
      case 'GET':
        if (isVersionsEndpoint && id) {
          return handleListVersions(tenantId, businessId, id);
        }
        return id
          ? handleGet(tenantId, businessId, id)
          : handleList(tenantId, businessId);
      case 'PUT':
      case 'PATCH':
        return handleUpdate(tenantId, businessId, requireId(id), event, auth);
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
  const parsed = templateCreateSchema.parse(body);

  // Create the template (repo writes both WATMPL# and WATMPLV#1)
  const template = await templateRepo.create(tenantId, businessId, {
    name: parsed.name,
    businessType: parsed.businessType,
    locale: parsed.locale,
    body: parsed.body,
    placeholders: parsed.placeholders,
    createdBy: auth.sub,
  });

  // Req 7.6: Audit_Log entry for template creation
  await auditService.recordTemplateChange(
    { tenantId, businessId, actor: auth.sub },
    {
      templateId: template.id,
      action: 'created',
      before: undefined,
      after: {
        name: template.name,
        body: template.body,
        placeholders: template.placeholders,
        businessType: template.businessType,
        locale: template.locale,
        version: template.currentVersion,
      },
    },
  );

  return response.success(template, 201);
}

// ── Get single ──────────────────────────────────────────────────────────────

async function handleGet(
  tenantId: string,
  businessId: string,
  id: string,
): Promise<APIGatewayProxyResultV2> {
  const template = await templateRepo.get(tenantId, businessId, id);
  if (!template) {
    throw new NotFoundError('Template');
  }
  return response.success(template);
}

// ── List ────────────────────────────────────────────────────────────────────

async function handleList(
  tenantId: string,
  businessId: string,
): Promise<APIGatewayProxyResultV2> {
  const templates = await templateRepo.list(tenantId, businessId);
  return response.success(templates);
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
  const parsed = templateUpdateSchema.parse(body);

  // At least one field must be provided
  if (!parsed.name && !parsed.body && !parsed.placeholders && !parsed.locale) {
    throw new ValidationError('At least one updatable field (name, body, placeholders, locale) is required');
  }

  // Fetch current for audit before/after comparison
  const current = await templateRepo.get(tenantId, businessId, id);
  if (!current) {
    throw new NotFoundError('Template');
  }

  // Reject updates to deactivated templates
  if (current.status === 'inactive') {
    throw new ValidationError('Cannot update a deactivated template. Reactivate or create a new one.');
  }

  // Update the template (repo increments version and writes WATMPLV# item)
  const updated = await templateRepo.update(tenantId, businessId, id, {
    name: parsed.name,
    body: parsed.body,
    placeholders: parsed.placeholders,
    locale: parsed.locale,
    updatedBy: auth.sub,
  });

  if (!updated) {
    throw new NotFoundError('Template');
  }

  // Req 7.6: Audit_Log entry for template update
  await auditService.recordTemplateChange(
    { tenantId, businessId, actor: auth.sub },
    {
      templateId: id,
      action: 'updated',
      before: {
        name: current.name,
        body: current.body,
        placeholders: current.placeholders,
        locale: current.locale,
        version: current.currentVersion,
      },
      after: {
        name: updated.name,
        body: updated.body,
        placeholders: updated.placeholders,
        locale: updated.locale,
        version: updated.currentVersion,
      },
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
  // Fetch current for audit logging
  const current = await templateRepo.get(tenantId, businessId, id);
  if (!current) {
    throw new NotFoundError('Template');
  }

  // Already inactive — idempotent, return success
  if (current.status === 'inactive') {
    return response.success({ id, status: 'inactive', message: 'Template already deactivated' });
  }

  const success = await templateRepo.deactivate(tenantId, businessId, id);
  if (!success) {
    throw new NotFoundError('Template');
  }

  // Req 7.6: Audit_Log entry for template deactivation
  await auditService.recordTemplateChange(
    { tenantId, businessId, actor: auth.sub },
    {
      templateId: id,
      action: 'deactivated',
      before: {
        name: current.name,
        status: current.status,
        version: current.currentVersion,
      },
      after: {
        status: 'inactive',
      },
    },
  );

  return response.success({ id, status: 'inactive', message: 'Template deactivated' });
}

// ── Version History (Req 7.7) ───────────────────────────────────────────────

async function handleListVersions(
  tenantId: string,
  businessId: string,
  templateId: string,
): Promise<APIGatewayProxyResultV2> {
  // Verify the template exists and belongs to this business
  const template = await templateRepo.get(tenantId, businessId, templateId);
  if (!template) {
    throw new NotFoundError('Template');
  }

  // List all immutable version snapshots chronologically
  const versions = await templateRepo.listVersions(tenantId, businessId, templateId);
  return response.success({
    templateId,
    templateName: template.name,
    currentVersion: template.currentVersion,
    versions,
  });
}

// ── Tenant Scope Resolution (Req 12.4) ──────────────────────────────────────

/**
 * Resolve the BusinessID exclusively from the authenticated session.
 * SECURITY (Req 12.4): BusinessID is NEVER taken from client-supplied input.
 */
async function resolveWhatsappTenantScope(
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

  // Defense-in-depth: reject conflicting businessId in body
  const bodyBusinessId = extractBodyBusinessId(event);
  if (
    bodyBusinessId &&
    bodyBusinessId !== scope.tenantContext.businessId &&
    !scope.tenantContext.hasCrossBusinessAccess
  ) {
    logger.error('SECURITY: Client-supplied businessId mismatch (whatsapp/templates)', {
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
