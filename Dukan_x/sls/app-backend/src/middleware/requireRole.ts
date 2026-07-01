// ============================================
// Role Gate Middleware — Portal-Specific Access Control
// ============================================

import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

export type LoginPortal = 'owner' | 'staff';

const OWNER_ROLES = ['owner', 'admin', 'superadmin'];
const STAFF_ROLES = ['staff', 'manager', 'cashier', 'accountant', 'viewer'];
const ALL_BUSINESS_ROLES = [...OWNER_ROLES, ...STAFF_ROLES];

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

        const isOwnerRole = OWNER_ROLES.includes(userRole) ||
            userGroups.includes('SuperAdmin') ||
            userGroups.includes('BusinessOwner');
        const isStaffRole = STAFF_ROLES.includes(userRole);

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

export const requireOwnerRole = requireRole('owner');
export const requireStaffRole = requireRole('staff');
export const requireAnyBusinessRole = requireRole('any');

export function isOwnerLevelRole(role: string): boolean {
    return OWNER_ROLES.includes(role);
}

export function isStaffLevelRole(role: string): boolean {
    return STAFF_ROLES.includes(role);
}

export function getAllBusinessRoles(): string[] {
    return [...ALL_BUSINESS_ROLES];
}
