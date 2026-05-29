// ============================================================================
// Notification_Service — `unauthorized_access_attempt` Audit Writer (Task 16.3)
// ============================================================================
// Validates: REQ 12.5, REQ 12.6, REQ 12.7 — every denied access attempt MUST
// write an `unauthorized_access_attempt` Audit_Log entry, and the entry MUST
// be written ONLY when the request is denied (never on permitted paths).
//
// Single source of truth for security-denial audit writes used by:
//
//   - `createNotification`             — caller fails authz on emit
//   - `dispatch`                       — recipient fails per-recipient authz
//   - `markAsRead`                     — caller is not a recipient
//   - `getUserPreferences` / `setUserPreferences` — caller is not the owner
//   - `getReplay`                      — caller targets another user OR
//                                        out-of-window (replay-attack guard)
//   - retention handlers (16.5)        — non-admin reads/writes
//
// Design notes
// ------------
// 1. Best-effort write. The Audit_Log is durability-critical for the
//    notification lifecycle, but for the security-denial trail we treat the
//    write as best-effort: a transient AuditLog outage MUST NOT change the
//    user-visible behaviour of the denial path. Failures are logged at warn
//    so CloudWatch alarms can detect sustained outages (separately tracked
//    by task 17.x observability).
//
// 2. Append-only. We always call `appendAuditLog` (the only public surface
//    on the audit-log repo). REQ 6.3 / 12.6 keeps the trail append-only —
//    we never update or delete an existing entry.
//
// 3. Stable error_reason taxonomy. A short snake_case code describes the
//    deny class so security tooling can group entries. The set is closed:
//
//      caller_not_authorized        — `createNotification` caller authz fail
//      recipient_not_authorized     — `dispatch` per-recipient authz fail
//      not_recipient                — read/modify by a non-recipient
//      not_owner                    — preferences read/write by another user
//      replay_window_exceeded       — `getReplay` request outside window
//      retention_admin_required     — non-admin retention-config request
//
//    Each call site supplies one of these — no free-form strings, so the
//    audit trail is queryable.
// ============================================================================

import { randomUUID } from 'crypto';
import { logger } from '../../utils/logger';
import {
    appendAuditLog,
    type AuditLogRepoOptions,
} from '../store';
import type {
    AuditLogRecord,
    NotificationChannel,
} from '../store/types';

/**
 * Closed set of deny-reason codes used by the `unauthorized_access_attempt`
 * audit trail. Adding a new code here MUST be paired with an entry in this
 * file's header so security reviewers have a single source of truth.
 */
export type UnauthorizedAccessReason =
    | 'caller_not_authorized'
    | 'recipient_not_authorized'
    | 'not_recipient'
    | 'not_owner'
    | 'replay_window_exceeded'
    | 'retention_admin_required';

/**
 * Input accepted by `recordUnauthorizedAccessAttempt`.
 *
 * - `actorId` is REQUIRED and identifies WHO attempted the denied action
 *   (the caller's user_id, falling back to `'anonymous'` when the request
 *   was unauthenticated and we still want a trail entry).
 * - `notificationId` is the target notification when one exists. The
 *   audit-log table uses `notification_id` as the partition key, so for
 *   denials that are NOT bound to a specific notification (preferences,
 *   replay, retention) we use a stable synthetic id derived from the
 *   `reason` so the entries remain queryable.
 * - `channel` is recorded only on denials that occur during a per-channel
 *   delivery attempt (currently only `dispatch`). Other call sites pass
 *   `null` (the default).
 * - `timestamp` defaults to `new Date().toISOString()` so production
 *   callers can omit it; tests pass a stable value for assertions.
 */
export interface RecordUnauthorizedAccessAttemptInput {
    readonly actorId: string;
    readonly reason: UnauthorizedAccessReason;
    readonly notificationId?: string | null;
    readonly channel?: NotificationChannel | null;
    readonly timestamp?: string;
    /** Optional structured context attached to the audit row. */
    readonly context?: Record<string, unknown>;
}

/**
 * Synthetic notification_id used for denials that are not bound to a
 * single notification. Suffixed with the deny reason so the AuditLog
 * `query` API can filter the trail by deny class without scanning every
 * row.
 */
const SYSTEM_AUDIT_ID_PREFIX = '__system__:unauthorized:';

function notificationIdFor(
    reason: UnauthorizedAccessReason,
    explicit: string | null | undefined,
): string {
    if (explicit && explicit.trim() !== '') return explicit;
    return `${SYSTEM_AUDIT_ID_PREFIX}${reason}`;
}

function buildErrorReason(
    reason: UnauthorizedAccessReason,
    context: Record<string, unknown> | undefined,
): string {
    if (!context || Object.keys(context).length === 0) return reason;
    // JSON-encode so the trail keeps the deny class as the leading prefix
    // (cheap to grep on) and the structured context behind it.
    return `${reason}:${JSON.stringify(context)}`;
}

/**
 * Append one `unauthorized_access_attempt` Audit_Log entry.
 *
 * Best-effort: any failure of the underlying `appendAuditLog` is caught
 * and logged at `warn`. The function NEVER throws so callers can drop it
 * inline in a denial path without altering the user-visible behaviour.
 *
 * Returns `true` when the audit row was successfully appended, `false`
 * otherwise. Tests that need to assert audit-trail contents use the
 * dependency-injection seam (`options.docClient` on `AuditLogRepoOptions`)
 * rather than the boolean return.
 */
export async function recordUnauthorizedAccessAttempt(
    input: RecordUnauthorizedAccessAttemptInput,
    options: AuditLogRepoOptions = {},
): Promise<boolean> {
    const record: AuditLogRecord = {
        audit_id: randomUUID(),
        notification_id: notificationIdFor(input.reason, input.notificationId),
        lifecycle_state: 'unauthorized_access_attempt',
        recipient_id: input.actorId || 'anonymous',
        channel: input.channel ?? null,
        attempt: 1,
        outcome: 'denied',
        error_reason: buildErrorReason(input.reason, input.context),
        timestamp: input.timestamp ?? new Date().toISOString(),
    };

    try {
        await appendAuditLog(record, options);
        return true;
    } catch (err) {
        logger.warn(
            '[unauthorized-audit] AuditLog append failed — continuing without trail entry',
            {
                actor_id: input.actorId,
                reason: input.reason,
                notification_id: record.notification_id,
                error: err instanceof Error ? err.message : String(err),
            },
        );
        return false;
    }
}
