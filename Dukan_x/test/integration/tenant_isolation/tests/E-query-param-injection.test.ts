// ============================================================================
// TEST E — Query Parameter Injection: tenantId in URL Query String
// ============================================================================
// Validates detectCrossTenantAccess checks for tenantId, tenant_id, tid
// in query string parameters.
// ============================================================================

import { authorizedHandler } from '../../../../../my-backend/src/middleware/handler-wrapper';
import { UserRole } from '../../../../../my-backend/src/types/tenant.types';
import { TENANT_A, TENANT_B, USERS, createAuthContext } from '../setup/jwt-factory';
import { makeEvent, makeContext, makeQueryInjectionEvent, parseResponseBody } from '../setup/event-factory';

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

describe('Attack Vector E — Query Parameter Injection', () => {
    const ctx = makeContext();

    beforeEach(() => {
        jest.clearAllMocks();
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_ADMIN));
    });

    const dummyHandler = authorizedHandler(
        [UserRole.ADMIN],
        async () => ({ statusCode: 200, body: JSON.stringify({ ok: true }) }),
    );

    it('SECURITY: ?tenantId=B → 401 BLOCKED', async () => {
        const event = makeQueryInjectionEvent('valid-token', TENANT_B.tenantId, 'tenantId');
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(401);
        const body = parseResponseBody(res);
        expect(body.message).toContain('Cross-tenant access denied');
    });

    it('SECURITY: ?tenant_id=B → 401 BLOCKED', async () => {
        const event = makeQueryInjectionEvent('valid-token', TENANT_B.tenantId, 'tenant_id');
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(401);
    });

    it('SECURITY: ?tid=B → 401 BLOCKED', async () => {
        const event = makeQueryInjectionEvent('valid-token', TENANT_B.tenantId, 'tid');
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(401);
    });

    it('PASS: ?tenantId=A (matching JWT) → allowed', async () => {
        const event = makeQueryInjectionEvent('valid-token', TENANT_A.tenantId, 'tenantId');
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(200);
    });

    it('PASS: No tenant query params → allowed', async () => {
        const event = makeEvent({
            method: 'GET',
            path: '/api/products',
            authToken: 'valid-token',
            queryStringParameters: { page: '1', limit: '20' },
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);
    });
});
