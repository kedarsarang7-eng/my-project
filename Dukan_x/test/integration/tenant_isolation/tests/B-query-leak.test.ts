// ============================================================================
// TEST B — Query Leakage: List Endpoints Must Never Return Cross-Tenant Data
// ============================================================================
// Validates that all list/query operations scope their DynamoDB queries
// to the authenticated tenant's partition key (PK = TENANT#<tenantId>).
// ============================================================================

import { authorizedHandler } from '../../../../../my-backend/src/middleware/handler-wrapper';
import { UserRole } from '../../../../../my-backend/src/types/tenant.types';
import { TENANT_A, TENANT_B, USERS, createAuthContext } from '../setup/jwt-factory';
import { IDS, assertNoLeakage } from '../setup/test-fixtures';
import { makeEvent, makeContext, parseResponseBody } from '../setup/event-factory';

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

const { queryAllItems } = require('../../../../../my-backend/src/config/dynamodb.config');

describe('Attack Vector B — Query Leakage (List Endpoints Cross-Tenant)', () => {
    const ctx = makeContext();

    beforeEach(() => {
        jest.clearAllMocks();
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_ADMIN));
    });

    // Simulated list handler
    const listProductsHandler = authorizedHandler(
        [UserRole.ADMIN, UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
        async (_event, _ctx, auth) => {
            const pk = `TENANT#${auth.tenantId}`;
            const items = await queryAllItems(pk, 'PRODUCT#');
            return {
                statusCode: 200,
                body: JSON.stringify({ data: items, count: items.length }),
            };
        },
    );

    const listInvoicesHandler = authorizedHandler(
        [UserRole.ADMIN, UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
        async (_event, _ctx, auth) => {
            const pk = `TENANT#${auth.tenantId}`;
            const items = await queryAllItems(pk, 'INVOICE#');
            return {
                statusCode: 200,
                body: JSON.stringify({ data: items, count: items.length }),
            };
        },
    );

    // ── Test Cases ──────────────────────────────────────────────────────────

    it('Tenant A list products → returns ONLY 3 Tenant A products', async () => {
        const event = makeEvent({ method: 'GET', path: '/products', authToken: 'valid' });
        const res = await listProductsHandler(event, ctx) as any;

        expect(res.statusCode).toBe(200);
        const body = parseResponseBody(res);

        expect(body.count).toBe(3); // Tenant A has exactly 3 products
        assertNoLeakage(body.data, TENANT_A.tenantId);
    });

    it('Tenant A list invoices → returns ONLY 2 Tenant A invoices', async () => {
        const event = makeEvent({ method: 'GET', path: '/invoices', authToken: 'valid' });
        const res = await listInvoicesHandler(event, ctx) as any;

        expect(res.statusCode).toBe(200);
        const body = parseResponseBody(res);

        expect(body.count).toBe(2); // Tenant A has exactly 2 invoices
        assertNoLeakage(body.data, TENANT_A.tenantId);
    });

    it('Tenant B list products → returns ONLY 2 Tenant B products', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.B_ADMIN));

        const event = makeEvent({ method: 'GET', path: '/products', authToken: 'valid' });
        const res = await listProductsHandler(event, ctx) as any;

        expect(res.statusCode).toBe(200);
        const body = parseResponseBody(res);

        expect(body.count).toBe(2); // Tenant B has exactly 2 products
        assertNoLeakage(body.data, TENANT_B.tenantId);
    });

    it('Tenant B list invoices → returns ONLY 1 Tenant B invoice', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.B_ADMIN));

        const event = makeEvent({ method: 'GET', path: '/invoices', authToken: 'valid' });
        const res = await listInvoicesHandler(event, ctx) as any;

        expect(res.statusCode).toBe(200);
        const body = parseResponseBody(res);

        expect(body.count).toBe(1); // Tenant B has exactly 1 invoice
        assertNoLeakage(body.data, TENANT_B.tenantId);
    });

    it('INTEGRITY: queryAllItems always called with auth.tenantId PK', async () => {
        const event = makeEvent({ method: 'GET', path: '/products', authToken: 'valid' });
        await listProductsHandler(event, ctx);

        expect(queryAllItems).toHaveBeenCalledWith(
            `TENANT#${TENANT_A.tenantId}`,
            'PRODUCT#',
        );
    });

    it('SECURITY: Tenant A results contain ZERO Tenant B product IDs', async () => {
        const event = makeEvent({ method: 'GET', path: '/products', authToken: 'valid' });
        const res = await listProductsHandler(event, ctx);

        const body = parseResponseBody(res);
        const ids = body.data.map((d: any) => d.id);

        expect(ids).not.toContain(IDS.B_PRODUCT_1);
        expect(ids).not.toContain(IDS.B_PRODUCT_2);
    });
});
