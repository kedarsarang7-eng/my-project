// ============================================================================
// JWT Factory — Generate Test Tokens for Tenant Isolation Tests
// ============================================================================
// Creates well-formed JWT-like tokens with controllable claims for testing
// the auth pipeline. These tokens are NOT signed — they are used with mocked
// verifyAuth/verifyToken functions to simulate authenticated requests.
// ============================================================================

import { randomUUID } from 'crypto';

// ── Tenant Constants ─────────────────────────────────────────────────────────

export const TENANT_A = {
    tenantId: 'a1a1a1a1-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    name: 'Alpha Electronics',
    slug: 'alpha-electronics',
} as const;

export const TENANT_B = {
    tenantId: 'b2b2b2b2-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    name: 'Bravo Pharmacy',
    slug: 'bravo-pharmacy',
} as const;

// ── User Constants ───────────────────────────────────────────────────────────

export const USERS = {
    // Tenant A users
    A_ADMIN: {
        sub: 'user-a-admin-0001',
        email: 'admin@alpha.com',
        tenantId: TENANT_A.tenantId,
        role: 'admin',
        businessType: 'electronics',
    },
    A_STAFF: {
        sub: 'user-a-staff-0002',
        email: 'staff@alpha.com',
        tenantId: TENANT_A.tenantId,
        role: 'staff',
        businessType: 'electronics',
    },
    A_MANAGER: {
        sub: 'user-a-mgr-0003',
        email: 'manager@alpha.com',
        tenantId: TENANT_A.tenantId,
        role: 'manager',
        businessType: 'electronics',
    },
    A_VIEWER: {
        sub: 'user-a-viewer-0004',
        email: 'viewer@alpha.com',
        tenantId: TENANT_A.tenantId,
        role: 'viewer',
        businessType: 'electronics',
    },
    A_CA: {
        sub: 'user-a-ca-0005',
        email: 'ca@alpha.com',
        tenantId: TENANT_A.tenantId,
        role: 'ca',
        businessType: 'electronics',
    },
    // Tenant B users
    B_ADMIN: {
        sub: 'user-b-admin-0006',
        email: 'admin@bravo.com',
        tenantId: TENANT_B.tenantId,
        role: 'admin',
        businessType: 'pharmacy',
    },
    B_STAFF: {
        sub: 'user-b-staff-0007',
        email: 'staff@bravo.com',
        tenantId: TENANT_B.tenantId,
        role: 'staff',
        businessType: 'pharmacy',
    },
    B_OWNER: {
        sub: 'user-b-owner-0008',
        email: 'owner@bravo.com',
        tenantId: TENANT_B.tenantId,
        role: 'owner',
        businessType: 'pharmacy',
    },
} as const;

// ── Token Types ──────────────────────────────────────────────────────────────

export interface TokenClaims {
    sub: string;
    email: string;
    'custom:tenant_id'?: string;
    'custom:role'?: string;
    'custom:business_type'?: string;
    'custom:user_role'?: string;
    'custom:license_status'?: string;
    'custom:plan_status'?: string;
    'custom:plan'?: string;
    'custom:signup_pending'?: string;
    tenantId?: string;
    iat?: number;
    exp?: number;
    iss?: string;
    token_use?: string;
}

export interface AuthContext {
    sub: string;
    email: string;
    tenantId: string;
    businessId: string;
    role: string;
    userRole: string;
    businessType: string;
    licenseStatus?: string;
    planStatus: string;
    planTier?: string;
    deviceId?: string;
}

// ── Factory Functions ────────────────────────────────────────────────────────

/**
 * Create a mock AuthContext (what verifyAuth returns after JWT validation).
 * This is used to mock the cognito-auth module directly.
 */
export function createAuthContext(
    user: typeof USERS[keyof typeof USERS],
    overrides?: Partial<AuthContext>,
): AuthContext {
    return {
        sub: user.sub,
        email: user.email,
        tenantId: user.tenantId,
        businessId: user.tenantId, // Default: businessId = tenantId
        role: user.role,
        userRole: user.role,
        businessType: user.businessType,
        licenseStatus: 'active',
        planStatus: 'active',
        planTier: 'pro',
        ...overrides,
    };
}

/**
 * Create a base64-encoded JWT payload (unsigned — for testing header extraction
 * in the lambda/ handlers that decode manually).
 */
export function createUnsignedJwt(claims: Partial<TokenClaims>): string {
    const header = { alg: 'RS256', typ: 'JWT' };
    const payload: TokenClaims = {
        sub: claims.sub || randomUUID(),
        email: claims.email || 'test@test.com',
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 3600,
        iss: 'https://cognito-idp.ap-south-1.amazonaws.com/test-pool',
        token_use: 'id',
        ...claims,
    };

    const b64Header = Buffer.from(JSON.stringify(header)).toString('base64url');
    const b64Payload = Buffer.from(JSON.stringify(payload)).toString('base64url');
    // Fake signature (not verifiable, but structurally valid)
    const fakeSig = Buffer.from('test-signature').toString('base64url');

    return `${b64Header}.${b64Payload}.${fakeSig}`;
}

/**
 * Create a JWT for a specific user (includes tenantId in custom claims).
 */
export function createTokenForUser(user: typeof USERS[keyof typeof USERS]): string {
    return createUnsignedJwt({
        sub: user.sub,
        email: user.email,
        'custom:tenant_id': user.tenantId,
        'custom:role': user.role,
        'custom:business_type': user.businessType,
        'custom:license_status': 'active',
        'custom:plan_status': 'active',
    });
}

/**
 * Create a JWT WITHOUT tenantId claim — used to test Finding #1
 * (x-tenant-id header fallback).
 */
export function createTokenWithoutTenantId(sub: string = 'user-no-tenant'): string {
    return createUnsignedJwt({
        sub,
        email: 'notenant@test.com',
        'custom:role': 'admin',
        // Intentionally NO 'custom:tenant_id'
    });
}

/**
 * Create a JWT with a DIFFERENT tenantId than the one in the header —
 * used to test cross-tenant header injection.
 */
export function createTokenWithMismatchedTenant(
    jwtTenantId: string,
    role: string = 'admin',
): string {
    return createUnsignedJwt({
        sub: `attacker-${randomUUID().substring(0, 8)}`,
        email: 'attacker@evil.com',
        'custom:tenant_id': jwtTenantId,
        'custom:role': role,
    });
}

/**
 * Create a completely malformed token.
 */
export function createMalformedToken(): string {
    return 'not.a.valid.jwt.at.all';
}
