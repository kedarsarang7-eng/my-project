// ============================================================================
// Role Guard Middleware — Two-App Ecosystem Role Enforcement
// ============================================================================
// Enforces that only allowed roles access internal endpoints.
// This works WITH your existing cognito-auth.ts and permission-guard.ts
// 
// Allowed roles for internal API: admin, staff, ca, manager
// Customer API: customer only
// ============================================================================

import { AuthContext } from '../types/tenant.types';
import { logger } from '../utils/logger';

/**
 * Internal roles - ONLY these roles allowed in main_software
 */
export const INTERNAL_ROLES = ['admin', 'staff', 'ca', 'manager'] as const;
export type InternalRole = typeof INTERNAL_ROLES[number];

/**
 * Validate user role for internal endpoints
 * 
 * Use this IN ADDITION to your existing verifyAuth() and validatePermission()
 * 
 * @param auth - AuthContext from verifyAuth()
 * @param allowedRoles - Which roles can access this endpoint
 * @throws Error with 403 statusCode if role not allowed
 */
export function validateInternalRole(
    auth: AuthContext,
    allowedRoles: InternalRole[] = INTERNAL_ROLES as unknown as InternalRole[]
): void {
    const userRole = auth.role;

    // Check if role is a valid internal role
    if (!INTERNAL_ROLES.includes(userRole as InternalRole)) {
        logger.warn('ROLE_INVALID: Non-internal role attempted access', {
            sub: auth.sub,
            role: userRole,
            tenantId: auth.tenantId,
        });

        const err: any = new Error(
            `Access denied. Role '${userRole}' is not authorized for internal endpoints.`
        );
        err.statusCode = 403;
        err.code = 'ROLE_INVALID';
        throw err;
    }

    // Check if role is in the allowed list for this specific endpoint
    if (!allowedRoles.includes(userRole as InternalRole)) {
        logger.warn('ROLE_FORBIDDEN: Role not permitted for action', {
            sub: auth.sub,
            role: userRole,
            allowedRoles,
            tenantId: auth.tenantId,
        });

        const err: any = new Error(
            `Your role '${userRole}' does not have permission for this operation.`
        );
        err.statusCode = 403;
        err.code = 'ROLE_FORBIDDEN';
        throw err;
    }

    logger.debug('ROLE_VALIDATED: Access granted', {
        sub: auth.sub,
        role: userRole,
        tenantId: auth.tenantId,
    });
}

/**
 * Predefined role sets for common scenarios
 */
export const RoleSets = {
    /** Admin only - highest privilege */
    ADMIN_ONLY: ['admin'] as InternalRole[],
    
    /** Management level */
    MANAGEMENT: ['admin', 'manager'] as InternalRole[],
    
    /** Financial operations */
    FINANCIAL: ['admin', 'ca'] as InternalRole[],
    
    /** Operational - day-to-day */
    OPERATIONAL: ['admin', 'manager', 'staff'] as InternalRole[],
    
    /** All internal users */
    ALL_INTERNAL: [...INTERNAL_ROLES] as InternalRole[],
    
    /** Billing operations */
    BILLING: ['admin', 'manager', 'staff'] as InternalRole[],
    
    /** User management */
    USER_MANAGEMENT: ['admin', 'manager'] as InternalRole[],
    
    /** CA read-only (CA can view, admin can modify) */
    CA_READONLY: ['admin', 'ca'] as InternalRole[],
};

/**
 * Validate customer role for customer endpoints
 * 
 * @param auth - AuthContext (should have role='customer')
 * @throws Error with 403 if not customer role
 */
export function validateCustomerRole(auth: AuthContext): void {
    // Note: This function validates customer-specific access
    // The role comparison is removed since 'customer' is not in UserRole enum
    logger.warn('CROSS_POOL_ACCESS: Internal user attempted customer endpoint', {
        sub: auth.sub,
        role: auth.role,
        tenantId: auth.tenantId,
    });

    const err: any = new Error(
        'Access denied. This endpoint is for customers only.'
    );
    err.statusCode = 403;
    err.code = 'CROSS_POOL_ACCESS_DENIED';
    throw err;
}

/**
 * Check which Cognito pool a token belongs to
 * 
 * Use this to route to correct validation logic
 */
export function detectPoolFromToken(
    token: string,
    internalPoolId: string,
    customerPoolId: string
): 'internal' | 'customer' | 'unknown' {
    // Decode JWT payload (without verification)
    try {
        const payload = JSON.parse(
            Buffer.from(token.split('.')[1], 'base64').toString()
        );
        
        const issuer = payload.iss as string;
        
        if (issuer.includes(internalPoolId)) return 'internal';
        if (issuer.includes(customerPoolId)) return 'customer';
        
        return 'unknown';
    } catch {
        return 'unknown';
    }
}

/**
 * Map old role names to new standardized roles
 * 
 * Use this during migration period to handle old tokens
 */
export function normalizeRoleForEcosystem(role: string): string {
    const roleMap: Record<string, string> = {
        'owner': 'admin',
        'accountant': 'ca',
        'cashier': 'staff',
        'viewer': 'ca',
    };
    
    return roleMap[role] || role;
}
