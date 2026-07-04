// ============================================================================
// Staff Module — Task Analytics Service (Task 7.2)
// ============================================================================
// Pure, deterministic, side-effect-free function that aggregates task counts
// by assignee and by status. Keeping it pure and decoupled from I/O makes it
// trivially property-testable (Property 19, Req 5.6).
//
// The handler fetches all tasks for the business (via TaskRepository.list) and
// passes them to this function — a clean separation of concerns.
// ============================================================================

import { Task, TaskStatus } from '../schemas/task.schema';

// ── Result shapes ─────────────────────────────────────────────────────────────

/** Count of tasks grouped by a single assignee. */
export interface AssigneeCount {
    assigneeId: string;
    count: number;
}

/** Count of tasks grouped by a single status. */
export interface StatusCount {
    status: TaskStatus;
    count: number;
}

/** The complete analytics result for a business's task collection. */
export interface TaskAnalytics {
    total: number;
    byAssignee: AssigneeCount[];
    byStatus: StatusCount[];
}

// ── Pure aggregation function ─────────────────────────────────────────────────

/**
 * Aggregate task counts by assignee and by status.
 *
 * Property 19: For any collection of tasks, the analytics counts grouped by
 * assignee and by status equal the true counts obtained by direct grouping of
 * that collection.
 *
 * @param tasks  The full list of (non-deleted) tasks for a business.
 * @returns      Aggregated analytics with total count, counts per assignee
 *              (sorted descending by count), and counts per status (sorted
 *              descending by count).
 */
export function aggregateTaskAnalytics(tasks: Task[]): TaskAnalytics {
    const assigneeMap = new Map<string, number>();
    const statusMap = new Map<TaskStatus, number>();

    for (const task of tasks) {
        // Group by assignee
        assigneeMap.set(task.assigneeId, (assigneeMap.get(task.assigneeId) ?? 0) + 1);

        // Group by status
        statusMap.set(task.status, (statusMap.get(task.status) ?? 0) + 1);
    }

    // Convert maps to sorted arrays (descending by count for usability).
    const byAssignee: AssigneeCount[] = [...assigneeMap.entries()]
        .map(([assigneeId, count]) => ({ assigneeId, count }))
        .sort((a, b) => b.count - a.count || a.assigneeId.localeCompare(b.assigneeId));

    const byStatus: StatusCount[] = [...statusMap.entries()]
        .map(([status, count]) => ({ status, count }))
        .sort((a, b) => b.count - a.count || a.status.localeCompare(b.status));

    return {
        total: tasks.length,
        byAssignee,
        byStatus,
    };
}
