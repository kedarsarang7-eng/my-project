// ============================================================================
// UNS Event_Bus — Publisher
// ============================================================================
// Single canonical publish entry point for every Producer (DukanX desktop via
// Shared_SDK, school sub-apps, backend Lambdas, voice-backend, lambda/*).
//
// Flow:
//   1. Charge the per-Producer publish rate limit (REQ 12.4). Default
//      1000 events/minute per Producer (`source_module`), configurable via
//      UNS_PUBLISH_RATE_LIMIT_PER_MIN / UNS_PUBLISH_RATE_WINDOW_MS. Evaluated
//      independently of and prior to authorization. On exceed →
//      ProducerRateLimitExceededError; nothing reaches validation or SNS.
//   2. Validate payload against the Event_Contract JSON Schema (REQ 3.6).
//      If invalid → throw EventContractValidationError, persist nothing.
//   3. Compute SNS message attributes (event_name, priority, delivery_mode,
//      source_app, dedup_key) so subscribers can filter without re-parsing.
//   4. Call `sns:Publish` against `UNS_SNS_TOPIC_ARN`.
//   5. Wait for SNS to acknowledge the publish (durable persistence across
//      multiple AZs is part of the SNS ack contract — REQ 3.3) before
//      returning to the caller.
//
// The publisher does NOT call DynamoDB; the Notification_Service consumes
// from SQS and writes the persisted Notification record there. Keeping the
// publisher thin matches `phase3-architecture.md` §2 (single component
// responsibility) and minimizes per-publish latency.
//
// Validates: REQ 3.1, 3.2, 3.3, 3.6, 3.7, 3.8, 9.1, 9.2, 9.7, 9.8, 12.4.
// ============================================================================

import {
    SNSClient,
    PublishCommand,
    type MessageAttributeValue,
} from '@aws-sdk/client-sns';
import { config } from '../../config/environment';
import { logger } from '../../utils/logger';
import {
    EventBusConfigError,
    EventBusUnavailableError,
    ProducerRateLimitExceededError,
} from './errors';
import { getDeliveryMode } from './delivery-modes';
import {
    getSharedRateLimiter,
    UNKNOWN_PRODUCER_ID,
} from './rate-limiter';
import {
    tryValidateEventContract,
    validateEventContract,
} from './schema-validator';
import {
    tryValidatePayloadRedaction,
    validatePayloadRedaction,
} from './redaction-validator';
import type {
    BusMessageAttributes,
    EventContract,
    PublishAck,
    PublishFailure,
} from './types';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const TOPIC_ARN_ENV = 'UNS_SNS_TOPIC_ARN';

function readTopicArn(): string {
    const arn = process.env[TOPIC_ARN_ENV];
    if (!arn || arn.trim().length === 0) {
        throw new EventBusConfigError(
            `Missing required environment variable ${TOPIC_ARN_ENV}. ` +
            'Configure the SNS topic ARN before publishing UNS events.',
        );
    }
    return arn;
}

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
// Helpers
// ---------------------------------------------------------------------------

function buildAttributes(event: EventContract): BusMessageAttributes {
    return {
        event_name: event.event_name,
        priority: event.priority,
        delivery_mode: getDeliveryMode(event.priority),
        source_app: event.source_app,
        dedup_key: event.dedup_key,
    };
}

function toSnsAttributes(attrs: BusMessageAttributes): Record<string, MessageAttributeValue> {
    // SNS message attributes only support String / String.Array / Number / Binary.
    // We use String for everything — these are short labels (≤ 256 bytes).
    return {
        event_name: { DataType: 'String', StringValue: attrs.event_name },
        priority: { DataType: 'String', StringValue: attrs.priority },
        delivery_mode: { DataType: 'String', StringValue: attrs.delivery_mode },
        source_app: { DataType: 'String', StringValue: attrs.source_app },
        dedup_key: { DataType: 'String', StringValue: attrs.dedup_key },
    };
}

function isTransientAwsError(err: unknown): boolean {
    // SNS surfaces transient/retryable conditions via these error names.
    // The `EventBusUnavailableError` returned to callers signals the producer
    // outbox shim should buffer and replay (REQ 9.7).
    if (!(err instanceof Error)) return true;
    const name = err.name || '';
    return (
        name === 'ThrottlingException' ||
        name === 'ServiceUnavailableException' ||
        name === 'InternalErrorException' ||
        name === 'TimeoutError' ||
        name === 'NetworkingError' ||
        // Generic Node fetch / undici failures
        name === 'AbortError' ||
        name === 'FetchError'
    );
}

/**
 * Best-effort extraction of the per-Producer identifier from a candidate
 * event payload, performed BEFORE Event_Contract validation so the
 * rate-limit accounting reflects every publish attempt — including ones
 * with malformed payloads (REQ 12.4: "applied to every publish attempt
 * regardless of whether the request is subsequently authorized or denied").
 *
 * We prefer `source_module` because it is the stablest per-Producer label
 * the envelope provides (canonical workspace path of the emitting module).
 * Falls back to `source_app`, then to a sentinel for completely malformed
 * payloads so a flood of garbage publishes is still throttled.
 */
function extractProducerId(candidate: unknown): string {
    if (candidate && typeof candidate === 'object') {
        const obj = candidate as Record<string, unknown>;
        const sourceModule = obj.source_module;
        if (typeof sourceModule === 'string' && sourceModule.trim().length > 0) {
            return sourceModule;
        }
        const sourceApp = obj.source_app;
        if (typeof sourceApp === 'string' && sourceApp.trim().length > 0) {
            return sourceApp;
        }
    }
    return UNKNOWN_PRODUCER_ID;
}

/**
 * Per-Producer rate-limit middleware (REQ 12.4).
 *
 * Charges one token against the Producer's bucket and, on rejection, throws
 * a structured `ProducerRateLimitExceededError` and emits a single
 * structured warn log line so floods are observable in CloudWatch.
 *
 * Evaluated BEFORE schema validation and BEFORE any SNS interaction — this
 * is the explicit ordering required by REQ 12.4 ("evaluated independently
 * of authorization checks", "applied to every publish attempt").
 */
function enforcePublishRateLimit(candidate: unknown): void {
    const producerId = extractProducerId(candidate);
    const decision = getSharedRateLimiter().consume(producerId);
    if (decision.allowed) return;

    logger.warn('[EventBus] Producer publish rate-limit exceeded', {
        producerId: decision.producerId,
        limit: decision.limit,
        windowMs: decision.windowMs,
        retryAfterMs: decision.retryAfterMs,
    });
    throw new ProducerRateLimitExceededError(
        `Producer "${decision.producerId}" exceeded publish rate limit ` +
        `of ${decision.limit} events per ${decision.windowMs} ms. ` +
        `Retry after ~${decision.retryAfterMs} ms.`,
        {
            producerId: decision.producerId,
            limit: decision.limit,
            windowMs: decision.windowMs,
            retryAfterMs: decision.retryAfterMs,
        },
    );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Publish a single Event_Contract event to the bus.
 *
 * Pipeline (REQ 12.4 mandates the per-Producer rate-limit step runs before
 * authorization; we run it before validation as well, so a buggy producer
 * flooding malformed payloads is still throttled and logged):
 *
 *   1. Per-Producer rate-limit (REQ 12.4) — throws on flood.
 *   2. Event_Contract JSON Schema validation (REQ 3.6) — throws on malformed.
 *   3. SNS publish (REQ 3.3) — durable persistence before ack.
 *
 * @throws ProducerRateLimitExceededError when the Producer has exceeded its
 *         configured publish budget within the window. Nothing is sent to
 *         SNS; nothing is persisted (REQ 12.4).
 * @throws EventContractValidationError when the payload fails JSON Schema
 *         validation. Nothing is sent to SNS; nothing is persisted (REQ 3.6).
 * @throws EventBusUnavailableError when SNS is unreachable. Producers
 *         catch this and buffer in the local outbox per REQ 9.7.
 * @throws EventBusConfigError when the topic ARN is not configured.
 *
 * Returns only after SNS has acknowledged durable persistence (REQ 3.3).
 */
export async function publishEvent(event: unknown): Promise<PublishAck> {
    // 1. Per-Producer rate-limit BEFORE validation (REQ 12.4).
    //    Done first so even malformed-payload floods consume a token and
    //    are subject to throttling.
    enforcePublishRateLimit(event);

    // 2. Validate. Only after a successful validate do we touch SNS.
    const validated = validateEventContract(event);

    // 3. Enforce REQ 12.8 — payloads must not embed raw secrets, full PAN,
    //    full credit cards, full government IDs. Runs AFTER schema
    //    validation (so we can rely on the envelope shape) and BEFORE the
    //    SNS publish (so a rejected publish persists nothing). Throws an
    //    `EventContractValidationError` whose `issues` enumerate every
    //    offending field path.
    validatePayloadRedaction(validated);

    // 4. Forward to SNS.
    return publishValidatedEvent(validated);
}

/**
 * Internal: SNS publish step shared by `publishEvent` and `publishBatch`.
 * Assumes the event has already passed rate-limit and validation. Kept
 * private to the module so external callers cannot bypass the gates.
 */
async function publishValidatedEvent(validated: EventContract): Promise<PublishAck> {
    const topicArn = readTopicArn();
    const attrs = buildAttributes(validated);

    let response;
    try {
        response = await getSnsClient().send(new PublishCommand({
            TopicArn: topicArn,
            Message: JSON.stringify(validated),
            MessageAttributes: toSnsAttributes(attrs),
        }));
    } catch (err) {
        // Distinguish transient (outbox-eligible) from permanent failures so
        // producers know whether to buffer-and-replay or surface the error.
        if (isTransientAwsError(err)) {
            const cause = err instanceof Error ? err : new Error(String(err));
            logger.warn('[EventBus] Transient SNS publish failure — caller should buffer to outbox', {
                eventId: validated.id,
                eventName: validated.event_name,
                error: cause.message,
            });
            throw new EventBusUnavailableError(
                `SNS publish failed transiently: ${cause.message}`,
                cause,
            );
        }
        // Permanent failure (auth / not found / invalid topic).
        logger.error('[EventBus] Permanent SNS publish failure', {
            eventId: validated.id,
            eventName: validated.event_name,
            error: err instanceof Error ? err.message : String(err),
        });
        throw err;
    }

    if (!response.MessageId) {
        throw new EventBusUnavailableError(
            'SNS returned an empty MessageId — treating as undelivered.',
        );
    }

    logger.info('[EventBus] Event published', {
        eventId: validated.id,
        eventName: validated.event_name,
        priority: validated.priority,
        deliveryMode: attrs.delivery_mode,
        snsMessageId: response.MessageId,
    });

    return { messageId: response.MessageId };
}

/**
 * Publish a batch of events.
 *
 * Per-Producer rate-limit is charged for every batch entry up-front
 * (REQ 12.4: "applied to every publish attempt") — including entries that
 * subsequently fail Event_Contract validation. A rate-limit rejection on
 * a single entry is reported back in `failed` with `code: 'rate_limited'`
 * and never reaches SNS. Validation failures are reported with
 * `code: 'validation_error'`. Valid entries that pass rate-limit are
 * forwarded to `publishEvent` one-by-one; SNS PublishBatch is bounded to
 * 10 entries per call so the simple loop is intentional.
 */
export async function publishBatch(events: unknown[]): Promise<{
    messageIds: string[];
    failed: PublishFailure[];
}> {
    const messageIds: string[] = [];
    const failed: PublishFailure[] = [];

    for (let index = 0; index < events.length; index++) {
        const candidate = events[index];

        // Charge the per-Producer rate-limit FIRST, before any other check.
        // Mirrors the ordering inside `publishEvent` so behaviour is consistent
        // whether a Producer publishes one-by-one or in batches.
        try {
            enforcePublishRateLimit(candidate);
        } catch (err) {
            if (err instanceof ProducerRateLimitExceededError) {
                failed.push({
                    index,
                    code: 'rate_limited',
                    message: err.message,
                    producerId: err.producerId,
                    retryAfterMs: err.retryAfterMs,
                });
                continue;
            }
            throw err;
        }

        const validation = tryValidateEventContract(candidate);
        if (!validation.ok) {
            failed.push({
                index,
                code: 'validation_error',
                message: 'Event_Contract validation failed',
                issues: validation.issues,
            });
            continue;
        }

        // REQ 12.8 — reject batched entries that embed raw secrets, full
        // PAN, full credit cards, or full government IDs. Reported as
        // `validation_error` so callers can branch on a single failure
        // code; the structured `issues` array names the offending fields
        // and the matched pattern (`keyword: 'pan_india' | 'credit_card'
        // | …`) so producer tooling can guide the fix.
        const redactionCheck = tryValidatePayloadRedaction(validation.event);
        if (!redactionCheck.ok) {
            failed.push({
                index,
                eventId: validation.event.id,
                code: 'validation_error',
                message: 'Event_Contract redaction policy violation',
                issues: redactionCheck.issues,
            });
            continue;
        }

        try {
            // The per-entry rate-limit was already charged above; route to
            // the validated-publish helper to avoid double-charging the same
            // attempt. This keeps batch and single-publish accounting
            // identical: one token per publish attempt regardless of mode.
            const ack = await publishValidatedEvent(validation.event);
            messageIds.push(ack.messageId);
        } catch (err) {
            const message = err instanceof Error ? err.message : String(err);
            failed.push({
                index,
                eventId: validation.event.id,
                code: 'publish_error',
                message,
            });
        }
    }

    return { messageIds, failed };
}

/**
 * Lightweight predicate used by the OutboxPublisher to decide whether to
 * route a publish to SNS or directly to the outbox. Exposed so other
 * Producer wrappers can re-use the same readiness check.
 */
export function isPublisherReady(): boolean {
    return Boolean(process.env[TOPIC_ARN_ENV] && process.env[TOPIC_ARN_ENV]?.trim().length);
}
