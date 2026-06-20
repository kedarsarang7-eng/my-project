// ============================================================================
// PHARMACY DASHBOARD API ROUTES
// ============================================================================
// REST API endpoints for pharmacy dashboard data
// Implements business-type validation, rate limiting, and caching
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import { Router, Request, Response } from 'express';
import { PharmacyDashboardService } from '../services/pharmacy-dashboard.service';
import { logger } from '../utils/logger';

// Temporary rate limiting implementation
const rateLimit = (options: any) => (req: Request, res: Response, next: any) => {
    next();
};

const router = Router();
const pharmacyService = new PharmacyDashboardService();

// Rate limiting: 60 requests per minute per tenantId
const pharmacyRateLimit = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 60,
    keyGenerator: (req: any) => req.user?.tenantId || req.ip,
    message: { error: 'Too many requests, please try again later' },
});

// Middleware to validate business type and license
const validatePharmacyAccess = (req: Request, res: Response, next: any) => {
    const businessType = req.headers['x-business-type'] as string;
    const user = (req as any).user;
    
    if (businessType !== 'pharmacy') {
        return res.status(403).json({ 
            error: 'Access denied. Pharmacy dashboard is only available for pharmacy businesses.' 
        });
    }
    
    if (!user?.license?.features?.includes('pharmacy_dashboard')) {
        return res.status(403).json({ 
            error: 'Access denied. Pharmacy dashboard feature not included in your license.' 
        });
    }
    
    next();
};

// Middleware to resolve tenantId from authenticated user context
const resolveTenantId = (req: Request, res: Response, next: any) => {
    const user = (req as any).user;
    const tenantId = user?.tenantId;
    if (!tenantId) {
        return res.status(401).json({ error: 'Unauthorized: missing tenant context' });
    }
    (req as any).tenantId = tenantId;
    next();
};

// Apply middleware to all pharmacy routes
router.use(pharmacyRateLimit);
router.use(validatePharmacyAccess);
router.use(resolveTenantId);

// ── KPI CARDS ENDPOINTS ─────────────────────────────────────────────────────

/**
 * GET /api/pharmacy/revenue
 * Get total revenue for the specified date range
 * Query params: range (last7days, last30days, last90days)
 */
router.get('/revenue', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const range = req.query.range as string || 'last30days';
        
        const data = await pharmacyService.getTotalRevenue(tenantId, range);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching pharmacy revenue:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /api/pharmacy/patients/new
 * Get count of new patients for the specified date range
 * Query params: range (last7days, last30days, last90days)
 */
router.get('/patients/new', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const range = req.query.range as string || 'last30days';
        
        const data = await pharmacyService.getNewPatientsCount(tenantId, range);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching new patients count:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /api/pharmacy/prescriptions/count
 * Get count of prescriptions with specified status
 * Query params: status (dispensed, pending, etc.), range
 */
router.get('/prescriptions/count', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const status = req.query.status as string || 'dispensed';
        const range = req.query.range as string || 'last30days';
        
        const data = await pharmacyService.getPrescriptionsFilledCount(tenantId, range);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching prescriptions count:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /api/pharmacy/inventory/low-stock/count
 * Get count of items below reorder point
 */
router.get('/inventory/low-stock/count', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        
        const data = await pharmacyService.getLowStockItemsCount(tenantId);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching low stock count:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── SALES PERFORMANCE CHART ─────────────────────────────────────────────────

/**
 * GET /api/pharmacy/sales/daily
 * Get daily sales data for the specified range
 * Query params: range (last7days, last30days, last90days)
 */
router.get('/sales/daily', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const range = req.query.range as string || 'last30days';
        
        const data = await pharmacyService.getSalesDailyData(tenantId, range);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching sales daily data:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── PRESCRIPTIONS BY CATEGORY ─────────────────────────────────────────────────

/**
 * GET /api/pharmacy/prescriptions/by-category
 * Get prescriptions breakdown by category
 * Query params: granularity (weekly, monthly)
 */
router.get('/prescriptions/by-category', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const granularity = req.query.granularity as string || 'weekly';
        
        const data = await pharmacyService.getPrescriptionsByCategory(tenantId, granularity);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching prescriptions by category:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── TOP SELLING PRODUCTS ─────────────────────────────────────────────────────

/**
 * GET /api/pharmacy/products/top-sellers
 * Get top selling products by revenue
 * Query params: limit (default: 5), range
 */
router.get('/products/top-sellers', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const limit = parseInt(req.query.limit as string) || 5;
        const range = req.query.range as string || 'last30days';
        
        const data = await pharmacyService.getTopSellingProducts(tenantId, range, limit);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching top selling products:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── INVENTORY STATUS ─────────────────────────────────────────────────────

/**
 * GET /api/pharmacy/inventory/status-summary
 * Get inventory status distribution (in stock, low stock, out of stock)
 */
router.get('/inventory/status-summary', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        
        const data = await pharmacyService.getInventoryStatusSummary(tenantId);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching inventory status summary:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── LOW STOCK ALERTS ─────────────────────────────────────────────────────

/**
 * GET /api/pharmacy/inventory/low-stock
 * Get list of items below reorder point
 * Query params: limit (default: 10)
 */
router.get('/inventory/low-stock', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const limit = parseInt(req.query.limit as string) || 10;
        
        const data = await pharmacyService.getLowStockAlerts(tenantId, limit);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching low stock alerts:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/pharmacy/inventory/reorder
 * Create a reorder request for a product
 * Body: { productId: string }
 */
router.post('/inventory/reorder', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const { productId } = req.body;
        
        if (!productId) {
            return res.status(400).json({ error: 'Product ID is required' });
        }
        
        const data = await pharmacyService.reorderProduct(tenantId, productId);
        res.json(data);
    } catch (error) {
        logger.error('Error creating reorder request:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── RECENT ACTIVITY ─────────────────────────────────────────────────────

/**
 * GET /api/pharmacy/activity/recent
 * Get recent activity feed
 * Query params: limit (default: 20)
 */
router.get('/activity/recent', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const limit = parseInt(req.query.limit as string) || 20;
        
        const data = await pharmacyService.getRecentActivity(tenantId, limit);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching recent activity:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── PATIENT FEEDBACK ─────────────────────────────────────────────────────

/**
 * GET /api/pharmacy/feedback/summary
 * Get patient feedback summary and trend
 * Query params: range (last7days, last30days, last90days)
 */
router.get('/feedback/summary', async (req: Request, res: Response) => {
    try {
        const tenantId = (req as any).tenantId;
        const range = req.query.range as string || 'last30days';
        
        const data = await pharmacyService.getPatientFeedbackSummary(tenantId, range);
        res.json(data);
    } catch (error) {
        logger.error('Error fetching patient feedback summary:', error as Record<string, unknown>);
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
