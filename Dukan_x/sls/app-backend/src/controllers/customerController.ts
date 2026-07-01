// ============================================
// Customer Controller — Customer App API Routes
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoCustomerAuth as requireCustomerAuth } from '../middleware/cognitoCustomerAuth';
import { requireTenant } from '../middleware/tenantMiddleware';
import { requireCustomerShopLink } from '../middleware/customerLinkGuard';
import * as customerService from '../services/customerService';
import * as customerLinkService from '../services/customerLinkService';
import { logger } from '../utils/logger';

const router = Router();

router.post('/verify-shop', async (req: Request, res: Response) => {
    try {
        const { shop_code } = req.body;
        if (!shop_code || typeof shop_code !== 'string' || shop_code.trim() === '') {
            res.status(400).json({ error: 'shop_code is required', code: 'MISSING_SHOP_CODE' });
            return;
        }
        const shop = await customerService.verifyShop(shop_code.trim());
        if (!shop) {
            res.status(404).json({ error: 'Shop not found or inactive', code: 'SHOP_NOT_FOUND' });
            return;
        }
        logger.info('Shop verified', { shopId: shop.id, name: shop.name });
        res.json({
            success: true,
            shop: {
                id: shop.id, name: shop.name, display_name: shop.display_name,
                business_type: shop.business_type, phone: shop.phone,
                logo_url: shop.logo_url, theme_color: shop.theme_color,
            },
        });
    } catch (error: any) {
        logger.error('Verify shop error', { error: error.message });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

router.get('/dashboard', requireCustomerAuth, requireTenant, requireCustomerShopLink,
    async (req: Request, res: Response) => {
        try {
            const dashboard = await customerService.getDashboard(req.shopId!, req.customerId!);
            if (!dashboard) {
                res.status(404).json({ error: 'Dashboard data not available', code: 'DASHBOARD_NOT_FOUND' });
                return;
            }
            res.json({ success: true, dashboard });
        } catch (error: any) {
            logger.error('Dashboard error', { error: error.message, shopId: req.shopId, customerId: req.customerId });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

router.get('/products', requireCustomerAuth, requireTenant, requireCustomerShopLink,
    async (req: Request, res: Response) => {
        try {
            const page = parseInt(req.query.page as string) || 1;
            const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
            const result = await customerService.getProducts(req.shopId!, {
                category: req.query.category as string | undefined,
                search: req.query.search as string | undefined,
                page, limit,
            });
            res.json({
                success: true, products: result.products,
                pagination: { page, limit, total: result.total, total_pages: Math.ceil(result.total / limit) },
            });
        } catch (error: any) {
            logger.error('Products error', { error: error.message, shopId: req.shopId });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

router.get('/orders', requireCustomerAuth, requireTenant, requireCustomerShopLink,
    async (req: Request, res: Response) => {
        try {
            const page = parseInt(req.query.page as string) || 1;
            const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
            const result = await customerService.getOrders(req.shopId!, req.customerId!, {
                status: req.query.status as string | undefined, page, limit,
            });
            res.json({
                success: true, orders: result.orders,
                pagination: { page, limit, total: result.total, total_pages: Math.ceil(result.total / limit) },
            });
        } catch (error: any) {
            logger.error('Orders error', { error: error.message, shopId: req.shopId, customerId: req.customerId });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

router.get('/orders/:orderId', requireCustomerAuth, requireTenant, requireCustomerShopLink,
    async (req: Request, res: Response) => {
        try {
            const { orderId } = req.params;
            if (!orderId) {
                res.status(400).json({ error: 'Order ID required', code: 'MISSING_ORDER_ID' });
                return;
            }
            const order = await customerService.getOrderDetail(req.shopId!, req.customerId!, orderId);
            if (!order) {
                res.status(404).json({ error: 'Order not found', code: 'ORDER_NOT_FOUND' });
                return;
            }
            res.json({ success: true, order });
        } catch (error: any) {
            logger.error('Order detail error', { error: error.message, shopId: req.shopId, customerId: req.customerId, orderId: req.params.orderId });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

router.post('/link-shop', requireCustomerAuth, requireTenant,
    async (req: Request, res: Response) => {
        try {
            const alreadyLinked = await customerLinkService.isLinked(req.customerId!, req.shopId!);
            if (alreadyLinked) {
                res.json({ success: true, message: 'Already linked to this shop', already_linked: true });
                return;
            }
            const link = await customerLinkService.linkCustomerToShop(req.customerId!, req.shopId!, {
                linked_via: 'customer_app',
                display_name: req.body.display_name || req.customer?.name || null,
                phone: req.body.phone || req.customer?.phone || null,
            });
            logger.info('Customer linked to shop via app', { customerId: req.customerId, shopId: req.shopId, linked_via: 'customer_app' });
            res.json({
                success: true,
                link: { id: link.id, tenant_id: link.tenant_id, linked_at: link.linked_at, linked_via: link.linked_via },
            });
        } catch (error: any) {
            logger.error('Link shop error', { error: error.message, shopId: req.shopId, customerId: req.customerId });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

router.post('/unlink-shop', requireCustomerAuth, requireTenant,
    async (req: Request, res: Response) => {
        try {
            const unlinked = await customerLinkService.unlinkCustomerFromShop(req.customerId!, req.shopId!, 'customer_request');
            if (!unlinked) {
                res.status(404).json({ error: 'No active link found for this shop', code: 'LINK_NOT_FOUND' });
                return;
            }
            logger.info('Customer unlinked from shop', { customerId: req.customerId, shopId: req.shopId });
            res.json({ success: true, message: 'Successfully unlinked from shop' });
        } catch (error: any) {
            logger.error('Unlink shop error', { error: error.message, shopId: req.shopId, customerId: req.customerId });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

router.get('/my-shops', requireCustomerAuth,
    async (req: Request, res: Response) => {
        try {
            const shops = await customerLinkService.getLinkedShops(req.customerId!);
            res.json({ success: true, shops, total: shops.length });
        } catch (error: any) {
            logger.error('My shops error', { error: error.message, customerId: req.customerId });
            res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
        }
    }
);

export default router;
