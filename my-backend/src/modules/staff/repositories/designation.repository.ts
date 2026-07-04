// ============================================================================
// Staff Module — Designation Repository (Task 3.2)
// ============================================================================
// CRUD + deactivate for Designation entities on the DynamoDB single table.
// SK: DESIG#{id}
// ============================================================================

import {
    buildDesignationKeys,
    DESIG_SK_PREFIX,
    STAFF_ENTITY_TYPE,
    type StaffEntityKeys,
    type StaffEntityType,
} from '../keys';
import { BaseRepository, type BaseItem } from './base.repository';
import type { DesignationCreateInput } from '../schemas/staff.schema';

// ── Domain type ─────────────────────────────────────────────────────────────

export interface Designation {
    id: string;
    businessId: string;
    title: string;
    departmentId?: string;
    status: 'active' | 'inactive';
    createdAt: string;
    updatedAt: string;
}

type DesignationItem = BaseItem & Designation;

export class DesignationRepository extends BaseRepository<Designation, DesignationCreateInput> {
    protected readonly entityType: StaffEntityType = STAFF_ENTITY_TYPE.DESIGNATION;
    protected readonly skPrefix = DESIG_SK_PREFIX;

    protected buildKeys(
        tenantId: string,
        businessId: string,
        id: string,
    ): StaffEntityKeys {
        return buildDesignationKeys(tenantId, businessId, id);
    }

    protected toDomain(item: BaseItem & Record<string, unknown>): Designation {
        return {
            id: item.id,
            businessId: item.businessId,
            title: item.title as string,
            departmentId: item.departmentId as string | undefined,
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
        data: DesignationCreateInput,
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
            title: data.title,
            departmentId: data.departmentId,
            status: data.status ?? 'active',
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
        };
    }
}
