// ============================================
// HWID Controller — Admin HWID Management
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoAuth as requireAuth, requireCognitoAdmin as requireAdmin } from '../middleware/cognitoAuth';
import * as hwidService from '../services/hwidService';
import { logger } from '../utils/logger';

const router = Router();

router.use(requireAuth, requireAdmin);

/**
 * GET /api/licenses/:id/hwids
 * List all HWID bindings for a license.
 */
router.get('/:id/hwids', async (req: Request, res: Response) => {
    try {
        const bindings = await hwidService.getBindings(req.params.id);
        res.json({ data: bindings, total: bindings.length });
    } catch (error: any) {
        logger.error('Get HWIDs error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * DELETE /api/licenses/:id/hwids/:hwidId
 * Reset a specific HWID binding. (The "Admin Reset HWID" button)
 */
router.delete('/:id/hwids/:hwidId', async (req: Request, res: Response) => {
    try {
        const reset = await hwidService.resetHwid(req.params.hwidId);
        if (!reset) {
            res.status(404).json({ error: 'HWID binding not found' });
            return;
        }
        res.json({ message: 'HWID binding reset successfully' });
    } catch (error: any) {
        logger.error('Reset HWID error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * DELETE /api/licenses/:id/hwids
 * Reset ALL HWID bindings for a license.
 */
router.delete('/:id/hwids', async (req: Request, res: Response) => {
    try {
        const count = await hwidService.resetAllHwids(req.params.id);
        res.json({ message: `${count} HWID binding(s) reset`, count });
    } catch (error: any) {
        logger.error('Reset all HWIDs error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
