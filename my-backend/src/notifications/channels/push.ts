// ============================================================================
// UNS Delivery_Layer — Push Channel Adapter (FCM via SNS)
// ============================================================================
// Single canonical push channel implementation for the Notification_System
// (`phase3-architecture.md` §9.2 — push). Plugs into the
// `DispatchChannelAdapter` callback exposed by `Notification_Service.dispatch`
// (see `../service/types.ts`) and conforms to its
// `async (args): Promise<void>` signature.
//
// Transport
// ---------
// We reuse the existing SNS-fronts-FCM pattern already in production at
// `my-backend/src/handlers/in-store-streams.ts` (`sendPushNotification`).
// Publishing to `FCM_SNS_TOPIC_ARN` keeps the IAM, observability, and
// per-device fan-out story identical to today's push surface, which
// matters because Phase 4 must not introduce a parallel push pipeline
// (REQ 20.1 — exactly one canonical implementation per component).
//
// `firebase-admin` is intentionally NOT used here: it is not installed in
// `my-backend/package.json`, and the SNS+platform-application path is
// already wired in `serverless.yml` (`PLATFORM_APPLICATION_ARN`,
// `FCM_SNS_TOPIC_ARN`). If the project later moves to direct
// `firebase-admin` calls, this file is the only swap-in point.
//
// Retry policy (REQ 5.9, 9.3)
// ---------------------------
// Up to 3 retries with exponential backoff on transient errors (network,
// throttle, temporary SNS unavailability). On exhaustion the adapter
// THROWS — the Notification_Service catches the throw, writes the
// `failed` AuditLog entry (task 6.1's `dispatch` implementation already
// records this), and the Event_Bus retry envelope routes the original
// payload to the DLQ per REQ 3.10 / 9.3.
//
// Device-token storage
// --------------------
// Per task 9.2's hand-off note, device-token registration is a separate
// concern owned by `my-backend/src/handlers/notification.ts`. This adapter
// does not look tokens up directly; instead it tags every SNS publish
// with the recipient's `user_id` as a `MessageAttribute`, leaving it to
// the SNS→FCM platform-application or a downstream filter Lambda to
// resolve the user's registered endpoint(s). This keeps the adapter
// stateless and decoupled from the device-token data model.
//
// Validates: REQ 5.2, 5.9, 9.3.
// ============================================================================

import {
    SNSClient,
    PublishCommand,
    type MessageAttributeValue,
} from '@aws-sdk/client-sns';
import { config } from '../../config/environment';
import { logger } from '../../utils/logger';
import { sanitizePayload } from '../service/sanitization';
import type { DispatchChannelAdapter, DispatchChannelArgs } from '../service/types';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/** Max retry attempts on top of the initial try (REQ 5.9 — "up to 3 retries"). */
export const PUSH_MAX_RETRIES = 3;

/** Base backoff in milliseconds; doubled on each subsequent attempt. */
export const PUSH_BACKOFF_BASE_MS = 200;

/** Cap on the per-retry sleep so a long backoff doesn't starve the dispatcher. */
export const PUSH_BACKOFF_MAX_MS = 5_000;

// ---------------------------------------------------------------------------
// SNS client (lazy init for Lambda cold-start friendliness)
// ---------------------------------------------------------------------------

let snsClient: SNSClient | null = null;

function getSnsClient(): SNSClient {
    if (!snsClient) {
        snsClient = new SNSClient({ region: config.aws.region });
    }
    return snsClient;
}

/** Test-only hook — replaces the SNS client for unit tests. */
export function _setSnsClientForTests(client: SNSClient | null): void {
    snsClient = client;
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/**
 * Thrown when the FCM topic ARN is not configured. The Notification_Service
 * treats every adapter throw as a `failed` lifecycle transition.
 */
export class PushAdapterConfigError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'PushAdapterConfigError';
    }
}

/**
 * Thrown after the configured retry budget is exhausted on transient
 * errors. Carries the underlying cause so the Notification_Service can
 * record `error_reason` on the AuditLog entry (REQ 14.1).
 */
export class PushDeliveryError extends Error {
    public readonly cause?: Error;
    public readonly attempts: number;

    constructor(message: string, attempts: number, cause?: Error) {
        super(message);
        this.name = 'PushDeliveryError';
        this.attempts = attempts;
        this.cause = cause;
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Identify SNS errors that are safe to retry. Mirrors the criteria used by
 * the Event_Bus publisher (`../event-bus/publisher.ts`) so retry behavior
 * is consistent across the notification stack.
 */
function isTransientAwsError(err: unknown): boolean {
    if (!(err instanceof Error)) return true;
    const name = err.name || '';
    return (
        name === 'ThrottlingException' ||
        name === 'ServiceUnavailableException' ||
        name === 'InternalErrorException' ||
        name === 'TimeoutError' ||
        name === 'NetworkingError' ||
        name === 'AbortError' ||
        name === 'FetchError'
    );
}

/**
 * Compute exponential backoff capped at `PUSH_BACKOFF_MAX_MS`.
 * Attempt 1 → base * 1, attempt 2 → base * 2, attempt 3 → base * 4, …
 */
export function computePushBackoffMs(attempt: number): number {
    const exp = Math.max(0, attempt - 1);
    const ms = PUSH_BACKOFF_BASE_MS * Math.pow(2, exp);
    return Math.min(ms, PUSH_BACKOFF_MAX_MS);
}

function delay(ms: number): Promise<void> {
    if (ms <= 0) return Promise.resolve();
    return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Test-only hook — replaces the sleep function so tests run instantly. */
let sleepImpl: (ms: number) => Promise<void> = delay;
export function _setSleepForTests(fn: ((ms: number) => Promise<void>) | null): void {
    sleepImpl = fn ?? delay;
}

/**
 * Build the FCM payload from a NotificationRecord. Shape mirrors the
 * existing in-store push payload so downstream FCM-side templates and
 * mobile clients keep working without per-event branching.
 *
 * Title/body fall back to placeholders when the payload omits them; the
 * receiving client should use `event_name` to render a localized message
 * via the templates at `my-backend/src/i18n/notification-templates.ts`
 * (referenced in `phase1-scan-report.md` line 1050).
 */
function buildFcmPayload(args: DispatchChannelArgs): string {
    const { notification, recipient } = args;

    // REQ 12.2 — defense-in-depth sanitization at the channel boundary
    // before handing the payload to the FCM transport. The push
    // notification surface fans out to mobile OS notification centers
    // which may render `title`/`body` directly, so any scripting tags or
    // control bytes that slipped past `createNotification` are stripped
    // here too.
    const payload = sanitizePayload(
        notification.payload as Record<string, unknown>,
    );

    // Pull display strings from the payload if the producer set them; the
    // unified-notification-system Event_Contract does not mandate these
    // fields, so we treat them as best-effort.
    const title =
        typeof payload.title === 'string' && payload.title.length > 0
            ? payload.title
            : `New ${notification.category} notification`;
    const body =
        typeof payload.body === 'string' && payload.body.length > 0
            ? payload.body
            : notification.event_name;

    const fcm = {
        // The platform-app SNS topic expects an FCM-shaped message under the
        // `GCM` key — same convention as `in-store-streams.ts`.
        GCM: JSON.stringify({
            notification: {
                title,
                body,
            },
            data: {
                notification_id: notification.notification_id,
                event_name: notification.event_name,
                category: notification.category,
                sub_category: notification.sub_category,
                priority: notification.priority,
                source_app: notification.source_app,
                source_module: notification.source_module,
                target_id: notification.target_id,
                actor_id: notification.actor_id,
                recipient_user_id: recipient.user_id,
                recipient_role: recipient.role,
                created_at: notification.created_at,
            },
        }),
    };

    return JSON.stringify(fcm);
}

function readTopicArn(): string {
    const arn = config.awsSns.fcmTopicArn || '';
    if (!arn || arn.trim().length === 0) {
        throw new PushAdapterConfigError(
            'FCM_SNS_TOPIC_ARN is not configured. Set it in the environment ' +
                'before dispatching push notifications.',
        );
    }
    return arn;
}

function buildSnsAttributes(
    args: DispatchChannelArgs,
): Record<string, MessageAttributeValue> {
    return {
        // Recipient label — downstream filter / platform-app rule selects
        // the registered FCM endpoint(s) for this user.
        recipient_user_id: {
            DataType: 'String',
            StringValue: args.recipient.user_id,
        },
        recipient_role: {
            DataType: 'String',
            StringValue: args.recipient.role,
        },
        notification_id: {
            DataType: 'String',
            StringValue: args.notification.notification_id,
        },
        event_name: {
            DataType: 'String',
            StringValue: args.notification.event_name,
        },
        priority: {
            DataType: 'String',
            StringValue: args.notification.priority,
        },
    };
}

// ---------------------------------------------------------------------------
// Public adapter
// ---------------------------------------------------------------------------

/**
 * The push channel adapter. Conforms to `DispatchChannelAdapter`.
 *
 * Returns when SNS acknowledges the publish on any attempt (≤ 1 + 3 = 4
 * total attempts). Throws `PushDeliveryError` on retry exhaustion or
 * `PushAdapterConfigError` on missing config — the Notification_Service
 * treats either throw as a `failed` lifecycle transition (REQ 9.3).
 */
export const pushChannelAdapter: DispatchChannelAdapter = async (
    args: DispatchChannelArgs,
): Promise<void> => {
    if (args.channel !== 'push') {
        // Defensive guard — the service routes by channel, but a misrouted
        // call should fail loudly rather than silently mis-deliver.
        throw new PushDeliveryError(
            `pushChannelAdapter invoked with channel='${args.channel}'`,
            0,
        );
    }

    const topicArn = readTopicArn();
    const message = buildFcmPayload(args);
    const messageAttributes = buildSnsAttributes(args);

    const totalAttempts = PUSH_MAX_RETRIES + 1; // 1 initial + 3 retries
    let lastError: Error | undefined;

    // Note on retry-budget layering: this adapter's 4-attempt budget sits
    // INSIDE the bus-level 5-retry envelope (consumer.ts). Choosing 4 here
    // (not 5) leaves headroom under the SQS visibility-timeout: the inner
    // backoff peaks at PUSH_BACKOFF_MAX_MS=5s × 4 ≈ 20s, well under the
    // 60s default visibilityTimeoutSeconds, so SQS never redelivers the
    // same message to a second consumer mid-retry.
    for (let attempt = 1; attempt <= totalAttempts; attempt++) {
        try {
            await getSnsClient().send(
                new PublishCommand({
                    TopicArn: topicArn,
                    Message: message,
                    MessageStructure: 'json',
                    MessageAttributes: messageAttributes,
                }),
            );

            if (attempt > 1) {
                logger.info('[push] Recovered after retry', {
                    notification_id: args.notification.notification_id,
                    recipient_user_id: args.recipient.user_id,
                    attempt,
                });
            } else {
                logger.debug?.('[push] Delivered', {
                    notification_id: args.notification.notification_id,
                    recipient_user_id: args.recipient.user_id,
                });
            }
            return;
        } catch (err) {
            lastError = err instanceof Error ? err : new Error(String(err));

            // Permanent error — do NOT retry; surface immediately so the
            // service records `failed` with a precise reason.
            if (!isTransientAwsError(err)) {
                logger.error('[push] Permanent FCM publish failure', {
                    notification_id: args.notification.notification_id,
                    recipient_user_id: args.recipient.user_id,
                    error_name: lastError.name,
                    error_message: lastError.message,
                });
                throw new PushDeliveryError(
                    `push delivery failed permanently: ${lastError.message}`,
                    attempt,
                    lastError,
                );
            }

            const isLast = attempt >= totalAttempts;
            if (isLast) break;

            const backoff = computePushBackoffMs(attempt);
            logger.warn('[push] Transient FCM publish failure — retrying', {
                notification_id: args.notification.notification_id,
                recipient_user_id: args.recipient.user_id,
                attempt,
                next_attempt_in_ms: backoff,
                error_name: lastError.name,
                error_message: lastError.message,
            });
            await sleepImpl(backoff);
        }
    }

    // Retry budget exhausted — REQ 5.9, 9.3. Throw so the caller records the
    // `failed` audit entry and routes to the DLQ via the Event_Bus envelope.
    logger.error('[push] Retry budget exhausted', {
        notification_id: args.notification.notification_id,
        recipient_user_id: args.recipient.user_id,
        attempts: totalAttempts,
        error_name: lastError?.name,
        error_message: lastError?.message,
    });
    throw new PushDeliveryError(
        `push delivery failed after ${totalAttempts} attempts: ` +
            (lastError?.message ?? 'unknown error'),
        totalAttempts,
        lastError,
    );
};

export default pushChannelAdapter;
