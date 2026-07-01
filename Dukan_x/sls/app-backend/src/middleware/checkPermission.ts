// ============================================
// RBAC Permission Check Middleware
// ============================================

import { Request, Response, NextFunction } from 'express';
import { queryOne } from '../config/database';
import { logger } from '../utils/logger';

export function checkPermission(requiredPermission: string) {
    return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        try {
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

            // Owner/admin bypasses all permission checks
            if (userRole === 'owner' || userRole === 'admin' || userRole === 'superadmin') {
                next();
                return;
            }

            const result = await queryOne<{ has_perm: boolean }>(
                `SELECT check_permission($1, $2, $3) AS has_perm`,
                [cognitoSub, tenantId, requiredPermission]
            );

            if (result?.has_perm) {
                next();
                return;
            }

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

export function checkAnyPermission(...permissions: string[]) {
    return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        const cognitoSub = req.cognitoUser?.sub || (req as any).user?.sub;
        const userRole = req.cognitoUser?.role || (req as any).user?.role;
        const tenantId = req.shopId || req.cognitoUser?.tenantId;

        if (!cognitoSub || !tenantId) {
            res.status(401).json({ error: 'Authentication required', code: 'AUTH_MISSING' });
            return;
        }

        if (userRole === 'owner' || userRole === 'admin' || userRole === 'superadmin') {
            next();
            return;
        }

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
