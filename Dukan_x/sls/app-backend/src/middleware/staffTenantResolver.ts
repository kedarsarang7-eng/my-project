// ============================================
// Staff Tenant Resolver — Auto-resolves business_id from Staff JWT
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

        if (!staff) {
            res.status(ERRORS.NOT_LINKED.status).json({
                error: ERRORS.NOT_LINKED.message,
                code: ERRORS.NOT_LINKED.code,
            });
            return;
        }

        if (!staff.is_active) {
            logger.warn('Inactive staff attempted access', { cognitoSub, staffId: staff.id });
            res.status(ERRORS.STAFF_INACTIVE.status).json({
                error: ERRORS.STAFF_INACTIVE.message,
                code: ERRORS.STAFF_INACTIVE.code,
            });
            return;
        }

        req.staffContext = {
            staffId: staff.id,
            businessId: staff.tenant_id,
            ownerId: staff.owner_id || '',
            staffName: staff.name,
            roleName: staff.role_name,
            roleId: staff.role_id,
            isActive: staff.is_active,
        };

        // Also set shopId for compatibility with withTenant() / RLS helpers
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

export const requireLinkedStaff = resolveStaffTenant;
