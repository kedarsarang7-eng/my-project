// ============================================
// RBAC Permission Check Middleware
// ============================================
// Validates that the authenticated user has the required permission
// for the current tenant. Works with both Cognito and legacy JWT auth.
//
// Usage in controllers:
//   router.get('/sensitive', requireCognitoAuth, requireTenant, checkPermission('view_profit'), handler);
// ============================================

import { Request, Response, NextFunction } from 'express';
import { queryOne } from '../config/database';
import { logger } from '../utils/logger';

/**
 * Middleware factory: checkPermission(requiredPermission)
 *
 * Checks if the authenticated user has the specified permission
 * within their current tenant context.
 *
 * MUST be placed AFTER auth middleware (requireCognitoAuth) and tenant middleware (requireTenant).
 *
 * Owner role bypasses all permission checks (full access).
 */
export function checkPermission(requiredPermission: string) {
    return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        try {
            // 1. Get user identity
            const cognitoSub = req.cognitoUser?.sub || (req as any).user?.sub;
            const userRole = req.cognitoUser?.role || (req as any).user?.role;
            const tenantId = req.shopId || req.cognitoUser?.tenantId;

            if (!cognitoSub) {
                res.status(401).json({
                    error: 'Authentication required',
                    code: 'AUTH_MISSING',
                });
                return;
            }

            if (!tenantId) {
                res.status(400).json({
                    error: 'Tenant context required',
                    code: 'TENANT_MISSING',
                });
                return;
            }

            // 2. Owner/admin bypasses all permission checks
            if (userRole === 'owner' || userRole === 'admin' || userRole === 'superadmin') {
                next();
                return;
            }

            // 3. Check permission in database
            const result = await queryOne<{ has_perm: boolean }>(
                `SELECT check_permission($1, $2, $3) AS has_perm`,
                [cognitoSub, tenantId, requiredPermission]
            );

            if (result?.has_perm) {
                next();
                return;
            }

            // 4. Permission denied
            logger.warn('Permission denied', {
                user: cognitoSub,
                tenant: tenantId,
                permission: requiredPermission,
            });

            res.status(403).json({
                error: `Permission '${requiredPermission}' is required for this action`,
                code: 'PERMISSION_DENIED',
                required_permission: requiredPermission,
            });
        } catch (error: any) {
            logger.error('Permission check error', { error: error.message });
            res.status(500).json({
                error: 'Internal server error during permission check',
                code: 'PERMISSION_CHECK_ERROR',
            });
        }
    };
}

/**
 * Check multiple permissions (ALL required).
 * User must have every listed permission.
 */
export function checkAllPermissions(...permissions: string[]) {
    return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        for (const perm of permissions) {
            const middleware = checkPermission(perm);
            const passed = await new Promise<boolean>((resolve) => {
                const mockRes = {
                    ...res,
                    status: (code: number) => ({
                        json: (body: any) => {
                            if (code >= 400) resolve(false);
                            return mockRes;
                        },
                    }),
                } as any;
                middleware(req, mockRes, () => resolve(true));
            });

            if (!passed) {
                res.status(403).json({
                    error: `Missing required permissions: ${permissions.join(', ')}`,
                    code: 'PERMISSION_DENIED',
                    required_permissions: permissions,
                });
                return;
            }
        }
        next();
    };
}

/**
 * Check multiple permissions (ANY one is sufficient).
 */
export function checkAnyPermission(...permissions: string[]) {
    return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        const cognitoSub = req.cognitoUser?.sub || (req as any).user?.sub;
        const userRole = req.cognitoUser?.role || (req as any).user?.role;
        const tenantId = req.shopId || req.cognitoUser?.tenantId;

        if (!cognitoSub || !tenantId) {
            res.status(401).json({ error: 'Authentication required', code: 'AUTH_MISSING' });
            return;
        }

        // Owner bypass
        if (userRole === 'owner' || userRole === 'admin' || userRole === 'superadmin') {
            next();
            return;
        }

        // Check if user has ANY of the permissions
        const placeholders = permissions.map((_, i) => `$${i + 3}`).join(', ');
        const result = await queryOne<{ has_any: boolean }>(
            `SELECT EXISTS(
                SELECT 1 FROM v_effective_permissions
                WHERE cognito_sub = $1
                  AND tenant_id = $2
                  AND permission_id IN (${placeholders})
                  AND is_granted = TRUE
            ) AS has_any`,
            [cognitoSub, tenantId, ...permissions]
        );

        if (result?.has_any) {
            next();
            return;
        }

        res.status(403).json({
            error: `One of these permissions is required: ${permissions.join(', ')}`,
            code: 'PERMISSION_DENIED',
            required_permissions: permissions,
        });
    };
}
