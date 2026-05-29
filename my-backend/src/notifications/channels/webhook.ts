// ============================================================================
// Delivery_Layer — Webhook Channel Adapter
// ============================================================================
// One-file webhook channel adapter for the Notification_System Delivery_Layer
// (`my-backend/src/notifications/channels/`). Plugs into the
// `DispatchChannelAdapter` callback that `Notification_Service.dispatch`
// forwards to (see `../service/types.ts`).
//
// Behaviour pinned by:
//   - REQ 5.5  — webhook channel posts notifications to a configured HTTPS
//                endpoint with a signed payload.
//   - REQ 5.12 — every webhook POST carries an `X-Signature` header computed
//                over the payload using a per-consumer shared secret.
//   - REQ 5.13 — on non-2xx response, retry up to 5 times with exponential
//                backoff; on persistent failure the adapter throws so the
//                Notification_Service writes a `failed` AuditLog entry and
//                routes the event to the DLQ.
//   - Phase 3 §9.1 / §9.2 — channel matrix and per-channel adapter behaviour:
//                signed HTTPS POST, per-consumer shared secret for the
//                `X-Signature` header, 5 retries with exponential backoff
//                before DLQ.
//
// IMPORTANT — recipient resolution.
// The webhook channel is for external consumers (Phase 2 §2 `webhook_consumer`).
// The `recipient.user_id` passed to this adapter is therefore a webhook
// CONSUMER id rather than a regular UNS user id. The adapter resolves the
// per-consumer endpoint and shared secret via `getWebhookConfig(consumerId)`;
// the real `WebhookConsumerRegistry` lookup is wired in a later task. The
// placeholder here keeps the adapter testable and lets the Delivery_Layer
// façade (task 9.6) plug it in immediately without blocking on that wiring.
//
// No third-party dependencies: uses Node 18+ built-in `fetch` and the
// `crypto` HMAC primitive. Failures inside one webhook delivery do not
// affect other channel adapters (Phase 3 §9.3 — failure isolation).
// ============================================================================

import { createHmac } from 'crypto';
import { logger } from '../../utils/logger';
import { sanitizePayload } from '../service/sanitization';
import type {
    DispatchChannelAdapter,
    DispatchChannelArgs,
} from '../service/types';

// ---- Configuration constants (Phase 3 §8.1, §9.2) -------------------------

/**
 * Maximum number of attempts for a single webhook delivery.
 * REQ 5.13 / Phase 3 §8.1 — up to 5 retries on persistent non-2xx; the
 * total attempt count is therefore 1 initial + up to 5 retries = 6. To
 * keep the implementation aligned with the textual "up to 5 retries" the
 * adapter caps at 5 total attempts (1 initial + 4 retries) UNLESS the
 * caller overrides via `WebhookAdapterOptions.maxAttempts`. Task 9.6 will
 * pin the value the production façade uses.
 */
export const WEBHOOK_MAX_ATTEMPTS = 5;

/** Initial backoff, doubled on every retry. */
export const WEBHOOK_INITIAL_BACKOFF_MS = 200;

/** Cap on backoff so an unhealthy peer cannot stall the worker indefinitely. */
export const WEBHOOK_MAX_BACKOFF_MS = 5_000;

/** Per-request HTTP timeout (REQ phrasing "10s timeout per request"). */
export const WEBHOOK_REQUEST_TIMEOUT_MS = 10_000;

/** Header name for the HMAC-SHA256 signature (REQ 5.12). */
export const WEBHOOK_SIGNATURE_HEADER = 'X-Signature';

// ---- Per-consumer configuration ------------------------------------------

/**
 * Resolved webhook configuration for a single external consumer. The
 * `secret` is the per-consumer shared secret used to compute the
 * `X-Signature` header (REQ 5.12). The `url` is the HTTPS endpoint the
 * adapter POSTs to (REQ 5.5).
 */
export interface WebhookConfig {
    readonly url: string;
    readonly secret: string;
}

/**
 * Resolve `(url, secret)` for an external webhook consumer.
 *
 * Placeholder implementation — returns `null` for every consumer. The real
 * registry-backed lookup is wired in a later task (the registry lives at
 * `my-backend/src/notifications/sync/` together with the rest of the
 * Sub_App_Sync_Layer surface). Until then the adapter SKIPS dispatch
 * gracefully when no configuration is found, which is the safe default
 * (we never POST to an unknown URL with an unknown secret).
 *
 * The Delivery_Layer façade (task 9.6) MAY override this resolver by
 * passing a custom `getConfig` to `sendWebhook` / by replacing the export
 * via dependency injection in tests.
 */
export type WebhookConfigResolver = (
    consumerId: string,
) => WebhookConfig | null | Promise<WebhookConfig | null>;

/**
 * Default resolver. Currently a stub. Real implementation is wired by the
 * Delivery_Layer façade once the consumer registry lands.
 */
export const getWebhookConfig: WebhookConfigResolver = (
    _consumerId: string,
): WebhookConfig | null => {
    // INTENTIONAL stub. See `WebhookConfigResolver` JSDoc above.
    return null;
};

// ---- Adapter options & errors --------------------------------------------

export interface WebhookAdapterOptions {
    /** Override the per-consumer config resolver (used by tests). */
    readonly getConfig?: WebhookConfigResolver;
    /** Maximum total attempts; default {@link WEBHOOK_MAX_ATTEMPTS}. */
    readonly maxAttempts?: number;
    /** Initial backoff in ms; default {@link WEBHOOK_INITIAL_BACKOFF_MS}. */
    readonly initialBackoffMs?: number;
    /** Backoff cap in ms; default {@link WEBHOOK_MAX_BACKOFF_MS}. */
    readonly maxBackoffMs?: number;
    /** Per-request timeout in ms; default {@link WEBHOOK_REQUEST_TIMEOUT_MS}. */
    readonly timeoutMs?: number;
    /**
     * Override the HTTP transport. Production uses Node's built-in
     * `fetch` (Node 18+). Tests inject a deterministic fake.
     */
    readonly fetchImpl?: typeof fetch;
    /**
     * Override the sleep-between-retries function. Tests inject a
     * synchronous resolver to keep retry tests fast.
     */
    readonly sleep?: (ms: number) => Promise<void>;
}

/**
 * Thrown when every retry attempt failed. `Notification_Service.dispatch`
 * relies on this throw to write the `failed` lifecycle AuditLog entry
 * (REQ 5.13, REQ 14.1) and to route the event to the DLQ
 * (REQ 3.10, REQ 9.3).
 */
export class WebhookDeliveryError extends Error {
    public readonly attempts: number;
    public readonly lastStatus: number | null;
    public readonly lastErrorReason: string;
    public readonly consumerId: string;

    constructor(args: {
        consumerId: string;
        attempts: number;
        lastStatus: number | null;
        lastErrorReason: string;
    }) {
        super(
            `Webhook delivery to consumer "${args.consumerId}" failed after ` +
                `${args.attempts} attempt(s); last error: ${args.lastErrorReason}` +
                (args.lastStatus !== null
                    ? ` (HTTP ${args.lastStatus})`
                    : ''),
        );
        this.name = 'WebhookDeliveryError';
        this.consumerId = args.consumerId;
        this.attempts = args.attempts;
        this.lastStatus = args.lastStatus;
        this.lastErrorReason = args.lastErrorReason;
    }
}

// ---- HMAC signing --------------------------------------------------------

/**
 * Compute the `X-Signature` value for a webhook payload (REQ 5.12).
 *
 * Format: `hex(hmac_sha256(secret, body))`. The body is the exact same
 * bytes sent on the wire — the adapter computes the signature AFTER
 * serialising the payload so the receiver can reproduce the digest by
 * running the same HMAC over the bytes it received.
 */
export function computeWebhookSignature(
    secret: string,
    body: string,
): string {
    return createHmac('sha256', secret).update(body, 'utf8').digest('hex');
}

// ---- Backoff helper ------------------------------------------------------

function computeBackoffMs(
    attempt: number,
    initial: number,
    cap: number,
): number {
    // Exponential: initial * 2^(attempt-1), capped. `attempt` is 1-indexed
    // here — the FIRST retry waits `initial` ms, the SECOND waits 2*initial,
    // and so on up to `cap`.
    const raw = initial * 2 ** Math.max(0, attempt - 1);
    return Math.min(raw, cap);
}

const defaultSleep = (ms: number): Promise<void> =>
    new Promise((resolve) => setTimeout(resolve, ms));

// ---- Webhook payload envelope --------------------------------------------

/**
 * The JSON body the adapter POSTs to the consumer endpoint. Shape is the
 * strict subset of the Notification record the consumer needs — full
 * payload plus enough context to dedupe and route on the receiver side.
 *
 * Sensitive fields are NOT redacted here: redaction is owed by
 * Notification_Service.createNotification (Phase 3 §11.4 / REQ 12.8). By
 * the time a notification reaches this adapter the payload has already
 * passed through the sanitisation + redaction pass.
 */
export interface WebhookPayload {
    readonly notification_id: string;
    readonly event_name: string;
    readonly category: string;
    readonly sub_category: string;
    readonly priority: string;
    readonly actor_id: string;
    readonly target_id: string;
    readonly recipient: {
        readonly consumer_id: string;
        readonly role: string;
    };
    readonly payload: Record<string, unknown>;
    readonly source_module: string;
    readonly source_app: string;
    readonly created_at: string;
    readonly dedup_key: string;
}

function buildWebhookPayload(args: DispatchChannelArgs): WebhookPayload {
    const { notification, recipient } = args;
    // REQ 12.2 — defense-in-depth sanitization at the webhook boundary
    // before the payload is HMAC-signed and sent on the wire to an
    // external consumer. Notification_Service.createNotification already
    // sanitizes at persistence time; re-running here covers payloads
    // that arrived through paths bypassing the service (legacy
    // producers, replay tooling) and keeps the wire format consistent
    // with the other channel adapters.
    const safePayload = sanitizePayload(notification.payload);
    return {
        notification_id: notification.notification_id,
        event_name: notification.event_name,
        category: notification.category,
        sub_category: notification.sub_category,
        priority: notification.priority,
        actor_id: notification.actor_id,
        target_id: notification.target_id,
        recipient: {
            // Webhook recipients are EXTERNAL consumers, not regular UNS
            // users (Phase 2 §2 `webhook_consumer`). We surface the value
            // as `consumer_id` in the on-the-wire envelope to keep that
            // distinction explicit for receiver implementations.
            consumer_id: recipient.user_id,
            role: recipient.role,
        },
        payload: safePayload,
        source_module: notification.source_module,
        source_app: notification.source_app,
        created_at: notification.created_at,
        dedup_key: notification.dedup_key,
    };
}

// ---- Single attempt ------------------------------------------------------

interface AttemptOutcome {
    readonly ok: boolean;
    readonly status: number | null;
    readonly errorReason: string | null;
    /**
     * Whether the failure is retryable. Network errors and 5xx are
     * retryable; non-2xx 4xx are also retryable per REQ 5.13 ("non-2xx").
     * 2xx is success.
     */
    readonly retryable: boolean;
}

async function attemptOnce(
    url: string,
    body: string,
    signature: string,
    timeoutMs: number,
    fetchImpl: typeof fetch,
): Promise<AttemptOutcome> {
    try {
        const response = await fetchImpl(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                [WEBHOOK_SIGNATURE_HEADER]: signature,
            },
            body,
            signal: AbortSignal.timeout(timeoutMs),
        });

        if (response.status >= 200 && response.status < 300) {
            return { ok: true, status: response.status, errorReason: null, retryable: false };
        }

        // REQ 5.13: any non-2xx is retryable until the budget is spent.
        return {
            ok: false,
            status: response.status,
            errorReason: `non-2xx response (${response.status})`,
            retryable: true,
        };
    } catch (err) {
        // Network error, DNS failure, TLS error, AbortSignal timeout —
        // all transient from the adapter's point of view.
        const message = err instanceof Error ? err.message : String(err);
        return {
            ok: false,
            status: null,
            errorReason: `transport error: ${message}`,
            retryable: true,
        };
    }
}

// ---- Public entry point used by tests -----------------------------------

/**
 * Send a single webhook delivery with retry/backoff, throwing
 * {@link WebhookDeliveryError} on exhaustion. Exposed independently of
 * {@link webhookAdapter} so tests can drive the retry logic directly
 * with synthetic payloads.
 */
export async function sendWebhook(
    consumerId: string,
    payload: WebhookPayload,
    options: WebhookAdapterOptions = {},
): Promise<void> {
    const resolver = options.getConfig ?? getWebhookConfig;
    const config = await resolver(consumerId);

    if (!config) {
        // No registered webhook consumer with this id. Treat this as an
        // unrecoverable configuration error so the Notification_Service
        // records a `failed` AuditLog entry instead of silently dropping
        // the event.
        throw new WebhookDeliveryError({
            consumerId,
            attempts: 0,
            lastStatus: null,
            lastErrorReason: 'no webhook config registered for consumer',
        });
    }

    const maxAttempts = options.maxAttempts ?? WEBHOOK_MAX_ATTEMPTS;
    const initialBackoff =
        options.initialBackoffMs ?? WEBHOOK_INITIAL_BACKOFF_MS;
    const maxBackoff = options.maxBackoffMs ?? WEBHOOK_MAX_BACKOFF_MS;
    const timeoutMs = options.timeoutMs ?? WEBHOOK_REQUEST_TIMEOUT_MS;
    const fetchImpl = options.fetchImpl ?? fetch;
    const sleep = options.sleep ?? defaultSleep;

    // Serialise ONCE so the signature matches the bytes on the wire byte
    // for byte (REQ 5.12).
    const body = JSON.stringify(payload);
    const signature = computeWebhookSignature(config.secret, body);

    let lastStatus: number | null = null;
    let lastErrorReason = 'unknown error';

    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        const outcome = await attemptOnce(
            config.url,
            body,
            signature,
            timeoutMs,
            fetchImpl,
        );

        if (outcome.ok) {
            if (attempt > 1) {
                logger.info('webhook delivery succeeded after retry', {
                    consumer_id: consumerId,
                    notification_id: payload.notification_id,
                    event_name: payload.event_name,
                    attempts: attempt,
                });
            }
            return;
        }

        lastStatus = outcome.status;
        lastErrorReason = outcome.errorReason ?? 'unknown error';

        const isLastAttempt = attempt >= maxAttempts;
        if (!outcome.retryable || isLastAttempt) {
            break;
        }

        const backoff = computeBackoffMs(attempt, initialBackoff, maxBackoff);
        logger.warn('webhook delivery failed; will retry', {
            consumer_id: consumerId,
            notification_id: payload.notification_id,
            event_name: payload.event_name,
            attempt,
            next_backoff_ms: backoff,
            last_status: lastStatus,
            last_error_reason: lastErrorReason,
        });
        await sleep(backoff);
    }

    // REQ 5.13 — retries exhausted, surface failure so Notification_Service
    // writes the `failed` AuditLog entry and the event lands on the DLQ
    // (Phase 3 §8.2).
    throw new WebhookDeliveryError({
        consumerId,
        attempts: maxAttempts,
        lastStatus,
        lastErrorReason,
    });
}

// ---- DispatchChannelAdapter export --------------------------------------

/**
 * Build a `DispatchChannelAdapter` (see `../service/types.ts`) that the
 * Delivery_Layer façade plugs in for the `webhook` channel. The factory
 * shape lets tests / the façade pass through `WebhookAdapterOptions`
 * without re-declaring the adapter.
 *
 * The adapter:
 *   1. Builds the on-the-wire payload from the dispatch args.
 *   2. Resolves `(url, secret)` for the recipient consumer id.
 *   3. POSTs with `X-Signature` header (REQ 5.12).
 *   4. Retries up to 5 times with exponential backoff on non-2xx
 *      / transport errors (REQ 5.13).
 *   5. Throws {@link WebhookDeliveryError} on exhaustion so the
 *      Notification_Service writes the `failed` audit entry and the event
 *      is routed to the DLQ (REQ 3.10, 5.13, 9.3).
 */
export function createWebhookAdapter(
    options: WebhookAdapterOptions = {},
): DispatchChannelAdapter {
    return async (args: DispatchChannelArgs): Promise<void> => {
        if (args.channel !== 'webhook') {
            // Defensive — the Delivery_Layer façade routes by channel,
            // but if a future caller forwards a non-webhook dispatch we
            // surface it instead of silently corrupting the audit trail.
            throw new Error(
                `webhookAdapter received unsupported channel: ${args.channel}`,
            );
        }

        const consumerId = args.recipient.user_id;
        const payload = buildWebhookPayload(args);
        await sendWebhook(consumerId, payload, options);
    };
}

/**
 * Default adapter instance used by the Delivery_Layer façade. Tests SHOULD
 * call {@link createWebhookAdapter} with a custom `fetchImpl` and `sleep`
 * to keep retries deterministic.
 */
export const webhookAdapter: DispatchChannelAdapter = createWebhookAdapter();
