// ============================================
// Analytics Controller — Dashboard Data
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoAuth as requireAuth, requireCognitoAdmin as requireAdmin } from '../middleware/cognitoAuth';
import * as analyticsService from '../services/analyticsService';
import { logger } from '../utils/logger';

const router = Router();

router.use(requireAuth, requireAdmin);

/**
 * GET /api/analytics/dashboard
 * Get comprehensive dashboard analytics.
 */
router.get('/dashboard', async (req: Request, res: Response) => {
    try {
        const analytics = await analyticsService.getDashboardAnalytics();
        res.json(analytics);
    } catch (error: any) {
        logger.error('Dashboard analytics error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /api/analytics/logs
 * Get access logs with pagination and filters.
 */
router.get('/logs', async (req: Request, res: Response) => {
    try {
        const page = parseInt(req.query.page as string || '1', 10);
        const limit = parseInt(req.query.limit as string || '50', 10);

        const filters: any = {};
        if (req.query.license_id) filters.license_id = req.query.license_id;
        if (req.query.action) filters.action = req.query.action;
        if (req.query.success !== undefined) filters.success = req.query.success === 'true';

        const result = await analyticsService.getAccessLogs(page, limit, filters);
        res.json({
            data: result.data,
            pagination: {
                page,
                limit,
                total: result.total,
                total_pages: Math.ceil(result.total / limit),
            },
        });
    } catch (error: any) {
        logger.error('Access logs error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
