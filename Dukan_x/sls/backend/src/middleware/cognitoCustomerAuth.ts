// ============================================
// Customer Auth Middleware — Cognito JWT Verification
// ============================================
// REPLACES: customerAuth.ts (Firebase Admin SDK)
//
// Verifies Cognito ID tokens from the Customer Mobile App.
// Uses `aws-jwt-verify` which caches JWKS keys automatically.
//
// Flow:
//   1. Customer logs in via Cognito in Flutter
//   2. Flutter sends Cognito ID token in Authorization header
//   3. This middleware verifies the token via JWKS
//   4. Sets req.customerId and req.customer with verified claims
//
// ROLLBACK: If issues arise, switch back to customerAuth.ts
//           by changing the import in customerController.ts
// ============================================

import { Request, Response, NextFunction } from 'express';
import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { logger } from '../utils/logger';

// ---- Types ----

export interface CognitoCustomerIdentity {
    uid: string;          // Cognito sub
    email: string | null;
    name: string | null;
    phone: string | null;
    emailVerified: boolean;
    tenantId: string | null;
    role: string | null;
    firebaseUid: string | null; // Preserved for migration mapping
}

declare global {
    namespace Express {
        interface Request {
            customer?: CognitoCustomerIdentity;
        }
    }
}

// ---- Cognito Verifier (Singleton, cached across requests) ----

let verifier: ReturnType<typeof CognitoJwtVerifier.create> | null = null;

function getVerifier() {
    if (!verifier) {
        const userPoolId = process.env.COGNITO_USER_POOL_ID;
        const clientIds = [
            process.env.COGNITO_CLIENT_ID,
            process.env.COGNITO_DESKTOP_CLIENT_ID,
            process.env.COGNITO_MOBILE_CLIENT_ID,
            process.env.COGNITO_ADMIN_CLIENT_ID,
        ].filter(Boolean) as string[];

        if (!userPoolId) {
            throw new Error('COGNITO_USER_POOL_ID environment variable is required');
        }

        if (clientIds.length === 0) {
            throw new Error('At least one COGNITO_*_CLIENT_ID environment variable is required');
        }

        verifier = CognitoJwtVerifier.create({
            userPoolId,
            tokenUse: 'id',
            clientId: clientIds,
        });
    }
    return verifier;
}

// ---- Middleware ----

/**
 * requireCognitoCustomerAuth — Verifies Cognito ID token from Authorization header.
 *
 * Expected header: Authorization: Bearer <cognito-id-token>
 *
 * On success: sets req.customer and req.customerId
 * On failure: returns 401
 */
export async function requireCognitoCustomerAuth(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            res.status(401).json({
                error: 'Authentication required. Send Cognito ID token in Authorization header.',
                code: 'AUTH_REQUIRED',
            });
            return;
        }

        const idToken = authHeader.substring(7);

        if (!idToken || idToken.trim() === '') {
            res.status(401).json({
                error: 'Empty authentication token',
                code: 'AUTH_EMPTY_TOKEN',
            });
            return;
        }

        // Verify Cognito ID token (JWKS keys are cached automatically)
        const payload = await getVerifier().verify(idToken);

        // Extract customer identity from JWT claims
        const claims = payload as Record<string, unknown>;
        const customer: CognitoCustomerIdentity = {
            uid: payload.sub,
            email: (claims.email as string) || null,
            name: (claims.name as string) || null,
            phone: (claims.phone_number as string) || null,
            emailVerified: (claims.email_verified as boolean) || false,
            tenantId: (claims['custom:tenant_id'] as string) || null,
            role: (claims['custom:role'] as string) || null,
            firebaseUid: (claims['custom:firebase_uid'] as string) || null,
        };

        // Attach to request
        req.customer = customer;
        req.customerId = customer.uid;

        logger.debug('Cognito customer authenticated', {
            uid: customer.uid,
            email: customer.email,
            role: customer.role,
        });

        next();
    } catch (error: any) {
        // Handle specific JWT verification errors
        if (error.message?.includes('Token expired')) {
            res.status(401).json({
                error: 'Token expired. Please refresh your session.',
                code: 'AUTH_TOKEN_EXPIRED',
            });
            return;
        }

        if (error.message?.includes('Token not yet valid') ||
            error.message?.includes('invalid')) {
            res.status(401).json({
                error: 'Invalid authentication token',
                code: 'AUTH_INVALID_TOKEN',
            });
            return;
        }

        logger.error('Cognito customer auth error', { error: error.message });
        res.status(401).json({
            error: 'Authentication failed',
            code: 'AUTH_FAILED',
        });
    }
}

/**
 * optionalCognitoCustomerAuth — Same as requireCognitoCustomerAuth but does NOT reject
 * if no token is present. Used for public endpoints that optionally
 * personalize responses for authenticated users.
 */
export async function optionalCognitoCustomerAuth(req: Request, res: Response, next: NextFunction): Promise<void> {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        next();
        return;
    }

    await requireCognitoCustomerAuth(req, res, next);
}
