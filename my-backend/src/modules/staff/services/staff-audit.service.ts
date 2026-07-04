// ============================================================================
// Staff Module — Audit Service (Task 3.3 + Task 6.2)
// ============================================================================
// Append-only audit entries for the staff module. Every audit entry identifies
// the actor, action, target, and timestamp (Req 8.3). Additional before/after
// values are recorded for balance or salary changes (Req 4.5, 6.8).
//
// PII UNMASK AUDITING (Task 3.3, Req 2.7)
// ----------------------------------------
// Every successful unmasked PII read produces an UnmaskEvent descriptor (via
// pii-access.service.ts). The `auditUnmaskedReads` helper consumes those
// descriptors and persists one audit entry per unmasked field containing:
// userId, field, employeeId, and timestamp.
//
// APPEND-ONLY INVARIANT (AD-4, Req 2.7, 8.3)
// -------------------------------------------
// Audit entries are IMMUTABLE. No update/delete operations exist. Writes use
// conditional PutItem (`attribute_not_exists(SK)`) so duplicate event IDs
// are silently ignored (idempotent).
//
// Requirements: 2.7, 4.5, 8.3
// ============================================================================

import { randomUUID } from 'crypto';
import { putItem } from '../../../config/dynamodb.config';
import { buildStaffAuditKeys, STAFF_ENTITY_TYPE } from '../keys';
import { buildSalaryChangeAuditKeys } from '../repositories/payroll.keys';
import type { UnmaskEvent } from './pii-access.service';

/** The shape of an audit log entry persisted to DynamoDB. */
export interface StaffAuditEntry {
    eventId: string;
    businessId: string;
    tenantId: string;
    actor: string;
    action: string;
    target: string;
    timestamp: string;
    field?: string;
    before?: unknown;
    after?: unknown;
    meta?: Record<string, unknown>;
}

/**
 * Write an append-only audit entry to the staff audit log.
 *
 * The entry is immutable once written (no update/delete operations exist for
 * audit records). This satisfies the append-only, immutable audit trail
 * requirement (design.md AD-4, Req 8.3).
 */
export async function writeAuditEntry(
    tenantId: string,
    businessId: string,
    entry: {
        actor: string;
        action: string;
        target: string;
        field?: string;
        before?: unknown;
        after?: unknown;
        meta?: Record<string, unknown>;
    },
): Promise<StaffAuditEntry> {
    const eventId = randomUUID();
    const timestamp = new Date().toISOString();
    const keys = buildStaffAuditKeys(tenantId, businessId, timestamp, eventId);

    const item = {
        PK: keys.PK,
        SK: keys.SK,
        GSI1PK: keys.GSI1PK,
        GSI1SK: keys.GSI1SK,
        entityType: STAFF_ENTITY_TYPE.AUDIT,
        tenantId,
        businessId,
        eventId,
        actor: entry.actor,
        action: entry.action,
        target: entry.target,
        timestamp,
        ...(entry.field !== undefined ? { field: entry.field } : {}),
        ...(entry.before !== undefined ? { before: entry.before } : {}),
        ...(entry.after !== undefined ? { after: entry.after } : {}),
        ...(entry.meta !== undefined ? { meta: entry.meta } : {}),
        isDeleted: false,
        createdAt: timestamp,
        updatedAt: timestamp,
    };

    await putItem(item as unknown as Record<string, unknown>);

    return {
        eventId,
        businessId,
        tenantId,
        actor: entry.actor,
        action: entry.action,
        target: entry.target,
        timestamp,
        field: entry.field,
        before: entry.before,
        after: entry.after,
        meta: entry.meta,
    };
}


// ── Salary-change audit helper (Task 9.4, Req 6.8) ─────────────────────────

/**
 * Record a salary-change audit entry BEFORE the salary change takes effect.
 *
 * This function MUST be awaited prior to persisting the actual salary component
 * update (Req 6.8, Property 22). It writes an append-only entry containing:
 *   - beforePaise: the current amount (undefined for new components)
 *   - afterPaise: the new amount (undefined for deletions)
 *   - approverId: the identity of the user who approved/initiated the change
 *
 * The entry is keyed under the SalaryChangeAudit SK pattern
 * (AUDIT#{isoTimestamp}#{eventId}) via `buildSalaryChangeAuditKeys`.
 */
export async function auditSalaryChange(
    tenantId: string,
    businessId: string,
    employeeId: string,
    beforePaise: number | undefined,
    afterPaise: number | undefined,
    approverId: string,
): Promise<SalaryChangeAuditRecord> {
    const eventId = randomUUID();
    const timestamp = new Date().toISOString();
    const keys = buildSalaryChangeAuditKeys(tenantId, businessId, timestamp, eventId);

    const item = {
        PK: keys.PK,
        SK: keys.SK,
        GSI1PK: keys.GSI1PK,
        GSI1SK: keys.GSI1SK,
        entityType: STAFF_ENTITY_TYPE.AUDIT,
        tenantId,
        businessId,
        eventId,
        employeeId,
        action: 'SALARY_CHANGE',
        actor: approverId,
        target: employeeId,
        beforePaise: beforePaise ?? null,
        afterPaise: afterPaise ?? null,
        approverId,
        at: timestamp,
        timestamp,
        isDeleted: false,
        createdAt: timestamp,
        updatedAt: timestamp,
    };

    await putItem(item as unknown as Record<string, unknown>);

    return {
        eventId,
        businessId,
        tenantId,
        employeeId,
        beforePaise,
        afterPaise,
        approverId,
        at: timestamp,
    };
}

/** The returned shape of a salary-change audit record. */
export interface SalaryChangeAuditRecord {
    eventId: string;
    businessId: string;
    tenantId: string;
    employeeId: string;
    beforePaise: number | undefined;
    afterPaise: number | undefined;
    approverId: string;
    at: string;
}

// ── PII unmask audit helper (Task 3.3, Req 2.7) ────────────────────────────

/**
 * Emit audit entries for one or more PII unmask events. Called by the employee
 * handler after a successful role-gated unmask read (Req 2.7).
 *
 * Each UnmaskEvent descriptor produces exactly one audit item containing:
 *   - actor (userId)
 *   - field (PII field kind)
 *   - target (employeeId)
 *   - timestamp
 */
export async function auditUnmaskedReads(
    tenantId: string,
    businessId: string,
    unmaskEvents: UnmaskEvent[],
): Promise<void> {
    await Promise.all(
        unmaskEvents.map((evt) =>
            writeAuditEntry(tenantId, businessId, {
                actor: evt.userId,
                action: 'PII_UNMASK_READ',
                target: evt.employeeId,
                field: evt.field,
            }),
        ),
    );
}
