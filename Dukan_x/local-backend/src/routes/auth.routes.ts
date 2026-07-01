// ============================================================================
// Auth Routes — Offline_Auth_Service surface (PUBLIC: pre-token endpoints)
// ============================================================================
// These are the credential-exchange endpoints (Cognito equivalent). They are
// mounted BEFORE requireAuth because a caller cannot present a local JWT until
// it has logged in — they are the means of obtaining a token, so requiring one
// here would be circular. Every OTHER endpoint stays behind requireAuth
// (Req 17.7/17.14); /health and these auth endpoints are the only public ones.
//
// Task 9.1 implements POST /auth/login against the Offline_Auth_Service.
// Task 9.2 maps the service's rate-limit/lockout outcomes onto distinct HTTP
// responses (429 RATE_LIMITED with Retry-After / 423 ACCOUNT_LOCKED with
// Retry-After), while still NOT issuing a token. signup and refresh remain
// scaffold stubs (their store-write and session-management behavior belong to
// later tasks).
// ============================================================================

import { Router, Request, Response } from 'express';
import * as response from '../utils/response';
import { getOfflineAuthService } from '../services/auth-service-registry';
import { validateRequest } from '../middleware/validate-request';

export function buildAuthRouter(): Router {
    const router = Router();

    // ── Login (Req 9.1 / 9.2 / 9.9) ─────────────────────────────────────────
    // Schema validation runs first (Req 17.8 / 17.15): the body must carry a
    // password plus at least a username or email. The handler keeps its own
    // identifier resolution (username OR email) because the schema cannot
    // express "one of two optional fields"; both are validated as optional
    // strings here and the cross-field requirement is enforced below.
    router.post(
        '/auth/login',
        validateRequest({
            body: {
                username: { type: 'string', maxLength: 320 },
                email: { type: 'string', maxLength: 320 },
                password: { type: 'string', required: true, nonEmpty: true, maxLength: 1024 },
            },
        }),
        async (req: Request, res: Response) => {
            const service = getOfflineAuthService();
            if (!service) {
                // The SQLCipher-backed user lookup is wired at startup by later
                // store tasks; until then the endpoint is not operational.
                response.notImplemented(res, 'auth.login');
                return;
            }

            const body = (req.body ?? {}) as Record<string, unknown>;
            // Accept username or email as the login identifier.
            const identifier =
                typeof body.username === 'string'
                    ? body.username
                    : typeof body.email === 'string'
                      ? body.email
                      : undefined;
            const password = typeof body.password === 'string' ? body.password : undefined;

            if (!identifier || !password) {
                response.badRequest(res, 'username (or email) and password are required.');
                return;
            }

            const result = await service.authenticate(identifier, password);

            if (!result.ok) {
                switch (result.reason) {
                    // Req 9.7: too many recent failures → temporarily rate limited.
                    case 'rate_limited':
                        res.setHeader('Retry-After', String(result.retryAfterSeconds));
                        response.error(res, 429, 'RATE_LIMITED', result.message, {
                            retryAfterSeconds: result.retryAfterSeconds,
                        });
                        return;
                    // Req 9.8: account locked for the 30-minute lock window.
                    case 'account_locked':
                        res.setHeader('Retry-After', String(result.retryAfterSeconds));
                        response.error(res, 423, 'ACCOUNT_LOCKED', result.message, {
                            retryAfterSeconds: result.retryAfterSeconds,
                        });
                        return;
                    // Req 9.9: invalid credentials → no token, invalid-credentials error.
                    case 'invalid_credentials':
                    default:
                        response.unauthorized(res, result.message);
                        return;
                }
            }

            response.success(res, {
                token: result.token,
                tokenType: 'Bearer',
                expiresAt: result.expiresAt,
                user: result.user,
            });
        },
    );

    // ── Signup / Refresh — scaffold stubs (later tasks) ─────────────────────
    router.post('/auth/signup', (_req: Request, res: Response) => {
        response.notImplemented(res, 'auth.signup');
    });
    router.post('/auth/refresh', (_req: Request, res: Response) => {
        response.notImplemented(res, 'auth.refresh');
    });

    return router;
}
