// ============================================================================
// Staff Module — Tenant Scoping (Task 2.1)
// ============================================================================
// Multi-tenancy isolation foundation shared by EVERY staff handler.
//
// Requirements covered:
//   • 11.1 — every query / API request / stored record is filtered by the
//            authenticated BusinessID (the resolved TenantContext scopes all
//            downstream reads/writes to PK = TENANT#{tenantId}#BIZ#{businessId}).
//   • 11.2 — a request whose token BusinessID (or tenant) differs from the
//            target record's BusinessID/tenant is DENIED (via
//            validateResourceOwnership → 403).
//   • 11.3 — BusinessID is derived from the authenticated session and validated
//            against the JWT tenant; a client-supplied businessId is NEVER
//            treated as authoritative (rejected when it disagrees with scope).
//
// This module deliberately REUSES the platform primitives
// (`buildTenantContext`, `validateResourceOwnership`) rather than
// re-implementing tenant logic — keeping a single source of truth for scoping.
// ============================================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { AuthContext } from '../../../types/tenant.types';
import { TenantContext, BusinessContext } from '../../../dynamodb/types';
import { buildTenantContext, validateResourceOwnership } from '../../../dynamodb/tenant-guard';
import { AuthError, ValidationError } from '../../../utils/errors';
import { logger } from '../../../utils/logger';

/**
 * Resolve the active BusinessID for a staff request.
 *
 * SECURITY (Req 11.3): the BusinessID is taken ONLY from the session-scoped
 * request headers set by the authenticated gateway context, NEVER from the
 * request body or query string. `buildTenantContext` then validates that this
 * business actually belongs to the caller's JWT tenant, so a forged header
 * cannot escalate across tenants.
 */
export function extractStaffBusinessId(event: APIGatewayProxyEventV2): string {
    return (
        event.headers?.['x-active-business'] ||
        event.headers?.['x-business-id'] ||
        event.headers?.['X-Business-Id'] ||
        event.headers?.['x-shop-id'] ||
        ''
    );
}

/**
 * The resolved, validated scope for a staff request. `tenantContext` is what
 * every repository/service call must be scoped by.
 */
export interface StaffTenantScope {
    tenantContext: TenantContext;
    businessContext: BusinessContext | null;
}

/**
 * Read a client-supplied businessId from the request body (if any), without
 * throwing on non-JSON bodies.
 */
function readBodyBusinessId(event: APIGatewayProxyEventV2): string | undefined {
    if (!event.body) return undefined;
    try {
        const parsed = JSON.parse(event.body) as Record<string, unknown>;
        const raw = parsed?.businessId ?? parsed?.business_id;
        return typeof raw === 'string' && raw.trim() !== '' ? raw : undefined;
    } catch {
        // Non-JSON body — nothing to validate here.
        return undefined;
    }
}

/**
 * Resolve and validate the tenant scope for a staff handler.
 *
 * Steps:
 *  1. Derive BusinessID from the session headers only (Req 11.3).
 *  2. Build + validate the TenantContext (business↔tenant ownership, Req 11.1).
 *  3. Defense-in-depth: if the client also supplied a businessId in the body,
 *     it MUST match the session-derived scope (unless the caller legitimately
 *     has cross-business access). A mismatch is treated as a client trying to
 *     assert an authoritative BusinessID and is rejected (Req 11.2, 11.3).
 *
 * @throws AuthError(401) when session/business identifiers are missing.
 * @throws AuthError(403) when a client-supplied businessId contradicts scope.
 */
export async function resolveStaffTenantScope(
    event: APIGatewayProxyEventV2,
    auth: AuthContext,
): Promise<StaffTenantScope> {
    const businessId = extractStaffBusinessId(event);

    let scope: StaffTenantScope;
    try {
        scope = await buildTenantContext(auth, businessId);
    } catch (err) {
        // buildTenantContext throws plain Errors — translate to typed auth errors
        // so the handler wrapper returns a clean 401/403 without leaking internals.
        const message = (err as Error).message || 'Tenant scope resolution failed';
        if (message.startsWith('BUSINESS_MISSING') || message.startsWith('TENANT_MISSING')) {
            throw new AuthError('Authenticated business context is required');
        }
        // BUSINESS_NOT_FOUND / HORIZONTAL_ESCALATION → cross-tenant denial.
        throw new AuthError('Cross-tenant access denied — this incident has been logged', 403);
    }

    // Req 11.3 — the client cannot assert an authoritative BusinessID via body.
    const bodyBusinessId = readBodyBusinessId(event);
    if (
        bodyBusinessId &&
        bodyBusinessId !== scope.tenantContext.businessId &&
        !scope.tenantContext.hasCrossBusinessAccess
    ) {
        logger.error('SECURITY: Client-supplied businessId mismatch (staff)', {
            userId: scope.tenantContext.userId,
            tenantId: scope.tenantContext.tenantId,
            sessionBusinessId: scope.tenantContext.businessId,
            bodyBusinessId,
            path: event.rawPath,
        });
        throw new AuthError('Cross-business access denied — this incident has been logged', 403);
    }

    return scope;
}

/**
 * Assert that a target record belongs to the caller's tenant + business scope
 * BEFORE it is read or mutated. Prevents IDOR / cross-tenant / cross-business
 * access (Req 11.1, 11.2).
 *
 * @throws AuthError(403) when the record is outside the caller's scope.
 */
export function assertStaffResourceScope(
    tenantContext: TenantContext,
    resourceTenantId: string,
    resourceBusinessId: string,
): void {
    const check = validateResourceOwnership(resourceTenantId, resourceBusinessId, tenantContext);
    if (!check.valid) {
        logger.error('SECURITY: Staff resource ownership violation', {
            userId: tenantContext.userId,
            callerTenantId: tenantContext.tenantId,
            callerBusinessId: tenantContext.businessId,
            resourceTenantId,
            resourceBusinessId,
            reason: check.error,
        });
        throw new AuthError('Access denied — resource does not belong to your business', 403);
    }
}

/**
 * Require a non-empty path/route identifier (small ergonomics helper reused by
 * staff handlers that operate on a single record).
 *
 * @throws ValidationError(400) when the id is missing/blank.
 */
export function requirePathId(id: string | undefined, name = 'id'): string {
    if (!id || id.trim() === '') {
        throw new ValidationError(`Path parameter '${name}' is required`);
    }
    return id;
}
