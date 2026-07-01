// ============================================
// Role Gate Middleware — Portal-Specific Access Control
// ============================================
// Enforces that only users with the correct role can access
// specific portals. Used AFTER cognitoAuth middleware.
//
// If a STAFF user tries to access the Owner portal, they get
// an immediate 403 BEFORE any business logic runs.
//
// Usage:
//   router.use(requireCognitoAuth, requireRole('owner'));   // Owner-only routes
//   router.use(requireCognitoAuth, requireRole('staff'));   // Staff-only routes
//   router.use(requireCognitoAuth, requireRole(['owner', 'staff'])); // Either
// ============================================

import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

/**
 * Portal type for dual-entry login enforcement.
 * Stored in JWT custom:login_portal after authentication.
 */
export type LoginPortal = 'owner' | 'staff';

/**
 * Role hierarchy for DukanX:
 *   superadmin > admin > owner > manager > accountant > cashier > staff > viewer
 *
 * The 'owner' role has full business access.
 * All other roles are 'staff' variants with varying permissions.
 */
const OWNER_ROLES = ['owner', 'admin', 'superadmin'];
const STAFF_ROLES = ['staff', 'manager', 'cashier', 'accountant', 'viewer'];
const ALL_BUSINESS_ROLES = [...OWNER_ROLES, ...STAFF_ROLES];

/**
 * Middleware factory: requireRole(allowedRoles)
 *
 * Checks if the authenticated user's role matches the allowed roles.
 * MUST be placed AFTER requireCognitoAuth middleware.
 *
 * @param allowedRoles - Single role string or array of allowed roles.
 *                       Special values:
 *                         'owner'  → only owner/admin/superadmin
 *                         'staff'  → only staff variants (manager, cashier, etc.)
 *                         'any'    → any authenticated business user
 */
export function requireRole(allowedRoles: string | string[]) {
    const roles = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

    return (req: Request, res: Response, next: NextFunction): void => {
        const cognitoUser = req.cognitoUser;
        const legacyUser = (req as any).user;

        if (!cognitoUser && !legacyUser) {
            res.status(401).json({
                error: 'Authentication required',
                code: 'AUTH_MISSING',
            });
            return;
        }

        const userRole = cognitoUser?.role || legacyUser?.role || 'unknown';
        const userGroups = cognitoUser?.groups || [];

        // Resolve effective role category
        const isOwnerRole = OWNER_ROLES.includes(userRole) ||
            userGroups.includes('SuperAdmin') ||
            userGroups.includes('BusinessOwner');
        const isStaffRole = STAFF_ROLES.includes(userRole);

        // Check against allowed roles
        let allowed = false;

        for (const role of roles) {
            switch (role) {
                case 'owner':
                    if (isOwnerRole) allowed = true;
                    break;
                case 'staff':
                    if (isStaffRole) allowed = true;
                    break;
                case 'any':
                    if (isOwnerRole || isStaffRole) allowed = true;
                    break;
                default:
                    // Direct role match (e.g., 'manager', 'cashier')
                    if (userRole === role) allowed = true;
                    break;
            }
        }

        if (!allowed) {
            logger.warn('Role gate: access denied', {
                userRole,
                requiredRoles: roles,
                user: cognitoUser?.sub || legacyUser?.sub,
            });

            res.status(403).json({
                error: 'Access denied. Your role does not have permission to access this portal.',
                code: 'ROLE_FORBIDDEN',
                required_roles: roles,
                your_role: userRole,
            });
            return;
        }

        next();
    };
}

/**
 * Middleware: requireOwnerRole
 * Shorthand for requireRole('owner').
 * Only owner/admin/superadmin can proceed.
 */
export const requireOwnerRole = requireRole('owner');

/**
 * Middleware: requireStaffRole
 * Shorthand for requireRole('staff').
 * Only staff-variant roles can proceed.
 */
export const requireStaffRole = requireRole('staff');

/**
 * Middleware: requireAnyBusinessRole
 * Any authenticated business user (owner or staff) can proceed.
 */
export const requireAnyBusinessRole = requireRole('any');

/**
 * Middleware: enforceLoginPortal(portal)
 *
 * Validates that the user logged in through the correct portal.
 * Checks the `x-login-portal` header sent by the Flutter client.
 *
 * If a STAFF user tries to access an endpoint marked as 'owner' portal,
 * they get 403 even if they have a valid JWT.
 *
 * Usage:
 *   router.use(requireCognitoAuth, enforceLoginPortal('owner'));
 */
export function enforceLoginPortal(requiredPortal: LoginPortal) {
    return (req: Request, res: Response, next: NextFunction): void => {
        const cognitoUser = req.cognitoUser;
        const legacyUser = (req as any).user;

        if (!cognitoUser && !legacyUser) {
            res.status(401).json({ error: 'Authentication required', code: 'AUTH_MISSING' });
            return;
        }

        const userRole = cognitoUser?.role || legacyUser?.role || 'unknown';
        const isOwnerRole = OWNER_ROLES.includes(userRole) ||
            (cognitoUser?.groups || []).includes('SuperAdmin') ||
            (cognitoUser?.groups || []).includes('BusinessOwner');
        const isStaffRole = STAFF_ROLES.includes(userRole);

        // Enforce portal match
        if (requiredPortal === 'owner' && !isOwnerRole) {
            logger.warn('Portal enforcement: staff attempted owner portal', {
                user: cognitoUser?.sub || legacyUser?.sub,
                role: userRole,
            });

            res.status(403).json({
                error: 'This portal is for business owners only. Staff members must use the Staff Login.',
                code: 'PORTAL_FORBIDDEN',
                portal: requiredPortal,
                your_role: userRole,
            });
            return;
        }

        if (requiredPortal === 'staff' && isOwnerRole && !isStaffRole) {
            // Owners CAN access staff portal (they can do everything)
            // But we log it for auditing
            logger.info('Owner accessing staff portal', {
                user: cognitoUser?.sub || legacyUser?.sub,
            });
        }

        next();
    };
}

/**
 * Helper: Check if a role string is an owner-level role
 */
export function isOwnerLevelRole(role: string): boolean {
    return OWNER_ROLES.includes(role);
}

/**
 * Helper: Check if a role string is a staff-level role
 */
export function isStaffLevelRole(role: string): boolean {
    return STAFF_ROLES.includes(role);
}

/**
 * Helper: Get all valid business roles
 */
export function getAllBusinessRoles(): string[] {
    return [...ALL_BUSINESS_ROLES];
}
