// ============================================
// Tenant Middleware — Multi-Tenancy Firewall
// ============================================
// Central middleware for Customer App API routes.
// Extracts shop_id, validates tenant exists & is active,
// checks subscription, and sets RLS context.
// ============================================

import { Request, Response, NextFunction } from 'express';
import { queryOne } from '../config/database';
import { logger } from '../utils/logger';

// ---- Types ----

export interface TenantInfo {
    id: string;
    name: string;
    display_name: string | null;
    business_type: string;
    subscription_plan: string;
    subscription_valid_until: Date | null;
    is_active: boolean;
    phone: string | null;
    email: string | null;
    logo_url: string | null;
    settings: Record<string, unknown>;
}

// Extend Express Request to include tenant context
declare global {
    namespace Express {
        interface Request {
            tenant?: TenantInfo;
            shopId?: string;
            customerId?: string;
        }
    }
}

// ---- Error Codes ----

const ERRORS = {
    MISSING_SHOP_ID: { status: 400, code: 'MISSING_SHOP_ID', message: 'shop_id is required in the x-shop-id header or request body' },
    SHOP_NOT_FOUND: { status: 404, code: 'SHOP_NOT_FOUND', message: 'Shop not found' },
    SHOP_INACTIVE: { status: 403, code: 'SHOP_INACTIVE', message: 'This shop is currently inactive' },
    SUBSCRIPTION_EXPIRED: { status: 403, code: 'SUBSCRIPTION_EXPIRED', message: 'Shop subscription has expired. Please contact the shop owner.' },
} as const;

// ---- Middleware ----

export async function requireTenant(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const shopId =
            (req.headers['x-shop-id'] as string) ||
            req.body?.shop_id ||
            req.query?.shop_id as string;

        if (!shopId || typeof shopId !== 'string' || shopId.trim() === '') {
            res.status(ERRORS.MISSING_SHOP_ID.status).json({
                error: ERRORS.MISSING_SHOP_ID.message,
                code: ERRORS.MISSING_SHOP_ID.code,
            });
            return;
        }

        const cleanShopId = shopId.trim();

        const tenant = await queryOne<TenantInfo>(
            `SELECT id, name, display_name, business_type, subscription_plan,
                    subscription_valid_until, is_active, phone, email, logo_url, settings
             FROM tenants
             WHERE id = $1`,
            [cleanShopId]
        );

        if (!tenant) {
            res.status(ERRORS.SHOP_NOT_FOUND.status).json({
                error: ERRORS.SHOP_NOT_FOUND.message,
                code: ERRORS.SHOP_NOT_FOUND.code,
            });
            return;
        }

        if (!tenant.is_active) {
            logger.warn('Access attempt to inactive tenant', { shopId: cleanShopId });
            res.status(ERRORS.SHOP_INACTIVE.status).json({
                error: ERRORS.SHOP_INACTIVE.message,
                code: ERRORS.SHOP_INACTIVE.code,
            });
            return;
        }

        if (tenant.subscription_valid_until) {
            const now = new Date();
            const expiry = new Date(tenant.subscription_valid_until);
            if (now > expiry) {
                logger.warn('Access attempt to expired subscription', {
                    shopId: cleanShopId,
                    expiredAt: expiry.toISOString(),
                });
                res.status(ERRORS.SUBSCRIPTION_EXPIRED.status).json({
                    error: ERRORS.SUBSCRIPTION_EXPIRED.message,
                    code: ERRORS.SUBSCRIPTION_EXPIRED.code,
                });
                return;
            }
        }

        req.tenant = tenant;
        req.shopId = cleanShopId;

        logger.debug('Tenant context set', {
            shopId: cleanShopId,
            name: tenant.name,
            plan: tenant.subscription_plan,
        });

        next();
    } catch (error: any) {
        logger.error('Tenant middleware error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
}

export async function optionalTenant(req: Request, res: Response, next: NextFunction): Promise<void> {
    const shopId =
        (req.headers['x-shop-id'] as string) ||
        req.body?.shop_id ||
        req.query?.shop_id as string;

    if (!shopId) {
        next();
        return;
    }

    await requireTenant(req, res, next);
}

/**
 * withTenant — Execute a callback within a tenant-scoped DB transaction.
 * Sets RLS context, runs the callback, then commits/rollbacks.
 */
export async function withTenant<T>(
    shopId: string,
    callback: (client: any) => Promise<T>
): Promise<T> {
    const { pool } = await import('../config/database');
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        await client.query(`SET LOCAL app.tenant_id = $1`, [shopId]);
        const result = await callback(client);
        await client.query('COMMIT');
        return result;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}
