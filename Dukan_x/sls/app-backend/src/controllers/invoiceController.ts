// ============================================
// Invoice Controller — Customer App Invoice Routes
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoCustomerAuth } from '../middleware/cognitoCustomerAuth';
import { requireTenant } from '../middleware/tenantMiddleware';
import { requireCustomerShopLink } from '../middleware/customerLinkGuard';
import * as invoiceService from '../services/invoiceService';
import { logger } from '../utils/logger';

const router = Router();

// Middleware Chain (applied to ALL routes below)
router.use(requireCognitoCustomerAuth, requireTenant, requireCustomerShopLink);

// GET /api/invoices
router.get('/', async (req: Request, res: Response) => {
    try {
        const shopId = req.shopId!;
        const customerId = req.customerId!;
        const status = typeof req.query.status === 'string' ? req.query.status : undefined;
        const from_date = typeof req.query.from_date === 'string' ? req.query.from_date : undefined;
        const to_date = typeof req.query.to_date === 'string' ? req.query.to_date : undefined;
        const page = Math.max(1, parseInt(req.query.page as string) || 1);
        const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));

        const result = await invoiceService.getInvoices(shopId, customerId, { status, from_date, to_date, page, limit });

        res.json({
            success: true, invoices: result.invoices,
            pagination: { page, limit, total: result.total, total_pages: Math.ceil(result.total / limit) },
        });
    } catch (error: any) {
        logger.error('List invoices error', { error: error.message, shopId: req.shopId, customerId: req.customerId });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// GET /api/invoices/stats
router.get('/stats', async (req: Request, res: Response) => {
    try {
        const stats = await invoiceService.getInvoiceStats(req.shopId!, req.customerId!);
        res.json({ success: true, stats });
    } catch (error: any) {
        logger.error('Invoice stats error', { error: error.message, shopId: req.shopId, customerId: req.customerId });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// GET /api/invoices/:invoiceId
router.get('/:invoiceId', async (req: Request, res: Response) => {
    try {
        const { invoiceId } = req.params;
        if (!invoiceId || invoiceId.length < 10) {
            res.status(400).json({ error: 'Invalid invoice ID format', code: 'INVALID_INVOICE_ID' });
            return;
        }

        const result = await invoiceService.getInvoiceById(req.shopId!, req.customerId!, invoiceId);

        if (!result.found) {
            res.status(404).json({ error: 'Invoice not found', code: 'INVOICE_NOT_FOUND' });
            return;
        }

        if (!result.authorized) {
            logger.warn('IDOR attempt blocked on /invoices/:id', {
                attackerCustomerId: req.customerId, targetInvoiceId: invoiceId,
                shopId: req.shopId, ip: req.ip, userAgent: req.headers['user-agent'],
            });
            res.status(403).json({ error: 'You do not have permission to access this invoice', code: 'INVOICE_FORBIDDEN' });
            return;
        }

        res.json({ success: true, invoice: result.data });
    } catch (error: any) {
        logger.error('Invoice detail error', { error: error.message, shopId: req.shopId, customerId: req.customerId, invoiceId: req.params.invoiceId });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

export default router;
