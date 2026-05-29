// ============================================================================
// Notification_Store — DynamoDB Table & Key Builders
// ============================================================================
// Three logical tables, persisted in DynamoDB in the same AWS account, region,
// and table-naming conventions used by `my-backend/` (REQ 19.2):
//
//   * <prefix>-notifications     — Notification records (REQ 6.1)
//   * <prefix>-user-preferences  — UserPreference records (REQ 6.2)
//   * <prefix>-audit-log         — AuditLog records (REQ 6.3, append-only)
//
// Each table has dedicated GSIs (REQ 6.4-6.6); see `notifications.resources.yml`
// snippet at the top of `notification.repo.ts` for the canonical CFN schema.
//
// The prefix follows my-backend's existing convention: read it from
// the `NOTIFICATIONS_TABLE_PREFIX` env variable, falling back to a safe
// stage-aware default. We do NOT reuse the single `bizmate` table because
// the Notification_Store is a separate logical store with its own access
// patterns (the design doc lists "Three logical tables in the
// Notification_Store" — phase3-architecture.md §12.1).
// ============================================================================

// ---- Table names ---------------------------------------------------------

/**
 * Prefix applied to every notification-store DynamoDB table name. The
 * convention `<service>-<stage>` matches the way `my-backend/` already names
 * its tables (e.g. `bizmate-prod`).
 *
 * Resolution order:
 *   1. NOTIFICATIONS_TABLE_PREFIX  (explicit override — preferred)
 *   2. <SERVICE>-<STAGE>           (composed from existing env vars)
 *   3. `notifications-dev`         (last-resort default for local dev)
 */
function resolveTablePrefix(): string {
    const explicit = process.env.NOTIFICATIONS_TABLE_PREFIX;
    if (explicit && explicit.trim() !== '') return explicit.trim();

    const service = process.env.SERVICE_NAME ?? 'notifications';
    const stage = process.env.STAGE ?? process.env.NODE_ENV ?? 'dev';
    return `${service}-${stage}`;
}

const TABLE_PREFIX = resolveTablePrefix();

export const NOTIFICATION_TABLE = `${TABLE_PREFIX}-notifications`;
export const USER_PREFERENCE_TABLE = `${TABLE_PREFIX}-user-preferences`;
export const AUDIT_LOG_TABLE = `${TABLE_PREFIX}-audit-log`;

/**
 * Table holding the per-user `unread_count` projection (REQ 6.7).
 *
 * Kept SEPARATE from `USER_PREFERENCE_TABLE` on purpose:
 *   * The projection performs atomic-counter updates (`ADD #unread_count :delta`)
 *     from a DynamoDB Streams handler that runs on every `delivered`/`read`
 *     lifecycle transition. The UserPreference table uses optimistic-version
 *     updates from `setUserPreferences`. Mixing both write paths on the same
 *     item would either bump `version` from the projection (corrupting concurrent
 *     preference writes) or force a read-modify-write loop on every increment
 *     (breaking the 100 ms p95 budget).
 *   * The bell widget only needs the count — a single-attribute Get on a
 *     dedicated table is faster than fetching the full UserPreference record.
 *   * If the projection lands first for a brand-new user, it must not create a
 *     phantom UserPreference row that other callers would mistake for valid
 *     preferences.
 *
 * See `unread-count.projection.ts` for the handler that writes here.
 */
export const UNREAD_COUNT_TABLE = `${TABLE_PREFIX}-unread-counts`;

// ---- GSI names -----------------------------------------------------------
// These names are referenced verbatim by tasks 4.1, 6.1 (`dedup.ts` queries
// `by-dedup-key`), and 5.1 (consumer uses the same GSIs). Do not rename
// without updating those callers.

export const GSI_BY_USER_STATUS = 'by-user-status';
export const GSI_BY_USER_CATEGORY = 'by-user-category';
export const GSI_BY_DEDUP_KEY = 'by-dedup-key';

// ---- Notification table key shapes --------------------------------------
//
// Notification table primary key:    HASH = notification_id
// (The three GSIs below are sparse — items missing the GSI key are not
// indexed, which is the standard DynamoDB pattern for fan-out queries.)
//
// Notification GSI `by-user-status`:
//     HASH  = user_status_pk      = `<user_id>#<status>`
//     RANGE = user_status_sk      = `<created_at>#<notification_id>`
// One physical row per recipient — see `notification.repo.ts`'s
// `buildRecipientGsiAttributes` helper.
//
// Notification GSI `by-user-category`:
//     HASH  = user_category_pk    = `<user_id>#<category>`
//     RANGE = user_category_sk    = `<created_at>#<notification_id>`
//
// Notification GSI `by-dedup-key`:
//     HASH  = dedup_key
//     RANGE = created_at_id_sk    = `<created_at>#<notification_id>`
// (We append `notification_id` to the sort key so simultaneous inserts
// with the same dedup_key in the same millisecond do not collide.)

export const NOTIFICATION_PK_FIELD = 'notification_id';

export interface UserStatusGsiKey {
    readonly user_status_pk: string;
    readonly user_status_sk: string;
}

export interface UserCategoryGsiKey {
    readonly user_category_pk: string;
    readonly user_category_sk: string;
}

export interface DedupGsiKey {
    readonly dedup_key: string;
    readonly created_at_id_sk: string;
}

/**
 * Build the `by-user-status` GSI hash + range key pair for a given
 * recipient. The sort-key suffix is `<created_at>#<notification_id>` so
 * the same `created_at` does not collide for two events emitted in the
 * same millisecond.
 */
export function userStatusGsiKey(
    userId: string,
    status: string,
    createdAt: string,
    notificationId: string,
): UserStatusGsiKey {
    return {
        user_status_pk: `${userId}#${status}`,
        user_status_sk: `${createdAt}#${notificationId}`,
    };
}

/**
 * Build the `by-user-category` GSI hash + range key pair for a given
 * recipient.
 */
export function userCategoryGsiKey(
    userId: string,
    category: string,
    createdAt: string,
    notificationId: string,
): UserCategoryGsiKey {
    return {
        user_category_pk: `${userId}#${category}`,
        user_category_sk: `${createdAt}#${notificationId}`,
    };
}

/**
 * Build the `by-dedup-key` GSI hash + range key pair for a Notification.
 * Used by the deduplication step (REQ 6.6, REQ 4.4) to perform a constant-
 * time lookup of prior deliveries for the same dedup_key.
 */
export function dedupGsiKey(
    dedupKey: string,
    createdAt: string,
    notificationId: string,
): DedupGsiKey {
    return {
        dedup_key: dedupKey,
        created_at_id_sk: `${createdAt}#${notificationId}`,
    };
}

// ---- UserPreference table key shape -------------------------------------
//
// UserPreference primary key: HASH = user_id (one record per user).

export const USER_PREFERENCE_PK_FIELD = 'user_id';

// ---- Unread-count projection table key shape ----------------------------
//
// UnreadCount primary key: HASH = user_id (one record per user).
// The single non-key attribute is `unread_count` (Number), maintained by
// the DynamoDB Streams handler in `unread-count.projection.ts`.

export const UNREAD_COUNT_PK_FIELD = 'user_id';
export const UNREAD_COUNT_FIELD = 'unread_count';

// ---- AuditLog table key shape -------------------------------------------
//
// AuditLog primary key:
//   HASH  = notification_id   — fast retrieval of one notification's full trail
//   RANGE = audit_sort_key    = `<timestamp>#<audit_id>`
//
// The composite sort key keeps the trail in chronological order and prevents
// collisions for events written in the same millisecond. A `query` filter on
// `notification_id` returns the notification's complete trail in order.

export const AUDIT_PK_FIELD = 'notification_id';
export const AUDIT_SORT_KEY_FIELD = 'audit_sort_key';

/**
 * Build the AuditLog sort-key for a given timestamp + audit_id pair.
 * The pair is unique by construction (audit_id is a UUID).
 */
export function auditSortKey(timestamp: string, auditId: string): string {
    return `${timestamp}#${auditId}`;
}
