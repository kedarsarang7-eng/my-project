// ============================================================================
// App — Express application assembly
// ============================================================================
// Builds the Express app for the packaged Local_Backend: shared middleware,
// the public /health router (Req 3.5/3.6), and the authenticated API contract
// router (Req 3.2/4.2). Kept separate from server.ts so it can be exercised by
// integration tests (task 2.4) without binding a socket.
// ============================================================================

import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import { buildHealthRouter } from './routes/health.routes';
import { buildAuthRouter } from './routes/auth.routes';
import { buildApiRouter } from './routes/api.routes';
import { requireAuth } from './middleware/require-auth';
import * as response from './utils/response';
import { logger } from './utils/logger';

export function buildApp(): Application {
    const app = express();

    // ── Middleware ──────────────────────────────────────────────────────────
    // Loopback-only deployment: the packaged desktop app is the sole origin.
    app.use(cors({ origin: false }));
    app.use(express.json({ limit: '10mb' }));

    // ── Public health endpoint (no auth) ─────────────────────────────────────
    app.use('/', buildHealthRouter());

    // ── Public auth endpoints (pre-token: login/signup/refresh) ──────────────
    // These are how a caller OBTAINS a token, so they cannot sit behind auth.
    app.use('/', buildAuthRouter());

    // ── Authenticated API surface (mirrors AWS contracts) ────────────────────
    // Req 17.7/17.14: everything except /health and the auth endpoints requires
    // valid auth.
    app.use('/', requireAuth, buildApiRouter());

    // ── 404 — same envelope as the AWS backend ───────────────────────────────
    app.use((_req: Request, res: Response) => {
        response.notFound(res, 'Endpoint');
    });

    // ── Error handler — standard envelope, scrubbed logging ──────────────────
    app.use((err: Error, _req: Request, res: Response, _next: express.NextFunction) => {
        logger.error('Local_Backend request error', { error: err.message });
        response.internalError(res);
    });

    return app;
}
