// ============================================================================
// Unit Tests: Staff Tenant Scoping (Task 2.1)
// ============================================================================
// Validates: Requirements 11.1, 11.2, 11.3
//   • BusinessID is derived from the authenticated session (headers), never
//     from client-supplied body input (11.3).
//   • Cross-business / cross-tenant resource access is denied (11.2).
//   • Every resolved scope is business-scoped (11.1).
// ============================================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { AuthContext, UserRole, BusinessType } from '../../../../types/tenant.types';
import { TenantContext } from '../../../../dynamodb/types';

// Mock the logger to keep test output clean.
jest.mock('../../../../utils/logger', () => ({
    logger: { debug: jest.fn(), info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));

// Mock ONLY buildTenantContext (it hits DynamoDB); keep validateResourceOwnership real.
jest.mock('../../../../dynamodb/tenant-guard', () => {
    const actual = jest.requireActual('../../../../dynamodb/tenant-guard');
    return { ...actual, buildTenantContext: jest.fn() };
});

import { buildTenantContext } from '../../../../dynamodb/tenant-guard';
import {
    extractStaffBusinessId,
    resolveStaffTenantScope,
    assertStaffResourceScope,
    requirePathId,
} from '../tenant-scope';

const mockBuildTenantContext = buildTenantContext as jest.MockedFunction<typeof buildTenantContext>;

function makeAuth(overrides: Partial<AuthContext> = {}): AuthContext {
    return {
        sub: 'user-1',
        email: 'u@example.com',
        tenantId: 'tenant-A',
        role: UserRole.MANAGER,
        businessType: BusinessType.GROCERY,
        ...overrides,
    };
}

function makeCtx(overrides: Partial<TenantContext> = {}): TenantContext {
    return {
        userId: 'user-1',
        tenantId: 'tenant-A',
        businessId: 'biz-1',
        role: 'manager',
        email: 'u@example.com',
        groups: [],
        isOwner: false,
        hasCrossBusinessAccess: false,
        ...overrides,
    };
}

function makeEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
    return {
        headers: {},
        rawPath: '/staff/context',
        ...overrides,
    } as APIGatewayProxyEventV2;
}

describe('extractStaffBusinessId', () => {
    it('reads businessId from session headers (never body)', () => {
        const event = makeEvent({ headers: { 'x-business-id': 'biz-1' } });
        expect(extractStaffBusinessId(event)).toBe('biz-1');
    });

    it('prefers x-active-business over other header aliases', () => {
        const event = makeEvent({
            headers: { 'x-active-business': 'biz-active', 'x-business-id': 'biz-other' },
        });
        expect(extractStaffBusinessId(event)).toBe('biz-active');
    });

    it('returns empty string when no business header present', () => {
        expect(extractStaffBusinessId(makeEvent())).toBe('');
    });
});

describe('resolveStaffTenantScope (Req 11.1, 11.3)', () => {
    beforeEach(() => jest.clearAllMocks());

    it('resolves a business-scoped context from the session header', async () => {
        mockBuildTenantContext.mockResolvedValue({
            tenantContext: makeCtx(),
            businessContext: null,
        });
        const event = makeEvent({ headers: { 'x-business-id': 'biz-1' } });

        const { tenantContext } = await resolveStaffTenantScope(event, makeAuth());

        expect(mockBuildTenantContext).toHaveBeenCalledWith(makeAuth(), 'biz-1');
        expect(tenantContext.businessId).toBe('biz-1');
    });

    it('ignores a client-supplied businessId in the body (uses session scope)', async () => {
        mockBuildTenantContext.mockResolvedValue({
            tenantContext: makeCtx({ businessId: 'biz-1' }),
            businessContext: null,
        });
        const event = makeEvent({
            headers: { 'x-business-id': 'biz-1' },
            body: JSON.stringify({ businessId: 'biz-1', name: 'Dept A' }),
        });

        const { tenantContext } = await resolveStaffTenantScope(event, makeAuth());
        expect(tenantContext.businessId).toBe('biz-1');
    });

    it('rejects a body businessId that contradicts the session scope (Req 11.3)', async () => {
        mockBuildTenantContext.mockResolvedValue({
            tenantContext: makeCtx({ businessId: 'biz-1', hasCrossBusinessAccess: false }),
            businessContext: null,
        });
        const event = makeEvent({
            headers: { 'x-business-id': 'biz-1' },
            body: JSON.stringify({ businessId: 'biz-999' }),
        });

        await expect(resolveStaffTenantScope(event, makeAuth())).rejects.toThrow(
            /Cross-business access denied/,
        );
    });

    it('allows a differing body businessId for cross-business owners', async () => {
        mockBuildTenantContext.mockResolvedValue({
            tenantContext: makeCtx({ businessId: 'biz-1', isOwner: true, hasCrossBusinessAccess: true }),
            businessContext: null,
        });
        const event = makeEvent({
            headers: { 'x-business-id': 'biz-1' },
            body: JSON.stringify({ businessId: 'biz-2' }),
        });

        await expect(resolveStaffTenantScope(event, makeAuth({ role: UserRole.OWNER }))).resolves.toBeDefined();
    });

    it('translates a missing business context into a 401 auth error', async () => {
        mockBuildTenantContext.mockRejectedValue(new Error('BUSINESS_MISSING: No business_id specified'));
        await expect(resolveStaffTenantScope(makeEvent(), makeAuth())).rejects.toMatchObject({
            statusCode: 401,
        });
    });

    it('translates a horizontal escalation attempt into a 403 denial (Req 11.2)', async () => {
        mockBuildTenantContext.mockRejectedValue(new Error('HORIZONTAL_ESCALATION: Cross-tenant access denied'));
        await expect(
            resolveStaffTenantScope(makeEvent({ headers: { 'x-business-id': 'biz-x' } }), makeAuth()),
        ).rejects.toMatchObject({ statusCode: 403 });
    });
});

describe('assertStaffResourceScope (Req 11.1, 11.2)', () => {
    it('permits access to a record in the caller tenant + business', () => {
        expect(() => assertStaffResourceScope(makeCtx(), 'tenant-A', 'biz-1')).not.toThrow();
    });

    it('denies access to a record in a different tenant', () => {
        expect(() => assertStaffResourceScope(makeCtx(), 'tenant-B', 'biz-1')).toThrow(/Access denied/);
    });

    it('denies access to a record in a different business (no cross-business access)', () => {
        expect(() => assertStaffResourceScope(makeCtx(), 'tenant-A', 'biz-2')).toThrow(/Access denied/);
    });

    it('permits cross-business owners to access sibling-business records in-tenant', () => {
        const ctx = makeCtx({ isOwner: true, hasCrossBusinessAccess: true });
        expect(() => assertStaffResourceScope(ctx, 'tenant-A', 'biz-2')).not.toThrow();
    });

    it('still denies cross-tenant access even for cross-business owners', () => {
        const ctx = makeCtx({ isOwner: true, hasCrossBusinessAccess: true });
        expect(() => assertStaffResourceScope(ctx, 'tenant-B', 'biz-1')).toThrow(/Access denied/);
    });
});

describe('requirePathId', () => {
    it('returns the id when present', () => {
        expect(requirePathId('abc')).toBe('abc');
    });

    it('throws a validation error when missing or blank', () => {
        expect(() => requirePathId(undefined, 'employeeId')).toThrow(/employeeId/);
        expect(() => requirePathId('   ')).toThrow();
    });
});
