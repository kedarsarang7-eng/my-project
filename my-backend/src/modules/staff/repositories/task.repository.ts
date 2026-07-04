// ============================================================================
// Staff Module — Task Repository (Task 7.1)
// ============================================================================
// Persistence for Task items on the DynamoDB single table.
//
// TENANT/BUSINESS ISOLATION INVARIANT
// -----------------------------------
// Every read/write is scoped to the business partition
//     PK = TENANT#{tenantId}#BIZ#{businessId}
// built ONLY via ../keys.ts::buildTaskKeys (which uses the shared businessPK
// builder that rejects '#' injection). BusinessID is always the leading
// partition scope (Req 1.5, 11.1). Like StaffFeatureConfigRepository, this
// repository composes the low-level single-table helpers directly rather than
// extending the tenant-partition BaseRepository, because staff entities use the
// finer-grained business partition.
//
// SK: TASK#{id}
// ============================================================================

import { randomUUID } from 'crypto';
import {
    getItem,
    putItem,
    queryAllItems,
    updateItem,
} from '../../../config/dynamodb.config';
import { businessPK } from '../../../dynamodb/keys';
import {
    buildTaskKeys,
    taskSK,
    TASK_SK_PREFIX,
    STAFF_ENTITY_TYPE,
} from '../keys';
import { Task } from '../schemas/task.schema';

/** Stored shape: the task plus table keys + scope/audit attributes. */
export type TaskItem = Task & {
    PK: string;
    SK: string;
    GSI1PK?: string;
    GSI1SK?: string;
    entity_type: string;
    tenantId: string;
    businessId: string;
    isDeleted: boolean;
};

/** Strip the DynamoDB envelope, returning the domain Task. */
function toTask(item: TaskItem): Task {
    const {
        PK: _pk,
        SK: _sk,
        GSI1PK: _g1pk,
        GSI1SK: _g1sk,
        entity_type: _et,
        tenantId: _t,
        isDeleted: _d,
        ...task
    } = item;
    void _pk; void _sk; void _g1pk; void _g1sk; void _et; void _t; void _d;
    return task as Task;
}

export interface CreateTaskData {
    title: string;
    description?: string;
    assigneeId: string;
    priority: Task['priority'];
    status: Task['status'];
    dependsOn?: string[];
    recurrence?: Task['recurrence'];
    escalation?: Task['escalation'];
    attachments?: Task['attachments'];
    comments?: Task['comments'];
    checklist?: Task['checklist'];
    dueAt?: string;
}

export class TaskRepository {
    /**
     * Create a task, assigning a server-generated id and scoping it to the
     * caller's business partition. `lastProgressAt` is initialised to the
     * creation time so escalation elapsed-time is measured from creation.
     */
    async create(
        tenantId: string,
        businessId: string,
        createdBy: string,
        data: CreateTaskData,
    ): Promise<Task> {
        const id = randomUUID();
        const now = new Date().toISOString();
        const keys = buildTaskKeys(tenantId, businessId, id, now);

        const item: TaskItem = {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entity_type: STAFF_ENTITY_TYPE.TASK,
            tenantId,
            businessId,
            id,
            title: data.title,
            description: data.description,
            assigneeId: data.assigneeId,
            priority: data.priority,
            status: data.status,
            dependsOn: data.dependsOn,
            recurrence: data.recurrence,
            escalation: data.escalation,
            attachments: data.attachments,
            comments: data.comments,
            checklist: data.checklist,
            dueAt: data.dueAt,
            lastProgressAt: now,
            createdBy,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        };

        await putItem(item as unknown as Record<string, unknown>);
        return toTask(item);
    }

    /** Fetch one task by id. Returns null when absent or soft-deleted. */
    async get(tenantId: string, businessId: string, taskId: string): Promise<Task | null> {
        const item = await getItem<TaskItem>(businessPK(tenantId, businessId), taskSK(taskId));
        if (!item || item.isDeleted) return null;
        return toTask(item);
    }

    /**
     * List every (non-deleted) task in the business. This is the clean
     * integration point consumed by task-analytics aggregation (task 7.2).
     */
    async list(tenantId: string, businessId: string): Promise<Task[]> {
        const items = await queryAllItems<TaskItem>(
            businessPK(tenantId, businessId),
            TASK_SK_PREFIX,
            {
                filterExpression:
                    '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND entity_type = :et',
                expressionAttributeValues: {
                    ':false': false,
                    ':et': STAFF_ENTITY_TYPE.TASK,
                },
            },
        );
        return items.map(toTask);
    }

    /**
     * Patch the mutable fields of a task. Only provided keys are written;
     * `updatedAt` is always refreshed. Returns the updated task (or null if it
     * does not exist).
     */
    async update(
        tenantId: string,
        businessId: string,
        taskId: string,
        patch: Partial<Task>,
    ): Promise<Task | null> {
        const now = new Date().toISOString();
        const entries = Object.entries({ ...patch, updatedAt: now }).filter(
            ([, v]) => v !== undefined,
        );

        const setParts = entries.map(([, ], i) => `#k${i} = :v${i}`).join(', ');
        const names: Record<string, string> = {};
        const values: Record<string, unknown> = {};
        entries.forEach(([k, v], i) => {
            names[`#k${i}`] = k;
            values[`:v${i}`] = v;
        });

        const updated = await updateItem(businessPK(tenantId, businessId), taskSK(taskId), {
            updateExpression: `SET ${setParts}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
            conditionExpression: 'attribute_exists(PK)',
        });

        return updated ? toTask(updated as unknown as TaskItem) : null;
    }

    /** Soft-delete a task (sets isDeleted = true). */
    async softDelete(tenantId: string, businessId: string, taskId: string): Promise<boolean> {
        try {
            await updateItem(businessPK(tenantId, businessId), taskSK(taskId), {
                updateExpression: 'SET isDeleted = :true, updatedAt = :now',
                expressionAttributeValues: { ':true': true, ':now': new Date().toISOString() },
                conditionExpression: 'attribute_exists(PK)',
            });
            return true;
        } catch {
            return false;
        }
    }
}
