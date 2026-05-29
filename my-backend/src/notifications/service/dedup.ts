// ============================================================================
// Notification_Service — Deduplication
// ============================================================================
// REQ 4.4, REQ 9.2, design.md §"Reliability Tiers and Deduplication",
// phase3-architecture.md §7 ("Deduplication Semantics").
//
// Deduplication_Key = sha256( event_name | actor_id | target_id | scope_fields )
// Deduplication_Window default = 60 seconds, overridable per event
// (the override surface lives in the service-layer `DispatchOptions` until
// the registry-driven config wiring lands in task 17.x).
//
// Lookups go through `findByDedupKey` on the `by-dedup-key` GSI (REQ 6.6).
// ============================================================================

import { createHash } from 'crypto';
import { findByDedupKey, type NotificationRepoOptions } from '../store';
import type { NotificationRecord } from '../store/types';

/**
 * Default Deduplication_Window in seconds (REQ glossary, design.md
 * §"Reliability Tiers and Deduplication"). Overridable per event.
 */
export const DEFAULT_DEDUP_WINDOW_SECONDS = 60;

/**
 * Inputs that participate in the Deduplication_Key. `dedup_scope_fields`
 * is the ordered list of payload field NAMES whose VALUES extend the key
 * for events that need finer dedup grain (e.g. dedup per line-item).
 *
 * The pair is documented in REQ glossary `Deduplication_Key`.
 */
export interface DedupKeyInput {
    readonly event_name: string;
    readonly actor_id: string;
    readonly target_id?: string | null;
    /** Ordered field names whose values extend the dedup key. */
    readonly dedup_scope_fields?: readonly string[];
    /** Event payload — only `dedup_scope_fields` keys are read. */
    readonly payload?: Record<string, unknown>;
}

/**
 * Compute the canonical `dedup_key` for a notification.
 *
 * The hash input is a deterministic, separator-tagged concatenation so two
 * different field combinations cannot accidentally hash to the same digest:
 *
 *   <event_name>\x1f<actor_id>\x1f<target_id>\x1f<field>=<value>\x1f<field>=<value>...
 *
 * `\x1f` is the ASCII Unit Separator — chosen because it is NEVER produced
 * by JSON serialization of normal user payloads, so it cannot be smuggled
 * inside a value to confuse the parser on the read side.
 *
 * Returns a 64-character lowercase hex sha256 digest.
 */
export function computeDedupKey(input: DedupKeyInput): string {
    const SEP = '\x1f';
    // Order matters: event_name must lead (cheapest discriminator), then
    // actor_id, then target_id, then ordered scope-field values. Reordering
    // would make the same logical event hash differently across versions,
    // breaking the by-dedup-key GSI lookup window for in-flight events
    // during a deploy.
    const parts: string[] = [
        input.event_name,
        input.actor_id,
        input.target_id ?? '',
    ];

    if (input.dedup_scope_fields && input.dedup_scope_fields.length > 0) {
        const payload = input.payload ?? {};
        // Stable: iterate fields IN THE ORDER the registry declared them.
        for (const field of input.dedup_scope_fields) {
            const raw = payload[field];
            const serialized = serializeScopeValue(raw);
            parts.push(`${field}=${serialized}`);
        }
    }

    return createHash('sha256').update(parts.join(SEP)).digest('hex');
}

/**
 * Serialize a payload value into a deterministic string. We `JSON.stringify`
 * objects so two equal-by-value records hash identically; primitives are
 * coerced through `String(...)` for the same reason.
 */
function serializeScopeValue(value: unknown): string {
    if (value === undefined || value === null) return '';
    if (typeof value === 'string') return value;
    if (
        typeof value === 'number' ||
        typeof value === 'boolean' ||
        typeof value === 'bigint'
    ) {
        return String(value);
    }
    // Objects / arrays — JSON.stringify is deterministic for primitive trees.
    try {
        return JSON.stringify(value);
    } catch {
        return '';
    }
}

// ---- Recipient-aware dedup lookup ----------------------------------------

/**
 * Inputs for the per-recipient dedup-window lookup performed by
 * `Notification_Service.dispatch`.
 *
 * `recipientId` is the user_id of the prospective recipient: the spec
 * (REQ 4.4) suppresses dispatch only to RECIPIENTS that have already
 * received a delivery for the same dedup_key within the window — not to
 * unrelated recipients of the same event.
 */
export interface IsDuplicateForRecipientInput {
    readonly dedup_key: string;
    readonly recipientId: string;
    readonly windowSeconds?: number;
    /** Stable "now" so callers (and tests) can pin time. */
    readonly now?: Date;
    /** Excluded notification id — never count the row we just created. */
    readonly excludeNotificationId?: string;
}

/**
 * Returns the matching prior `NotificationRecord` if a delivery already
 * occurred for the same `dedup_key` and `recipientId` within the window;
 * returns `null` otherwise.
 *
 * "Already delivered" here means the prior record contains the recipient
 * with `status` advanced past `emitted` — i.e. one of `dispatched`,
 * `delivered`, or `read`. A record stuck at `emitted` does NOT count as a
 * prior delivery (we have not actually forwarded it anywhere yet).
 */
export async function findDuplicateForRecipient(
    input: IsDuplicateForRecipientInput,
    options: NotificationRepoOptions = {},
): Promise<NotificationRecord | null> {
    const windowSeconds = input.windowSeconds ?? DEFAULT_DEDUP_WINDOW_SECONDS;
    if (!Number.isFinite(windowSeconds) || windowSeconds < 0) {
        throw new Error('windowSeconds must be a non-negative finite number');
    }

    const now = input.now ?? new Date();
    const sinceMs = now.getTime() - windowSeconds * 1000;
    const since = new Date(sinceMs).toISOString();

    const candidates = await findByDedupKey(
        { dedup_key: input.dedup_key, since, limit: 25 },
        options,
    );

    for (const candidate of candidates) {
        if (
            input.excludeNotificationId &&
            candidate.notification_id === input.excludeNotificationId
        ) {
            continue;
        }
        const recipient = candidate.recipients.find(
            (r) => r.user_id === input.recipientId,
        );
        if (!recipient) continue;
        // REQ 4.4: a record stuck at `emitted`/`queued` has not actually
        // reached the recipient yet. Counting it as a duplicate would
        // suppress legitimate retries triggered by a transient dispatch
        // failure. Only `dispatched` and later count as a prior delivery.
        if (
            recipient.status === 'dispatched' ||
            recipient.status === 'delivered' ||
            recipient.status === 'read'
        ) {
            return candidate;
        }
    }

    return null;
}
