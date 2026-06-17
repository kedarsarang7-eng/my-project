// ============================================================================
// JWT Auth Middleware for Lambda — Cognito (prod) + Keycloak (local)
// ============================================================================
// Verifies the JWT and extracts tenant context.
// In production: uses aws-jwt-verify with Cognito JWKS (cached).
// In local mode: uses generic JWKS verification against Keycloak.
// ============================================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { cognitoConfig } from '../config/aws.config';
import { config } from '../config/environment';
import { AuthContext, normalizeBusinessType } from '../types/tenant.types';
import { AuthError } from '../utils/errors';
import { logger } from '../utils/logger';
import { normalizeJwtRole } from '../utils/jwt-role';

// ── Auth Mode Detection ──────────────────────────────────────────────────
const IS_LOCAL = config.app.isLocal;
const USE_KEYCLOAK = config.local.authProvider === 'keycloak';

// ── Cognito Verifier (production) ────────────────────────────────────────
let cognitoVerifier: ReturnType<typeof CognitoJwtVerifier.create> | null = null;

function getCognitoVerifier() {
    if (!cognitoVerifier) {
        const clientIds = cognitoConfig.allClientIds;
        cognitoVerifier = CognitoJwtVerifier.create({
            userPoolId: cognitoConfig.userPoolId,
            tokenUse: 'id',
            clientId: clientIds.length > 0 ? clientIds : cognitoConfig.clientId,
        });
    }
    return cognitoVerifier;
}

// ── Keycloak JWKS Verifier (local mode) ──────────────────────────────────
// Uses jose library for generic JWKS verification when available,
// falls back to manual JWT decode for local development.
async function verifyKeycloakToken(token: string): Promise<Record<string, unknown>> {
    try {
        // Try jose for proper RS256 verification
        const { createRemoteJWKSet, jwtVerify } = await import('jose');
        const jwksUri = config.keycloak.jwksUri
            || 'http://localhost:8080/realms/dukanx/protocol/openid-connect/certs';
        const JWKS = createRemoteJWKSet(new URL(jwksUri));
        const { payload } = await jwtVerify(token, JWKS, {
            algorithms: ['RS256'],
        });
        return payload as Record<string, unknown>;
    } catch (joseErr: any) {
        // If jose is not installed, decode the JWT without signature verification
        // (acceptable for local development only).
        if (joseErr.code === 'MODULE_NOT_FOUND' || joseErr.code === 'ERR_MODULE_NOT_FOUND') {
            logger.warn('[LOCAL] jose not installed — decoding JWT without signature verification');
            const parts = token.split('.');
            if (parts.length !== 3) throw new AuthError('Invalid JWT format');
            const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
            return payload;
        }
        throw joseErr;
    }
}

// ── Unified Token Verifier ───────────────────────────────────────────────
async function verifyToken(token: string): Promise<Record<string, unknown>> {
    if (IS_LOCAL && USE_KEYCLOAK) {
        logger.debug('[LOCAL] Verifying JWT via Keycloak JWKS');
        return verifyKeycloakToken(token);
    }
    // Production path: Cognito jwt-verify
    const payload = await getCognitoVerifier().verify(token);
    return payload as Record<string, unknown>;
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
 * @throws AuthError if token is missing, expired, or invalid.
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
        const payload = await verifyToken(token) as any;

        const tenantId = (payload)['custom:tenant_id'] as string
            || (payload)['tenantId'] as string;
        const businessId = (payload as Record<string, unknown>)['custom:business_id'] as string;
        const role = (payload as Record<string, unknown>)['custom:role'] as string;
        const userRole = (payload as Record<string, unknown>)['custom:user_role'] as string;
        const businessType = (payload as Record<string, unknown>)['custom:business_type'] as string;
        const licenseStatus = (payload as Record<string, unknown>)['custom:license_status'] as string;
        const planStatus = (payload as Record<string, unknown>)['custom:plan_status'] as string;
        // F004: Extract plan tier from JWT so plan-guard fast path can use it
        // without a DynamoDB round-trip on every request.
        const planTier = (payload as Record<string, unknown>)['custom:plan'] as string | undefined;

        if (licenseStatus === 'suspended' || licenseStatus === 'banned' || licenseStatus === 'revoked') {
            logger.warn('Auth denied: License revoked/suspended', { sub: payload.sub, licenseStatus });
            throw new AuthError(`Account access denied. License status: ${licenseStatus}`);
        }

        let finalTenantId = tenantId;
        let finalRole = role;

        if (!finalTenantId) {
            // HIGH-006 FIX: Only auto-provision during explicit signup flow.
            // Check for 'custom:signup_pending' attribute set by the signup Lambda.
            // Without this guard, ANY Cognito user could trigger free tenant creation
            // by calling any authenticated endpoint.
            const signupPending = payload['custom:signup_pending'] as string;
            if (signupPending !== 'true') {
                logger.warn('Auto-provision blocked: no signup_pending marker', {
                    sub: payload.sub,
                    email: payload.email,
                });
                throw new AuthError(
                    'Account setup incomplete. Please complete the signup process first.'
                );
            }

            try {
                const { AuthService } = require('../services/auth.service');
                const authService = new AuthService();
                // We attempt to auto-provision based on sub and email.
                const provisionResult = await authService.autoProvision(payload.sub, payload.email as string);

                finalTenantId = provisionResult.tenantId;
                finalRole = provisionResult.role;
            } catch (authErr) {
                logger.error('Auto-provisioning failed', { sub: payload.sub, error: (authErr as Error).message });
                throw new AuthError('Failed to initialize account during first login');
            }
        }

        // Validate tenant_id is proper UUID format before using in DB queries
        // Non-UUID values could cause injection or invalid key construction
        const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (finalTenantId && !UUID_REGEX.test(finalTenantId)) {
            logger.warn('Invalid tenant_id format in JWT', {
                sub: payload.sub,
                tenantId: finalTenantId,
            });
            throw new AuthError(
                'Invalid Tenant ID format. Expected UUID. Please contact support if this persists.'
            );
        }

        // Tenant license status check via DynamoDB (replaces dead Redis shim)
        const { getItem: getTenantItem, Keys: TenantKeys } = await import('../config/dynamodb.config');
        const licenseRecord = await getTenantItem<Record<string, any>>(
            TenantKeys.tenantPK(finalTenantId), TenantKeys.tenantLicenseSK()
        );
        
        if (licenseRecord) {
            const dbLicenseStatus = licenseRecord.status || licenseRecord.licenseStatus;
            
            // Hard blocks
            if (dbLicenseStatus === 'suspended' || dbLicenseStatus === 'banned' || dbLicenseStatus === 'revoked') {
                logger.warn('Auth denied: Tenant license revoked in DB', { sub: payload.sub, tenantId: finalTenantId, status: dbLicenseStatus });
                throw new AuthError(`Account access denied. License status: ${dbLicenseStatus}`);
            }

            // Grace period enforcement (72 hours)
            if (licenseRecord.expiresAt) {
                const expiresAt = new Date(licenseRecord.expiresAt).getTime();
                const now = Date.now();
                const gracePeriodMs = 72 * 60 * 60 * 1000; // 72 hours
                
                if (now > expiresAt && now > expiresAt + gracePeriodMs) {
                    logger.warn('Auth denied: License expired beyond grace period', { 
                        sub: payload.sub, 
                        tenantId: finalTenantId, 
                        expiresAt: licenseRecord.expiresAt 
                    });
                    throw new AuthError('License expired. Grace period ended. Please renew to restore access.');
                }
            }
        }

        const authContext: AuthContext = {
            sub: payload.sub,
            email: payload.email as string,
            tenantId: finalTenantId,
            businessId: businessId || finalTenantId,
            role: normalizeJwtRole(finalRole),
            userRole: userRole || normalizeJwtRole(finalRole),
            businessType: normalizeBusinessType(businessType),
            licenseStatus,
            planStatus: planStatus || 'active',
            // F004: Carry planTier from JWT claim so plan-guard uses the fast path.
            planTier: planTier || undefined,
            deviceId: event.headers?.['x-device-id'] || undefined,
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
