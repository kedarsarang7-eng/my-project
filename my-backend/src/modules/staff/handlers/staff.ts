// ============================================================================
// Staff Module — Main Handler Entry Point (Task 2.1)
// ============================================================================
// Serves /staff/* for employee/department/designation CRUD, attendance, leave,
// and task operations. This task (2.1) wires the MULTI-TENANCY ISOLATION
// foundation into the handler entry point; entity-specific CRUD is layered on
// in later tasks (3.2, 5.x, 6.x, 7.x) on top of the scope resolved here.
//
// Every staff handler:
//   1. Runs behind `authorizedHandler` (Cognito auth + role enforcement +
//      cross-tenant/cross-business attack detection).
//   2. Resolves a validated TenantContext via `resolveStaffTenantScope`
//      (BusinessID derived from the authenticated session only — Req 11.3).
//   3. Scopes every read/write to PK = TENANT#{tenantId}#BIZ#{businessId}
//      (Req 11.1) and calls `assertStaffResourceScope` before touching any
//      single record so cross-business/cross-tenant access is denied (Req 11.2).
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { resolveStaffTenantScope } from './tenant-scope';

// Roles permitted to reach the staff surface. Fine-grained per-capability
// gating (field/action level) is refined in task 11.1; the module manifest sets
// the baseline minRole = MANAGER.
const STAFF_ROLES: UserRole[] = [
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.MANAGER,
];

/**
 * GET /staff/context — resolve and echo the caller's validated staff scope.
 *
 * This is the concrete proof that tenant scoping is wired end-to-end: it forces
 * `resolveStaffTenantScope` to run (session-derived BusinessID, ownership
 * validated against the JWT tenant) and returns only the non-sensitive scope
 * identifiers. Downstream entity handlers reuse the exact same resolution.
 */
export const getStaffContextHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);

        return response.success({
            tenantId: tenantContext.tenantId,
            businessId: tenantContext.businessId,
            role: tenantContext.role,
            isOwner: tenantContext.isOwner,
            hasCrossBusinessAccess: tenantContext.hasCrossBusinessAccess,
        });
    },
);
