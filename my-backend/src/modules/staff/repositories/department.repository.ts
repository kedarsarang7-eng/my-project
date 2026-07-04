// ============================================================================
// Staff Module — Department Repository (Task 3.2)
// ============================================================================
// CRUD + deactivate for Department entities on the DynamoDB single table.
// SK: DEPT#{id}
// ============================================================================

import {
    buildDepartmentKeys,
    DEPT_SK_PREFIX,
    STAFF_ENTITY_TYPE,
    type StaffEntityKeys,
    type StaffEntityType,
} from '../keys';
import { BaseRepository, type BaseItem } from './base.repository';
import type { DepartmentCreateInput } from '../schemas/staff.schema';

// ── Domain type ─────────────────────────────────────────────────────────────

export interface Department {
    id: string;
    businessId: string;
    name: string;
    status: 'active' | 'inactive';
    createdAt: string;
    updatedAt: string;
}

type DepartmentItem = BaseItem & Department;

export class DepartmentRepository extends BaseRepository<Department, DepartmentCreateInput> {
    protected readonly entityType: StaffEntityType = STAFF_ENTITY_TYPE.DEPARTMENT;
    protected readonly skPrefix = DEPT_SK_PREFIX;

    protected buildKeys(
        tenantId: string,
        businessId: string,
        id: string,
    ): StaffEntityKeys {
        return buildDepartmentKeys(tenantId, businessId, id);
    }

    protected toDomain(item: BaseItem & Record<string, unknown>): Department {
        return {
            id: item.id,
            businessId: item.businessId,
            name: item.name as string,
            status: (item.status as 'active' | 'inactive') ?? 'active',
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
        };
    }

    protected buildCreateItem(
        tenantId: string,
        businessId: string,
        id: string,
        keys: StaffEntityKeys,
        data: DepartmentCreateInput,
        now: string,
    ): BaseItem & Record<string, unknown> {
        return {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entityType: this.entityType,
            tenantId,
            businessId,
            id,
            name: data.name,
            status: data.status ?? 'active',
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
        };
    }
}
