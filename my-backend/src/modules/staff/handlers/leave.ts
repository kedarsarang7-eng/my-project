// ============================================================================
// Staff Module — Leave Management Handlers (Task 6.1)
// ============================================================================
// REST handlers for leave TYPES, BALANCES, and REQUEST VALIDATION under
// /staff/leave/*. Every handler:
//   1. runs behind `authorizedHandler` (Cognito auth + role enforcement),
//   2. resolves a validated TenantContext via `resolveStaffTenantScope`
//      (BusinessID from the authenticated session only — Req 11.3), and scopes
//      every read/write to PK = TENANT#{tenantId}#BIZ#{businessId} (Req 11.1),
//   3. validates input with a Zod schema (fail-closed),
//   4. returns the standard response envelope.
//
// The leave-request handler enforces Property 12: a request is accepted IFF it
// satisfies the LeaveType rules AND the requested duration does not exceed the
// available LeaveBalance; otherwise it is rejected and balances are unchanged
// (validation is pure and never touches the balance).
//
// The approval workflow (deducting balance on approve) + leave calendar are
// task 6.2. These handlers deliberately leave those integration points clean:
// the LeaveRequestRepository.updateStatus method and the pending/approved
// statuses are already in place for 6.2 to build on.
//
// Requirements: 4.1 (LeaveType definitions, accrual rules, balance tracking),
// 4.2 (validate against LeaveType rules AND available LeaveBalance).
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError } from '../../../utils/errors';
import { resolveStaffTenantScope } from './tenant-scope';
import {
    LeaveTypeRepository,
    LeaveBalanceRepository,
    LeaveRequestRepository,
} from '../repositories/leave.repository';
import {
    leaveTypeInputSchema,
    leaveBalanceInputSchema,
    leaveRequestInputSchema,
    leaveApprovalInputSchema,
    leaveCalendarQuerySchema,
} from '../schemas/leave.schema';
import { validateLeaveRequest, readBalance, computeLeaveDurationDays } from '../services/leave.service';
import { writeAuditEntry } from '../services/staff-audit.service';

// Roles permitted to reach the leave surface (mirrors staff.ts baseline).
const STAFF_ROLES: UserRole[] = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER];

const leaveTypeRepo = new LeaveTypeRepository();
const leaveBalanceRepo = new LeaveBalanceRepository();
const leaveRequestRepo = new LeaveRequestRepository();

/** Parse a JSON request body, throwing a 400 on malformed/absent JSON. */
function parseJsonBody(event: APIGatewayProxyEventV2): Record<string, unknown> {
    if (!event.body) {
        throw new ValidationError('Request body is required');
    }
    try {
        const parsed = JSON.parse(event.body) as unknown;
        if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
            throw new ValidationError('Request body must be a JSON object');
        }
        return parsed as Record<string, unknown>;
    } catch (err) {
        if (err instanceof ValidationError) throw err;
        throw new ValidationError('Request body must be valid JSON');
    }
}

/** Format a ZodError into a flat, client-safe details array. */
function zodDetails(issues: { path: PropertyKey[]; message: string }[]): string[] {
    return issues.map((i) => `${i.path.map(String).join('.') || '(root)'}: ${i.message}`);
}

// ── LeaveType handlers (Req 4.1) ─────────────────────────────────────────────

/** POST /staff/leave/types — create a leave type (accrual rule + request rules). */
export const createLeaveTypeHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const body = parseJsonBody(event);

        const parsed = leaveTypeInputSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid leave type', zodDetails(parsed.error.issues));
        }

        const created = await leaveTypeRepo.create(
            tenantContext.tenantId,
            tenantContext.businessId,
            {
                name: parsed.data.name,
                accrualRule: parsed.data.accrualRule,
                rules: parsed.data.rules,
                status: parsed.data.status,
            },
        );

        // Audit: record leave type creation (Req 8.3, Task 11.2).
        await writeAuditEntry(tenantContext.tenantId, tenantContext.businessId, {
            actor: tenantContext.userId,
            action: 'CREATE',
            target: `LeaveType:${created.id}`,
        });

        return response.success(created, 201);
    },
);

/** GET /staff/leave/types — list leave types for the business. */
export const listLeaveTypesHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const items = await leaveTypeRepo.list(tenantContext.tenantId, tenantContext.businessId);
        return response.success({ items });
    },
);

// ── LeaveBalance handlers (Req 4.1 — balance tracking) ───────────────────────

/** POST /staff/leave/balances — set/adjust a balance for an (employee, leaveType). */
export const upsertLeaveBalanceHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const body = parseJsonBody(event);

        const parsed = leaveBalanceInputSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid leave balance', zodDetails(parsed.error.issues));
        }

        // The referenced leave type must exist in this business (scoped lookup).
        const leaveType = await leaveTypeRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            parsed.data.leaveTypeId,
        );
        if (!leaveType) {
            return response.notFound('Leave type');
        }

        const balance = await leaveBalanceRepo.upsert(
            tenantContext.tenantId,
            tenantContext.businessId,
            parsed.data.employeeId,
            parsed.data.leaveTypeId,
            parsed.data.balance,
        );
        return response.success(balance);
    },
);

/** GET /staff/leave/balances?employeeId=... — list an employee's balances. */
export const listLeaveBalancesHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const employeeId = event.queryStringParameters?.employeeId;
        if (!employeeId || employeeId.trim() === '') {
            throw new ValidationError('Query parameter `employeeId` is required');
        }
        const items = await leaveBalanceRepo.listForEmployee(
            tenantContext.tenantId,
            tenantContext.businessId,
            employeeId,
        );
        return response.success({ items });
    },
);

// ── LeaveRequest handler — request validation (Req 4.2, Property 12) ─────────

/**
 * POST /staff/leave/requests — submit a leave request.
 *
 * Accepts the request IFF it satisfies the LeaveType rules AND the requested
 * duration does not exceed the available LeaveBalance (validateLeaveRequest).
 * On acceptance the request is created as `pending`; on rejection nothing is
 * written and the balance is unchanged. A 422 with a stable rejection code is
 * returned for a rules/balance rejection.
 */
export const createLeaveRequestHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const body = parseJsonBody(event);

        const parsed = leaveRequestInputSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid leave request', zodDetails(parsed.error.issues));
        }
        const input = parsed.data;

        // The leave type must exist in this business.
        const leaveType = await leaveTypeRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            input.leaveTypeId,
        );
        if (!leaveType) {
            return response.notFound('Leave type');
        }

        // Available balance for this (employee, leaveType). Missing balance = 0.
        const balanceRecord = await leaveBalanceRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            input.employeeId,
            input.leaveTypeId,
        );
        const availableBalance = readBalance(balanceRecord);

        // Property 12 — pure decision; balance is NOT modified either way.
        const decision = validateLeaveRequest(leaveType, availableBalance, {
            from: input.from,
            to: input.to,
        });

        if (!decision.accepted) {
            return response.error(422, decision.code ?? 'LEAVE_REQUEST_REJECTED', decision.reason ?? 'Leave request rejected', {
                code: decision.code,
                durationDays: decision.durationDays,
                availableBalance,
            });
        }

        const created = await leaveRequestRepo.create(
            tenantContext.tenantId,
            tenantContext.businessId,
            {
                employeeId: input.employeeId,
                leaveTypeId: input.leaveTypeId,
                from: input.from,
                to: input.to,
                status: 'pending',
            },
        );

        // Audit: record leave request creation (Req 8.3, Task 11.2).
        await writeAuditEntry(tenantContext.tenantId, tenantContext.businessId, {
            actor: tenantContext.userId,
            action: 'CREATE',
            target: `LeaveRequest:${created.id}`,
        });

        return response.success(
            { request: created, durationDays: decision.durationDays },
            201,
        );
    },
);

/** GET /staff/leave/requests — list leave requests for the business. */
export const listLeaveRequestsHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const items = await leaveRequestRepo.list(tenantContext.tenantId, tenantContext.businessId);
        return response.success({ items });
    },
);


// ── Leave Approval/Rejection Handlers (Task 6.2, Req 4.5, Property 15) ──────

/**
 * POST /staff/leave/requests/:id/approve — approve a pending leave request.
 *
 * Property 15: On approval the LeaveBalance is deducted by the request's
 * duration (computeLeaveDurationDays). On rejection the balance is unchanged.
 * An audit entry is recorded in both cases (Req 4.5).
 *
 * Uses optimistic concurrency (version field) via LeaveRequestRepository.updateStatus.
 */
export const approveLeaveRequestHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const requestId = event.pathParameters?.id;
        if (!requestId || requestId.trim() === '') {
            throw new ValidationError('Path parameter `id` is required');
        }

        const body = parseJsonBody(event);
        const parsed = leaveApprovalInputSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid approval input', zodDetails(parsed.error.issues));
        }
        const { from, expectedVersion } = parsed.data;

        // 1. Update the request status to 'approved' with optimistic concurrency.
        let updatedRequest;
        try {
            updatedRequest = await leaveRequestRepo.updateStatus(
                tenantContext.tenantId,
                tenantContext.businessId,
                requestId,
                from,
                'approved',
                expectedVersion,
            );
        } catch (err: unknown) {
            if ((err as { name?: string }).name === 'OptimisticLockError') {
                return response.conflict(
                    'Leave request was modified concurrently. Please refresh and retry.',
                );
            }
            throw err;
        }

        if (!updatedRequest) {
            return response.notFound('Leave request');
        }

        // 2. Compute the leave duration (inclusive days).
        const durationDays = computeLeaveDurationDays(updatedRequest.from, updatedRequest.to);
        if (durationDays === null || durationDays <= 0) {
            // Should not happen for a valid request, but guard defensively.
            return response.error(422, 'INVALID_DATE_RANGE', 'Cannot compute leave duration');
        }

        // 3. Deduct the balance — Property 15 (approval deducts the request's duration).
        const balanceRecord = await leaveBalanceRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            updatedRequest.employeeId,
            updatedRequest.leaveTypeId,
        );
        const currentBalance = readBalance(balanceRecord);
        const newBalance = currentBalance - durationDays;

        await leaveBalanceRepo.upsert(
            tenantContext.tenantId,
            tenantContext.businessId,
            updatedRequest.employeeId,
            updatedRequest.leaveTypeId,
            newBalance,
        );

        // 4. Write an audit entry (Req 4.5).
        await writeAuditEntry(tenantContext.tenantId, tenantContext.businessId, {
            actor: tenantContext.userId,
            action: 'LEAVE_REQUEST_APPROVED',
            target: `LeaveRequest:${requestId}`,
            field: 'balance',
            before: currentBalance,
            after: newBalance,
            meta: {
                employeeId: updatedRequest.employeeId,
                leaveTypeId: updatedRequest.leaveTypeId,
                from: updatedRequest.from,
                to: updatedRequest.to,
                durationDays,
            },
        });

        return response.success({
            request: updatedRequest,
            durationDays,
            balanceAfter: newBalance,
        });
    },
);

/**
 * POST /staff/leave/requests/:id/reject — reject a pending leave request.
 *
 * Property 15: On rejection the LeaveBalance is UNCHANGED. An audit entry is
 * recorded (Req 4.5).
 */
export const rejectLeaveRequestHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const requestId = event.pathParameters?.id;
        if (!requestId || requestId.trim() === '') {
            throw new ValidationError('Path parameter `id` is required');
        }

        const body = parseJsonBody(event);
        const parsed = leaveApprovalInputSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid rejection input', zodDetails(parsed.error.issues));
        }
        const { from, expectedVersion } = parsed.data;

        // 1. Update the request status to 'rejected' with optimistic concurrency.
        let updatedRequest;
        try {
            updatedRequest = await leaveRequestRepo.updateStatus(
                tenantContext.tenantId,
                tenantContext.businessId,
                requestId,
                from,
                'rejected',
                expectedVersion,
            );
        } catch (err: unknown) {
            if ((err as { name?: string }).name === 'OptimisticLockError') {
                return response.conflict(
                    'Leave request was modified concurrently. Please refresh and retry.',
                );
            }
            throw err;
        }

        if (!updatedRequest) {
            return response.notFound('Leave request');
        }

        // 2. Balance is UNCHANGED on rejection (Property 15).

        // 3. Write an audit entry (Req 4.5).
        await writeAuditEntry(tenantContext.tenantId, tenantContext.businessId, {
            actor: tenantContext.userId,
            action: 'LEAVE_REQUEST_REJECTED',
            target: `LeaveRequest:${requestId}`,
            meta: {
                employeeId: updatedRequest.employeeId,
                leaveTypeId: updatedRequest.leaveTypeId,
                from: updatedRequest.from,
                to: updatedRequest.to,
            },
        });

        return response.success({ request: updatedRequest });
    },
);

// ── Leave Calendar Handler (Task 6.2, Req 4.6) ──────────────────────────────

/**
 * GET /staff/leave/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD — returns approved and
 * pending leave requests within a date range for the authenticated business.
 *
 * Uses GSI1 on the leave requests (GSI1PK scoped to the business + entity type,
 * GSI1SK sorted by from-date) to efficiently query a date window. Both
 * 'approved' and 'pending' requests are returned to give calendar viewers
 * visibility into upcoming and tentative leave (Req 4.6).
 */
export const leaveCalendarHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);

        const qp = event.queryStringParameters ?? {};
        const parsed = leaveCalendarQuerySchema.safeParse({ from: qp.from, to: qp.to });
        if (!parsed.success) {
            throw new ValidationError(
                'Query parameters `from` and `to` (YYYY-MM-DD) are required',
                zodDetails(parsed.error.issues),
            );
        }

        const { from, to } = parsed.data;

        // Query leave requests for the business in the date range using the
        // repository's list-all method, then filter by status and date overlap.
        // For larger datasets a GSI1 range query would be more efficient, but
        // the current queryItems utility supports begins_with, not between. We
        // list all requests and filter in application code (acceptable at the
        // scale of leave requests per business — typically < 1000).
        const allRequests = await leaveRequestRepo.list(
            tenantContext.tenantId,
            tenantContext.businessId,
        );

        // Filter to approved + pending AND overlapping the [from, to] window.
        // A request overlaps the window if request.from <= window.to AND request.to >= window.from.
        const calendarItems = allRequests.filter((req) => {
            if (req.status !== 'approved' && req.status !== 'pending') return false;
            return req.from <= to && req.to >= from;
        });

        return response.success({
            from,
            to,
            items: calendarItems,
        });
    },
);
