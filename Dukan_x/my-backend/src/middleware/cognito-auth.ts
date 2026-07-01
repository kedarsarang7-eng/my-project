// ============================================================================
// Cognito JWT Auth Middleware for Lambda
// ============================================================================
// Verifies the Cognito ID Token and extracts tenant context.
// Uses `aws-jwt-verify` which caches JWKS keys automatically.
// ============================================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { cognitoConfig } from '../config/aws.config';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import { logger } from '../utils/logger';

// ── Singleton Verifier (cached across warm Lambda invocations) ───────────
// Accepts tokens from ANY registered app client (Desktop, Mobile, Admin, Legacy)
let verifier: ReturnType<typeof CognitoJwtVerifier.create> | null = null;

function getVerifier() {
    if (!verifier) {
        const clientIds = cognitoConfig.allClientIds;
        verifier = CognitoJwtVerifier.create({
            userPoolId: cognitoConfig.userPoolId,
            tokenUse: 'id', // We use ID tokens (they contain custom attributes)
            clientId: clientIds.length > 0 ? clientIds : cognitoConfig.clientId,
        });
    }
    return verifier;
}

/**
 * Extract and verify the Cognito JWT from the Authorization header.
 *
 * Returns the decoded AuthContext containing:
 * - sub (Cognito user ID)
 * - email
 * - tenant_id (custom attribute)
 * - role (custom attribute)
 * - business_type (custom attribute)
 *
 * @throws Error if token is missing, expired, or invalid.
 */
export async function verifyAuth(event: APIGatewayProxyEventV2): Promise<AuthContext> {
    const authHeader = event.headers?.authorization || event.headers?.Authorization;

    if (!authHeader) {
        throw new AuthError('Missing Authorization header');
    }

    const token = authHeader.startsWith('Bearer ')
        ? authHeader.slice(7)
        : authHeader;

    if (!token) {
        throw new AuthError('Empty Bearer token');
    }

    try {
        const payload = await getVerifier().verify(token);

        // Extract custom attributes injected during Cognito signup
        const tenantId = (payload as Record<string, unknown>)['custom:tenant_id'] as string;
        const role = (payload as Record<string, unknown>)['custom:role'] as string;
        const businessType = (payload as Record<string, unknown>)['custom:business_type'] as string;

        if (!tenantId) {
            throw new AuthError('Token missing custom:tenant_id attribute');
        }

        const authContext: AuthContext = {
            sub: payload.sub,
            email: payload.email as string,
            tenantId,
            role: (role as UserRole) || UserRole.STAFF,
            businessType: (businessType as BusinessType) || BusinessType.OTHER,
        };

        logger.debug('Auth verified', {
            sub: authContext.sub,
            tenantId: authContext.tenantId,
            role: authContext.role,
        });

        return authContext;
    } catch (err) {
        if (err instanceof AuthError) throw err;

        logger.warn('JWT verification failed', {
            error: (err as Error).message,
        });
        throw new AuthError('Invalid or expired token');
    }
}

/**
 * Check if the authenticated user has one of the required roles.
 */
export function requireRole(auth: AuthContext, ...allowedRoles: UserRole[]): void {
    if (!allowedRoles.includes(auth.role)) {
        throw new AuthError(
            `Role '${auth.role}' not authorized. Required: ${allowedRoles.join(', ')}`,
            403
        );
    }
}

/**
 * Custom auth error with HTTP status code.
 */
export class AuthError extends Error {
    public statusCode: number;

    constructor(message: string, statusCode = 401) {
        super(message);
        this.name = 'AuthError';
        this.statusCode = statusCode;
    }
}
