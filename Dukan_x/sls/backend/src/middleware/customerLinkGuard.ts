// ============================================
// Customer-Shop Link Guard Middleware
// ============================================
// Verifies that the authenticated customer is EXPLICITLY linked
// to the shop they are trying to access.
//
// This is the CRITICAL missing layer that prevents a customer
// from querying ANY shop's data just by knowing the shop UUID.
//
// Middleware chain order (all customer routes):
//   1. requireCognitoCustomerAuth  → verifies JWT, sets req.customerId
//   2. requireTenant               → validates shop, sets req.shopId
//   3. requireCustomerShopLink     → THIS: verifies customer ↔ shop link
//   4. Controller handler          → safe to use req.customerId + req.shopId
//
// Security Note:
//   Without this middleware, a malicious customer who knows a shop UUID
//   could set `x-shop-id` header to any value and access that shop's
//   products, orders, etc. This middleware closes that gap.
// ============================================

import { Request, Response, NextFunction } from 'express';
import { queryOne } from '../config/database';
import { logger } from '../utils/logger';

// ---- Types ----

interface LinkCheckResult {
    exists: boolean;
}

// ---- Middleware ----

/**
 * requireCustomerShopLink — Verifies the customer is linked to the shop.
 *
 * MUST be used AFTER requireCognitoCustomerAuth + requireTenant.
 * Requires: req.customerId (from auth) + req.shopId (from tenant)
 *
 * On success: proceeds to next middleware/handler
 * On failure: returns 403 Forbidden
 */
export async function requireCustomerShopLink(
    req: Request,
    res: Response,
    next: NextFunction
): Promise<void> {
    try {
        const customerId = req.customerId;
        const shopId = req.shopId;

        if (!customerId || !shopId) {
            // This should never happen if middleware chain is correct
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

        // Check if customer is linked to this shop
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

            // Return 403 — customer is authenticated but NOT authorized for this shop
            res.status(403).json({
                error: 'You are not linked to this shop. Please link your account first.',
                code: 'SHOP_NOT_LINKED',
            });
            return;
        }

        logger.debug('Customer-shop link verified', { customerId, shopId });
        next();
    } catch (error: any) {
        // If the customer_shop_links table doesn't exist yet (pre-migration),
        // log error but allow the request through to avoid breaking existing users.
        // Remove this fallback after migration 006 is applied.
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

/**
 * optionalCustomerShopLink — Same check but does NOT reject if not linked.
 * Sets req.isLinkedToShop = true/false for controllers that want to
 * conditionally show data (e.g., public product catalog).
 */
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
