// ============================================================================
// SECURITY FIX S-8: User-Scope Access Guard
// ============================================================================
// Prevents horizontal privilege escalation within a tenant:
//   - Cashier A cannot access Cashier B's personal data (sales, shifts, etc.)
//   - Owner/Admin/Manager retain full tenant-wide visibility.
//
// Usage in handlers:
//   if (!canAccessUserData(auth, requestedStaffId)) {
//       return response.forbidden('You can only access your own records');
//   }
// ============================================================================

import { AuthContext, UserRole } from '../types/tenant.types';

/**
 * Roles that have full visibility across all users within a tenant.
 * These roles can view any staff member's data.
 */
const TENANT_WIDE_ROLES: ReadonlySet<string> = new Set([
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.MANAGER,
]);

/**
 * Check if the authenticated user can access data belonging to another user.
 *
 * Rules:
 * - Owner/Admin/Manager → can access any user's data within their tenant
 * - Cashier/Staff/Viewer → can only access their own data (auth.sub must match targetUserId)
 * - If targetUserId is not provided, access is allowed (tenant-wide query by a privileged role)
 *
 * @param auth - Authenticated user context from JWT
 * @param targetUserId - The Cognito sub / staffId whose data is being accessed
 * @returns true if access is allowed, false if denied
 */
export function canAccessUserData(auth: AuthContext, targetUserId?: string): boolean {
    // Privileged roles have tenant-wide access
    if (TENANT_WIDE_ROLES.has(auth.role)) {
        return true;
    }

    // If no specific user is targeted, deny for non-privileged (they shouldn't list all)
    if (!targetUserId) {
        return false;
    }

    // Non-privileged users can only access their own data
    return auth.sub === targetUserId;
}

/**
 * Filter an array of records to only include items the user has access to.
 * Privileged roles see everything; lower roles see only their own records.
 *
 * @param auth - Authenticated user context
 * @param items - Array of records with a user identifier field
 * @param userField - The field name that contains the user/staff ID (default: 'createdBy')
 * @returns Filtered array based on user's access level
 */
export function filterByUserAccess<T extends Record<string, any>>(
    auth: AuthContext,
    items: T[],
    userField: string = 'createdBy',
): T[] {
    if (TENANT_WIDE_ROLES.has(auth.role)) {
        return items; // Privileged roles see everything
    }

    // Non-privileged: filter to only their own records
    return items.filter(item => item[userField] === auth.sub);
}
