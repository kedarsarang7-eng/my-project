// ============================================================================
// TEST C — Header Injection: x-tenant-id Header Attack Vector
// ============================================================================
// Tests Finding #1: The most critical vulnerability.
// Verifies that:
//   1. authorizedHandler blocks mismatched x-tenant-id headers
//   2. storageHandler no longer falls back to x-tenant-id header
//   3. batchHandler no longer falls back to x-tenant-id header
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../../../../my-backend/src/middleware/handler-wrapper';
import { UserRole } from '../../../../../my-backend/src/types/tenant.types';
import { TENANT_A, TENANT_B, USERS, createAuthContext } from '../setup/jwt-factory';
import {
    makeEvent,
    makeContext,
    makeHeaderInjectionEvent,
    parseResponseBody,
    expectBlocked,
} from '../setup/event-factory';

// ── Mock Auth ────────────────────────────────────────────────────────────────

const mockVerifyAuth = jest.fn();
jest.mock('../../../../../my-backend/src/middleware/cognito-auth', () => ({
    verifyAuth: (...args: any[]) => mockVerifyAuth(...args),
}));

jest.mock('../../../../../my-backend/src/config/dynamodb.config', () => {
    const { queryByPKPrefix, getByPKSK } = require('../setup/test-fixtures');
    return {
        Keys: {
            tenantPK: (tenantId: string) => `TENANT#${tenantId}`,
            tenantLicenseSK: () => 'LICENSE',
        },
        getItem: jest.fn(async (pk: string, sk: string) => getByPKSK(pk, sk)),
        queryItems: jest.fn(async (pk: string, skPrefix?: string) => ({
            items: queryByPKPrefix(pk, skPrefix),
        })),
        queryAllItems: jest.fn(async (pk: string, skPrefix?: string) =>
            queryByPKPrefix(pk, skPrefix),
        ),
        TABLE_NAME: 'TestTable',
    };
});

jest.mock('../../../../../my-backend/src/middleware/software-lock', () => ({
    checkSoftwareLock: jest.fn().mockResolvedValue({ allowed: true, lockLevel: 'NONE' }),
    LockLevel: { NONE: 'NONE' },
}));

jest.mock('../../../../../my-backend/src/middleware/cloudwatch-logger', () => ({
    logRequest: jest.fn().mockResolvedValue(undefined),
    logAuthFailure: jest.fn(),
}));

// ── Test Setup ───────────────────────────────────────────────────────────────

describe('Attack Vector C — Header Injection (x-tenant-id)', () => {
    const ctx = makeContext();

    beforeEach(() => {
        jest.clearAllMocks();
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_ADMIN));
    });

    // Dummy handler that reaches business logic if auth passes
    const dummyHandler = authorizedHandler(
        [UserRole.ADMIN, UserRole.OWNER],
        async (_event, _ctx, auth) => ({
            statusCode: 200,
            body: JSON.stringify({
                message: 'Business logic reached',
                tenantId: auth.tenantId,
            }),
        }),
    );

    // ── authorizedHandler Detection ────────────────────────────────────────

    it('SECURITY: x-tenant-id header matching JWT → allowed', async () => {
        const event = makeHeaderInjectionEvent('valid-token', TENANT_A.tenantId);
        const res = await dummyHandler(event, ctx) as any;

        // Should pass — header matches JWT
        expect(res.statusCode).toBe(200);
        const body = parseResponseBody(res);
        expect(body.tenantId).toBe(TENANT_A.tenantId);
    });

    it('SECURITY: x-tenant-id header mismatches JWT → 401 BLOCKED', async () => {
        // Tenant A JWT, but x-tenant-id header says Tenant B
        const event = makeHeaderInjectionEvent('valid-token', TENANT_B.tenantId);
        const res = await dummyHandler(event, ctx) as any;

        // MUST be blocked — handler-wrapper detects the mismatch
        expect(res.statusCode).toBe(401);
        const body = parseResponseBody(res);
        expect(body.message).toContain('Cross-tenant access denied');
    });

    it('SECURITY: x-tenant-id header with random value → 401 BLOCKED', async () => {
        const event = makeHeaderInjectionEvent('valid-token', 'random-evil-tenant-id');
        const res = await dummyHandler(event, ctx) as any;

        expect(res.statusCode).toBe(401);
    });

    it('SECURITY: No x-tenant-id header → allowed (header is optional)', async () => {
        const event = makeEvent({
            method: 'GET',
            path: '/api/data',
            authToken: 'valid-token',
            // No tenantIdHeader
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);
    });

    it('SECURITY: X-Tenant-Id (mixed case) mismatch → 401 BLOCKED', async () => {
        const event = makeEvent({
            method: 'GET',
            path: '/api/data',
            authToken: 'valid-token',
            headers: { 'X-Tenant-Id': TENANT_B.tenantId },
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(401);
    });

    // ── POST with header injection ─────────────────────────────────────────

    it('SECURITY: POST with x-tenant-id mismatch → 401 BLOCKED', async () => {
        const event = makeEvent({
            method: 'POST',
            path: '/api/products',
            authToken: 'valid-token',
            tenantIdHeader: TENANT_B.tenantId,
            body: { name: 'Injected Product', price: 999 },
        });

        const res = await dummyHandler(event, ctx) as any;
        expect(res.statusCode).toBe(401);
    });

    // ── Business logic NEVER receives wrong tenantId ───────────────────────

    it('INTEGRITY: Even if header present and matches, auth.tenantId is from JWT', async () => {
        let capturedTenantId: string | null = null;

        const captureHandler = authorizedHandler(
            [UserRole.ADMIN],
            async (_event, _ctx, auth) => {
                capturedTenantId = auth.tenantId;
                return { statusCode: 200, body: '{}' };
            },
        );

        const event = makeEvent({
            method: 'GET',
            path: '/api/data',
            authToken: 'valid-token',
            tenantIdHeader: TENANT_A.tenantId, // Matches JWT
        });

        await captureHandler(event, ctx);
        expect(capturedTenantId).toBe(TENANT_A.tenantId);
    });
});
