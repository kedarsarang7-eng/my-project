// ============================================================================
// Staff Module — Task Management Handlers (Task 7.1)
// ============================================================================
// REST handlers for Task CRUD under /staff/tasks/*. Every handler:
//   1. runs behind `authorizedHandler` (Cognito auth + role enforcement),
//   2. resolves a validated TenantContext via `resolveStaffTenantScope`
//      (BusinessID from the authenticated session only — Req 11.3),
//   3. validates input with a Zod schema (fail-closed),
//   4. returns the standard response envelope.
//
// This handler integrates the three pure workflow functions from
// task-workflow.service.ts:
//   • Dependency gating (Property 17, Req 5.4): completing a task requires all
//     prerequisites to be complete first.
//   • Escalation (Property 18, Req 5.5): status-check endpoints trigger the
//     configured escalation action when elapsed time breaches the threshold.
//   • Recurrence (Property 16, Req 5.3): generating occurrences for a window
//     is exposed via a query endpoint.
//
// Task analytics aggregation (Task 7.2, Property 19, Req 5.6) is exposed via
// getTaskAnalyticsHandler using the pure aggregateTaskAnalytics function.
//
// Requirements: 5.1 (assignee/priority/status), 5.2 (attachments/comments/
// checklists), 5.3 (recurrence), 5.4 (dependencies gate completion),
// 5.5 (escalation on threshold breach).
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { authorizedHandler } from '../../../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../../../types/tenant.types';
import * as response from '../../../utils/response';
import { ValidationError } from '../../../utils/errors';
import { resolveStaffTenantScope } from './tenant-scope';
import { httpMethod, pathId, parseJsonBody } from './http';
import { TaskRepository, CreateTaskData } from '../repositories/task.repository';
import {
    createTaskSchema,
    updateTaskSchema,
    addTaskCommentSchema,
    TASK_DONE_STATUS,
    Task,
} from '../schemas/task.schema';
import {
    canCompleteTask,
    evaluateEscalation,
    elapsedHoursSince,
    generateOccurrences,
    DateWindow,
} from '../services/task-workflow.service';
import { aggregateTaskAnalytics } from '../services/task-analytics.service';
import { writeAuditEntry } from '../services/staff-audit.service';

// Roles permitted to reach the task surface.
const STAFF_ROLES: UserRole[] = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER];

const taskRepo = new TaskRepository();

/** Format Zod issues into a flat, client-safe details array. */
function zodDetails(issues: { path: PropertyKey[]; message: string }[]): string[] {
    return issues.map((i) => `${i.path.map(String).join('.') || '(root)'}: ${i.message}`);
}

// ── Task CRUD ─────────────────────────────────────────────────────────────────

/**
 * POST /staff/tasks — create a task.
 *
 * Records assignee, priority, status; supports optional attachments, comments,
 * checklists, recurrence rule, dependency list, and escalation policy (Req 5.1,
 * 5.2, 5.3, 5.5).
 */
export const createTaskHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const body = parseJsonBody(event);

        const parsed = createTaskSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid task input', zodDetails(parsed.error.issues));
        }
        const input = parsed.data;

        // Assign server-generated IDs to checklist/attachment items if missing.
        const checklist = input.checklist?.map((item) => ({
            id: item.id ?? randomUUID(),
            text: item.text,
            done: item.done,
        }));
        const attachments = input.attachments?.map((att) => ({
            id: att.id ?? randomUUID(),
            name: att.name,
            url: att.url,
            contentType: att.contentType,
            sizeBytes: att.sizeBytes,
            uploadedBy: att.uploadedBy,
            uploadedAt: att.uploadedAt,
        }));

        const data: CreateTaskData = {
            title: input.title,
            description: input.description,
            assigneeId: input.assigneeId,
            priority: input.priority,
            status: input.status,
            dependsOn: input.dependsOn,
            recurrence: input.recurrence,
            escalation: input.escalation,
            checklist,
            attachments,
            dueAt: input.dueAt,
        };

        const task = await taskRepo.create(
            tenantContext.tenantId,
            tenantContext.businessId,
            tenantContext.userId,
            data,
        );

        // Audit: record task creation (Req 8.3, Task 11.2).
        await writeAuditEntry(tenantContext.tenantId, tenantContext.businessId, {
            actor: tenantContext.userId,
            action: 'CREATE',
            target: `Task:${task.id}`,
        });

        return response.success(task, 201);
    },
);

/**
 * GET /staff/tasks — list all tasks for the business.
 *
 * This is the clean integration point for task 7.2 (analytics aggregation).
 */
export const listTasksHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const items = await taskRepo.list(
            tenantContext.tenantId,
            tenantContext.businessId,
        );
        return response.success({ items });
    },
);

/**
 * GET /staff/tasks/:id — get a single task by ID.
 */
export const getTaskHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const taskId = pathId(event);
        if (!taskId) {
            throw new ValidationError("Path parameter 'id' is required");
        }

        const task = await taskRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            taskId,
        );
        if (!task) {
            return response.notFound('Task');
        }
        return response.success(task);
    },
);

/**
 * PATCH /staff/tasks/:id — update a task (partial update).
 *
 * Enforces dependency gating (Property 17, Req 5.4): if the update transitions
 * status to 'done' and the task has dependencies, all prerequisites must
 * already be complete. Otherwise a 409 CONFLICT is returned with the blocking
 * prerequisite IDs.
 *
 * Tracks progress: when status changes, `lastProgressAt` is refreshed so
 * escalation elapsed time is correctly measured from the latest progress.
 */
export const updateTaskHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const taskId = pathId(event);
        if (!taskId) {
            throw new ValidationError("Path parameter 'id' is required");
        }

        const body = parseJsonBody(event);
        const parsed = updateTaskSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid task update', zodDetails(parsed.error.issues));
        }
        const patch = parsed.data;

        // Fetch the current task to check dependencies/status.
        const existing = await taskRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            taskId,
        );
        if (!existing) {
            return response.notFound('Task');
        }

        // ─── Dependency gating (Property 17, Req 5.4) ────────────────────────
        // If transitioning to 'done' and the task has dependencies, verify all
        // prerequisites are complete.
        if (
            patch.status === TASK_DONE_STATUS &&
            existing.status !== TASK_DONE_STATUS &&
            existing.dependsOn &&
            existing.dependsOn.length > 0
        ) {
            // Fetch prerequisite statuses.
            const prerequisiteStatus: Record<string, Task['status']> = {};
            for (const depId of existing.dependsOn) {
                const dep = await taskRepo.get(
                    tenantContext.tenantId,
                    tenantContext.businessId,
                    depId,
                );
                if (dep) {
                    prerequisiteStatus[depId] = dep.status;
                }
                // Missing prerequisites are treated as NOT complete (fail-closed).
            }

            const gate = canCompleteTask(existing.dependsOn, prerequisiteStatus);
            if (!gate.allowed) {
                return response.error(
                    409,
                    'DEPENDENCY_GATE',
                    'Cannot complete task: prerequisite tasks are not done',
                    { blockedBy: gate.blockedBy },
                );
            }
        }

        // Track progress: refresh lastProgressAt when status changes.
        const finalPatch: Record<string, unknown> = { ...patch };
        if (patch.status && patch.status !== existing.status) {
            finalPatch.lastProgressAt = new Date().toISOString();
        }

        const updated = await taskRepo.update(
            tenantContext.tenantId,
            tenantContext.businessId,
            taskId,
            finalPatch as Partial<Task>,
        );
        if (!updated) {
            return response.notFound('Task');
        }

        // Audit: record task update (Req 8.3, Task 11.2).
        await writeAuditEntry(tenantContext.tenantId, tenantContext.businessId, {
            actor: tenantContext.userId,
            action: 'UPDATE',
            target: `Task:${taskId}`,
        });

        return response.success(updated);
    },
);

/**
 * DELETE /staff/tasks/:id — soft-delete a task.
 */
export const deleteTaskHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const taskId = pathId(event);
        if (!taskId) {
            throw new ValidationError("Path parameter 'id' is required");
        }

        const deleted = await taskRepo.softDelete(
            tenantContext.tenantId,
            tenantContext.businessId,
            taskId,
        );
        if (!deleted) {
            return response.notFound('Task');
        }

        // Audit: record task deletion (Req 8.3, Task 11.2).
        await writeAuditEntry(tenantContext.tenantId, tenantContext.businessId, {
            actor: tenantContext.userId,
            action: 'DELETE',
            target: `Task:${taskId}`,
        });

        return response.success({ deleted: true });
    },
);

// ── Comments (Req 5.2) ───────────────────────────────────────────────────────

/**
 * POST /staff/tasks/:id/comments — add a comment to a task.
 */
export const addTaskCommentHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const taskId = pathId(event);
        if (!taskId) {
            throw new ValidationError("Path parameter 'id' is required");
        }

        const body = parseJsonBody(event);
        const parsed = addTaskCommentSchema.safeParse(body);
        if (!parsed.success) {
            throw new ValidationError('Invalid comment', zodDetails(parsed.error.issues));
        }

        const existing = await taskRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            taskId,
        );
        if (!existing) {
            return response.notFound('Task');
        }

        const newComment = {
            id: randomUUID(),
            authorId: tenantContext.userId,
            text: parsed.data.text,
            createdAt: new Date().toISOString(),
        };

        const comments = [...(existing.comments ?? []), newComment];
        const updated = await taskRepo.update(
            tenantContext.tenantId,
            tenantContext.businessId,
            taskId,
            { comments } as Partial<Task>,
        );
        return response.success(updated, 201);
    },
);

// ── Escalation check (Req 5.5, Property 18) ─────────────────────────────────

/**
 * POST /staff/tasks/:id/escalation-check — evaluate and trigger escalation.
 *
 * If the task has passed its configured escalation threshold without
 * progressing, the configured escalation action is triggered exactly once and
 * the task is marked with `escalatedAt` to prevent repeat firing.
 */
export const checkTaskEscalationHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const taskId = pathId(event);
        if (!taskId) {
            throw new ValidationError("Path parameter 'id' is required");
        }

        const task = await taskRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            taskId,
        );
        if (!task) {
            return response.notFound('Task');
        }

        const elapsed = elapsedHoursSince(task.lastProgressAt);
        const decision = evaluateEscalation(
            task.escalation,
            task.status,
            elapsed,
            !!task.escalatedAt,
        );

        if (decision.shouldEscalate) {
            // Mark the task as escalated (at-most-once guarantee).
            await taskRepo.update(
                tenantContext.tenantId,
                tenantContext.businessId,
                taskId,
                { escalatedAt: new Date().toISOString() } as Partial<Task>,
            );

            return response.success({
                escalated: true,
                action: decision.action,
                elapsedHours: elapsed,
                thresholdHours: task.escalation!.thresholdHours,
            });
        }

        return response.success({
            escalated: false,
            elapsedHours: elapsed,
            thresholdHours: task.escalation?.thresholdHours ?? null,
            alreadyEscalated: !!task.escalatedAt,
        });
    },
);

// ── Task analytics (Req 5.6, Property 19) ────────────────────────────────────

/**
 * GET /staff/tasks/analytics — aggregate task counts by assignee and status.
 *
 * Fetches all tasks for the business and applies the pure aggregateTaskAnalytics
 * function. The result includes total count, counts per assignee, and counts
 * per status — all scoped to the authenticated BusinessID (Req 5.6).
 */
export const getTaskAnalyticsHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const tasks = await taskRepo.list(
            tenantContext.tenantId,
            tenantContext.businessId,
        );
        const analytics = aggregateTaskAnalytics(tasks);
        return response.success(analytics);
    },
);

// ── Recurrence occurrences (Req 5.3, Property 16) ────────────────────────────

/**
 * GET /staff/tasks/:id/occurrences?from=YYYY-MM-DD&to=YYYY-MM-DD
 *
 * Returns the occurrence dates generated by the task's recurrence rule within
 * the specified window.
 */
export const getTaskOccurrencesHandler = authorizedHandler(
    STAFF_ROLES,
    async (
        event: APIGatewayProxyEventV2,
        _ctx: Context,
        auth: AuthContext,
    ): Promise<APIGatewayProxyResultV2> => {
        const { tenantContext } = await resolveStaffTenantScope(event, auth);
        const taskId = pathId(event);
        if (!taskId) {
            throw new ValidationError("Path parameter 'id' is required");
        }

        const from = event.queryStringParameters?.from;
        const to = event.queryStringParameters?.to;
        if (!from || !to) {
            throw new ValidationError("Query parameters 'from' and 'to' (YYYY-MM-DD) are required");
        }

        const task = await taskRepo.get(
            tenantContext.tenantId,
            tenantContext.businessId,
            taskId,
        );
        if (!task) {
            return response.notFound('Task');
        }

        if (!task.recurrence) {
            return response.success({ occurrences: [], message: 'Task has no recurrence rule' });
        }

        const window: DateWindow = { from, to };
        const occurrences = generateOccurrences(task.recurrence, window);
        return response.success({ occurrences });
    },
);
