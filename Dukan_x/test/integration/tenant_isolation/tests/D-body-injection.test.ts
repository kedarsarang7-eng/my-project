// ============================================================================
// TEST D — Body Injection: tenantId Injected in Request Body
// ============================================================================
// Validates that detectCrossTenantAccess catches tenantId in:
//   1. Top-level body fields (tenantId, tenant_id)
//   2. Nested objects up to depth 3
// ============================================================================

import { authorizedHandler } from '../../../../../my-backend/src/middleware/handler-wrapper';
import { UserRole } from '../../../../../my-backend/src/types/tenant.types';
import { TENANT_A, TENANT_B, USERS, createAuthContext } from '../setup/jwt-factory';
import {
    makeEvent,
    makeContext,
    makeBodyInjectionEvent,
    makeNestedBodyInjectionEvent,
    parseResponseBody,
} from '../setup/event-factory';

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

describe('Attack Vector D — Body Injection (tenantId in Request Body)', () => {
    const ctx = makeContext();

    beforeEach(() => {
        jest.clearAllMocks();
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_ADMIN));
    });

    const dummyHandler = authorizedHandler(
        [UserRole.ADMIN],
        async () => ({ statusCode: 200, body: JSON.stringify({ ok: true }) }),
    );

    // ── Top-Level Body Injection ───────────────────────────────────────────

    it('SECURITY: body.tenantId mismatching JWT → 401 BLOCKED', async () => {
        const event = makeBodyInjectionEvent('valid-token', TENANT_B.tenantId);
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(401);
        const body = parseResponseBody(res);
        expect(body.message).toContain('Cross-tenant access denied');
    });

    it('SECURITY: body.tenant_id (snake_case) mismatching JWT → 401 BLOCKED', async () => {
        const event = makeEvent({
            method: 'POST',
            path: '/api/data',
            authToken: 'valid-token',
            body: { tenant_id: TENANT_B.tenantId, name: 'Evil Product' },
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(401);
    });

    it('PASS: body.tenantId matching JWT → allowed', async () => {
        const event = makeBodyInjectionEvent('valid-token', TENANT_A.tenantId);
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(200);
    });

    it('PASS: body without tenantId → allowed', async () => {
        const event = makeEvent({
            method: 'POST',
            path: '/api/data',
            authToken: 'valid-token',
            body: { name: 'Normal Product', price: 999 },
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);
    });

    // ── Nested Body Injection ──────────────────────────────────────────────

    it('SECURITY: nested body { metadata: { config: { tenantId: B } } } → 401', async () => {
        const event = makeNestedBodyInjectionEvent('valid-token', TENANT_B.tenantId);
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(401);
    });

    it('SECURITY: body { data: { tenantId: B } } → 401 (depth 1)', async () => {
        const event = makeEvent({
            method: 'POST',
            path: '/api/data',
            authToken: 'valid-token',
            body: { data: { tenantId: TENANT_B.tenantId } },
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(401);
    });

    // ── Payload Size Limit ─────────────────────────────────────────────────

    it('SECURITY: oversized payload (> 1MB) → 401 BLOCKED', async () => {
        const event = makeEvent({
            method: 'POST',
            path: '/api/data',
            authToken: 'valid-token',
            body: 'X'.repeat(1048577), // > 1MB
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(401);
    });
});
