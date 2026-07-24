/**
 * Route Guard — Route-Level Permission Decorator
 *
 * Provides a declarative way to define route-level permission requirements
 * and verify them against TenantContext. Returns non-disclosing errors
 * if denied (no entity existence signal).
 *
 * Usage:
 * ```typescript
 * const guard = routeGuard([MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE]);
 * const result = guard.check(tenantContext);
 * if (!result.authorized) {
 *   return result.response; // Non-disclosing 403
 * }
 * ```
 *
 * Requirements: 6.5–6.6, 8.3–8.7
 */

import { APIGatewayProxyResultV2 } from 'aws-lambda';
import { TenantContext } from './tenant-context';
import { type MobileShopPermission } from '../permissions/mobile-shop-permissions';
import { CANONICAL_BUSINESS_TYPE } from '../schemas/common.schema';

// ─── Guard Result ────────────────────────────────────────────────────────────

export interface GuardResult {
  /** Whether the request is authorized to proceed */
  readonly authorized: boolean;
  /** Non-disclosing error response (only present if not authorized) */
  readonly response?: APIGatewayProxyResultV2;
}

/** Successful guard check */
const AUTHORIZED: GuardResult = { authorized: true };

/** Non-disclosing 403 — reveals nothing about entity existence */
const DENIED: GuardResult = {
  authorized: false,
  response: {
    statusCode: 403,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      error: 'ACCESS_DENIED',
      message: 'Access denied',
    }),
  },
};

// ─── Route Guard ─────────────────────────────────────────────────────────────

export interface RouteGuard {
  /** Required permissions for this guard */
  readonly requiredPermissions: readonly MobileShopPermission[];

  /**
   * Checks whether the given TenantContext satisfies this guard.
   *
   * @param context - Resolved TenantContext (from auth middleware)
   * @returns Guard result indicating authorization status
   */
  check(context: TenantContext): GuardResult;
}

/**
 * Creates a route guard for one or more required permissions.
 *
 * All specified permissions must be present (AND logic).
 * The guard also validates that:
 * - TenantContext exists
 * - Business type is canonical mobile_shop
 * - No null/empty tenant ID
 *
 * Returns a non-disclosing error if any check fails.
 *
 * @param requiredPermissions - Permissions that must ALL be present
 * @returns A RouteGuard instance
 */
export function routeGuard(
  requiredPermissions: readonly MobileShopPermission[],
): RouteGuard {
  return {
    requiredPermissions,
    check(context: TenantContext): GuardResult {
      // Fail closed: context must be present
      if (!context) {
        return DENIED;
      }

      // Fail closed: tenant must be identified
      if (!context.tenantId) {
        return DENIED;
      }

      // Fail closed: must be mobile_shop business type
      if (context.businessType !== CANONICAL_BUSINESS_TYPE) {
        return DENIED;
      }

      // Check all required permissions
      for (const perm of requiredPermissions) {
        if (!context.permissions.has(perm)) {
          return DENIED;
        }
      }

      return AUTHORIZED;
    },
  };
}

/**
 * Creates a route guard that requires ANY of the specified permissions (OR logic).
 *
 * At least one of the specified permissions must be present.
 * Still validates business type and tenant context.
 *
 * @param permissions - Permissions where at least ONE must be present
 * @returns A RouteGuard instance
 */
export function routeGuardAny(
  permissions: readonly MobileShopPermission[],
): RouteGuard {
  return {
    requiredPermissions: permissions,
    check(context: TenantContext): GuardResult {
      // Fail closed: context must be present
      if (!context) {
        return DENIED;
      }

      // Fail closed: tenant must be identified
      if (!context.tenantId) {
        return DENIED;
      }

      // Fail closed: must be mobile_shop business type
      if (context.businessType !== CANONICAL_BUSINESS_TYPE) {
        return DENIED;
      }

      // Check that at least one permission is present
      if (permissions.length === 0) {
        return AUTHORIZED;
      }

      const hasAny = permissions.some((perm) => context.permissions.has(perm));
      if (!hasAny) {
        return DENIED;
      }

      return AUTHORIZED;
    },
  };
}
