// ============================================================================
// require-auth — authentication middleware (RS256 local-JWT enforcement)
// ============================================================================
// Requirement 17.7 / 17.14: the Local_Backend requires valid authentication
// credentials on EVERY endpoint except /health, and a request to any other
// endpoint that arrives without valid credentials is rejected WITHOUT executing
// the requested operation, returning an authentication-required error.
//
// This middleware is the single enforcement point mounted ahead of the API
// router in app.ts (only /health and the pre-token /auth/* endpoints sit in
// front of it). It performs REAL verification by reusing the task-9.1
// Offline_Auth_Service.verifyToken, which validates the RS256 signature, issuer
// and expiry and — together with the Session_Registry — rejects tokens whose
// session has been invalidated (e.g. after a role change, Req 9.6).
//
// Fail closed: the Offline_Auth_Service is provisioned at startup through the
// auth-service-registry seam. Until it is wired, this middleware REJECTS every
// non-health request rather than letting it through, so the backend is never
// briefly open during startup.
//
// On success the verified claims (userId / tenantId / role) are attached to the
// request for downstream handlers; the route handler runs ONLY after a token
// verifies (Req 17.14).
// ============================================================================

import { Request, Response, NextFunction } from 'express';
import * as response from '../utils/response';
import { getOfflineAuthService } from '../services/auth-service-registry';
import { logger } from '../utils/logger';

/** The verified identity attached to an authenticated request. */
export interface AuthContext {
    /** The authenticated user id (from the token `sub`). */
    userId: string;
    /** The tenant the user belongs to. */
    tenantId: string;
    /** The user's RBAC role, carried for downstream enforcement. */
    role: string;
    /** Optional session id used for targeted invalidation (Req 9.6). */
    sessionId?: string;
}

/** Augments Express requests with the verified auth context. */
export interface AuthedRequest extends Request {
    auth?: AuthContext;
}

/**
 * Enforce valid authentication on a non-health endpoint (Req 17.7 / 17.14).
 *
 * A request is allowed to proceed ONLY when it carries a bearer token that the
 * Offline_Auth_Service verifies (valid RS256 signature, correct issuer, not
 * expired, and — when a Session_Registry is wired — backed by an active
 * session). In every other case (no token, no auth service wired, or a
 * token that fails verification for any reason) the request is rejected with
 * the standard authentication-required error envelope and the route handler is
 * NOT invoked.
 */
export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction): void {
    const header = req.header('authorization') || req.header('Authorization');
    const token = header?.toLowerCase().startsWith('bearer ')
        ? header.slice(7).trim()
        : undefined;

    // No bearer credential supplied → reject without executing (Req 17.14).
    if (!token) {
        response.unauthorized(res, 'Authentication required');
        return;
    }

    // Fail closed: without the live Offline_Auth_Service we cannot verify the
    // token cryptographically, so we MUST reject rather than allow through.
    const service = getOfflineAuthService();
    if (!service) {
        logger.warn('Auth rejected: Offline_Auth_Service is not wired');
        response.unauthorized(res, 'Authentication required');
        return;
    }

    // Reuse task-9.1 verification (RS256 + session-active check). Any failure —
    // tampered/invalid signature, wrong issuer, expiry, or an invalidated
    // session — throws and is treated uniformly as an auth failure.
    try {
        const claims = service.verifyToken(token);
        req.auth = {
            userId: claims.userId,
            tenantId: claims.tenantId,
            role: claims.role,
            sessionId: claims.sessionId,
        };
    } catch (err) {
        logger.warn('Auth rejected: token verification failed', {
            error: err instanceof Error ? err.message : 'unknown error',
        });
        response.unauthorized(res, 'Authentication required');
        return;
    }

    // Token verified — let the requested operation run (Req 17.14).
    next();
}
