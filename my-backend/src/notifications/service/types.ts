// ============================================================================
// Notification_Service — Service-Level Types
// ============================================================================
// Types specific to the service layer that wraps the Notification_Store and
// the Event_Bus. The persisted shapes (NotificationRecord, UserPreferenceRecord,
// AuditLogRecord, etc.) live in `../store/types`; the wire/envelope shapes
// (EventContract, etc.) live in `../event-bus/types`. This module only adds
// types that are unique to the service surface.
//
// Validates: REQ 4.1, 4.3, 4.5, 4.7, 4.8 (operation signatures), REQ 8.4,
//            8.5, 8.5a (replay envelope).
// ============================================================================

import type {
    EventContract,
    Recipient as EventBusRecipient,
} from '../event-bus/types';
import type {
    NotificationCategory,
    NotificationChannel,
    NotificationRecord,
    UserPreferenceRecord,
} from '../store/types';

// ---- createNotification ----------------------------------------------------

/**
 * Input accepted by `Notification_Service.createNotification`. Shape mirrors
 * the canonical `EventContract` (Phase 3 §6 — single event contract on the
 * bus). The `id`, `created_at`, `dedup_key`, and `dedup_scope_fields` are
 * optional here: when callers omit them the service synthesises:
 *   - `id`           — fresh UUID v4
 *   - `created_at`   — current ISO-8601 timestamp (UTC)
 *   - `dedup_key`    — sha256 of `(event_name, actor_id, target_id, scope_fields)`
 *   - `dedup_scope_fields` — empty array (event has no extra dedup scope)
 *
 * This keeps producer ergonomics close to the Phase 1 helpers we are
 * replacing while still passing the canonical EventContract through to the
 * Event_Bus.
 */
export interface CreateNotificationInput {
    readonly id?: string;
    readonly event_name: string;
    readonly category: EventContract['category'];
    readonly sub_category?: string;
    readonly priority: EventContract['priority'];
    readonly actor_id: string;
    readonly target_id?: string | null;
    readonly recipients: readonly EventBusRecipient[];
    readonly payload: Record<string, unknown>;
    readonly channels: readonly NotificationChannel[];
    readonly source_module: string;
    readonly source_app: EventContract['source_app'];
    readonly created_at?: string;
    readonly dedup_key?: string;
    readonly dedup_scope_fields?: readonly string[];
}

/**
 * Authentication / authorization context the caller of `createNotification`
 * supplies. The service uses this to verify the caller is allowed to emit
 * on behalf of `input.actor_id` (REQ 4.10).
 *
 * For backend Lambdas this is built from the JWT auth context; for the
 * Shared_SDK it is built from the device-level user session.
 */
export interface CreateNotificationCaller {
    /** The authenticated user emitting the event. */
    readonly user_id: string;
    /** Role for the authenticated user (used by RBAC checks). */
    readonly role: string;
    /**
     * Optional list of `actor_id` values the caller is allowed to emit on
     * behalf of in addition to themselves (e.g. a system Lambda emitting
     * for the tenant's `system` actor).
     */
    readonly allowed_actor_ids?: readonly string[];
}

/**
 * Result returned by `createNotification` (REQ 4.1).
 */
export interface CreateNotificationResult {
    readonly notification_id: string;
}

// ---- dispatch --------------------------------------------------------------

/**
 * Options accepted by `Notification_Service.dispatch`.
 *
 * `dedupWindowSeconds` overrides the default 60-second Deduplication_Window
 * (Phase 3 §7.2) on a per-call basis. The Event_Registry is the canonical
 * source of per-event overrides; once that wiring lands (task 17.x) this
 * parameter will be sourced from it. For now the default lives here so
 * callers can run the service without the registry plumbed in.
 */
export interface DispatchOptions {
    /** Override for the Deduplication_Window in seconds. Default: 60. */
    readonly dedupWindowSeconds?: number;
    /**
     * Override for the per-recipient delivery callback. Tests inject a fake
     * adapter; production wires the real `Delivery_Layer` façade here.
     */
    readonly deliver?: DispatchChannelAdapter;
    /**
     * Override for the per-recipient authorizer. Tests inject a stub; the
     * production wiring (task 14.1) injects the RBAC-backed implementation.
     */
    readonly recipientAuthorizer?: import('./authz').RecipientAuthorizer;
}

/**
 * Per-recipient outcome captured by `dispatch` so callers (and tests) can
 * inspect what happened on a single call.
 */
export interface DispatchRecipientOutcome {
    readonly user_id: string;
    readonly role: string;
    readonly channels: readonly NotificationChannel[];
    /**
     * - `delivered`             — adapter accepted the dispatch
     * - `skipped_duplicate`     — Deduplication_Window suppressed delivery
     * - `denied_unauthorized`   — recipient failed the authorization check
     * - `failed`                — adapter raised an error
     */
    readonly outcome:
        | 'delivered'
        | 'skipped_duplicate'
        | 'denied_unauthorized'
        | 'failed';
    readonly error_reason?: string;
}

/**
 * Result returned by `dispatch`. The lifecycle status is `dispatched` once
 * any recipient was successfully forwarded to the Delivery_Layer; if every
 * recipient was skipped/denied/failed the status remains `emitted`.
 */
export interface DispatchResult {
    readonly notification_id: string;
    readonly status: 'dispatched' | 'emitted' | 'failed';
    readonly recipients: readonly DispatchRecipientOutcome[];
}

/**
 * Shape of the per-channel adapter callback the service forwards to. The
 * actual `Delivery_Layer` implementation lands in task 9; this interface
 * keeps the service decoupled from channel-specific code.
 *
 * Implementations MUST throw on unrecoverable errors; transient failures
 * inside the adapter are the adapter's responsibility (Delivery_Layer
 * applies its own retry budget per REQ 5.9-5.13).
 */
export type DispatchChannelAdapter = (
    args: DispatchChannelArgs,
) => Promise<void>;

export interface DispatchChannelArgs {
    readonly notification: NotificationRecord;
    readonly recipient: {
        readonly user_id: string;
        readonly role: string;
    };
    readonly channel: NotificationChannel;
}

// ---- markAsRead ------------------------------------------------------------

export interface MarkAsReadResult {
    readonly notification_id: string;
    readonly user_id: string;
    /** Time the notification was first read (ISO-8601 UTC). Stable across calls. */
    readonly read_at: string;
    /** True when this call was the first one to mark the notification as read. */
    readonly first_read: boolean;
}

// ---- preferences ----------------------------------------------------------

/**
 * Input accepted by `setUserPreferences`. Shape matches the persisted
 * `UserPreferenceRecord` minus the server-managed fields (`updated_at`,
 * `version`). `role` is required so a brand-new record can be created on
 * the first call; subsequent calls may omit it (the service preserves the
 * existing value).
 */
export interface SetUserPreferencesInput {
    readonly role?: string;
    readonly per_category_channels?: Partial<
        Record<NotificationCategory, readonly NotificationChannel[]>
    >;
    readonly per_event_channels?: Record<string, readonly NotificationChannel[]>;
    readonly quiet_hours_start?: string | null;
    readonly quiet_hours_end?: string | null;
    readonly quiet_hours_timezone?: string | null;
    readonly mute_targets?: readonly string[];
}

// ---- replay ---------------------------------------------------------------

/**
 * Replay window default — 7 days (REQ 8.5).
 */
export const REPLAY_WINDOW_DAYS = 7;

/**
 * Result returned by `getReplay`. Items are in `created_at` ascending order
 * (REQ 8.4). `next_cursor` is reserved for future cursor-paginated replay;
 * the current implementation returns every matching record and sets the
 * field to `null`.
 */
export interface ReplayResult {
    readonly notifications: readonly NotificationRecord[];
    readonly next_cursor: string | null;
}

// ---- re-exports for callers ----------------------------------------------

export type { NotificationRecord, UserPreferenceRecord };
