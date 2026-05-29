// ============================================================================
// Notification_Store — Retention Configuration Types
// ============================================================================
// Validates: REQ 13.4, REQ 13.4a, REQ 6.8.
//
// The Archive_Period (REQ glossary) is the retention period — in days — for
// `Notification` and `AuditLog` records before they are moved to cold storage
// (REQ 6.8). It is configurable (REQ 13.4) and changes MUST be made through
// an authenticated endpoint that writes an Audit_Log entry naming the actor,
// the previous value, the new value, and the timestamp.
// ============================================================================

/**
 * Persisted shape of the retention configuration record.
 *
 * The system stores exactly one record (singleton). Per-tenant scoping is
 * intentionally avoided: the Archive_Period is a system-wide retention
 * policy (the spec talks about "the configured Archive_Period", singular).
 * If per-tenant retention becomes a requirement later, a `tenant_id` field
 * can be added without breaking the existing surface.
 */
export interface RetentionConfigRecord {
    /**
     * Number of days to retain `Notification` and `AuditLog` records before
     * moving them to cold storage. Always a positive integer.
     */
    readonly archive_period_days: number;
    /**
     * ISO-8601 timestamp of the last successful update. Defaults to the
     * record's first persistence time.
     */
    readonly updated_at: string;
    /**
     * `user_id` of the actor who last changed the value, or `null` if the
     * record is still on system defaults (i.e. has never been updated by a
     * human caller).
     */
    readonly updated_by: string | null;
    /**
     * Monotonically increasing optimistic-lock counter. Starts at `0` for
     * the synthetic default record returned when no row has been persisted
     * yet, and increments by 1 on every successful update.
     */
    readonly version: number;
}

/**
 * Input shape for `setRetentionConfig`. The actor's identity is taken from
 * the verified JWT, never from the request body.
 */
export interface UpdateRetentionConfigInput {
    readonly archive_period_days: number;
    readonly actor_id: string;
}

/**
 * Bounds enforced on `archive_period_days` at the validation layer. The
 * upper bound is generous (10 years) to support compliance regimes that
 * mandate long-term retention; the lower bound is 1 day to prevent
 * accidental deletion of records the same day they are written.
 */
export const MIN_ARCHIVE_PERIOD_DAYS = 1;
export const MAX_ARCHIVE_PERIOD_DAYS = 3650; // 10 years
