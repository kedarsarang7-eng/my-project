// ============================================
// Cognito JWT Auth Middleware — Owner/Staff Routes
// ============================================
// Verifies Cognito ID tokens for business owner and staff routes.
// Uses `aws-jwt-verify` which caches JWKS keys automatically.
// ============================================

import { Request, Response, NextFunction } from 'express';
import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { logger } from '../utils/logger';

// ---- Types ----

export interface CognitoJwtPayload {
    sub: string;
    email: string;
    role: string;
    tenantId: string | null;
    groups: string[];
    type: 'cognito';
}

declare global {
    namespace Express {
        interface Request {
            cognitoUser?: CognitoJwtPayload;
        }
    }
}

// ---- Cognito Verifier (Singleton) ----

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

        verifier = CognitoJwtVerifier.create({
            userPoolId,
            tokenUse: 'id',
            clientId: clientIds.length > 0 ? clientIds : null,
        });
    }
    return verifier;
}

// ---- Middleware: Require Cognito Auth ----

export function requireCognitoAuth(req: Request, res: Response, next: NextFunction): void {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({
            error: 'Authentication required',
            code: 'AUTH_MISSING',
        });
        return;
    }

    const token = authHeader.split(' ')[1];

    getVerifier()!
        .verify(token)
        .then((payload: any) => {
            const claims = payload as Record<string, unknown>;

            const cognitoUser: CognitoJwtPayload = {
                sub: payload.sub,
                email: (claims.email as string) || '',
                role: (claims['custom:role'] as string) || 'staff',
                tenantId: (claims['custom:tenant_id'] as string) || null,
                groups: ((claims['cognito:groups'] as string[]) || []),
                type: 'cognito',
            };

            req.cognitoUser = cognitoUser;

            // Backward compatibility
            (req as any).user = {
                sub: cognitoUser.sub,
                email: cognitoUser.email,
                role: _mapCognitoRoleToLegacy(cognitoUser),
                type: 'access',
            };

            next();
        })
        .catch((error: any) => {
            if (error.message?.includes('expired')) {
                res.status(401).json({
                    error: 'Token expired',
                    code: 'AUTH_EXPIRED',
                });
                return;
            }

            logger.warn('Invalid Cognito JWT token', { error: error.message });
            res.status(401).json({
                error: 'Invalid token',
                code: 'AUTH_INVALID',
            });
        });
}

// ---- Helper ----

function _mapCognitoRoleToLegacy(user: CognitoJwtPayload): string {
    if (user.groups.includes('SuperAdmin')) return 'superadmin';
    if (user.groups.includes('BusinessOwner')) return 'admin';
    if (user.role === 'owner') return 'admin';
    if (user.role === 'admin') return 'admin';
    return user.role || 'staff';
}
