// ============================================================================
// Tenant Guard — Lambda-Native Multi-Tenant Context Resolver
// ============================================================================
// Extracts TenantContext from my-backend's AuthContext.
// Used by v1-* handlers to bridge my-backend's auth system with
// app-backend's service layer (which expects TenantContext).
// ============================================================================

import { AuthContext } from '../types/tenant.types';
import { TenantContext, OWNER_ROLES, UserRole } from './types';
import { getItem } from './client';
import { tenantPK, businessSK, businessPK } from './keys';
import { BusinessContext } from './types';
import { logger } from '../utils/logger';

/**
 * Build TenantContext from my-backend's AuthContext + business headers.
 *
 * my-backend's verifyAuth() gives us AuthContext (sub, tenantId, role, etc).
 * v1 services need TenantContext (same data + businessId + isOwner flags).
 *
 * @param auth - AuthContext from verifyAuth()
 * @param businessId - x-business-id or x-active-business header
 */
export async function buildTenantContext(
  auth: AuthContext,
  businessId: string,
): Promise<{ tenantContext: TenantContext; businessContext: BusinessContext | null }> {
  if (!auth.tenantId) {
    throw new Error('TENANT_MISSING: No tenant_id in JWT claims');
  }
  if (!businessId || businessId.trim() === '') {
    throw new Error('BUSINESS_MISSING: No business_id specified');
  }

  const role = (auth.role || 'staff') as UserRole;
  const isOwner = OWNER_ROLES.has(role);

  // Validate business belongs to tenant
  const business = await getItem<BusinessContext>(
    tenantPK(auth.tenantId),
    businessSK(businessId),
    { consistentRead: true },
  );

  if (!business) {
    logger.error('SECURITY: Business-tenant mismatch', {
      userId: auth.sub,
      tenantId: auth.tenantId,
      businessId,
    });
    throw new Error('BUSINESS_NOT_FOUND: Business not found or wrong tenant');
  }

  if (business.tenantId !== auth.tenantId) {
    logger.error('SECURITY: Horizontal privilege escalation attempt', {
      userId: auth.sub,
      claimedTenantId: auth.tenantId,
      actualTenantId: business.tenantId,
      businessId,
    });
    throw new Error('HORIZONTAL_ESCALATION: Cross-tenant access denied');
  }

  const tenantContext: TenantContext = {
    userId: auth.sub,
    tenantId: auth.tenantId,
    businessId,
    role,
    email: auth.email,
    groups: [],
    isOwner,
    hasCrossBusinessAccess: isOwner,
  };

  return { tenantContext, businessContext: business };
}

/**
 * Validate resource ownership — prevents IDOR attacks.
 */
export function validateResourceOwnership(
  tenantId: string,
  resourceBusinessId: string,
  ctx: TenantContext,
): { valid: boolean; error?: string } {
  if (tenantId !== ctx.tenantId) {
    return {
      valid: false,
      error: `SECURITY: Cross-tenant access attempt. Resource tenant=${tenantId}, caller tenant=${ctx.tenantId}`,
    };
  }
  if (!ctx.hasCrossBusinessAccess && resourceBusinessId !== ctx.businessId) {
    return {
      valid: false,
      error: `SECURITY: Cross-business access attempt. Resource business=${resourceBusinessId}, caller business=${ctx.businessId}`,
    };
  }
  return { valid: true };
}
