// ============================================================================
// Super Admin Guard — Restricts endpoints to SUPER_ADMIN role only
// ============================================================================
// Used on license management endpoints (generate, manage, upgrade, transfer,
// extend, convert, list) to prevent regular OWNER/ADMIN from accessing.
//
// Checks Cognito JWT custom:role attribute for 'super_admin' value.
// Falls back to Cognito group membership check ('SuperAdmins' group).
// ============================================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { AuthContext, UserRole } from '../types/tenant.types';
import { AuthError } from '../utils/errors';
import { logger } from '../utils/logger';

/**
 * Validate that the authenticated user has SUPER_ADMIN privileges.
 * 
 * Checks two sources:
 * 1. JWT custom:role === 'super_admin'
 * 2. Cognito group membership includes 'SuperAdmins'
 * 
 * Throws AuthError if neither condition is met.
 */
export function requireSuperAdmin(
    auth: AuthContext,
    event: APIGatewayProxyEventV2,
): void {
    // Check 1: Direct role check
    if (auth.role === UserRole.SUPER_ADMIN) {
        return; // Authorized
    }

    // Check 2: Cognito group membership (from JWT claims)
    const groups = extractCognitoGroups(event);
    if (groups.includes('SuperAdmins') || groups.includes('super_admin')) {
        return; // Authorized via group
    }

    // Neither check passed — REJECT
    logger.error('SUPER_ADMIN access denied', {
        userId: auth.sub,
        email: auth.email,
        role: auth.role,
        tenantId: auth.tenantId,
        path: event.rawPath,
        sourceIp: event.requestContext?.http?.sourceIp,
    });

    throw new AuthError(
        'Super Admin access required. This endpoint is restricted to platform administrators only.',
        403,
    );
}

/**
 * Extract Cognito groups from the JWT token claims.
 * Groups are in the 'cognito:groups' claim of the ID token.
 */
function extractCognitoGroups(event: APIGatewayProxyEventV2): string[] {
    try {
        // API Gateway v2 JWT authorizer puts claims in requestContext
        const claims = (event.requestContext as any)?.authorizer?.jwt?.claims;
        if (claims?.['cognito:groups']) {
            const groups = claims['cognito:groups'];
            if (Array.isArray(groups)) return groups;
            if (typeof groups === 'string') return groups.split(',').map((g: string) => g.trim());
        }

        // Fallback: parse from Authorization header directly
        const authHeader = event.headers?.['authorization'] || event.headers?.['Authorization'];
        if (authHeader?.startsWith('Bearer ')) {
            const token = authHeader.split(' ')[1];
            const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
            if (payload['cognito:groups']) {
                return Array.isArray(payload['cognito:groups'])
                    ? payload['cognito:groups']
                    : [payload['cognito:groups']];
            }
        }
    } catch {
        // parse failure — no groups
    }
    return [];
}
