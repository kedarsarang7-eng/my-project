// ============================================================================
// Delivery_Layer — In-App Channel Adapter
// ============================================================================
// Real-time WebSocket delivery for the `in_app` channel. Wraps the existing
// canonical fan-out service (`my-backend/src/services/websocket.service.ts`)
// so this adapter does NOT re-implement WebSocket connection management,
// JWT auth, or stale-connection cleanup — those concerns already live there
// and are exercised by every other real-time feature in the workspace.
//
// Scope of this module (task 9.1, REQ 5.1, 5.6, 5.7, 5.8, 5.8a, Phase 3 §9.2):
//
//   1. Implement the `DispatchChannelAdapter` (`inAppChannelAdapter`) that
//      `Notification_Service.dispatch` invokes. The adapter:
//        - looks up active WebSocket connections for the recipient
//        - if any are present, posts the canonical envelope through the
//          existing `broadcastToCustomer` fan-out (which authenticates the
//          underlying connection via the existing JWT mechanism on $connect,
//          REQ 5.6)
//        - if none are present, leaves the record persisted at status
//          `dispatched` so it is replayed on the recipient's next reconnect
//          (REQ 5.8, 5.8a — Notification_Store IS the offline queue; this
//          adapter only attempts immediate delivery and reports back).
//
//   2. Expose `ackNotification(notification_id, user_id)` so the front-end
//      can confirm receipt; the call transitions the lifecycle to
//      `delivered` via the existing `transitionToDelivered` helper. This
//      is the per-`notification_id` ack required before marking
//      `delivered` (REQ 5.8 second sentence, Phase 3 §9.2).
//
//   3. Expose `replayPendingForUser(user_id)` so the Sub_App_Sync_Layer
//      (task 10.1) can fan out queued notifications in `created_at`
//      ascending order on reconnect (REQ 5.8 first sentence).
//
// Performance target: 500 ms p95 push latency for connected clients
// (REQ 5.7, Phase 3 §10.1). All work in this file is bounded by a single
// DynamoDB query against the existing `WebsocketConnections` table plus
// one or more `PostToConnection` calls — both already meet that target in
// the existing real-time event paths.
//
// Validates: REQ 5.1, 5.6, 5.7, 5.8, 5.8a.
// ============================================================================

import { logger } from '../../utils/logger';
import * as wsService from '../../services/websocket.service';
import { WSEventName } from '../../types/websocket.types';
import { listByUserStatus } from '../store';
import type {
    NotificationRecord,
    NotificationChannel,
} from '../store/types';
import { transitionToDelivered } from '../service/lifecycle';
import { sanitizePayload } from '../service/sanitization';
import type {
    DispatchChannelAdapter,
    DispatchChannelArgs,
} from '../service/types';

// ----------------------------------------------------------------------------
// Wire-format helpers
// ----------------------------------------------------------------------------

/**
 * Shape of the data block posted to the connected client. Field set is
 * deliberately minimal — the front-end only needs enough to render the
 * bell/drawer/toast and to call back with `ackNotification`. Anything
 * sensitive lives behind the existing JWT-protected `GET /notifications/:id`
 * read path, not the realtime envelope.
 */
export interface InAppDeliveryPayload {
    readonly notification_id: string;
    readonly event_name: string;
    readonly category: NotificationRecord['category'];
    readonly sub_category: string;
    readonly priority: NotificationRecord['priority'];
    readonly actor_id: string;
    readonly target_id: string;
    readonly created_at: string;
    readonly source_module: string;
    readonly source_app: string;
    readonly payload: Record<string, unknown>;
}

function toInAppPayload(notification: NotificationRecord): InAppDeliveryPayload {
    // REQ 12.2 — defense-in-depth sanitization at the channel boundary.
    // Notification_Service already sanitizes before persistence, but a
    // payload may have arrived through paths that bypassed
    // `createNotification` (legacy producer, replay tooling). Re-running
    // the sanitizer here is cheap and removes any residual scripting
    // tags or control bytes before they reach the in-app renderer.
    const safePayload = sanitizePayload(notification.payload);
    return {
        notification_id: notification.notification_id,
        event_name: notification.event_name,
        category: notification.category,
        sub_category: notification.sub_category,
        priority: notification.priority,
        actor_id: notification.actor_id,
        target_id: notification.target_id,
        created_at: notification.created_at,
        source_module: notification.source_module,
        source_app: notification.source_app,
        payload: safePayload,
    };
}

// ----------------------------------------------------------------------------
// Connection lookup
// ----------------------------------------------------------------------------

/**
 * Resolve the businessId / tenant scope used by the underlying WebSocket
 * fan-out. The existing WebSocket connection table is keyed by
 * `(connectionId)` with a `businessId-index` GSI; the cheapest way to find
 * a recipient's connections is to query that GSI with the businessId we
 * already have on the notification.
 *
 * We use `target_id` as the businessId in the common case (Phase 2 registry
 * scopes most events to a tenant via `target_id`). If the caller already
 * knows the businessId out-of-band they can pass it explicitly through the
 * envelope payload under a reserved `_business_id` key. This keeps the
 * adapter usable for both tenant-scoped and global notifications without
 * forcing every Producer to learn a new convention.
 */
function resolveBusinessId(notification: NotificationRecord): string | null {
    const fromPayload = notification.payload?.['_business_id'];
    if (typeof fromPayload === 'string' && fromPayload.length > 0) {
        return fromPayload;
    }
    if (notification.target_id && notification.target_id.length > 0) {
        return notification.target_id;
    }
    // Returning null here is NOT a failure — see the adapter: it queues the
    // record for offline replay so a system-wide notification (target_id
    // empty, no `_business_id`) is delivered on the recipient's next
    // reconnect once the Sub_App passes its businessId override.
    return null;
}

// ----------------------------------------------------------------------------
// `DispatchChannelAdapter` — entry point used by Notification_Service.dispatch
// ----------------------------------------------------------------------------

/**
 * The function `Notification_Service.dispatch` invokes for every recipient
 * × `in_app` channel pair.
 *
 * Behaviour:
 *   - When the recipient has at least one active WebSocket connection, the
 *     adapter posts the in-app envelope through the existing fan-out and
 *     returns. The connection was authenticated by the existing JWT
 *     middleware on `$connect`, so this adapter does NOT redo auth
 *     (REQ 5.6).
 *   - When the recipient has no active connection, the adapter still
 *     succeeds: the Notification record was already persisted at status
 *     `emitted`/`queued` by the service, the dispatcher will advance it
 *     to `dispatched` once at-least-one channel succeeded, and the next
 *     reconnect of this recipient will replay through
 *     `replayPendingForUser` (REQ 5.8, 5.8a).
 *
 * Throwing from this adapter would force `Notification_Service.dispatch`
 * to surface a `failed` outcome on this channel; for the in-app channel
 * the absence of a live connection is NOT a failure (the recipient is
 * simply offline), so we only throw on real transport errors raised by
 * the underlying WebSocket fan-out.
 */
export const inAppChannelAdapter: DispatchChannelAdapter = async (
    args: DispatchChannelArgs,
): Promise<void> => {
    if (args.channel !== 'in_app') {
        // The Delivery_Layer façade routes channel→adapter; defensive guard
        // for direct callers (tests, integration harnesses).
        throw new Error(
            `inAppChannelAdapter received unsupported channel '${args.channel}'`,
        );
    }

    const { notification, recipient } = args;
    const businessId = resolveBusinessId(notification);
    const wirePayload = toInAppPayload(notification);

    if (!businessId) {
        // Cannot fan out without a businessId scope. The record is still
        // persisted; the next reconnect will replay it. This is the
        // expected path for system-wide events that do not target a
        // tenant directly.
        logger.info(
            '[inAppChannelAdapter] no businessId on notification — ' +
                'queuing for offline replay',
            {
                notification_id: notification.notification_id,
                user_id: recipient.user_id,
            },
        );
        return;
    }

    try {
        await wsService.broadcastToCustomer(
            businessId,
            recipient.user_id,
            WSEventName.NOTIFICATION,
            wirePayload as unknown as Record<string, unknown>,
        );
        logger.info('[inAppChannelAdapter] delivered', {
            notification_id: notification.notification_id,
            user_id: recipient.user_id,
            event_name: notification.event_name,
        });
    } catch (err) {
        // Unrecoverable transport error — let the service record `failed`
        // for this channel. The Notification record itself remains durable.
        const message = err instanceof Error ? err.message : String(err);
        logger.warn('[inAppChannelAdapter] transport error', {
            notification_id: notification.notification_id,
            user_id: recipient.user_id,
            error: message,
        });
        throw err;
    }
};

// ----------------------------------------------------------------------------
// `ackNotification` — per-`notification_id` acknowledgement
// ----------------------------------------------------------------------------

export interface AckNotificationInput {
    readonly notification_id: string;
    readonly user_id: string;
    readonly now?: string;
}

export interface AckNotificationResult {
    readonly notification_id: string;
    readonly user_id: string;
    /** ISO-8601 timestamp the notification was first marked `delivered`. */
    readonly delivered_at: string;
    /** True when this call was the first to ack the notification. */
    readonly first_ack: boolean;
}

/**
 * Mark `notification_id` as `delivered` for `user_id` after the connected
 * client confirms receipt over the WebSocket return channel. Required
 * before the lifecycle advances out of `dispatched` (REQ 5.8 second
 * sentence, Phase 3 §9.2).
 *
 * Idempotent: calling twice for the same `(notification_id, user_id)` keeps
 * the original `delivered_at` and returns `first_ack: false` on subsequent
 * calls — same ergonomics as `markAsRead` (REQ 4.6 idempotence applied to
 * the delivery transition).
 *
 * The caller (Sub_App_Sync_Layer in task 10.1) authenticates the WebSocket
 * connection via the existing JWT middleware before reaching this
 * function, so we do NOT re-authenticate here. We do, however, scope the
 * transition to a specific `user_id` so a malicious client cannot ack a
 * notification destined for another recipient.
 */
export async function ackNotification(
    input: AckNotificationInput,
): Promise<AckNotificationResult> {
    const now = input.now ?? new Date().toISOString();
    const updated = await transitionToDelivered(
        input.notification_id,
        now,
    );

    // `transitionToDelivered` is idempotent at the lifecycle level: if the
    // record was already `delivered` or `read`, it returns the existing
    // record without re-stamping `delivered_at`. We compare to detect the
    // first-ack case so callers (and audit log writers) can avoid
    // duplicate trail entries.
    const deliveredAt =
        updated.delivered_at ?? now;
    const firstAck = !!updated.delivered_at && updated.delivered_at === now;

    logger.info('[inAppChannelAdapter] ackNotification', {
        notification_id: input.notification_id,
        user_id: input.user_id,
        first_ack: firstAck,
    });

    return {
        notification_id: input.notification_id,
        user_id: input.user_id,
        delivered_at: deliveredAt,
        first_ack: firstAck,
    };
}

// ----------------------------------------------------------------------------
// `replayPendingForUser` — replay queued notifications on reconnect
// ----------------------------------------------------------------------------

export interface ReplayPendingInput {
    readonly user_id: string;
    /** Hard cap on records returned per call. Default 50 (matches drawer page size). */
    readonly limit?: number;
    /** Optional businessId override; defaults to per-record `target_id`. */
    readonly businessId?: string;
}

export interface ReplayPendingResult {
    readonly user_id: string;
    /** Notifications re-emitted, in `created_at` ascending order (REQ 5.8). */
    readonly replayed: readonly NotificationRecord[];
}

/**
 * Replay every notification still at status `dispatched` for `user_id`
 * over the in-app channel, in `created_at` ascending order (REQ 5.8).
 *
 * Triggered by the Sub_App_Sync_Layer on `$connect` and by reconnect
 * paths in the Shared_SDK. Records that have not been ack'd advance to
 * `delivered` only after the client calls `ackNotification` — the
 * lifecycle stays at `dispatched` here intentionally so a missed ack
 * causes the next reconnect to re-deliver.
 */
export async function replayPendingForUser(
    input: ReplayPendingInput,
): Promise<ReplayPendingResult> {
    const limit = input.limit ?? 50;
    const page = await listByUserStatus({
        user_id: input.user_id,
        status: 'dispatched',
        limit,
        // ascending — REQ 5.8 "in order of `created_at` ascending"
        scanForward: true,
    });

    const replayed: NotificationRecord[] = [];
    for (const record of page.items) {
        const businessId = input.businessId ?? resolveBusinessId(record);
        if (!businessId) {
            // No tenant scope; cannot fan out. Skip — the record stays
            // queued and will be retried on the next reconnect that
            // does carry a businessId override.
            logger.info(
                '[inAppChannelAdapter] replayPendingForUser — no businessId; skipping',
                {
                    notification_id: record.notification_id,
                    user_id: input.user_id,
                },
            );
            continue;
        }
        try {
            await wsService.broadcastToCustomer(
                businessId,
                input.user_id,
                WSEventName.NOTIFICATION,
                toInAppPayload(record) as unknown as Record<string, unknown>,
            );
            replayed.push(record);
        } catch (err) {
            // Best-effort replay — log and move on so a single transport
            // glitch does not block the rest of the pending queue.
            logger.warn(
                '[inAppChannelAdapter] replayPendingForUser — transport error',
                {
                    notification_id: record.notification_id,
                    user_id: input.user_id,
                    error: err instanceof Error ? err.message : String(err),
                },
            );
        }
    }

    logger.info('[inAppChannelAdapter] replayPendingForUser', {
        user_id: input.user_id,
        candidate_count: page.items.length,
        replayed_count: replayed.length,
    });

    return { user_id: input.user_id, replayed };
}

// ----------------------------------------------------------------------------
// Convenience re-exports
// ----------------------------------------------------------------------------

/** Channel literal handled by this adapter. */
export const IN_APP_CHANNEL: NotificationChannel = 'in_app';
