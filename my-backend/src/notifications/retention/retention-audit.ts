// ============================================================================
// Retention Configuration — Audit_Log Writer
// ============================================================================
// Writes one Audit_Log entry per retention-configuration change, using the
// existing notification-system Audit_Log table (REQ 12.5/12.6 — single
// append-only audit trail for the notification subsystem).
//
// Per REQ 13.4 the entry MUST name the actor, the previous value, the new
// value, and the timestamp. Per REQ 13.4a, if this write fails (the
// Audit_Log subsystem is unavailable), callers MUST reject the
// configuration change and leave the previous Archive_Period in effect.
//
// Validates: REQ 13.4, REQ 13.4a, REQ 12.5, REQ 12.6.
// ============================================================================

import { randomUUID } from 'crypto';
import { appendAuditLog } from '../store';
import type { AuditLogRecord } from '../store/types';
import { logger } from '../../utils/logger';
import { AuditLogUnavailableError } from './errors';

/**
 * The synthetic `notification_id` used for retention-config audit entries.
 * The Audit_Log table is keyed by `notification_id`; retention changes are
 * not tied to a single notification, so we use a stable system-scope key
 * that groups every retention-change entry under one queryable trail.
 */
export const RETENTION_AUDIT_NOTIFICATION_ID =
    '__system__:retention_config';

/**
 * The lifecycle_state stored on retention-config audit entries. The Audit
 * table's `lifecycle_state` column is reused to carry the action verb so
 * the existing `query` API surfaces these entries unchanged.
 */
export const RETENTION_LIFECYCLE_STATE = 'failed';
// NOTE: We pick `failed` purely because the audit-log type union does not
// include a free-form action label; `failed` is the most innocuous of the
// six lifecycle states and never collides with a real notification's
// `failed` entry because the notification_id is the synthetic system key.
// The full action context lives in `error_reason`.

export interface RecordRetentionChangeInput {
    readonly actor_id: string;
    readonly previous_archive_period_days: number;
    readonly new_archive_period_days: number;
    /** ISO-8601 timestamp; defaults to "now" if omitted. */
    readonly timestamp?: string;
}

/**
 * Append one Audit_Log entry naming the actor, the previous value, the new
 * value, and the timestamp.
 *
 * Throws `AuditLogUnavailableError` if the underlying append fails for any
 * reason — the caller is responsible for propagating this so the retention
 * change is rejected and the previous Archive_Period remains in effect.
 */
export async function recordRetentionChange(
    input: RecordRetentionChangeInput,
): Promise<AuditLogRecord> {
    const timestamp = input.timestamp ?? new Date().toISOString();
    const record: AuditLogRecord = {
        audit_id: randomUUID(),
        notification_id: RETENTION_AUDIT_NOTIFICATION_ID,
        lifecycle_state: RETENTION_LIFECYCLE_STATE,
        recipient_id: input.actor_id,
        channel: null,
        attempt: 1,
        outcome: 'success',
        error_reason: JSON.stringify({
            action: 'retention_config_changed',
            previous_archive_period_days: input.previous_archive_period_days,
            new_archive_period_days: input.new_archive_period_days,
            actor_id: input.actor_id,
        }),
        timestamp,
    };

    try {
        return await appendAuditLog(record);
    } catch (err) {
        // REQ 13.4a — any failure to write the audit entry must cause the
        // retention change to be rejected. We do NOT swallow this and we do
        // NOT fall through to a best-effort log: the spec is explicit that
        // the previous Archive_Period must remain in effect.
        logger.error('Audit_Log unavailable for retention change', {
            error: (err as Error).message,
            actor_id: input.actor_id,
            previous_archive_period_days: input.previous_archive_period_days,
            new_archive_period_days: input.new_archive_period_days,
        });
        throw new AuditLogUnavailableError(err);
    }
}
