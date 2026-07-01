// ============================================================================
// Health Route — GET /health (PUBLIC, no auth)
// ============================================================================
// Requirement 3.5/3.6: the Backend_Supervisor polls this endpoint during the
// startup window and only connects the repository layer once it returns a
// success response. This is the ONLY endpoint exempt from authentication
// (Req 17.7/17.14) — every other route requires a valid local token.
// ============================================================================

import { Router, Request, Response } from 'express';
import { SERVICE_NAME, SERVICE_VERSION, LOOPBACK_PORT } from '../config/constants';
import * as response from '../utils/response';

export function buildHealthRouter(): Router {
    const router = Router();

    router.get('/health', (_req: Request, res: Response) => {
        response.success(res, {
            status: 'healthy',
            service: SERVICE_NAME,
            mode: 'offline_lifetime',
            port: LOOPBACK_PORT,
            version: SERVICE_VERSION,
            uptimeSeconds: Math.round(process.uptime()),
            timestamp: new Date().toISOString(),
        });
    });

    return router;
}
