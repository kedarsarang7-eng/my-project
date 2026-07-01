// ============================================================================
// TEST G — RBAC Enforcement: Role-Based Access Control
// ============================================================================
// Validates that:
//   1. Role restrictions are enforced (staff can't access admin endpoints)
//   2. Viewer role has read-only access (POST/PATCH/DELETE blocked)
//   3. Chartered Accountant role restricted to financial routes
// ============================================================================

import { authorizedHandler } from '../../../../../my-backend/src/middleware/handler-wrapper';
import { UserRole } from '../../../../../my-backend/src/types/tenant.types';
import { TENANT_A, USERS, createAuthContext } from '../setup/jwt-factory';
import { makeEvent, makeContext, parseResponseBody } from '../setup/event-factory';

const mockVerifyAuth = jest.fn();
jest.mock('../../../../../my-backend/src/middleware/cognito-auth', () => ({
    verifyAuth: (...args: any[]) => mockVerifyAuth(...args),
}));

jest.mock('../../../../../my-backend/src/config/dynamodb.config', () => ({
    Keys: { tenantPK: (t: string) => `TENANT#${t}`, tenantLicenseSK: () => 'LICENSE' },
    getItem: jest.fn().mockResolvedValue(null),
    queryItems: jest.fn().mockResolvedValue({ items: [] }),
    TABLE_NAME: 'TestTable',
}));

jest.mock('../../../../../my-backend/src/middleware/software-lock', () => ({
    checkSoftwareLock: jest.fn().mockResolvedValue({ allowed: true, lockLevel: 'NONE' }),
    LockLevel: { NONE: 'NONE' },
}));

jest.mock('../../../../../my-backend/src/middleware/cloudwatch-logger', () => ({
    logRequest: jest.fn().mockResolvedValue(undefined),
    logAuthFailure: jest.fn(),
}));

describe('Attack Vector G — RBAC Enforcement', () => {
    const ctx = makeContext();

    beforeEach(() => {
        jest.clearAllMocks();
    });

    // Admin-only handler
    const adminOnlyHandler = authorizedHandler(
        [UserRole.ADMIN, UserRole.OWNER],
        async () => ({ statusCode: 200, body: JSON.stringify({ ok: true }) }),
    );

    // All-roles handler
    const allRolesHandler = authorizedHandler(
        [UserRole.ADMIN, UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF, UserRole.VIEWER],
        async () => ({ statusCode: 200, body: JSON.stringify({ ok: true }) }),
    );

    // Financial-only handler
    const financialHandler = authorizedHandler(
        [UserRole.ADMIN, UserRole.CHARTERED_ACCOUNTANT],
        async () => ({ statusCode: 200, body: JSON.stringify({ ok: true }) }),
    );

    // ── Role Restriction Tests ─────────────────────────────────────────────

    it('RBAC: Admin accessing admin-only endpoint → 200', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_ADMIN));

        const event = makeEvent({ method: 'GET', path: '/admin/settings', authToken: 'valid' });
        const res = await adminOnlyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);
    });

    it('RBAC: Staff accessing admin-only endpoint → 403', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_STAFF));

        const event = makeEvent({ method: 'GET', path: '/admin/settings', authToken: 'valid' });
        const res = await adminOnlyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(403);
    });

    it('RBAC: Staff accessing all-roles endpoint → 200', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_STAFF));

        const event = makeEvent({ method: 'GET', path: '/products', authToken: 'valid' });
        const res = await allRolesHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);
    });

    // ── Viewer Read-Only Enforcement ───────────────────────────────────────

    it('RBAC: Viewer sending GET → 200', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_VIEWER));

        const event = makeEvent({ method: 'GET', path: '/products', authToken: 'valid' });
        const res = await allRolesHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);
    });

    it('RBAC: Viewer sending POST → 403 (read-only)', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_VIEWER));

        const event = makeEvent({
            method: 'POST',
            path: '/products',
            authToken: 'valid',
            body: { name: 'New Product' },
        });
        const res = await allRolesHandler(event, ctx) as any;
        expect(res.statusCode).toBe(403);
    });

    it('RBAC: Viewer sending PATCH → 403 (read-only)', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_VIEWER));

        const event = makeEvent({
            method: 'PATCH',
            path: '/products/123',
            authToken: 'valid',
        });
        const res = await allRolesHandler(event, ctx) as any;
        expect(res.statusCode).toBe(403);
    });

    it('RBAC: Viewer sending DELETE → 403 (read-only)', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_VIEWER));

        const event = makeEvent({
            method: 'DELETE',
            path: '/products/123',
            authToken: 'valid',
        });
        const res = await allRolesHandler(event, ctx) as any;
        expect(res.statusCode).toBe(403);
    });

    // ── CA Route Restriction ───────────────────────────────────────────────

    it('RBAC: CA accessing /reports → 200', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_CA));

        const event = makeEvent({ method: 'GET', path: '/reports/gst', authToken: 'valid' });
        // Use the financial handler which allows CA role
        const res = await financialHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);
    });

    it('RBAC: CA accessing /products (non-financial) → 403', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_CA));

        const event = makeEvent({ method: 'GET', path: '/products', authToken: 'valid' });
        const res = await financialHandler(event, ctx) as any;
        expect(res.statusCode).toBe(403);
    });

    // ── Cross-Tenant + Wrong Role (Double Attack) ──────────────────────────

    it('SECURITY: Tenant B staff trying admin-only on Tenant A → 403', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.B_STAFF));

        const event = makeEvent({
            method: 'GET',
            path: '/admin/settings',
            authToken: 'valid',
            tenantIdHeader: TENANT_A.tenantId, // cross-tenant header injection too
        });
        const res = await adminOnlyHandler(event, ctx) as any;

        // Should be blocked — either by role check (403) or cross-tenant (401)
        expect([401, 403]).toContain(res.statusCode);
    });
});
