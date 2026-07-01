// ============================================
// Staff Tenant Resolver — Auto-resolves business_id from Staff JWT
// ============================================
// Unlike requireTenant (which reads x-shop-id header for Customer App),
// this middleware resolves the tenant context from the staff member's
// Cognito UUID stored in the staff_members table.
//
// Every Staff App request auto-inherits the correct business_id + owner_id.
// No header manipulation needed — the tenant is baked into the staff record.
//
// MUST be placed AFTER requireCognitoAuth middleware.
// ============================================

import { Request, Response, NextFunction } from 'express';
import { queryOne } from '../config/database';
import { logger } from '../utils/logger';

// ---- Types ----

export interface StaffContext {
    staffId: string;
    businessId: string;
    ownerId: string;
    staffName: string;
    roleName: string;
    roleId: string;
    isActive: boolean;
}

// Extend Express Request
declare global {
    namespace Express {
        interface Request {
            staffContext?: StaffContext;
        }
    }
}

// ---- Error Codes ----

const ERRORS = {
    NOT_LINKED: {
        status: 403,
        code: 'STAFF_NOT_LINKED',
        message: 'Your account is not linked to any business. Please use a Linking Code from your employer to claim your profile.',
    },
    STAFF_INACTIVE: {
        status: 403,
        code: 'STAFF_INACTIVE',
        message: 'Your staff account has been deactivated. Please contact the business owner.',
    },
    AUTH_MISSING: {
        status: 401,
        code: 'AUTH_MISSING',
        message: 'Authentication required. Please log in first.',
    },
} as const;

// ---- Middleware ----

/**
 * resolveStaffTenant — Resolves business_id + owner_id from the staff's Cognito sub.
 *
 * Flow:
 *   1. Read cognitoUser.sub from the authenticated request
 *   2. Look up staff_members by cognito_sub
 *   3. Verify staff is active
 *   4. Attach staffContext { staffId, businessId, ownerId } to request
 *
 * All subsequent route handlers can use req.staffContext.businessId
 * to scope queries — guaranteeing zero cross-tenant data leaks.
 */
export async function resolveStaffTenant(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const cognitoSub = req.cognitoUser?.sub;

        if (!cognitoSub) {
            res.status(ERRORS.AUTH_MISSING.status).json({
                error: ERRORS.AUTH_MISSING.message,
                code: ERRORS.AUTH_MISSING.code,
            });
            return;
        }

        // Look up the staff record by Cognito UUID
        const staff = await queryOne<{
            id: string;
            tenant_id: string;
            owner_id: string;
            name: string;
            role_name: string;
            role_id: string;
            is_active: boolean;
        }>(
            `SELECT sm.id, sm.tenant_id, sm.owner_id, sm.name, sm.is_active,
                    r.name AS role_name, r.id AS role_id
             FROM staff_members sm
             JOIN roles r ON r.id = sm.role_id
             WHERE sm.cognito_sub = $1
             LIMIT 1`,
            [cognitoSub]
        );

        // Not linked to any business
        if (!staff) {
            res.status(ERRORS.NOT_LINKED.status).json({
                error: ERRORS.NOT_LINKED.message,
                code: ERRORS.NOT_LINKED.code,
            });
            return;
        }

        // Staff deactivated by owner
        if (!staff.is_active) {
            logger.warn('Inactive staff attempted access', { cognitoSub, staffId: staff.id });
            res.status(ERRORS.STAFF_INACTIVE.status).json({
                error: ERRORS.STAFF_INACTIVE.message,
                code: ERRORS.STAFF_INACTIVE.code,
            });
            return;
        }

        // Attach tenant context derived from the staff record
        req.staffContext = {
            staffId: staff.id,
            businessId: staff.tenant_id,
            ownerId: staff.owner_id || '',
            staffName: staff.name,
            roleName: staff.role_name,
            roleId: staff.role_id,
            isActive: staff.is_active,
        };

        // Also set shopId for compatibility with existing withTenant() / RLS helpers
        req.shopId = staff.tenant_id;

        logger.debug('Staff tenant resolved', {
            staffId: staff.id,
            businessId: staff.tenant_id,
            role: staff.role_name,
        });

        next();
    } catch (error: any) {
        logger.error('Staff tenant resolver error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
}

/**
 * requireLinkedStaff — Convenience alias that chains:
 *   1. resolveStaffTenant (find business from JWT)
 *
 * Use this on any route that requires a fully-linked staff member.
 */
export const requireLinkedStaff = resolveStaffTenant;
