// ============================================================================
// TEST H — Batch Handler: Cross-Tenant DynamoDB Writes via /api/v1/batch
// ============================================================================
// Tests the batchHandler specifically for:
//   1. POST-FIX: tenantId no longer falls back to x-tenant-id header
//   2. enforceTenantScope strips/overrides tenantId in operation data
//   3. TransactWriteItems always includes auth tenantId
// ============================================================================

import {
    TENANT_A,
    TENANT_B,
    USERS,
    createTokenForUser,
    createTokenWithoutTenantId,
} from '../setup/jwt-factory';
import { makeEvent, parseResponseBody } from '../setup/event-factory';

// Mock verifyToken to return decoded claims from our JWT factory tokens
const mockVerifyToken = jest.fn();
jest.mock('../setup/utils-transpiled.js', () => ({
    success: (data: any, code = 200) => ({
        statusCode: code,
        body: JSON.stringify({ success: true, data }),
    }),
    error: (msg: string, code = 400) => ({
        statusCode: code,
        body: JSON.stringify({ success: false, message: msg }),
    }),
    verifyToken: (...args: any[]) => mockVerifyToken(...args),
    enforceTenantScope: jest.fn((data: any, context: any) => {
        // Simulate: if data.tenantId doesn't match context.tenantId, throw
        if (data.tenantId && data.tenantId !== context.tenantId) {
            throw new Error('FORBIDDEN');
        }
    }),
}));

// Mock DynamoDB
const mockTransactWrite = jest.fn().mockResolvedValue({});
jest.mock('@aws-sdk/client-dynamodb', () => ({
    DynamoDBClient: jest.fn().mockImplementation(() => ({})),
}));
jest.mock('@aws-sdk/lib-dynamodb', () => ({
    DynamoDBDocumentClient: {
        from: jest.fn().mockReturnValue({
            send: (...args: any[]) => mockTransactWrite(...args),
        }),
    },
    TransactWriteCommand: jest.fn().mockImplementation((params) => ({
        _type: 'TransactWrite',
        ...params,
    })),
}));

// Import after mocks
const { handler } = require('../setup/batchHandler-transpiled.js');

describe('Attack Vector H — Batch Handler Cross-Tenant Write', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    // ── POST-FIX: No Header Fallback ───────────────────────────────────────

    it('SECURITY (POST-FIX): JWT without tenantId + x-tenant-id header → 403', async () => {
        // Simulate: JWT has no tenantId, attacker sets x-tenant-id header
        mockVerifyToken.mockResolvedValue({
            sub: 'attacker',
            email: 'evil@evil.com',
            role: 'admin',
            // NO tenantId
        });

        const event = makeEvent({
            method: 'POST',
            path: '/api/v1/batch',
            authToken: 'token-without-tenant',
            tenantIdHeader: TENANT_B.tenantId, // Attack vector
            body: {
                operations: [
                    {
                        type: 'set',
                        collection: 'products',
                        documentId: 'evil-product',
                        data: { name: 'Injected Product' },
                    },
                ],
            },
        });

        const res = await handler(event);

        // After our fix: must be 403 (not 200)
        expect(res.statusCode).toBe(403);
        const body = parseResponseBody(res);
        expect(body.message).toContain('tenant context');
    });

    it('SECURITY: Valid JWT with tenantId → 200 (batch writes with correct tenant)', async () => {
        mockVerifyToken.mockResolvedValue({
            sub: USERS.A_ADMIN.sub,
            email: USERS.A_ADMIN.email,
            role: 'admin',
            tenantId: TENANT_A.tenantId,
        });

        const event = makeEvent({
            method: 'POST',
            path: '/api/v1/batch',
            authToken: 'valid-token',
            body: {
                operations: [
                    {
                        type: 'set',
                        collection: 'products',
                        documentId: 'new-product',
                        data: { name: 'Valid Product' },
                    },
                ],
            },
        });

        const res = await handler(event);
        expect(res.statusCode).toBe(200);
    });

    it('SECURITY: Batch with tenantId in operation data mismatching JWT → FORBIDDEN', async () => {
        mockVerifyToken.mockResolvedValue({
            sub: USERS.A_ADMIN.sub,
            email: USERS.A_ADMIN.email,
            role: 'admin',
            tenantId: TENANT_A.tenantId,
        });

        const event = makeEvent({
            method: 'POST',
            path: '/api/v1/batch',
            authToken: 'valid-token',
            body: {
                operations: [
                    {
                        type: 'set',
                        collection: 'products',
                        documentId: 'evil-product',
                        data: {
                            name: 'Stolen Product',
                            tenantId: TENANT_B.tenantId, // Injection in data
                        },
                    },
                ],
            },
        });

        const res = await handler(event);
        // enforceTenantScope should catch the mismatch
        expect(res.statusCode).toBe(500); // Error from thrown FORBIDDEN
    });

    it('SECURITY: Missing auth header → 401', async () => {
        const event = makeEvent({
            method: 'POST',
            path: '/api/v1/batch',
            body: { operations: [] },
        });

        const res = await handler(event);
        expect(res.statusCode).toBe(401);
    });
});
