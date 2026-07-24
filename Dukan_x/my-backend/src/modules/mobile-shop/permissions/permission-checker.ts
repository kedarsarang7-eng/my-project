/**
 * MobileShop Permission Checker
 *
 * Utility for checking whether a TenantContext has a specific MobileShop
 * permission. Respects manage-implies-view semantics and expands
 * permission implications before checking.
 *
 * Requirements: 8.1–8.2, 8.5–8.7
 */

import {
  type MobileShopPermission,
  PERMISSION_IMPLICATIONS,
  ALL_MOBILE_SHOP_PERMISSIONS,
  expandPermissions,
} from './mobile-shop-permissions';

// ─── TenantContext Interface (Backend) ───────────────────────────────────────

/**
 * Minimal TenantContext shape required for permission checking.
 * Matches the backend TenantContext resolved from auth middleware.
 */
export interface PermissionContext {
  readonly tenantId: string;
  readonly businessType: string;
  readonly permissions: readonly string[];
}

// ─── Permission Check Result ─────────────────────────────────────────────────

export interface PermissionCheckResult {
  /** Whether the permission is granted */
  readonly granted: boolean;
  /** Reason for denial (undefined if granted) */
  readonly reason?: string;
}

// ─── Permission Checker ──────────────────────────────────────────────────────

/**
 * Checks whether the given context has a specific MobileShop permission.
 *
 * This checker:
 * 1. Validates the business type is `mobile_shop`
 * 2. Expands permissions (manage implies view)
 * 3. Checks the required permission against the expanded set
 *
 * @param context - The tenant/permission context
 * @param required - The permission to check
 * @returns Whether the permission is granted
 */
export function checkMobileShopPermission(
  context: PermissionContext,
  required: MobileShopPermission,
): PermissionCheckResult {
  // Business type must be mobile_shop
  if (context.businessType !== 'mobile_shop') {
    return {
      granted: false,
      reason: 'Business type is not mobile_shop',
    };
  }

  // Expand permissions with implications (manage implies view)
  const effective = expandPermissions(new Set(context.permissions));

  if (effective.has(required)) {
    return { granted: true };
  }

  return {
    granted: false,
    reason: `Missing required permission: ${required}`,
  };
}

/**
 * Checks whether the context has ALL of the specified permissions.
 *
 * @param context - The tenant/permission context
 * @param required - Array of permissions that must all be present
 * @returns Whether all permissions are granted
 */
export function checkAllPermissions(
  context: PermissionContext,
  required: readonly MobileShopPermission[],
): PermissionCheckResult {
  if (context.businessType !== 'mobile_shop') {
    return {
      granted: false,
      reason: 'Business type is not mobile_shop',
    };
  }

  const effective = expandPermissions(new Set(context.permissions));

  const missing = required.filter(p => !effective.has(p));
  if (missing.length === 0) {
    return { granted: true };
  }

  return {
    granted: false,
    reason: `Missing required permissions: ${missing.join(', ')}`,
  };
}

/**
 * Checks whether the context has ANY of the specified permissions.
 *
 * @param context - The tenant/permission context
 * @param required - Array of permissions where at least one must be present
 * @returns Whether at least one permission is granted
 */
export function checkAnyPermission(
  context: PermissionContext,
  required: readonly MobileShopPermission[],
): PermissionCheckResult {
  if (context.businessType !== 'mobile_shop') {
    return {
      granted: false,
      reason: 'Business type is not mobile_shop',
    };
  }

  const effective = expandPermissions(new Set(context.permissions));

  const granted = required.some(p => effective.has(p));
  if (granted) {
    return { granted: true };
  }

  return {
    granted: false,
    reason: `None of the required permissions present: ${required.join(', ')}`,
  };
}

/**
 * Returns all MobileShop permissions effectively granted to the context,
 * after expanding implications.
 *
 * @param context - The tenant/permission context
 * @returns Set of all effective MobileShop permissions
 */
export function getEffectiveMobileShopPermissions(
  context: PermissionContext,
): ReadonlySet<MobileShopPermission> {
  if (context.businessType !== 'mobile_shop') {
    return new Set();
  }

  const effective = expandPermissions(new Set(context.permissions));

  // Filter to only MobileShop permissions
  const mobilePerms = new Set<MobileShopPermission>();
  for (const perm of ALL_MOBILE_SHOP_PERMISSIONS) {
    if (effective.has(perm)) {
      mobilePerms.add(perm);
    }
  }

  return mobilePerms;
}

/**
 * Validates that a given string is a recognized MobileShop permission.
 */
export function isValidMobileShopPermission(value: string): value is MobileShopPermission {
  return (ALL_MOBILE_SHOP_PERMISSIONS as readonly string[]).includes(value);
}
