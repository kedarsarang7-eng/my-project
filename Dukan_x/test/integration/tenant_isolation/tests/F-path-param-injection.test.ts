// ============================================================================
// TEST F — Path Parameter Injection: tenantId in URL Path
// ============================================================================
// Validates detectCrossTenantAccess checks path parameters for tenantId.
// Also validates the legacy validateTenantAccess in tenantHandler.
// ============================================================================

import { authorizedHandler } from '../../../../../my-backend/src/middleware/handler-wrapper';
import { UserRole } from '../../../../../my-backend/src/types/tenant.types';
import { TENANT_A, TENANT_B, USERS, createAuthContext } from '../setup/jwt-factory';
import { makeEvent, makeContext, makePathInjectionEvent, parseResponseBody } from '../setup/event-factory';

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

describe('Attack Vector F — Path Parameter Injection', () => {
    const ctx = makeContext();

    beforeEach(() => {
        jest.clearAllMocks();
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_ADMIN));
    });

    const dummyHandler = authorizedHandler(
        [UserRole.ADMIN],
        async (_event, _ctx, auth) => ({
            statusCode: 200,
            body: JSON.stringify({ tenantId: auth.tenantId }),
        }),
    );

    it('SECURITY: pathParam tenantId=B, JWT=A → 401 BLOCKED', async () => {
        const event = makePathInjectionEvent('valid-token', TENANT_B.tenantId);
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(401);
        const body = parseResponseBody(res);
        expect(body.message).toContain('Cross-tenant access denied');
    });

    it('PASS: pathParam tenantId=A, JWT=A → allowed', async () => {
        const event = makePathInjectionEvent('valid-token', TENANT_A.tenantId);
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(200);
    });

    it('SECURITY: pathParam tenant_id=B → 401 BLOCKED', async () => {
        const event = makeEvent({
            method: 'GET',
            path: `/tenants/${TENANT_B.tenantId}`,
            authToken: 'valid-token',
            pathParameters: { tenant_id: TENANT_B.tenantId },
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(401);
    });

    it('PASS: No tenant-related path params → allowed', async () => {
        const event = makeEvent({
            method: 'GET',
            path: '/products/prod-123',
            authToken: 'valid-token',
            pathParameters: { productId: 'prod-123' },
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);
    });
});
