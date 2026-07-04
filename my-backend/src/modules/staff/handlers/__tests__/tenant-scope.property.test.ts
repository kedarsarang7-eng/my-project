// ============================================================================
// Feature: universal-staff-management, Property 2: Cross-business/cross-tenant access is denied
// ----------------------------------------------------------------------------
// Validates: Requirements 10.6, 11.2
//
// Property 2 (design.md):
//   "For any authenticated context and any target record, access is granted if
//    and only if the record's tenant id equals the context tenant id and (the
//    caller has cross-business access or the record's business id equals the
//    context business id); otherwise the request is denied."
//
// Units under test (implemented in task 2.1):
//   • validateResourceOwnership(resourceTenantId, resourceBusinessId, ctx)
//        — the underlying pure predicate in dynamodb/tenant-guard.ts.
//   • assertStaffResourceScope(tenantContext, resTenantId, resBusinessId)
//        — the staff-handler guard in modules/staff/handlers/tenant-scope.ts,
//          which throws AuthError(403) exactly when ownership is invalid.
//
// Strategy: an independent reference oracle encodes the iff-condition from the
// property statement. For every generated (context, target-record) pair we
// assert BOTH helpers agree with the oracle across the whole grant/deny space.
// Identifiers are drawn from a SMALL shared pool so tenant/business ids collide
// frequently — exercising the grant path, the cross-business deny path, and the
// cross-tenant deny path with meaningful density.
// ============================================================================

import fc from 'fast-check';

import { validateResourceOwnership } from '../../../../dynamodb/tenant-guard';
import { assertStaffResourceScope } from '../tenant-scope';
import { TenantContext, UserRole } from '../../../../dynamodb/types';
import { AuthError } from '../../../../utils/errors';

// Minimum fast-check iterations mandated by the spec for property tests.
const RUNS = 200;

// A deliberately tiny id pool so caller/resource ids collide often — this makes
// grants (ids match) and both denial modes (tenant differs / business differs)
// all occur with high frequency instead of near-never.
const ID_POOL = ['t1', 't2', 'b1', 'b2', 'x'] as const;
const idArb = fc.constantFrom(...ID_POOL);

const roleArb = fc.constantFrom<UserRole>('owner', 'admin', 'manager', 'staff', 'viewer');

/**
 * Build a TenantContext from primitive fields. Only `tenantId`, `businessId`
 * and `hasCrossBusinessAccess` participate in the ownership decision; the rest
 * are populated for realism and to prove they do not influence the outcome.
 */
function makeContext(
    tenantId: string,
    businessId: string,
    hasCrossBusinessAccess: boolean,
    role: UserRole,
): TenantContext {
    return {
        userId: 'user-1',
        tenantId,
        businessId,
        role,
        email: 'user@example.com',
        groups: [],
        isOwner: hasCrossBusinessAccess,
        hasCrossBusinessAccess,
    };
}

/**
 * Independent reference oracle for the property's iff-condition.
 * Access is granted IFF same tenant AND (cross-business access OR same business).
 */
function shouldGrant(
    ctx: TenantContext,
    resourceTenantId: string,
    resourceBusinessId: string,
): boolean {
    return (
        resourceTenantId === ctx.tenantId &&
        (ctx.hasCrossBusinessAccess || resourceBusinessId === ctx.businessId)
    );
}

const scenarioArb = fc.record({
    callerTenantId: idArb,
    callerBusinessId: idArb,
    resourceTenantId: idArb,
    resourceBusinessId: idArb,
    hasCrossBusinessAccess: fc.boolean(),
    role: roleArb,
});

describe('Property 2: Cross-business/cross-tenant access is denied', () => {
    it('validateResourceOwnership grants access iff same-tenant AND (cross-business access OR same-business)', () => {
        fc.assert(
            fc.property(scenarioArb, (s) => {
                const ctx = makeContext(
                    s.callerTenantId,
                    s.callerBusinessId,
                    s.hasCrossBusinessAccess,
                    s.role,
                );

                const result = validateResourceOwnership(
                    s.resourceTenantId,
                    s.resourceBusinessId,
                    ctx,
                );

                const expectGrant = shouldGrant(ctx, s.resourceTenantId, s.resourceBusinessId);

                // The predicate's verdict must match the oracle exactly.
                expect(result.valid).toBe(expectGrant);

                // Denials must carry a diagnostic reason; grants must not.
                if (expectGrant) {
                    expect(result.error).toBeUndefined();
                } else {
                    expect(typeof result.error).toBe('string');
                    expect(result.error && result.error.length).toBeGreaterThan(0);
                }
            }),
            { numRuns: RUNS },
        );
    });

    it('assertStaffResourceScope passes on grant and throws AuthError(403) on any cross-tenant/cross-business denial', () => {
        fc.assert(
            fc.property(scenarioArb, (s) => {
                const ctx = makeContext(
                    s.callerTenantId,
                    s.callerBusinessId,
                    s.hasCrossBusinessAccess,
                    s.role,
                );

                const expectGrant = shouldGrant(ctx, s.resourceTenantId, s.resourceBusinessId);
                const call = () =>
                    assertStaffResourceScope(ctx, s.resourceTenantId, s.resourceBusinessId);

                if (expectGrant) {
                    // In-scope resource: guard must allow the access silently.
                    expect(call).not.toThrow();
                } else {
                    // Out-of-scope resource: guard must deny with a 403 AuthError.
                    let thrown: unknown;
                    try {
                        call();
                    } catch (err) {
                        thrown = err;
                    }
                    expect(thrown).toBeInstanceOf(AuthError);
                    expect((thrown as AuthError).statusCode).toBe(403);
                }
            }),
            { numRuns: RUNS },
        );
    });

    it('denies every cross-tenant access regardless of cross-business privilege (Req 11.2/10.6)', () => {
        fc.assert(
            fc.property(scenarioArb, (s) => {
                // Force a tenant mismatch: pick a resource tenant that differs.
                const resourceTenantId = s.callerTenantId === 't1' ? 't2' : 't1';
                const ctx = makeContext(
                    s.callerTenantId,
                    s.callerBusinessId,
                    // Even an owner with cross-business access cannot cross tenants.
                    s.hasCrossBusinessAccess,
                    s.role,
                );

                const result = validateResourceOwnership(
                    resourceTenantId,
                    s.resourceBusinessId,
                    ctx,
                );
                expect(result.valid).toBe(false);

                expect(() =>
                    assertStaffResourceScope(ctx, resourceTenantId, s.resourceBusinessId),
                ).toThrow(AuthError);
            }),
            { numRuns: RUNS },
        );
    });
});
