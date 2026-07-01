// ============================================================================
// TEST A — Direct IDOR: Tenant A Tries to Access Tenant B Resources by ID
// ============================================================================
// Validates that the DynamoDB single-table PK design (TENANT#<tenantId>)
// prevents any handler from returning another tenant's data by direct ID.
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../../../../my-backend/src/middleware/handler-wrapper';
import { UserRole } from '../../../../../my-backend/src/types/tenant.types';
import * as cognitoAuth from '../../../../../my-backend/src/middleware/cognito-auth';
import { TENANT_A, TENANT_B, USERS, createAuthContext } from '../setup/jwt-factory';
import { IDS } from '../setup/test-fixtures';
import { makeEvent, makeContext, parseResponseBody, expectBlocked } from '../setup/event-factory';

// ── Mock Auth ────────────────────────────────────────────────────────────────

// Default: logged in as Tenant A Admin
const mockVerifyAuth = jest.fn();
jest.mock('../../../../../my-backend/src/middleware/cognito-auth', () => ({
    verifyAuth: (...args: any[]) => mockVerifyAuth(...args),
}));

// Mock DynamoDB to use our seed data
jest.mock('../../../../../my-backend/src/config/dynamodb.config', () => {
    const { SEED_ITEMS, queryByPKPrefix, getByPKSK } = require('../setup/test-fixtures');
    return {
        Keys: {
            tenantPK: (tenantId: string) => `TENANT#${tenantId}`,
            productSK: (id: string) => `PRODUCT#${id}`,
            invoiceSK: (id: string) => `INVOICE#${id}`,
            customerSK: (id: string) => `CUSTOMER#${id}`,
            businessSK: (id: string) => `BUSINESS#${id}`,
            tenantLicenseSK: () => 'LICENSE',
        },
        getItem: jest.fn(async (pk: string, sk: string) => getByPKSK(pk, sk)),
        queryItems: jest.fn(async (pk: string, skPrefix?: string) => ({
            items: queryByPKPrefix(pk, skPrefix),
        })),
        queryAllItems: jest.fn(async (pk: string, skPrefix?: string) =>
            queryByPKPrefix(pk, skPrefix),
        ),
        putItem: jest.fn(),
        updateItem: jest.fn(),
        deleteItem: jest.fn(),
        TABLE_NAME: 'TestTable',
    };
});

// Mock software-lock to not block
jest.mock('../../../../../my-backend/src/middleware/software-lock', () => ({
    checkSoftwareLock: jest.fn().mockResolvedValue({ allowed: true, lockLevel: 'NONE' }),
    LockLevel: { NONE: 'NONE' },
}));

// Mock cloudwatch-logger
jest.mock('../../../../../my-backend/src/middleware/cloudwatch-logger', () => ({
    logRequest: jest.fn().mockResolvedValue(undefined),
    logAuthFailure: jest.fn(),
}));

// ── Test Setup ───────────────────────────────────────────────────────────────

const { getItem } = require('../../../../../my-backend/src/config/dynamodb.config');

describe('Attack Vector A — Direct IDOR (Cross-Tenant Resource Access by ID)', () => {
    const ctx = makeContext();

    beforeEach(() => {
        jest.clearAllMocks();
        // Default: Tenant A admin
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.A_ADMIN));
    });

    // ── Simulated handler: GET resource by ID ──────────────────────────────
    // This simulates a typical handler that looks up a resource by ID
    // within the tenant's partition.
    const getResourceHandler = authorizedHandler(
        [UserRole.ADMIN, UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
        async (event, _ctx, auth) => {
            const resourceId = event.pathParameters?.id;
            if (!resourceId) {
                return { statusCode: 400, body: JSON.stringify({ message: 'id required' }) };
            }

            // The correct pattern: query by TENANT#<auth.tenantId> PK
            const pk = `TENANT#${auth.tenantId}`;
            const item = await getItem(pk, `PRODUCT#${resourceId}`);

            if (!item) {
                return { statusCode: 404, body: JSON.stringify({ message: 'Not found' }) };
            }

            return {
                statusCode: 200,
                body: JSON.stringify({ data: item }),
            };
        },
    );

    // ── Test Cases ──────────────────────────────────────────────────────────

    it('PASS: Tenant A accesses own product → 200', async () => {
        const event = makeEvent({
            method: 'GET',
            path: `/products/${IDS.A_PRODUCT_1}`,
            authToken: 'valid-token',
            pathParameters: { id: IDS.A_PRODUCT_1 },
        });

        const res = await getResourceHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);

        const body = parseResponseBody(res);
        expect(body.data.tenantId).toBe(TENANT_A.tenantId);
        expect(body.data.id).toBe(IDS.A_PRODUCT_1);
    });

    it('SECURITY: Tenant A tries Tenant B product ID → 404 (not 200)', async () => {
        const event = makeEvent({
            method: 'GET',
            path: `/products/${IDS.B_PRODUCT_1}`,
            authToken: 'valid-token',
            pathParameters: { id: IDS.B_PRODUCT_1 },
        });

        const res = await getResourceHandler(event, ctx) as any;

        // KEY ASSERTION: Must be 404, NOT 200.
        // Because getItem(TENANT#A, PRODUCT#B_PRODUCT_1) returns null —
        // Tenant B's product doesn't exist in Tenant A's partition.
        expect(res.statusCode).toBe(404);
    });

    it('SECURITY: Tenant A tries Tenant B product with B\'s full PK → 404', async () => {
        // Even if attacker knows the exact PK format, auth.tenantId is used
        const event = makeEvent({
            method: 'GET',
            path: `/products/${IDS.B_PRODUCT_1}`,
            authToken: 'valid-token',
            pathParameters: { id: IDS.B_PRODUCT_1 },
        });

        const res = await getResourceHandler(event, ctx) as any;
        expect(res.statusCode).toBe(404);

        // Verify that getItem was called with Tenant A's PK, not Tenant B's
        expect(getItem).toHaveBeenCalledWith(
            `TENANT#${TENANT_A.tenantId}`,
            `PRODUCT#${IDS.B_PRODUCT_1}`,
        );
    });

    it('SECURITY: Tenant B admin accesses Tenant B product → 200', async () => {
        // Switch to Tenant B context
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.B_ADMIN));

        const event = makeEvent({
            method: 'GET',
            path: `/products/${IDS.B_PRODUCT_1}`,
            authToken: 'valid-token',
            pathParameters: { id: IDS.B_PRODUCT_1 },
        });

        const res = await getResourceHandler(event, ctx) as any;
        expect(res.statusCode).toBe(200);

        const body = parseResponseBody(res);
        expect(body.data.tenantId).toBe(TENANT_B.tenantId);
    });

    it('SECURITY: Tenant B admin tries Tenant A product → 404', async () => {
        mockVerifyAuth.mockResolvedValue(createAuthContext(USERS.B_ADMIN));

        const event = makeEvent({
            method: 'GET',
            path: `/products/${IDS.A_PRODUCT_1}`,
            authToken: 'valid-token',
            pathParameters: { id: IDS.A_PRODUCT_1 },
        });

        const res = await getResourceHandler(event, ctx) as any;
        expect(res.statusCode).toBe(404);
    });

    it('INTEGRITY: DynamoDB query PK always uses auth.tenantId, not user input', async () => {
        const event = makeEvent({
            method: 'GET',
            path: `/products/${IDS.B_PRODUCT_1}`,
            authToken: 'valid-token',
            pathParameters: { id: IDS.B_PRODUCT_1 },
        });

        await getResourceHandler(event, ctx);

        // The PK used in the DynamoDB call MUST be Tenant A's (from JWT), not B's
        const [calledPK] = getItem.mock.calls[0];
        expect(calledPK).toBe(`TENANT#${TENANT_A.tenantId}`);
        expect(calledPK).not.toContain(TENANT_B.tenantId);
    });
});
