// ============================================================================
// Staff Module — Department CRUD Handler (Task 3.2)
// ============================================================================
// Handles /staff/departments routes (POST, GET, PUT/PATCH, DELETE) with:
//   • Tenant scoping (BusinessID from session only, Req 11.1–11.3)
//   • Zod validation (staff.schema.ts)
//   • Deactivation (soft delete) instead of hard delete
//
// Requirements: 2.2
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { NotFoundError } from '../../../utils/errors';
import { resolveStaffTenantScope, requirePathId } from './tenant-scope';
import { httpMethod, pathId, parseJsonBody } from './http';
import { DepartmentRepository } from '../repositories/department.repository';
import {
    departmentCreateSchema,
    departmentUpdateSchema,
} from '../schemas/staff.schema';
import { writeAuditEntry } from '../services/staff-audit.service';

const STAFF_ROLES: UserRole[] = [
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.MANAGER,
];

const deptRepo = new DepartmentRepository();

/**
 * Lambda handler for /staff/departments and /staff/departments/{id}.
 */
export const departmentHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const { tenantId, businessId } = tenantContext;
        const method = httpMethod(event);
        const id = pathId(event);

        switch (method) {
            case 'POST':
                return handleCreate(tenantId, businessId, event, auth);
            case 'GET':
                return id
                    ? handleGet(tenantId, businessId, id)
                    : handleList(tenantId, businessId);
            case 'PUT':
            case 'PATCH':
                return handleUpdate(tenantId, businessId, requirePathId(id), event, auth);
            case 'DELETE':
                return handleDeactivate(tenantId, businessId, requirePathId(id), auth);
            default:
                return response.error(405, 'METHOD_NOT_ALLOWED', `Method ${method} not allowed`);
        }
    },
);

// ── Create ──────────────────────────────────────────────────────────────────

async function handleCreate(
    tenantId: string,
    businessId: string,
    event: APIGatewayProxyEventV2,
    auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
    const body = parseJsonBody(event);
    const parsed = departmentCreateSchema.parse(body);
    const department = await deptRepo.create(tenantId, businessId, parsed);

    // Audit: record department creation (Req 8.3, Task 11.2).
    await writeAuditEntry(tenantId, businessId, {
        actor: auth.sub,
        action: 'CREATE',
        target: `Department:${department.id}`,
    });

    return response.success(department, 201);
}

// ── Get single ──────────────────────────────────────────────────────────────

async function handleGet(
    tenantId: string,
    businessId: string,
    id: string,
): Promise<APIGatewayProxyResultV2> {
    const department = await deptRepo.get(tenantId, businessId, id);
    if (!department) {
        throw new NotFoundError('Department');
    }
    return response.success(department);
}

// ── List ────────────────────────────────────────────────────────────────────

async function handleList(
    tenantId: string,
    businessId: string,
): Promise<APIGatewayProxyResultV2> {
    const departments = await deptRepo.list(tenantId, businessId);
    return response.success(departments);
}

// ── Update ──────────────────────────────────────────────────────────────────

async function handleUpdate(
    tenantId: string,
    businessId: string,
    id: string,
    event: APIGatewayProxyEventV2,
    auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
    const body = parseJsonBody(event);
    const parsed = departmentUpdateSchema.parse(body);
    const updated = await deptRepo.update(tenantId, businessId, id, parsed as Record<string, unknown>);
    if (!updated) {
        throw new NotFoundError('Department');
    }

    // Audit: record department update (Req 8.3, Task 11.2).
    await writeAuditEntry(tenantId, businessId, {
        actor: auth.sub,
        action: 'UPDATE',
        target: `Department:${id}`,
    });

    return response.success(updated);
}

// ── Deactivate (soft delete) ──────────────────────────────────────────────────

async function handleDeactivate(
    tenantId: string,
    businessId: string,
    id: string,
    auth: AuthContext,
): Promise<APIGatewayProxyResultV2> {
    const ok = await deptRepo.deactivate(tenantId, businessId, id);
    if (!ok) {
        throw new NotFoundError('Department');
    }

    // Audit: record department deactivation (Req 8.3, Task 11.2).
    await writeAuditEntry(tenantId, businessId, {
        actor: auth.sub,
        action: 'DEACTIVATE',
        target: `Department:${id}`,
    });

    return response.success({ id, status: 'inactive', deactivated: true });
}
