// ============================================================================
// Staff Module — Leave Repositories (Task 6.1)
// ============================================================================
// Persistence for the three leave entities on the DynamoDB single table:
//   LeaveTypeRepository    — LVTYPE#{id}
//   LeaveRequestRepository — LVREQ#{id}
//   LeaveBalanceRepository — LVBAL#{employeeId}#{leaveTypeId}
//
// TENANT/BUSINESS ISOLATION INVARIANT
// -----------------------------------
// Every read/write is scoped to the business partition
//     PK = TENANT#{tenantId}#BIZ#{businessId}
// built ONLY via ../keys.ts builders (which use the shared businessPK builder
// that rejects '#' injection). BusinessID is always the leading partition scope
// (Req 1.5, 11.1). Like StaffFeatureConfigRepository, these repositories compose
// the low-level dynamodb.config helpers directly rather than extending the
// tenant-partition BaseRepository, because staff entities use the finer-grained
// business partition.
// ============================================================================

import { randomUUID } from 'crypto';
import {
    getItem,
    putItem,
    queryItems,
    updateItemWithVersion,
} from '../../../config/dynamodb.config';
import {
    buildLeaveTypeKeys,
    buildLeaveRequestKeys,
    buildLeaveBalanceKeys,
    LVTYPE_SK_PREFIX,
    LVREQ_SK_PREFIX,
    LVBAL_SK_PREFIX,
    STAFF_ENTITY_TYPE,
} from '../keys';
import {
    LeaveType,
    LeaveRequest,
    LeaveBalance,
    LeaveTypeStatus,
    LeaveRequestStatus,
    AccrualRule,
    LeaveTypeRules,
} from '../schemas/leave.schema';

// ── Common stored-item scaffolding ────────────────────────────────────────────

interface BaseItem {
    PK: string;
    SK: string;
    GSI1PK?: string;
    GSI1SK?: string;
    entityType: string;
    tenantId: string;
    businessId: string;
    isDeleted: boolean;
    createdAt: string;
    updatedAt: string;
}

const NOT_DELETED_FILTER = {
    filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
    expressionAttributeValues: { ':false': false },
};

// ============================================================================
// LeaveType
// ============================================================================

type LeaveTypeItem = LeaveType & BaseItem;

function toLeaveType(item: LeaveTypeItem): LeaveType {
    return {
        id: item.id,
        businessId: item.businessId,
        name: item.name,
        accrualRule: item.accrualRule,
        rules: item.rules,
        status: item.status,
    };
}

export class LeaveTypeRepository {
    async create(
        tenantId: string,
        businessId: string,
        data: { name: string; accrualRule: AccrualRule; rules: LeaveTypeRules; status: LeaveTypeStatus },
    ): Promise<LeaveType> {
        const id = randomUUID();
        const keys = buildLeaveTypeKeys(tenantId, businessId, id);
        const now = new Date().toISOString();
        const item: LeaveTypeItem = {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entityType: STAFF_ENTITY_TYPE.LEAVE_TYPE,
            tenantId,
            businessId,
            id,
            name: data.name,
            accrualRule: data.accrualRule,
            rules: data.rules,
            status: data.status,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
        };
        await putItem(item as unknown as Record<string, unknown>);
        return toLeaveType(item);
    }

    async get(tenantId: string, businessId: string, id: string): Promise<LeaveType | null> {
        const keys = buildLeaveTypeKeys(tenantId, businessId, id);
        const item = await getItem<LeaveTypeItem>(keys.PK, keys.SK);
        if (!item || item.isDeleted) return null;
        return toLeaveType(item);
    }

    async list(tenantId: string, businessId: string): Promise<LeaveType[]> {
        const keys = buildLeaveTypeKeys(tenantId, businessId, 'x');
        const result = await queryItems<LeaveTypeItem>(keys.PK, LVTYPE_SK_PREFIX, NOT_DELETED_FILTER);
        return result.items.map(toLeaveType);
    }
}

// ============================================================================
// LeaveBalance
// ============================================================================

type LeaveBalanceItem = LeaveBalance & BaseItem;

function toLeaveBalance(item: LeaveBalanceItem): LeaveBalance {
    return {
        id: item.id,
        businessId: item.businessId,
        employeeId: item.employeeId,
        leaveTypeId: item.leaveTypeId,
        balance: item.balance,
    };
}

export class LeaveBalanceRepository {
    async get(
        tenantId: string,
        businessId: string,
        employeeId: string,
        leaveTypeId: string,
    ): Promise<LeaveBalance | null> {
        const keys = buildLeaveBalanceKeys(tenantId, businessId, employeeId, leaveTypeId);
        const item = await getItem<LeaveBalanceItem>(keys.PK, keys.SK);
        if (!item || item.isDeleted) return null;
        return toLeaveBalance(item);
    }

    async listForEmployee(
        tenantId: string,
        businessId: string,
        employeeId: string,
    ): Promise<LeaveBalance[]> {
        // Composite SK is LVBAL#{employeeId}#{leaveTypeId} — a prefix scan on the
        // employee segment returns all that employee's balances (O(matched)).
        const keys = buildLeaveBalanceKeys(tenantId, businessId, employeeId, 'x');
        const result = await queryItems<LeaveBalanceItem>(
            keys.PK,
            `${LVBAL_SK_PREFIX}${employeeId}#`,
            NOT_DELETED_FILTER,
        );
        return result.items.map(toLeaveBalance);
    }

    /**
     * Create or overwrite the balance for an (employee, leaveType). Used to set
     * an opening balance or apply an accrual result. Approval-time deductions are
     * task 6.2.
     */
    async upsert(
        tenantId: string,
        businessId: string,
        employeeId: string,
        leaveTypeId: string,
        balance: number,
    ): Promise<LeaveBalance> {
        const keys = buildLeaveBalanceKeys(tenantId, businessId, employeeId, leaveTypeId);
        const now = new Date().toISOString();
        const existing = await getItem<LeaveBalanceItem>(keys.PK, keys.SK);
        const item: LeaveBalanceItem = {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entityType: STAFF_ENTITY_TYPE.LEAVE_BALANCE,
            tenantId,
            businessId,
            id: existing?.id ?? `${employeeId}:${leaveTypeId}`,
            employeeId,
            leaveTypeId,
            balance,
            isDeleted: false,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
        };
        await putItem(item as unknown as Record<string, unknown>);
        return toLeaveBalance(item);
    }
}

// ============================================================================
// LeaveRequest
// ============================================================================

type LeaveRequestItem = LeaveRequest & BaseItem;

function toLeaveRequest(item: LeaveRequestItem): LeaveRequest {
    return {
        id: item.id,
        businessId: item.businessId,
        employeeId: item.employeeId,
        leaveTypeId: item.leaveTypeId,
        from: item.from,
        to: item.to,
        status: item.status,
        version: item.version,
    };
}

export class LeaveRequestRepository {
    /**
     * Persist a validated leave request. Callers MUST validate against the leave
     * type rules + available balance (leave.service.validateLeaveRequest) before
     * creating. New requests start `pending` with version 0; balances are NOT
     * touched here (deduction happens on approval — task 6.2).
     */
    async create(
        tenantId: string,
        businessId: string,
        data: {
            employeeId: string;
            leaveTypeId: string;
            from: string;
            to: string;
            status?: LeaveRequestStatus;
        },
    ): Promise<LeaveRequest> {
        const id = randomUUID();
        const keys = buildLeaveRequestKeys(tenantId, businessId, id, data.from);
        const now = new Date().toISOString();
        const item: LeaveRequestItem = {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entityType: STAFF_ENTITY_TYPE.LEAVE_REQUEST,
            tenantId,
            businessId,
            id,
            employeeId: data.employeeId,
            leaveTypeId: data.leaveTypeId,
            from: data.from,
            to: data.to,
            status: data.status ?? 'pending',
            version: 0,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
        };
        await putItem(item as unknown as Record<string, unknown>);
        return toLeaveRequest(item);
    }

    async get(tenantId: string, businessId: string, id: string): Promise<LeaveRequest | null> {
        const keys = buildLeaveRequestKeys(tenantId, businessId, id, '0000-00-00');
        const item = await getItem<LeaveRequestItem>(keys.PK, keys.SK);
        if (!item || item.isDeleted) return null;
        return toLeaveRequest(item);
    }

    async list(tenantId: string, businessId: string): Promise<LeaveRequest[]> {
        const keys = buildLeaveRequestKeys(tenantId, businessId, 'x', '0000-00-00');
        const result = await queryItems<LeaveRequestItem>(keys.PK, LVREQ_SK_PREFIX, NOT_DELETED_FILTER);
        return result.items.map(toLeaveRequest);
    }

    /**
     * Update the status of a leave request using optimistic concurrency on the
     * `version` field (design.md). Wired into the approval workflow in task 6.2;
     * exposed here so the entity is complete.
     *
     * @throws OptimisticLockError (409) on a version mismatch.
     */
    async updateStatus(
        tenantId: string,
        businessId: string,
        id: string,
        from: string,
        status: LeaveRequestStatus,
        expectedVersion: number,
    ): Promise<LeaveRequest | null> {
        const keys = buildLeaveRequestKeys(tenantId, businessId, id, from);
        const now = new Date().toISOString();
        const updated = await updateItemWithVersion(
            keys.PK,
            keys.SK,
            {
                updateExpression: '#status = :status, updatedAt = :now',
                expressionAttributeNames: { '#status': 'status' },
                expressionAttributeValues: { ':status': status, ':now': now },
            },
            expectedVersion,
            'version',
        );
        return updated ? toLeaveRequest(updated as unknown as LeaveRequestItem) : null;
    }
}
