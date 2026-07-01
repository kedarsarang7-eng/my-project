// ============================================
// Customer-Shop Link Guard Middleware
// ============================================
// Verifies that the authenticated customer is EXPLICITLY linked
// to the shop they are trying to access.
// ============================================

import { Request, Response, NextFunction } from 'express';
import { queryOne } from '../config/database';
import { logger } from '../utils/logger';

// ---- Types ----

interface LinkCheckResult {
    exists: boolean;
}

// ---- Middleware ----

export async function requireCustomerShopLink(
    req: Request,
    res: Response,
    next: NextFunction
): Promise<void> {
    try {
        const customerId = req.customerId;
        const shopId = req.shopId;

        if (!customerId || !shopId) {
            logger.error('customerLinkGuard: missing customerId or shopId', {
                hasCustomerId: !!customerId,
                hasShopId: !!shopId,
            });
            res.status(500).json({
                error: 'Internal middleware configuration error',
                code: 'MIDDLEWARE_ERROR',
            });
            return;
        }

        const result = await queryOne<LinkCheckResult>(
            `SELECT EXISTS(
                 SELECT 1 FROM customer_shop_links
                 WHERE customer_id = $1
                   AND tenant_id = $2::uuid
                   AND is_active = TRUE
             ) AS exists`,
            [customerId, shopId]
        );

        if (!result?.exists) {
            logger.warn('Customer-shop link check FAILED (unauthorized access attempt)', {
                customerId,
                shopId,
                ip: req.ip,
                userAgent: req.headers['user-agent'],
                path: req.path,
                method: req.method,
            });

            res.status(403).json({
                error: 'You are not linked to this shop. Please link your account first.',
                code: 'SHOP_NOT_LINKED',
            });
            return;
        }

        logger.debug('Customer-shop link verified', { customerId, shopId });
        next();
    } catch (error: any) {
        if (error.message?.includes('customer_shop_links') && error.message?.includes('does not exist')) {
            logger.warn('customer_shop_links table not found — allowing request (pre-migration fallback)', {
                customerId: req.customerId,
                shopId: req.shopId,
            });
            next();
            return;
        }

        logger.error('Customer link guard error', { error: error.message });
        res.status(500).json({
            error: 'Internal server error',
            code: 'INTERNAL_ERROR',
        });
    }
}

export async function optionalCustomerShopLink(
    req: Request,
    res: Response,
    next: NextFunction
): Promise<void> {
    try {
        const customerId = req.customerId;
        const shopId = req.shopId;

        if (!customerId || !shopId) {
            (req as any).isLinkedToShop = false;
            next();
            return;
        }

        const result = await queryOne<LinkCheckResult>(
            `SELECT EXISTS(
                 SELECT 1 FROM customer_shop_links
                 WHERE customer_id = $1
                   AND tenant_id = $2::uuid
                   AND is_active = TRUE
             ) AS exists`,
            [customerId, shopId]
        );

        (req as any).isLinkedToShop = result?.exists || false;
        next();
    } catch (error: any) {
        (req as any).isLinkedToShop = false;
        next();
    }
}
