// ============================================================================
// Staff Module — Roster Repository (Task 5.3)
// ============================================================================
// CRUD + deactivate for Roster entities on the DynamoDB single table.
// SK: ROSTER#{id}
//
// A roster is a date-specific collection of shift assignments. The roster-builder
// service validates assignments against shift rules before persistence — only
// assignments that pass enforcement reach this repository.
//
// Requirements: 3.7 (assign shifts on roster build).
// ============================================================================

import {
    buildRosterKeys,
    ROSTER_SK_PREFIX,
    STAFF_ENTITY_TYPE,
    type StaffEntityKeys,
    type StaffEntityType,
} from '../keys';
import { BaseRepository, type BaseItem } from './base.repository';
import type { Roster, RosterCreateInput, RosterAssignment } from '../schemas/shift.schema';

type RosterItem = BaseItem & Roster;

export class RosterRepository extends BaseRepository<Roster, RosterCreateInput> {
    protected readonly entityType: StaffEntityType = STAFF_ENTITY_TYPE.ROSTER;
    protected readonly skPrefix = ROSTER_SK_PREFIX;

    protected buildKeys(
        tenantId: string,
        businessId: string,
        id: string,
        extras?: Record<string, string>,
    ): StaffEntityKeys {
        // The roster key builder requires a date for GSI1 ordering. When the
        // date is not yet known (e.g. get-by-id), use a placeholder that won't
        // affect the PK/SK (GSI1 keys are only used on create).
        const date = extras?.date ?? '9999-12-31';
        return buildRosterKeys(tenantId, businessId, id, date);
    }

    protected toDomain(item: BaseItem & Record<string, unknown>): Roster {
        return {
            id: item.id,
            businessId: item.businessId,
            date: item.date as string,
            assignments: (item.assignments as RosterAssignment[]) ?? [],
            status: (item.status as 'active' | 'inactive') ?? 'active',
        };
    }

    protected buildCreateItem(
        tenantId: string,
        businessId: string,
        id: string,
        keys: StaffEntityKeys,
        data: RosterCreateInput,
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
            date: data.date,
            assignments: data.assignments,
            status: 'active',
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
        };
    }

    /**
     * Override the base create to accept date for proper GSI1 key construction.
     */
    async create(
        tenantId: string,
        businessId: string,
        data: RosterCreateInput,
    ): Promise<Roster> {
        const { randomUUID } = await import('crypto');
        const id = randomUUID();
        const now = new Date().toISOString();
        const keys = this.buildKeys(tenantId, businessId, id, { date: data.date });
        const item = this.buildCreateItem(tenantId, businessId, id, keys, data, now);
        const { putItem } = await import('../../../config/dynamodb.config');
        await putItem(item as unknown as Record<string, unknown>);
        return this.toDomain(item);
    }
}
