// ============================================================================
// Staff Module — Shift Repository (Task 5.3)
// ============================================================================
// CRUD + deactivate for Shift entities on the DynamoDB single table.
// SK: SHIFT#{id}
//
// DISAMBIGUATION: the base-table `begins_with(SK, 'SHIFT#')` scan can match
// petrol-pump fuel-shift items too. This repository filters by
// `entity_type = STAFF_SHIFT` on all queries (see keys.ts boundary note).
//
// Requirements: 3.3 (shift definitions per Business).
// ============================================================================

import {
    buildShiftKeys,
    STAFF_SHIFT_SK_PREFIX,
    STAFF_ENTITY_TYPE,
    type StaffEntityKeys,
    type StaffEntityType,
} from '../keys';
import { BaseRepository, type BaseItem } from './base.repository';
import type { Shift, ShiftCreateInput } from '../schemas/shift.schema';

type ShiftItem = BaseItem & Shift;

export class ShiftRepository extends BaseRepository<Shift, ShiftCreateInput> {
    protected readonly entityType: StaffEntityType = STAFF_ENTITY_TYPE.SHIFT;
    protected readonly skPrefix = STAFF_SHIFT_SK_PREFIX;

    protected buildKeys(
        tenantId: string,
        businessId: string,
        id: string,
    ): StaffEntityKeys {
        return buildShiftKeys(tenantId, businessId, id);
    }

    protected toDomain(item: BaseItem & Record<string, unknown>): Shift {
        return {
            id: item.id,
            businessId: item.businessId,
            name: item.name as string,
            start: item.start as string,
            end: item.end as string,
            breakRules: item.breakRules as Shift['breakRules'],
            lateThresholdMin: item.lateThresholdMin as number | undefined,
            overtimeRule: item.overtimeRule as Shift['overtimeRule'],
            geoFence: item.geoFence as Shift['geoFence'],
            approvalRule: item.approvalRule as Shift['approvalRule'],
            status: (item.status as 'active' | 'inactive') ?? 'active',
        };
    }

    protected buildCreateItem(
        tenantId: string,
        businessId: string,
        id: string,
        keys: StaffEntityKeys,
        data: ShiftCreateInput,
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
            start: data.start,
            end: data.end,
            ...(data.breakRules !== undefined ? { breakRules: data.breakRules } : {}),
            ...(data.lateThresholdMin !== undefined ? { lateThresholdMin: data.lateThresholdMin } : {}),
            ...(data.overtimeRule !== undefined ? { overtimeRule: data.overtimeRule } : {}),
            ...(data.geoFence !== undefined ? { geoFence: data.geoFence } : {}),
            ...(data.approvalRule !== undefined ? { approvalRule: data.approvalRule } : {}),
            status: data.status ?? 'active',
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
        };
    }
}
