// ============================================================================
// Notification_Service — Lifecycle Helpers
// ============================================================================
// Wraps the store-level `updateLifecycle` (which enforces the ordering
// invariant `created_at <= dispatched_at <= delivered_at <= read_at`,
// REQ 6.7a) with the higher-level transitions the service uses:
//
//   transitionToQueued      — emitted -> queued
//   transitionToDispatched  — queued/emitted -> dispatched (records dispatched_at)
//   transitionToDelivered   — dispatched -> delivered     (records delivered_at)
//   transitionToFailed      — any state  -> failed
//   markAsRead              — sets read_at on first call, no-op afterwards
//                             (REQ 4.6 idempotence)
//
// `lifecycle.ts` does NOT touch the recipients sub-array directly; that is
// the dispatcher's responsibility (one row per recipient is built by the
// store layer when GSI keys are computed). Top-level lifecycle is the only
// concern here.
// ============================================================================

import {
    getNotification,
    updateLifecycle,
    type NotificationRepoOptions,
    type UpdateLifecycleInput,
} from '../store';
import type { NotificationRecord, NotificationStatus } from '../store/types';
import { NotificationNotFoundError } from './errors';

// ---- Result envelope -----------------------------------------------------

export interface MarkAsReadOutput {
    readonly notification: NotificationRecord;
    readonly first_read: boolean;
}

// ---- Generic transition helpers ------------------------------------------

/**
 * Internal helper — read the existing record and refuse on missing ids
 * with a structured `NotificationNotFoundError` rather than the store-
 * layer "lifecycle ordering violation" which would mislead operators.
 */
async function loadOrFail(
    notificationId: string,
    options: NotificationRepoOptions,
): Promise<NotificationRecord> {
    const existing = await getNotification(notificationId, options);
    if (!existing) {
        throw new NotificationNotFoundError(notificationId);
    }
    return existing;
}

/**
 * Move a notification's top-level lifecycle to `queued`. Idempotent: no-op
 * when the record is already at or past `queued`.
 *
 * `queued` does not have a dedicated timestamp column on the record, so the
 * transition only updates the `status` field; the ordering invariant
 * remains satisfied.
 */
export async function transitionToQueued(
    notificationId: string,
    options: NotificationRepoOptions = {},
): Promise<NotificationRecord> {
    const existing = await loadOrFail(notificationId, options);
    if (existing.status !== 'emitted') {
        return existing;
    }
    return updateLifecycle(
        { notificationId, status: 'queued' },
        options,
    );
}

/**
 * Move a notification's top-level lifecycle to `dispatched` and stamp
 * `dispatched_at`. Idempotent: when called on a record that is already at
 * `dispatched` or later, the function returns the existing record without
 * re-stamping the timestamp (we MUST NOT advance `dispatched_at` past its
 * first-set value or the invariant would be violated for a record whose
 * `delivered_at` was already populated).
 */
export async function transitionToDispatched(
    notificationId: string,
    now: string = new Date().toISOString(),
    options: NotificationRepoOptions = {},
): Promise<NotificationRecord> {
    const existing = await loadOrFail(notificationId, options);
    if (
        existing.status === 'dispatched' ||
        existing.status === 'delivered' ||
        existing.status === 'read'
    ) {
        return existing;
    }
    return updateLifecycle(
        {
            notificationId,
            status: 'dispatched',
            dispatched_at: existing.dispatched_at ?? now,
        },
        options,
    );
}

/**
 * Move a notification's top-level lifecycle to `delivered` and stamp
 * `delivered_at`. Idempotent.
 */
export async function transitionToDelivered(
    notificationId: string,
    now: string = new Date().toISOString(),
    options: NotificationRepoOptions = {},
): Promise<NotificationRecord> {
    const existing = await loadOrFail(notificationId, options);
    if (existing.status === 'delivered' || existing.status === 'read') {
        return existing;
    }
    // The ordering invariant requires `dispatched_at` to be set before
    // `delivered_at`. If we somehow reach this transition without one
    // (e.g. test seam), synthesize one from the same `now` so the
    // store-level check still passes.
    const dispatched_at = existing.dispatched_at ?? now;
    return updateLifecycle(
        {
            notificationId,
            status: 'delivered',
            dispatched_at,
            delivered_at: existing.delivered_at ?? now,
        },
        options,
    );
}

/**
 * Move a notification's top-level lifecycle to `failed`. Allowed from any
 * non-`failed` state (REQ 4 lifecycle diagram in store/types.ts).
 */
export async function transitionToFailed(
    notificationId: string,
    options: NotificationRepoOptions = {},
): Promise<NotificationRecord> {
    const existing = await loadOrFail(notificationId, options);
    if (existing.status === 'failed') return existing;
    return updateLifecycle(
        { notificationId, status: 'failed' as NotificationStatus },
        options,
    );
}

// ---- markAsRead (REQ 4.5, 4.6 — idempotent) -----------------------------

export interface MarkAsReadInput {
    readonly notification_id: string;
    readonly user_id: string;
    readonly now?: string;
}

/**
 * Idempotently mark a notification as read for `user_id` (REQ 4.5, 4.6).
 *
 * Behaviour:
 *   - When the notification is already at `read` (i.e. `read_at` is set),
 *     return the existing record with `first_read: false` and DO NOT
 *     update DynamoDB.
 *   - Otherwise transition through `dispatched`/`delivered` as needed so
 *     the ordering invariant is satisfied and stamp `read_at`.
 *
 * `user_id` is currently informational — the top-level `read_at` is shared
 * across all recipients of a notification. The full per-recipient `read_at`
 * lives in the `recipients[]` array (REQ 6.1) and is updated by the
 * dispatcher (task 6.1 / 9.1) when the in-app channel acks a read. The
 * service-level `markAsRead` operates on the SUMMARY field that drives the
 * unread-count projection (REQ 6.7).
 */
export async function markAsRead(
    input: MarkAsReadInput,
    options: NotificationRepoOptions = {},
): Promise<MarkAsReadOutput> {
    const existing = await loadOrFail(input.notification_id, options);

    // Already read → no-op (REQ 4.6).
    if (existing.read_at) {
        return { notification: existing, first_read: false };
    }

    // Synthesize the prior trailing timestamps so the ordering invariant
    // holds: read_at MUST come after delivered_at MUST come after
    // dispatched_at MUST come after created_at. If a caller marks a record
    // as read before the dispatcher has stamped delivery (rare; possible
    // when the in-app channel races the server-side projection), we keep
    // the strict ordering by stamping each intermediate timestamp at the
    // same `now` value. Using identical values is safe because REQ 6.7a
    // uses `<=` (non-strict), not `<`.
    const now = input.now ?? new Date().toISOString();
    const dispatched_at = existing.dispatched_at ?? now;
    const delivered_at = existing.delivered_at ?? now;

    const updated = await updateLifecycle(
        {
            notificationId: input.notification_id,
            status: 'read',
            dispatched_at,
            delivered_at,
            read_at: now,
        } satisfies UpdateLifecycleInput,
        options,
    );

    return { notification: updated, first_read: true };
}
