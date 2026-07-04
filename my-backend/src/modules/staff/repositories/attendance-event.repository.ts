// ============================================================================
// Staff Module — AttendanceEvent Repository (Task 5.1) — CREATE-ONLY
// ============================================================================
// Persistence for append-only, immutable AttendanceEvent items on the DynamoDB
// single table.
//
// AD-4 — APPEND-ONLY ATTENDANCE
// -----------------------------
// This repository is deliberately CREATE-ONLY: it exposes NO update and NO
// delete methods. A correction is a brand-new event (Req 3.4). `create` uses a
// conditional PutItem (`attribute_not_exists(SK)`) so an existing event can
// NEVER be overwritten — the timestamp+eventId SK is effectively write-once.
//
// TENANT/BUSINESS ISOLATION INVARIANT
// -----------------------------------
// Every read/write is scoped to the business partition
//     PK = TENANT#{tenantId}#BIZ#{businessId}
// built ONLY via ../keys.ts::buildAttendanceEventKeys (which uses the shared
// businessPK builder that rejects '#' injection). BusinessID is always the
// leading partition scope (Req 1.5, 11.1). Like the other staff repositories
// this does NOT extend the tenant-partition BaseRepository — it composes the
// same low-level DynamoDB helpers directly to keep the finer-grained business
// partition (see staff-feature-config.repository.ts for the same pattern).
//
// SK: ATT#{isoTimestamp}#{eventId}
// ============================================================================

import { getItem, putItem, queryItems } from '../../../config/dynamodb.config';
import { ConflictError } from '../../../utils/errors';
import {
    ATT_SK_PREFIX,
    attendanceEventSK,
    buildAttendanceEventKeys,
    STAFF_ENTITY_TYPE,
} from '../keys';
import { AttendanceEvent, attendanceEventSchema } from '../schemas/attendance.schema';

/** Stored shape: the event plus table keys + scope attributes. Immutable. */
type AttendanceEventItem = AttendanceEvent & {
    PK: string;
    SK: string;
    GSI1PK?: string;
    GSI1SK?: string;
    entityType: string;
    tenantId: string;
    businessId: string;
    createdAt: string;
};

function toEvent(item: AttendanceEventItem): AttendanceEvent {
    return {
        eventId: item.eventId,
        employeeId: item.employeeId,
        businessId: item.businessId,
        type: item.type,
        method: item.method,
        timestamp: item.timestamp,
        ...(item.geo !== undefined ? { geo: item.geo } : {}),
        ...(item.rejected !== undefined ? { rejected: item.rejected } : {}),
        ...(item.rejectionReason !== undefined ? { rejectionReason: item.rejectionReason } : {}),
    };
}

export class AttendanceEventRepository {
    /**
     * Append a new immutable attendance event. Validates against the schema
     * fail-closed, then writes with a conditional PutItem so an event with the
     * same (timestamp, eventId) is NEVER overwritten (append-only, Req 3.4).
     *
     * @throws ConflictError when an event already exists at this SK.
     */
    async create(
        tenantId: string,
        businessId: string,
        event: AttendanceEvent,
    ): Promise<AttendanceEvent> {
        const parsed = attendanceEventSchema.parse(event);
        const keys = buildAttendanceEventKeys(
            tenantId,
            businessId,
            parsed.employeeId,
            parsed.timestamp,
            parsed.eventId,
        );
        const now = new Date().toISOString();

        const item: AttendanceEventItem = {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entityType: STAFF_ENTITY_TYPE.ATTENDANCE,
            tenantId,
            businessId,
            eventId: parsed.eventId,
            employeeId: parsed.employeeId,
            type: parsed.type,
            method: parsed.method,
            timestamp: parsed.timestamp,
            ...(parsed.geo !== undefined ? { geo: parsed.geo } : {}),
            ...(parsed.rejected !== undefined ? { rejected: parsed.rejected } : {}),
            ...(parsed.rejectionReason !== undefined
                ? { rejectionReason: parsed.rejectionReason }
                : {}),
            createdAt: now,
        };

        try {
            // Append-only guarantee: never overwrite an existing event.
            await putItem(item as unknown as Record<string, unknown>, 'attribute_not_exists(SK)');
        } catch (err) {
            if ((err as { name?: string }).name === 'ConditionalCheckFailedException') {
                throw new ConflictError(
                    `Attendance event ${parsed.eventId} already exists and is immutable`,
                );
            }
            throw err;
        }

        return toEvent(item);
    }

    /**
     * Fetch a single event by its (timestamp, eventId) key. Returns null when
     * absent. There is no soft-delete flag — events are never removed.
     */
    async get(
        tenantId: string,
        businessId: string,
        isoTimestamp: string,
        eventId: string,
    ): Promise<AttendanceEvent | null> {
        const keys = buildAttendanceEventKeys(tenantId, businessId, 'x', isoTimestamp, eventId);
        // The employeeId segment only affects GSI1SK, not the base-table key, so
        // a placeholder is safe for a base-table GetItem by (PK, SK).
        const item = await getItem<AttendanceEventItem>(keys.PK, attendanceEventSK(isoTimestamp, eventId));
        return item ? toEvent(item) : null;
    }

    /**
     * List events for a business, optionally constrained to a timestamp prefix
     * (e.g. a date 'YYYY-MM-DD' or month 'YYYY-MM'). Timestamp-first SK ordering
     * makes these range reads cheap and naturally chronological.
     */
    async listByWindow(
        tenantId: string,
        businessId: string,
        opts?: { timestampPrefix?: string; limit?: number; scanIndexForward?: boolean },
    ): Promise<AttendanceEvent[]> {
        const keys = buildAttendanceEventKeys(tenantId, businessId, 'x', '1970-01-01T00:00:00.000Z', 'x');
        const skPrefix = opts?.timestampPrefix
            ? `${ATT_SK_PREFIX}${opts.timestampPrefix}`
            : ATT_SK_PREFIX;
        const result = await queryItems<AttendanceEventItem>(keys.PK, skPrefix, {
            limit: opts?.limit,
            scanIndexForward: opts?.scanIndexForward ?? true,
        });
        return result.items.map(toEvent);
    }

    /**
     * List events for a single employee (across dates) via GSI1, ordered by
     * timestamp. Uses the STAFF_ATT-namespaced GSI1 partition and the
     * {employeeId}# GSI1SK prefix.
     */
    async listByEmployee(
        tenantId: string,
        businessId: string,
        employeeId: string,
        opts?: { limit?: number; scanIndexForward?: boolean },
    ): Promise<AttendanceEvent[]> {
        const keys = buildAttendanceEventKeys(tenantId, businessId, employeeId, '1970-01-01T00:00:00.000Z', 'x');
        const result = await queryItems<AttendanceEventItem>(keys.GSI1PK!, `${employeeId}#`, {
            indexName: 'GSI1',
            limit: opts?.limit,
            scanIndexForward: opts?.scanIndexForward ?? true,
        });
        return result.items.map(toEvent);
    }
}
