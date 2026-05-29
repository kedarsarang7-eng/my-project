// ============================================================================
// Notification_Store — Type Definitions
// ============================================================================
// Field unions are taken verbatim from REQ 6.1 (Notification),
// REQ 6.2 (UserPreference), and REQ 6.3 (AuditLog) of the
// unified-notification-system spec at:
//   .kiro/specs/unified-notification-system/requirements.md
//
// The lifecycle ordering invariant
//   created_at <= dispatched_at <= delivered_at <= read_at
// is enforced by the repositories on every state transition (REQ 6.7a).
// ============================================================================

// ---- Enumerations (REQ 2.3, 2.4, glossary) ----

/**
 * The eight permitted notification categories (REQ 2.3).
 */
export type NotificationCategory =
    | 'billing'
    | 'orders'
    | 'payments'
    | 'inventory'
    | 'users'
    | 'system'
    | 'delivery'
    | 'reports';

/**
 * The four permitted priority tiers (REQ 2.4, glossary `Priority_Tier`).
 */
export type NotificationPriority = 'critical' | 'high' | 'normal' | 'low';

/**
 * The five supported delivery channels (REQ 2.5, glossary `Channel`).
 */
export type NotificationChannel =
    | 'in_app'
    | 'push'
    | 'sms'
    | 'email'
    | 'webhook';

/**
 * Lifecycle status of a Notification record (REQ 4 lifecycle, REQ 14.1).
 *
 * Allowed transitions (enforced by `lifecycle.ts` in task 6.1, but the
 * ordering invariant in this module already rejects out-of-order
 * timestamp writes):
 *   emitted -> queued -> dispatched -> delivered -> read
 *   any state -> failed
 */
export type NotificationStatus =
    | 'emitted'
    | 'queued'
    | 'dispatched'
    | 'delivered'
    | 'read'
    | 'failed';

/**
 * Lifecycle state recorded on AuditLog entries (REQ 6.3, REQ 12.7).
 *
 * Superset of `NotificationStatus`:
 *   - The six standard states `emitted | queued | dispatched | delivered | read | failed`
 *     mirror the notification lifecycle (REQ 14.1).
 *   - `unauthorized_access_attempt` (REQ 12.7) is a security-only audit
 *     entry written when a request to read/modify a notification — or to
 *     emit one on behalf of an actor the caller does not own — is denied.
 *     It is NEVER a value of `NotificationRecord.status`; it only appears
 *     on AuditLog records.
 *
 * Per-recipient lifecycle blocks inside `NotificationRecord.recipients[]`
 * use the smaller `NotificationStatus` enum because a recipient row never
 * carries a security-only state.
 */
export type LifecycleState =
    | NotificationStatus
    | 'unauthorized_access_attempt';

// ---- Per-recipient block (nested in Notification.recipients, REQ 6.1) ----

/**
 * One entry in the `recipients` array of a Notification record.
 * Shape and field names taken from REQ 6.1.
 */
export interface NotificationRecipient {
    readonly user_id: string;
    readonly role: string;
    readonly channels: readonly NotificationChannel[];
    readonly status: NotificationStatus;
    readonly delivered_at: string | null;
    readonly read_at: string | null;
}

// ---- Notification record (REQ 6.1) ----

/**
 * Persistent shape of a Notification record.
 * Field set is the verbatim union from REQ 6.1.
 *
 * Trailing lifecycle timestamps (`dispatched_at`, `delivered_at`, `read_at`)
 * are nullable; the repository enforces
 *   created_at <= dispatched_at <= delivered_at <= read_at
 * with `null` permitted for any unset trailing timestamp (REQ 6.7a).
 */
export interface NotificationRecord {
    readonly notification_id: string;
    readonly event_name: string;
    readonly category: NotificationCategory;
    readonly sub_category: string;
    readonly priority: NotificationPriority;
    readonly actor_id: string;
    readonly target_id: string;
    readonly recipients: readonly NotificationRecipient[];
    readonly payload: Record<string, unknown>;
    readonly channels: readonly NotificationChannel[];
    readonly status: NotificationStatus;
    readonly created_at: string;
    readonly dispatched_at: string | null;
    readonly delivered_at: string | null;
    readonly read_at: string | null;
    readonly dedup_key: string;
    readonly source_module: string;
    readonly source_app: string;
}

/**
 * Lifecycle timestamps grouped together — used by the ordering-invariant
 * checker so callers can hand the four fields as a single tuple.
 */
export interface LifecycleTimestamps {
    readonly created_at: string;
    readonly dispatched_at: string | null;
    readonly delivered_at: string | null;
    readonly read_at: string | null;
}

// ---- UserPreference record (REQ 6.2) ----

/**
 * A user's `quiet_hours_*` configuration. Times are local-time `HH:MM`
 * (24-hour) strings; the timezone is an IANA name (e.g. `Asia/Kolkata`).
 * The Preference_Engine (task 7.1) interprets them.
 */
export interface QuietHours {
    readonly quiet_hours_start: string | null;
    readonly quiet_hours_end: string | null;
    readonly quiet_hours_timezone: string | null;
}

/**
 * Persistent shape of a UserPreference record.
 * Field set is the verbatim union from REQ 6.2.
 *
 * `version` is a monotonically increasing optimistic-lock counter; the
 * repository update rejects writes whose `expectedVersion` does not match.
 */
export interface UserPreferenceRecord {
    readonly user_id: string;
    readonly role: string;
    readonly per_category_channels: Readonly<
        Partial<Record<NotificationCategory, readonly NotificationChannel[]>>
    >;
    readonly per_event_channels: Readonly<
        Record<string, readonly NotificationChannel[]>
    >;
    readonly quiet_hours_start: string | null;
    readonly quiet_hours_end: string | null;
    readonly quiet_hours_timezone: string | null;
    readonly mute_targets: readonly string[];
    readonly updated_at: string;
    readonly version: number;
}

// ---- AuditLog record (REQ 6.3) ----

/**
 * Outcome of a single lifecycle attempt.
 * `skipped_duplicate` is referenced by REQ 4.4; `denied` by REQ 12.7.
 */
export type AuditOutcome =
    | 'success'
    | 'failure'
    | 'skipped_duplicate'
    | 'denied';

/**
 * Persistent shape of an AuditLog record.
 * Field set is the verbatim union from REQ 6.3.
 *
 * INVARIANT: AuditLog records are append-only. The `audit-log.repo.ts`
 * module exposes only `append` and `query`; it does NOT expose `update`
 * or `delete` and rejects any attempt to mutate an existing record
 * (REQ 12.6, REQ 6.3 phrasing "append-only").
 */
export interface AuditLogRecord {
    readonly audit_id: string;
    readonly notification_id: string;
    readonly lifecycle_state: LifecycleState;
    readonly recipient_id: string | null;
    readonly channel: NotificationChannel | null;
    readonly attempt: number;
    readonly outcome: AuditOutcome;
    readonly error_reason: string | null;
    readonly timestamp: string;
}

// ---- Cursor-pagination result envelope (REQ 6.9) ----

/**
 * One page of notifications returned by a paginated query.
 * `next_cursor` is the opaque base64url-encoded cursor described in
 * `cursor.ts`; `null` means there is no further page.
 */
export interface PaginatedNotifications {
    readonly items: readonly NotificationRecord[];
    readonly next_cursor: string | null;
}
