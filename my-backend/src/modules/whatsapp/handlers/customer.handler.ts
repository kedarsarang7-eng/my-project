// ============================================================================
// WhatsApp Module — Customer Profile CRUD Handler (Task 6.1)
// ============================================================================
// Handles /whatsapp/customers routes (POST, GET, PUT, PATCH) with:
//   • Tenant scoping (BusinessID from session ONLY — never client input, Req 12.4)
//   • E.164 validation on save (Req 2.1, 2.2)
//   • Consent_State defaults to 'pending' on create (Req 2.4)
//   • Audit logging on consent state changes (Req 2.7)
//   • RBAC gate: users without WA permission cannot see WhatsApp numbers
//     or message content (Req 13.3, 13.4)
//
// Requirements: 2.1, 2.2, 2.3, 2.4, 2.7, 2.8, 2.9, 12.4, 13.3, 13.4
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError, NotFoundError, AuthError } from '../../../utils/errors';
import { buildTenantContext } from '../../../dynamodb/tenant-guard';
import { logger } from '../../../utils/logger';
import { CustomerProfileRepository } from '../repositories/customer-profile.repository';
import { validateE164 } from '../services/phone.service';
import { WaAuditService, AUDIT_ACTIONS, buildAuditTarget } from '../services/wa-audit.service';
import { checkPermission } from '../../../config/permission-matrix';
import { FeatureKey } from '../../../config/plan-feature-registry';
import type { ConsentState, CustomerProfile } from '../schemas/entities';
import { consentStateSchema, e164PhoneSchema } from '../schemas/entities';

// ── Constants ─────────────────────────────────────────────────────────────────

/** Roles allowed to manage customer profiles. */
const ALLOWED_ROLES: UserRole[] = [
  UserRole.OWNER,
  UserRole.ADMIN,
  UserRole.MANAGER,
];

/** The WA_CORE feature key gates customer profile access. */
const REQUIRED_FEATURE = FeatureKey.WA_CORE;

// ── Zod Schemas for Request Validation ────────────────────────────────────────

const customerCreateSchema = z.object({
  customerId: z.string().trim().min(1).max(128).optional(),
  whatsappNumber: z.string().trim().min(1),
  consentState: consentStateSchema.optional(),
  locale: z.string().trim().min(2).max(10).optional(),
  messagingPreferences: z.object({
    quietHoursStart: z.string().trim().max(10).optional(),
    quietHoursEnd: z.string().trim().max(10).optional(),
    preferredTime: z.string().trim().max(10).optional(),
  }).optional(),
});

const customerUpdateSchema = z.object({
  whatsappNumber: z.string().trim().min(1).optional(),
  consentState: consentStateSchema.optional(),
  locale: z.string().trim().min(2).max(10).optional(),
  messagingPreferences: z.object({
    quietHoursStart: z.string().trim().max(10).optional(),
    quietHoursEnd: z.string().trim().max(10).optional(),
    preferredTime: z.string().trim().max(10).optional(),
  }).optional(),
});

const consentUpdateSchema = z.object({
  consentState: consentStateSchema,
});

// ── Instances ─────────────────────────────────────────────────────────────────

const customerRepo = new CustomerProfileRepository();
const auditService = new WaAuditService();

// ── Main Handler ──────────────────────────────────────────────────────────────

/**
 * Lambda handler for /whatsapp/customers and /whatsapp/customers/{id}.
 * Also handles /whatsapp/customers/{id}/consent for consent-specific updates.
 */
export const customerHandler = authorizedHandler(
  ALLOWED_ROLES,
  async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
    auth: AuthContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const { tenantId, businessId } = await resolveWhatsappTenantScope(event, auth);
    const method = httpMethod(event);
    const id = pathId(event);

    // Check if this is a consent-specific endpoint
    const isConsentEndpoint = event.rawPath?.includes('/consent');

    switch (method) {
      case 'POST':
        if (isConsentEndpoint && id) {
          return handleSetConsent(tenantId, businessId, id, event, auth);
        }
        return handleCreate(tenantId, businessId, event, auth);
      case 'GET':
        return id
          ? handleGet(tenantId, businessId, id, auth)
          : handleList(tenantId, businessId, auth);
      case 'PUT':
      case 'PATCH':
        if (isConsentEndpoint && id) {
          return handleSetConsent(tenantId, businessId, id, event, auth);
        }
        return handleUpdate(tenantId, businessId, requireId(id), event, auth);
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
  const parsed = customerCreateSchema.parse(body);

  // Req 2.1, 2.2: Validate E.164 format — reject save if invalid
  const phoneValidation = validateE164(parsed.whatsappNumber);
  if (!phoneValidation.valid) {
    throw new ValidationError(
      `WhatsApp number is not valid E.164: ${phoneValidation.error}`,
    );
  }

  // Req 2.4: Consent defaults to 'pending' if not explicitly provided
  const customer = await customerRepo.create(tenantId, businessId, {
    customerId: parsed.customerId,
    whatsappNumber: phoneValidation.normalized!,
    consentState: parsed.consentState, // repo defaults to 'pending' if undefined
    locale: parsed.locale,
    messagingPreferences: parsed.messagingPreferences,
  });

  // Req 2.7: Audit log if consent was explicitly set (not default)
  if (parsed.consentState && parsed.consentState !== 'pending') {
    await auditService.recordConsentChange(
      { tenantId, businessId, actor: auth.sub },
      {
        customerId: customer.id,
        previousState: 'pending',
        newState: parsed.consentState,
        source: 'api_create',
      },
    );
  }

  // Apply RBAC gate before returning (Req 13.3, 13.4)
  const sanitized = applyRbacGate(customer, auth);
  return response.success(sanitized, 201);
}

// ── Get single ──────────────────────────────────────────────────────────────

async function handleGet(
  tenantId: string,
  businessId: string,
  id: string,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  const customer = await customerRepo.get(tenantId, businessId, id);
  if (!customer) {
    throw new NotFoundError('Customer');
  }

  // Apply RBAC gate (Req 13.3, 13.4)
  const sanitized = applyRbacGate(customer, auth);
  return response.success(sanitized);
}

// ── List ────────────────────────────────────────────────────────────────────

async function handleList(
  tenantId: string,
  businessId: string,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  const customers = await customerRepo.list(tenantId, businessId);

  // Apply RBAC gate to each customer (Req 13.3, 13.4)
  const sanitized = customers.map((c) => applyRbacGate(c, auth));
  return response.success(sanitized);
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
  const parsed = customerUpdateSchema.parse(body);

  // Req 2.1, 2.2: Validate E.164 if whatsappNumber is being updated
  if (parsed.whatsappNumber) {
    const phoneValidation = validateE164(parsed.whatsappNumber);
    if (!phoneValidation.valid) {
      throw new ValidationError(
        `WhatsApp number is not valid E.164: ${phoneValidation.error}`,
      );
    }
    parsed.whatsappNumber = phoneValidation.normalized!;
  }

  // Fetch current profile for consent audit comparison
  const current = await customerRepo.get(tenantId, businessId, id);
  if (!current) {
    throw new NotFoundError('Customer');
  }

  // Build update fields
  const updateFields: Record<string, unknown> = {};
  if (parsed.whatsappNumber !== undefined) updateFields.whatsappNumber = parsed.whatsappNumber;
  if (parsed.consentState !== undefined) updateFields.consentState = parsed.consentState;
  if (parsed.locale !== undefined) updateFields.locale = parsed.locale;
  if (parsed.messagingPreferences !== undefined) updateFields.messagingPreferences = parsed.messagingPreferences;

  if (Object.keys(updateFields).length === 0) {
    throw new ValidationError('No updatable fields provided');
  }

  const updated = await customerRepo.update(tenantId, businessId, id, updateFields);
  if (!updated) {
    throw new NotFoundError('Customer');
  }

  // Req 2.7: Audit log on consent state change
  if (parsed.consentState && parsed.consentState !== current.consentState) {
    await auditService.recordConsentChange(
      { tenantId, businessId, actor: auth.sub },
      {
        customerId: id,
        previousState: current.consentState,
        newState: parsed.consentState,
        source: 'api_update',
      },
    );
  }

  // Apply RBAC gate (Req 13.3, 13.4)
  const sanitized = applyRbacGate(updated, auth);
  return response.success(sanitized);
}

// ── Set Consent (dedicated endpoint) ────────────────────────────────────────

async function handleSetConsent(
  tenantId: string,
  businessId: string,
  id: string,
  event: APIGatewayProxyEventV2,
  auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
  const body = parseJsonBody(event);
  const parsed = consentUpdateSchema.parse(body);

  // Fetch current profile
  const current = await customerRepo.get(tenantId, businessId, id);
  if (!current) {
    throw new NotFoundError('Customer');
  }

  // No-op if consent hasn't changed
  if (current.consentState === parsed.consentState) {
    const sanitized = applyRbacGate(current, auth);
    return response.success(sanitized);
  }

  const updated = await customerRepo.setConsentState(
    tenantId,
    businessId,
    id,
    parsed.consentState,
  );
  if (!updated) {
    throw new NotFoundError('Customer');
  }

  // Req 2.7: Audit log for consent state change
  await auditService.recordConsentChange(
    { tenantId, businessId, actor: auth.sub },
    {
      customerId: id,
      previousState: current.consentState,
      newState: parsed.consentState,
      source: 'api_consent',
    },
  );

  // Apply RBAC gate (Req 13.3, 13.4)
  const sanitized = applyRbacGate(updated, auth);
  return response.success(sanitized);
}

// ── RBAC Gate (Req 13.3, 13.4) ──────────────────────────────────────────────

/**
 * Applies the RBAC gate that withholds WhatsApp numbers and message content
 * from users who do not have the WA_CORE permission.
 *
 * Users without the WhatsApp feature permission see a redacted profile:
 * - whatsappNumber is replaced with a masked version (e.g., "+91****3210")
 * - Only non-sensitive fields are exposed
 *
 * This ensures that even if the endpoint is reachable, sensitive WhatsApp
 * data is not disclosed to unauthorized roles (Req 13.3, 13.4).
 */
export function applyRbacGate(
  customer: CustomerProfile,
  auth: AuthContext,
): Record<string, unknown> {
  const hasWhatsappPermission = checkWhatsappReadPermission(auth);

  const base: Record<string, unknown> = {
    id: customer.id,
    businessId: customer.businessId,
    consentState: customer.consentState,
    locale: customer.locale,
    messagingPreferences: customer.messagingPreferences,
    eligible: customer.eligible,
    createdAt: customer.createdAt,
    updatedAt: customer.updatedAt,
  };

  if (hasWhatsappPermission) {
    // Full access: include WhatsApp number
    base.whatsappNumber = customer.whatsappNumber;
  } else {
    // RBAC gate: mask the WhatsApp number (Req 13.3)
    base.whatsappNumber = maskPhoneNumber(customer.whatsappNumber);
    base._redacted = ['whatsappNumber'];
  }

  return base;
}

/**
 * Check whether the authenticated user has permission to view WhatsApp
 * numbers and message content. Uses fail-closed logic: if the check
 * cannot determine permission, access is denied.
 */
export function checkWhatsappReadPermission(auth: AuthContext): boolean {
  // Owner and Admin always have access
  if (auth.role === UserRole.OWNER || auth.role === UserRole.ADMIN) {
    return true;
  }

  // Manager has access (included in ALLOWED_ROLES and has WA_CORE)
  if (auth.role === UserRole.MANAGER) {
    return true;
  }

  // For other roles: check if their plan includes WA_CORE and role is sufficient
  const planTier = auth.planTier || 'basic';
  const result = checkPermission(REQUIRED_FEATURE, auth.role, planTier);
  return result.allowed;
}

/**
 * Masks a phone number for display to unauthorized users.
 * Shows country code + first digit + masked middle + last 4 digits.
 * Example: "+919876543210" → "+91****3210"
 */
export function maskPhoneNumber(number: string): string {
  if (!number || number.length < 8) return '****';
  // Keep first 3 chars (+ and country code start) and last 4
  const prefix = number.slice(0, 3);
  const suffix = number.slice(-4);
  return `${prefix}****${suffix}`;
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
    logger.error('SECURITY: Client-supplied businessId mismatch (whatsapp/customers)', {
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
