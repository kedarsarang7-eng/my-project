// ============================================================================
// chaos/shim/fixtures.ts — minimal Event_Contract / NotificationRecord builders
// ============================================================================
//
// Shared, deterministic fixture helpers for the chaos tests. Each chaos
// test composes these factories with the production modules from
// `my-backend/src/notifications/`. None of these helpers reach into the
// production code other than to import its types.
//
// The factories are deterministic by construction — every input becomes
// an output without random fallbacks — so the tests stay reproducible
// across machines and CI runs.
// ============================================================================

import type {
    Channel,
    EventContract,
    Priority,
    Recipient,
} from '../../../../src/notifications/event-bus/types';
import type {
    NotificationCategory,
    NotificationChannel,
    NotificationRecipient,
    NotificationRecord,
} from '../../../../src/notifications/store/types';

// ---------------------------------------------------------------------------
// Stable / deterministic identifiers
// ---------------------------------------------------------------------------

/**
 * Build a deterministic UUID-v4-looking string from a numeric seed.
 * Avoids the `crypto.randomUUID()` randomness so test ordering is stable.
 *
 * Output shape: `00000000-0000-4000-8000-000000000NNN` where NNN encodes
 * the seed in zero-padded hex. Conforms to the Event_Contract schema's
 * `format: uuid` constraint (RFC 4122 v4).
 */
export function deterministicId(seed: number): string {
    const hex = seed.toString(16).padStart(12, '0');
    // Static prefix keeps the version (4) and variant (8) bits valid;
    // suffix encodes the seed for human-readable test output.
    return `00000000-0000-4000-8000-${hex}`;
}

/** ISO-8601 timestamp seeded by an integer epoch base + offset ms. */
export function deterministicTimestamp(base: number, offsetMs: number): string {
    return new Date(base + offsetMs).toISOString();
}

// ---------------------------------------------------------------------------
// Event_Contract factory
// ---------------------------------------------------------------------------

export interface BuildEventOptions {
    readonly seed: number;
    readonly baseEpochMs: number;
    /** Offset (ms) added to baseEpochMs to derive `created_at`. */
    readonly offsetMs?: number;
    readonly event_name?: string;
    readonly priority?: Priority;
    readonly category?: EventContract['category'];
    readonly actor_id?: string;
    readonly target_id?: string | null;
    readonly recipients?: readonly Recipient[];
    readonly channels?: readonly Channel[];
    readonly source_module?: string;
    readonly source_app?: EventContract['source_app'];
    readonly payload?: Record<string, unknown>;
    readonly dedup_key?: string;
}

/**
 * Build a valid `EventContract` envelope from a small option bag. Every
 * unspecified field has a stable default so the test code stays focused
 * on the chaos scenario rather than schema plumbing.
 */
export function buildEvent(opts: BuildEventOptions): EventContract {
    const id = deterministicId(opts.seed);
    const created_at = deterministicTimestamp(
        opts.baseEpochMs,
        opts.offsetMs ?? 0,
    );
    const event_name = opts.event_name ?? 'inventory.stock.changed';
    const priority: Priority = opts.priority ?? 'normal';
    const category = opts.category ?? 'inventory';
    const actor_id = opts.actor_id ?? 'actor-test';
    const target_id = opts.target_id === undefined ? null : opts.target_id;
    const channels: Channel[] = [...(opts.channels ?? ['in_app'])];
    const recipients: Recipient[] = (
        opts.recipients ?? [
            { user_id: 'recipient-1', role: 'admin', channels },
        ]
    ).map((r) => ({ ...r }));
    const source_module = opts.source_module ?? 'tests/notifications/chaos';
    const source_app = opts.source_app ?? 'dukanx_backend';
    const payload = opts.payload ?? { seq: opts.seed };
    // Deterministic dedup_key — production callers compute it from the
    // event identity tuple; for chaos tests we just need a stable string
    // that survives a serialization round-trip.
    const dedup_key =
        opts.dedup_key ??
        `${event_name}:${actor_id}:${target_id ?? 'null'}:${opts.seed}`;

    return {
        id,
        event_name,
        category,
        priority,
        actor_id,
        target_id,
        recipients,
        payload,
        channels,
        source_module,
        source_app,
        created_at,
        dedup_key,
        dedup_scope_fields: [],
    };
}

// ---------------------------------------------------------------------------
// NotificationRecord factory (for tests that bypass the service to drive
// the Delivery_Layer / consumer directly).
// ---------------------------------------------------------------------------

export interface BuildNotificationOptions {
    readonly seed: number;
    readonly baseEpochMs: number;
    readonly offsetMs?: number;
    readonly event_name?: string;
    readonly priority?: NotificationRecord['priority'];
    readonly category?: NotificationCategory;
    readonly recipients?: readonly NotificationRecipient[];
    readonly channels?: readonly NotificationChannel[];
    readonly payload?: Record<string, unknown>;
    readonly source_module?: string;
    readonly source_app?: NotificationRecord['source_app'];
}

/**
 * Build a minimal persisted `NotificationRecord` with status `emitted`.
 * Used by the slow-channel and DLQ-recovery tests, which exercise the
 * Delivery_Layer / consumer without actually persisting through the
 * Notification_Store.
 */
export function buildNotificationRecord(
    opts: BuildNotificationOptions,
): NotificationRecord {
    const channels: NotificationChannel[] = [...(opts.channels ?? ['in_app'])];
    const recipients: NotificationRecipient[] = (
        opts.recipients ?? [
            {
                user_id: 'recipient-1',
                role: 'admin',
                channels,
                status: 'emitted',
                delivered_at: null,
                read_at: null,
            },
        ]
    ).map((r) => ({ ...r }));

    return {
        notification_id: deterministicId(opts.seed),
        event_name: opts.event_name ?? 'inventory.stock.changed',
        category: opts.category ?? 'inventory',
        sub_category: '',
        priority: opts.priority ?? 'normal',
        actor_id: 'actor-test',
        target_id: '',
        recipients,
        payload: opts.payload ?? { seq: opts.seed },
        channels,
        status: 'emitted',
        created_at: deterministicTimestamp(
            opts.baseEpochMs,
            opts.offsetMs ?? 0,
        ),
        dispatched_at: null,
        delivered_at: null,
        read_at: null,
        dedup_key: `dedup-${opts.seed}`,
        source_module: opts.source_module ?? 'tests/notifications/chaos',
        source_app: opts.source_app ?? 'dukanx_backend',
    };
}
