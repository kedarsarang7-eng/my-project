// ============================================
// Offline Activation Controller
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoAuth as requireAuth, requireCognitoAdmin as requireAdmin } from '../middleware/cognitoAuth';
import * as offlineService from '../services/offlineService';
import { offlineSignSchema, validateBody } from '../utils/validators';
import { logger } from '../utils/logger';

const router = Router();

/**
 * POST /api/offline/sign
 * Admin signs an offline activation request.
 * The admin receives a request file from the user (via email/USB),
 * uploads it here, and receives a signed license file to send back.
 */
router.post('/sign', requireAuth, requireAdmin, async (req: Request, res: Response) => {
    try {
        const data = validateBody(offlineSignSchema, req.body);

        const result = await offlineService.signOfflineRequest(
            data.license_key,
            data.hwid,
            data.nonce,
            req.user!.sub,
            data.device_name
        );

        if (!result.activation) {
            res.status(400).json({ error: result.error, code: 'OFFLINE_SIGN_FAILED' });
            return;
        }

        // Return the signed payload that the user will import
        res.json({
            message: 'Offline activation signed successfully',
            activation_id: result.activation.id,
            signed_payload: result.activation.signed_payload,
            signature: result.activation.signature,
            expires_at: result.activation.expires_at,
        });
    } catch (error: any) {
        if (error.name === 'ZodError') {
            res.status(400).json({ error: 'Validation failed', details: error.errors });
            return;
        }
        logger.error('Offline sign error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
