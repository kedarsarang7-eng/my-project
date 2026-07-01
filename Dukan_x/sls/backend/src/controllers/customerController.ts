// ============================================
// Customer Controller — Customer App API Routes
// ============================================
// All customer-facing endpoints for the mobile app.
// Every route enforces multi-tenant isolation.
//
// Route Structure:
//   POST /api/customer/verify-shop     — Public (no auth)
//   POST /api/customer/link-shop       — Auth + Tenant (creates customer-shop link)
//   POST /api/customer/unlink-shop     — Auth + Tenant (deactivates link)
//   GET  /api/customer/my-shops        — Auth (lists all linked shops)
//   GET  /api/customer/dashboard       — Auth + Tenant + Link
//   GET  /api/customer/products        — Auth + Tenant + Link
//   GET  /api/customer/orders          — Auth + Tenant + Link
//   GET  /api/customer/orders/:id      — Auth + Tenant + Link
//
// Headers required (except verify-shop):
//   Authorization: Bearer <cognito-id-token>
//   x-shop-id: <tenant-uuid>
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoCustomerAuth as requireCustomerAuth } from '../middleware/cognitoCustomerAuth';
import { requireTenant } from '../middleware/tenantMiddleware';
import { requireCustomerShopLink } from '../middleware/customerLinkGuard';
import * as customerService from '../services/customerService';
import * as customerLinkService from '../services/customerLinkService';
import { logger } from '../utils/logger';

const router = Router();

// ============================================
// POST /api/customer/verify-shop
// ============================================
// Public endpoint. Customer enters a shop code or scans QR.
// Returns shop public info if valid and active.
//
// Body: { shop_code: "uuid-or-phone-or-code" }
// Response: { shop: { id, name, business_type, logo_url, theme_color, ... } }
//
router.post('/verify-shop', async (req: Request, res: Response) => {
    try {
        const { shop_code } = req.body;

        if (!shop_code || typeof shop_code !== 'string' || shop_code.trim() === '') {
            res.status(400).json({
                error: 'shop_code is required',
                code: 'MISSING_SHOP_CODE',
            });
            return;
        }

        const shop = await customerService.verifyShop(shop_code.trim());

        if (!shop) {
            res.status(404).json({
                error: 'Shop not found or inactive',
                code: 'SHOP_NOT_FOUND',
            });
            return;
        }

        logger.info('Shop verified', { shopId: shop.id, name: shop.name });

        res.json({
            success: true,
            shop: {
                id: shop.id,
                name: shop.name,
                display_name: shop.display_name,
                business_type: shop.business_type,
                phone: shop.phone,
                logo_url: shop.logo_url,
                theme_color: shop.theme_color,
            },
        });
    } catch (error: any) {
        logger.error('Verify shop error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ============================================
// GET /api/customer/dashboard
// ============================================
// Returns aggregated billing stats + recent orders for the
// authenticated customer within the specified shop.
//
// Headers: Authorization + x-shop-id
// Response: { dashboard: { shop, total_billed, outstanding, recent_orders, ... } }
//
router.get(
    '/dashboard',
    requireCustomerAuth,
    requireTenant,
    requireCustomerShopLink,
    async (req: Request, res: Response) => {
        try {
            const shopId = req.shopId!;
            const customerId = req.customerId!;

            const dashboard = await customerService.getDashboard(shopId, customerId);

            if (!dashboard) {
                res.status(404).json({
                    error: 'Dashboard data not available',
                    code: 'DASHBOARD_NOT_FOUND',
                });
                return;
            }

            res.json({ success: true, dashboard });
        } catch (error: any) {
            logger.error('Dashboard error', {
                error: error.message,
                shopId: req.shopId,
                customerId: req.customerId,
            });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// GET /api/customer/products
// ============================================
// Returns the product catalog for the specified shop.
// Products are public within a shop — any linked customer can see them.
//
// Headers: Authorization + x-shop-id
// Query: ?category=&search=&page=1&limit=50
// Response: { products: [...], pagination: { page, limit, total, total_pages } }
//
router.get(
    '/products',
    requireCustomerAuth,
    requireTenant,
    requireCustomerShopLink,
    async (req: Request, res: Response) => {
        try {
            const shopId = req.shopId!;
            const category = req.query.category as string | undefined;
            const search = req.query.search as string | undefined;
            const page = parseInt(req.query.page as string) || 1;
            const limit = Math.min(parseInt(req.query.limit as string) || 50, 100); // Cap at 100

            const result = await customerService.getProducts(shopId, {
                category,
                search,
                page,
                limit,
            });

            res.json({
                success: true,
                products: result.products,
                pagination: {
                    page,
                    limit,
                    total: result.total,
                    total_pages: Math.ceil(result.total / limit),
                },
            });
        } catch (error: any) {
            logger.error('Products error', {
                error: error.message,
                shopId: req.shopId,
            });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// GET /api/customer/orders
// ============================================
// Returns orders for the authenticated customer within the specified shop.
// STRICT ISOLATION: shop_id (RLS) + customer_id (WHERE clause).
//
// Headers: Authorization + x-shop-id
// Query: ?status=&page=1&limit=20
// Response: { orders: [...], pagination: { ... } }
//
router.get(
    '/orders',
    requireCustomerAuth,
    requireTenant,
    requireCustomerShopLink,
    async (req: Request, res: Response) => {
        try {
            const shopId = req.shopId!;
            const customerId = req.customerId!;
            const status = req.query.status as string | undefined;
            const page = parseInt(req.query.page as string) || 1;
            const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

            const result = await customerService.getOrders(shopId, customerId, {
                status,
                page,
                limit,
            });

            res.json({
                success: true,
                orders: result.orders,
                pagination: {
                    page,
                    limit,
                    total: result.total,
                    total_pages: Math.ceil(result.total / limit),
                },
            });
        } catch (error: any) {
            logger.error('Orders error', {
                error: error.message,
                shopId: req.shopId,
                customerId: req.customerId,
            });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// GET /api/customer/orders/:orderId
// ============================================
// Returns a single order with line items.
// STRICT ISOLATION: shop_id (RLS) + customer_id (WHERE clause).
//
// Headers: Authorization + x-shop-id
// Response: { order: { ...order, items: [...] } }
//
router.get(
    '/orders/:orderId',
    requireCustomerAuth,
    requireTenant,
    requireCustomerShopLink,
    async (req: Request, res: Response) => {
        try {
            const shopId = req.shopId!;
            const customerId = req.customerId!;
            const { orderId } = req.params;

            if (!orderId) {
                res.status(400).json({ error: 'Order ID required', code: 'MISSING_ORDER_ID' });
                return;
            }

            const order = await customerService.getOrderDetail(shopId, customerId, orderId);

            if (!order) {
                res.status(404).json({
                    error: 'Order not found',
                    code: 'ORDER_NOT_FOUND',
                });
                return;
            }

            res.json({ success: true, order });
        } catch (error: any) {
            logger.error('Order detail error', {
                error: error.message,
                shopId: req.shopId,
                customerId: req.customerId,
                orderId: req.params.orderId,
            });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// POST /api/customer/link-shop
// ============================================
// Creates a customer-shop link after verifying the shop exists.
// This is called AFTER verify-shop when the customer confirms.
//
// Headers: Authorization + x-shop-id
// Body: { display_name?: string, phone?: string }
// Response: { success: true, link: { ... } }
//
router.post(
    '/link-shop',
    requireCustomerAuth,
    requireTenant,
    async (req: Request, res: Response) => {
        try {
            const shopId = req.shopId!;
            const customerId = req.customerId!;
            const { display_name, phone } = req.body;

            // Check if already linked
            const alreadyLinked = await customerLinkService.isLinked(customerId, shopId);
            if (alreadyLinked) {
                res.json({
                    success: true,
                    message: 'Already linked to this shop',
                    already_linked: true,
                });
                return;
            }

            const link = await customerLinkService.linkCustomerToShop(
                customerId,
                shopId,
                {
                    linked_via: 'customer_app',
                    display_name: display_name || req.customer?.name || null,
                    phone: phone || req.customer?.phone || null,
                }
            );

            logger.info('Customer linked to shop via app', {
                customerId,
                shopId,
                linked_via: 'customer_app',
            });

            res.json({
                success: true,
                link: {
                    id: link.id,
                    tenant_id: link.tenant_id,
                    linked_at: link.linked_at,
                    linked_via: link.linked_via,
                },
            });
        } catch (error: any) {
            logger.error('Link shop error', {
                error: error.message,
                shopId: req.shopId,
                customerId: req.customerId,
            });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// POST /api/customer/unlink-shop
// ============================================
// Deactivates a customer-shop link.
// The customer will lose access to this shop's data.
//
// Headers: Authorization + x-shop-id
// Response: { success: true }
//
router.post(
    '/unlink-shop',
    requireCustomerAuth,
    requireTenant,
    async (req: Request, res: Response) => {
        try {
            const shopId = req.shopId!;
            const customerId = req.customerId!;

            const unlinked = await customerLinkService.unlinkCustomerFromShop(
                customerId,
                shopId,
                'customer_request'
            );

            if (!unlinked) {
                res.status(404).json({
                    error: 'No active link found for this shop',
                    code: 'LINK_NOT_FOUND',
                });
                return;
            }

            logger.info('Customer unlinked from shop', { customerId, shopId });

            res.json({ success: true, message: 'Successfully unlinked from shop' });
        } catch (error: any) {
            logger.error('Unlink shop error', {
                error: error.message,
                shopId: req.shopId,
                customerId: req.customerId,
            });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// GET /api/customer/my-shops
// ============================================
// Returns all shops the customer is linked to.
// Does NOT require x-shop-id header (it's a cross-shop query).
//
// Headers: Authorization
// Response: { shops: [...], total: number }
//
router.get(
    '/my-shops',
    requireCustomerAuth,
    async (req: Request, res: Response) => {
        try {
            const customerId = req.customerId!;

            const shops = await customerLinkService.getLinkedShops(customerId);

            res.json({
                success: true,
                shops,
                total: shops.length,
            });
        } catch (error: any) {
            logger.error('My shops error', {
                error: error.message,
                customerId: req.customerId,
            });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

export default router;
