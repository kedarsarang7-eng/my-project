// ============================================
// Invoice Controller — Customer App Invoice Routes
// ============================================
// Dedicated invoice endpoints with IDOR protection.
//
// SECURITY MODEL (4 Layers):
//   Layer 1: requireCognitoCustomerAuth → JWT verification, extracts sub
//   Layer 2: requireTenant              → validates shop, sets RLS context
//   Layer 3: requireCustomerShopLink    → verifies customer ↔ shop link
//   Layer 4: invoiceService             → customer_id WHERE clause + ownership check
//
// Route Structure:
//   GET  /api/invoices            — List customer's invoices (paginated)
//   GET  /api/invoices/stats      — Aggregated invoice statistics
//   GET  /api/invoices/:invoiceId — Single invoice (with IDOR 403 protection)
//
// All routes require: Authorization: Bearer <cognito-id-token> + x-shop-id header
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoCustomerAuth } from '../middleware/cognitoCustomerAuth';
import { requireTenant } from '../middleware/tenantMiddleware';
import { requireCustomerShopLink } from '../middleware/customerLinkGuard';
import * as invoiceService from '../services/invoiceService';
import { logger } from '../utils/logger';

const router = Router();

// ============================================
// Middleware Chain (applied to ALL routes below)
// ============================================
// Order matters! Each middleware depends on the previous:
//   1. Auth    → sets req.customerId (from Cognito JWT sub)
//   2. Tenant  → sets req.shopId (from x-shop-id header)
//   3. Link    → verifies customer is linked to shop
router.use(requireCognitoCustomerAuth, requireTenant, requireCustomerShopLink);

// ============================================
// GET /api/invoices
// ============================================
// Returns paginated list of invoices for the authenticated customer.
//
// Query params:
//   ?status=paid|unpaid|partial   — filter by payment status
//   ?from_date=2024-01-01         — filter from date (inclusive)
//   ?to_date=2024-12-31           — filter to date (inclusive)
//   ?page=1                       — page number (default: 1)
//   ?limit=20                     — items per page (default: 20, max: 50)
//
// Security: customer_id comes from verified JWT (req.customerId),
//           NEVER from query params or request body.
//
router.get('/', async (req: Request, res: Response) => {
    try {
        const shopId = req.shopId!;
        const customerId = req.customerId!;

        // Parse query params (user-controlled input — sanitize)
        const status = typeof req.query.status === 'string' ? req.query.status : undefined;
        const from_date = typeof req.query.from_date === 'string' ? req.query.from_date : undefined;
        const to_date = typeof req.query.to_date === 'string' ? req.query.to_date : undefined;
        const page = Math.max(1, parseInt(req.query.page as string) || 1);
        const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 20));

        const result = await invoiceService.getInvoices(shopId, customerId, {
            status,
            from_date,
            to_date,
            page,
            limit,
        });

        res.json({
            success: true,
            invoices: result.invoices,
            pagination: {
                page,
                limit,
                total: result.total,
                total_pages: Math.ceil(result.total / limit),
            },
        });
    } catch (error: any) {
        logger.error('List invoices error', {
            error: error.message,
            shopId: req.shopId,
            customerId: req.customerId,
        });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ============================================
// GET /api/invoices/stats
// ============================================
// Returns aggregated invoice statistics for the customer.
//
router.get('/stats', async (req: Request, res: Response) => {
    try {
        const shopId = req.shopId!;
        const customerId = req.customerId!;

        const stats = await invoiceService.getInvoiceStats(shopId, customerId);

        res.json({ success: true, stats });
    } catch (error: any) {
        logger.error('Invoice stats error', {
            error: error.message,
            shopId: req.shopId,
            customerId: req.customerId,
        });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

// ============================================
// GET /api/invoices/:invoiceId
// ============================================
// Returns a single invoice with line items.
//
// IDOR PROTECTION:
//   - If invoice doesn't exist → 404 Not Found
//   - If invoice exists but belongs to ANOTHER customer → 403 Forbidden
//   - If invoice belongs to requesting customer → 200 OK
//
// The 403 response intentionally reveals that the resource exists.
// This is a deliberate design choice for this endpoint because:
//   a) The customer is already authenticated and linked to the shop
//   b) Invoice IDs are UUIDs (not guessable sequential integers)
//   c) The 403 enables clear security monitoring / alerting
//
// If you prefer stealth (hide resource existence), change 403 → 404.
//
router.get('/:invoiceId', async (req: Request, res: Response) => {
    try {
        const shopId = req.shopId!;
        const customerId = req.customerId!;
        const { invoiceId } = req.params;

        // Validate invoiceId format (basic UUID check)
        if (!invoiceId || invoiceId.length < 10) {
            res.status(400).json({
                error: 'Invalid invoice ID format',
                code: 'INVALID_INVOICE_ID',
            });
            return;
        }

        // ── THE CRITICAL IDOR-SAFE LOOKUP ──
        const result = await invoiceService.getInvoiceById(shopId, customerId, invoiceId);

        // Case 1: Invoice doesn't exist at all
        if (!result.found) {
            res.status(404).json({
                error: 'Invoice not found',
                code: 'INVOICE_NOT_FOUND',
            });
            return;
        }

        // Case 2: Invoice exists but belongs to a DIFFERENT customer (IDOR blocked!)
        if (!result.authorized) {
            // Log the IDOR attempt for security monitoring
            logger.warn('🚨 IDOR attempt blocked on /invoices/:id', {
                attackerCustomerId: customerId,
                targetInvoiceId: invoiceId,
                shopId,
                ip: req.ip,
                userAgent: req.headers['user-agent'],
            });

            res.status(403).json({
                error: 'You do not have permission to access this invoice',
                code: 'INVOICE_FORBIDDEN',
            });
            return;
        }

        // Case 3: Invoice found and customer is authorized
        res.json({ success: true, invoice: result.data });
    } catch (error: any) {
        logger.error('Invoice detail error', {
            error: error.message,
            shopId: req.shopId,
            customerId: req.customerId,
            invoiceId: req.params.invoiceId,
        });
        res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR' });
    }
});

export default router;
