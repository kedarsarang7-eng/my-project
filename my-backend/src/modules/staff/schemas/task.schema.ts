// ============================================================================
// Staff Module — Task Item Shape + Zod Schemas (Task 7.1)
// ============================================================================
// The Task entity models an assignable unit of work with rich metadata and a
// small workflow: assignee/priority/status, attachments, comments, checklists,
// a recurrence rule, task dependencies, and an escalation policy.
//
// DynamoDB single-table item — SK: TASK#{id}
// (key builder: ../keys.ts::buildTaskKeys). Every record is tenant + business
// scoped (PK = TENANT#{tenantId}#BIZ#{businessId}); BusinessID is the leading
// partition scope (Req 1.5, 11.1).
//
// Requirements: 5.1 (assignee/priority/status), 5.2 (attachments/comments/
// checklists), 5.3 (recurrence), 5.4 (dependencies gate completion), 5.5
// (escalation on threshold breach).
// ============================================================================

import { z } from 'zod';

// ── Enumerations ──────────────────────────────────────────────────────────────

export const TASK_PRIORITIES = ['low', 'medium', 'high'] as const;
export type TaskPriority = (typeof TASK_PRIORITIES)[number];

export const TASK_STATUSES = ['open', 'in_progress', 'blocked', 'done'] as const;
export type TaskStatus = (typeof TASK_STATUSES)[number];

/** The single terminal status. A task in this status is "complete". */
export const TASK_DONE_STATUS: TaskStatus = 'done';

export const RECURRENCE_FREQUENCIES = ['daily', 'weekly', 'monthly'] as const;
export type RecurrenceFrequency = (typeof RECURRENCE_FREQUENCIES)[number];

// ── Sub-shapes ────────────────────────────────────────────────────────────────

export interface TaskAttachment {
    id: string;
    name: string;
    url: string;
    contentType?: string;
    sizeBytes?: number;
    uploadedBy?: string;
    uploadedAt?: string;
}

export interface TaskComment {
    id: string;
    authorId: string;
    text: string;
    createdAt: string;
}

export interface TaskChecklistItem {
    id: string;
    text: string;
    done: boolean;
}

/**
 * A calendar recurrence rule. Occurrences are generated deterministically by
 * `services/task-workflow.service.ts::generateOccurrences` (Property 16).
 *
 *  - `frequency` + `interval` define the cadence (every N days/weeks/months).
 *  - `startDate` anchors the sequence (inclusive), format 'YYYY-MM-DD'.
 *  - `count` caps the total number of occurrences from `startDate`.
 *  - `until` is an inclusive end date 'YYYY-MM-DD'.
 *  - `byWeekday` (weekly only) selects weekdays 0..6 where 0 = Sunday.
 */
export interface RecurrenceRule {
    frequency: RecurrenceFrequency;
    interval: number;
    startDate: string;
    count?: number;
    until?: string;
    byWeekday?: number[];
}

/**
 * Escalation policy. When a task passes `thresholdHours` without progressing,
 * the configured `action` is triggered exactly once (Property 18, Req 5.5).
 */
export interface TaskEscalation {
    thresholdHours: number;
    action: string;
}

// ── Item shape (stored) ─────────────────────────────────────────────────────

export interface Task {
    id: string;
    businessId: string;
    title: string;
    description?: string;
    assigneeId: string;
    priority: TaskPriority;
    status: TaskStatus;
    dependsOn?: string[];
    recurrence?: RecurrenceRule;
    escalation?: TaskEscalation;
    attachments?: TaskAttachment[];
    comments?: TaskComment[];
    checklist?: TaskChecklistItem[];
    dueAt?: string;
    /**
     * Timestamp of the task's last forward progress (creation, or the most
     * recent status change). Escalation elapsed time is measured from here so
     * "without progressing" is honoured precisely (Req 5.5).
     */
    lastProgressAt: string;
    /** Set once when escalation has been triggered — guarantees at-most-once. */
    escalatedAt?: string;
    createdBy?: string;
    createdAt: string;
    updatedAt: string;
}

// ── Shared validators ─────────────────────────────────────────────────────────

const nonEmpty = z.string().min(1);

/** Identifiers used in SK segments must never contain the '#' delimiter. */
const skSafeId = nonEmpty
    .max(128)
    .refine((v) => !v.includes('#'), { message: "id must not contain '#'" });

const dateOnly = z
    .string()
    .regex(/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/, 'date must be YYYY-MM-DD');

const isoTimestamp = z.string().datetime({ offset: true });

// ── Component schemas ─────────────────────────────────────────────────────────

export const recurrenceRuleSchema = z
    .object({
        frequency: z.enum(RECURRENCE_FREQUENCIES),
        interval: z.number().int().positive(),
        startDate: dateOnly,
        count: z.number().int().positive().optional(),
        until: dateOnly.optional(),
        byWeekday: z.array(z.number().int().min(0).max(6)).nonempty().optional(),
    })
    .superRefine((rule, ctx) => {
        if (rule.byWeekday && rule.frequency !== 'weekly') {
            ctx.addIssue({
                code: 'custom',
                message: 'byWeekday is only valid for weekly recurrence',
                path: ['byWeekday'],
            });
        }
        if (rule.until && rule.until < rule.startDate) {
            ctx.addIssue({
                code: 'custom',
                message: 'until must not be before startDate',
                path: ['until'],
            });
        }
    });

export const taskEscalationSchema = z.object({
    thresholdHours: z.number().positive(),
    action: nonEmpty.max(200),
});

export const taskAttachmentSchema = z.object({
    id: skSafeId,
    name: nonEmpty.max(255),
    url: nonEmpty.max(2048),
    contentType: z.string().max(200).optional(),
    sizeBytes: z.number().int().nonnegative().optional(),
    uploadedBy: z.string().max(128).optional(),
    uploadedAt: isoTimestamp.optional(),
});

export const taskChecklistItemSchema = z.object({
    id: skSafeId,
    text: nonEmpty.max(500),
    done: z.boolean(),
});

export const taskCommentSchema = z.object({
    id: skSafeId,
    authorId: nonEmpty.max(128),
    text: nonEmpty.max(2000),
    createdAt: isoTimestamp,
});

// ── Handler input schemas ─────────────────────────────────────────────────────

/**
 * Create-task input. `businessId`/`tenantId` are NEVER accepted from the client
 * (derived from the authenticated session — Req 11.3), so they are absent here.
 */
export const createTaskSchema = z.object({
    title: nonEmpty.max(255),
    description: z.string().max(4000).optional(),
    assigneeId: nonEmpty.max(128),
    priority: z.enum(TASK_PRIORITIES).default('medium'),
    status: z.enum(TASK_STATUSES).default('open'),
    dependsOn: z.array(skSafeId).max(50).optional(),
    recurrence: recurrenceRuleSchema.optional(),
    escalation: taskEscalationSchema.optional(),
    // Checklist items may be provided without ids; ids are assigned server-side.
    checklist: z
        .array(taskChecklistItemSchema.partial({ id: true }))
        .max(200)
        .optional(),
    attachments: z
        .array(taskAttachmentSchema.partial({ id: true }))
        .max(50)
        .optional(),
    dueAt: isoTimestamp.optional(),
});

export type CreateTaskInput = z.infer<typeof createTaskSchema>;

/** Update-task input — every field optional; unknown fields rejected. */
export const updateTaskSchema = z
    .object({
        title: nonEmpty.max(255),
        description: z.string().max(4000),
        assigneeId: nonEmpty.max(128),
        priority: z.enum(TASK_PRIORITIES),
        status: z.enum(TASK_STATUSES),
        dependsOn: z.array(skSafeId).max(50),
        recurrence: recurrenceRuleSchema,
        escalation: taskEscalationSchema,
        checklist: z.array(taskChecklistItemSchema).max(200),
        dueAt: isoTimestamp,
    })
    .partial()
    .strict()
    .refine((v) => Object.keys(v).length > 0, {
        message: 'At least one field must be provided to update',
    });

export type UpdateTaskInput = z.infer<typeof updateTaskSchema>;

/** Add-comment input. */
export const addTaskCommentSchema = z.object({
    text: nonEmpty.max(2000),
});

export type AddTaskCommentInput = z.infer<typeof addTaskCommentSchema>;
