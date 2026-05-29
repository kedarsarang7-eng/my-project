// ============================================================================
// UNS Event_Bus — Consumer
// ============================================================================
// Long-poll SQS, deserialize Event_Contract messages, hand them to a domain
// handler, and apply the bus-level retry / DLQ semantics.
//
// Consumer model:
//   - SQS provides the per-consumer cursor (REQ 3.4): a message stays
//     "in-flight" until the consumer deletes it or the visibility timeout
//     expires. There is no separate offset commit — DELETE is the commit.
//   - On handler failure, we extend the message visibility timeout using
//     exponential backoff (REQ 3.9) so SQS redelivers the same message
//     after the back-off window. The retry counter lives in the message
//     attribute `retry_count`.
//   - When the retry budget (default 5, REQ 3.9) is exhausted, we write a
//     `failed` AuditLog entry and STOP deleting the message — letting the
//     SQS-managed DLQ redrive policy move the message to the DLQ with the
//     original payload, message attributes, and timestamps preserved
//     (REQ 3.10). The actual DLQ move is owned by AWS, not by this module.
//
// This module deliberately exposes a `processSqsBatch` function that fits
// the AWS Lambda SQS event source signature (`SQSEvent` → batchItemFailures)
// AND a `pollOnce` helper for non-Lambda runtimes (offline / dev / load
// tests). Either way the same retry+DLQ semantics apply.
//
// Validates: REQ 3.4, 3.5, 3.9, 3.10, 9.3, 9.8.
// ============================================================================

import {
    SQSClient,
    ReceiveMessageCommand,
    DeleteMessageCommand,
    ChangeMessageVisibilityCommand,
    type Message as SqsMessage,
} from '@aws-sdk/client-sqs';
import { config } from '../../config/environment';
import { logger } from '../../utils/logger';
import { EventBusConfigError, RetryBudgetExhaustedError } from './errors';
import { validateEventContract } from './schema-validator';
import type { EventContract } from './types';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const QUEUE_URL_ENV = 'UNS_SQS_QUEUE_URL';
const DLQ_URL_ENV = 'UNS_DLQ_URL';

/** Default retry budget (REQ 3.9). */
export const DEFAULT_MAX_RETRIES = 5;

/**
 * Exponential backoff schedule. Returns SQS visibility-timeout extension in
 * SECONDS for a given attempt number (1-indexed). Capped at 900 s — SQS
 * `ChangeMessageVisibility` allows up to 12 hours but capping at 15 minutes
 * keeps redelivery responsive enough for real-time-ish notifications while
 * still growing fast enough to absorb downstream outages.
 *
 *   attempt 1 →  2 s
 *   attempt 2 →  4 s
 *   attempt 3 →  8 s
 *   attempt 4 → 16 s
 *   attempt 5 → 32 s (terminal — message lands in DLQ next time)
 */
export function backoffSeconds(attempt: number): number {
    const base = 2;
    const seconds = Math.pow(base, Math.max(1, attempt));
    return Math.min(900, seconds);
}

// ---------------------------------------------------------------------------
// SQS client (lazy init)
// ---------------------------------------------------------------------------

let sqsClient: SQSClient | null = null;

function getSqsClient(): SQSClient {
    if (!sqsClient) {
        sqsClient = new SQSClient({ region: config.aws.region });
    }
    return sqsClient;
}

/** Test-only hook — replaces the SQS client for unit tests. */
export function _setSqsClientForTests(client: SQSClient | null): void {
    sqsClient = client;
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Domain handler signature. Implementations should be idempotent — SQS is
 * at-least-once, and this consumer redelivers on failure.
 *
 * The handler MAY throw to signal a transient failure that should be retried.
 * Returning normally signals success and the message is deleted from SQS
 * (which is the SQS commit operation — REQ 3.4).
 */
export type EventHandler = (event: EventContract, ctx: HandlerContext) => Promise<void>;

export interface HandlerContext {
    /** SQS message id, useful for distributed tracing. */
    messageId: string;
    /** SNS message id (when the queue is fed by SNS). */
    snsMessageId?: string;
    /** Current attempt number (1-indexed). */
    attempt: number;
    /** Maximum allowed attempts before DLQ. */
    maxRetries: number;
    /** SQS receipt handle (consumers MUST NOT manipulate this directly). */
    receiptHandle: string;
}

export interface ConsumerOptions {
    /** SQS queue URL. Falls back to `process.env.UNS_SQS_QUEUE_URL`. */
    queueUrl?: string;
    /** Max retry attempts before routing to DLQ. Default 5 (REQ 3.9). */
    maxRetries?: number;
    /** SQS long-poll wait time in seconds (1-20). Default 20. */
    waitTimeSeconds?: number;
    /** Max messages to receive per poll (1-10). Default 10. */
    maxMessages?: number;
    /** Initial visibility timeout in seconds when receiving. Default 60. */
    visibilityTimeoutSeconds?: number;
    /**
     * Optional audit-log integration hook. Called when a message exhausts
     * its retry budget so the integrating module can write a `failed`
     * AuditLog entry (REQ 12.5, 14.1). Best-effort — failures here are
     * logged but do not block DLQ progression.
     */
    onAuditFailed?: (event: EventContract | null, info: {
        messageId: string;
        snsMessageId?: string;
        attempt: number;
        maxRetries: number;
        lastError: string;
    }) => Promise<void> | void;
}

export interface Consumer {
    readonly queueUrl: string;
    readonly maxRetries: number;
    /** Process a SINGLE long-poll cycle. Used by non-Lambda runtimes. */
    pollOnce(): Promise<void>;
    /**
     * Process a SQS Lambda event batch. Returns the AWS-required
     * `batchItemFailures` shape so SQS knows which messages to redeliver
     * (partial-batch failure protocol).
     */
    processSqsBatch(messages: SqsMessage[]): Promise<{
        batchItemFailures: { itemIdentifier: string }[];
    }>;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface ParsedEnvelope {
    /** Original SNS message id, when present (SQS-via-SNS subscriptions). */
    snsMessageId?: string;
    /** Body string that should be JSON.parsed into an Event_Contract object. */
    body: string;
}

/**
 * SQS messages fed by an SNS subscription have an outer JSON envelope:
 *   { "Type":"Notification","MessageId":"...","Message":"<inner JSON>", ... }
 * Direct sqs:SendMessage calls have the raw body directly. This helper
 * normalizes both shapes so downstream parsing is uniform.
 */
function unwrapBody(rawBody: string): ParsedEnvelope {
    try {
        const parsed = JSON.parse(rawBody);
        if (parsed && typeof parsed === 'object' && parsed.Type === 'Notification' && typeof parsed.Message === 'string') {
            return {
                snsMessageId: typeof parsed.MessageId === 'string' ? parsed.MessageId : undefined,
                body: parsed.Message,
            };
        }
    } catch {
        // Not JSON — could be a malformed payload. Pass through and let
        // schema validation surface the failure with a structured error.
    }
    return { body: rawBody };
}

/**
 * Read the current `retry_count` from SQS message attributes. SQS message
 * attributes are limited to String / Number / Binary so the count is stored
 * as a string and parsed here. Defaults to 0 when the attribute is absent
 * (first attempt).
 */
function readRetryCount(message: SqsMessage): number {
    const raw = message.MessageAttributes?.retry_count?.StringValue;
    if (!raw) return 0;
    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

async function deleteMessage(queueUrl: string, receiptHandle: string): Promise<void> {
    await getSqsClient().send(new DeleteMessageCommand({
        QueueUrl: queueUrl,
        ReceiptHandle: receiptHandle,
    }));
}

async function extendVisibility(
    queueUrl: string,
    receiptHandle: string,
    seconds: number,
): Promise<void> {
    try {
        await getSqsClient().send(new ChangeMessageVisibilityCommand({
            QueueUrl: queueUrl,
            ReceiptHandle: receiptHandle,
            VisibilityTimeout: seconds,
        }));
    } catch (err) {
        // Best-effort — if the visibility extension fails, SQS will still
        // redeliver after the existing timeout expires; we just lose the
        // backoff smoothing for this single message.
        logger.warn('[EventBus] Failed to extend message visibility', {
            queueUrl,
            seconds,
            error: err instanceof Error ? err.message : String(err),
        });
    }
}

// ---------------------------------------------------------------------------
// Per-message processing core (shared between pollOnce and processSqsBatch)
// ---------------------------------------------------------------------------

interface ProcessOutcome {
    /** True when the handler succeeded (caller should DELETE the message). */
    success: boolean;
    /** True when retry budget is exhausted and the message should go to DLQ. */
    exhausted: boolean;
    /** Last error encountered, when `success === false`. */
    lastError?: string;
    /** Parsed event when validation succeeded (used by audit hook). */
    parsedEvent?: EventContract;
    /** Current attempt number (1-indexed). */
    attempt: number;
}

async function processOneMessage(
    message: SqsMessage,
    handler: EventHandler,
    queueUrl: string,
    maxRetries: number,
): Promise<ProcessOutcome> {
    const messageId = message.MessageId ?? '<no-id>';
    const receiptHandle = message.ReceiptHandle ?? '';
    const previousAttempts = readRetryCount(message);
    const attempt = previousAttempts + 1;

    if (!message.Body) {
        // Empty body — treat as poison and let DLQ absorb it.
        return {
            success: false,
            exhausted: true,
            lastError: 'Empty SQS message body',
            attempt,
        };
    }

    const envelope = unwrapBody(message.Body);
    let parsedEvent: EventContract;
    try {
        const json = JSON.parse(envelope.body);
        parsedEvent = validateEventContract(json);
    } catch (err) {
        // Schema-invalid OR malformed JSON. These are not transient — retrying
        // will not fix a bad payload. Skip retries entirely and let DLQ catch
        // them so an operator can investigate.
        const lastError = err instanceof Error ? err.message : String(err);
        logger.error('[EventBus] Consumer received invalid payload — routing to DLQ', {
            messageId,
            snsMessageId: envelope.snsMessageId,
            error: lastError,
        });
        return {
            success: false,
            exhausted: true,
            lastError,
            attempt,
        };
    }

    const ctx: HandlerContext = {
        messageId,
        snsMessageId: envelope.snsMessageId,
        attempt,
        maxRetries,
        receiptHandle,
    };

    try {
        await handler(parsedEvent, ctx);
        return {
            success: true,
            exhausted: false,
            attempt,
            parsedEvent,
        };
    } catch (err) {
        const lastError = err instanceof Error ? err.message : String(err);
        const exhausted = attempt >= maxRetries;

        if (!exhausted && receiptHandle) {
            // Apply exponential backoff via visibility-timeout extension so
            // SQS redelivers later (REQ 3.9).
            await extendVisibility(queueUrl, receiptHandle, backoffSeconds(attempt));
        }

        logger.warn('[EventBus] Handler failed', {
            messageId,
            snsMessageId: envelope.snsMessageId,
            eventId: parsedEvent.id,
            eventName: parsedEvent.event_name,
            attempt,
            maxRetries,
            exhausted,
            error: lastError,
        });

        return {
            success: false,
            exhausted,
            lastError,
            attempt,
            parsedEvent,
        };
    }
}

// ---------------------------------------------------------------------------
// Public factory
// ---------------------------------------------------------------------------

/**
 * Create a consumer bound to a single SQS queue + handler pair.
 * The factory does not start any background loop — invocation is driven by
 * the caller (Lambda event source for production, `pollOnce()` for offline /
 * dev / load tests).
 */
export function createConsumer(args: ConsumerOptions & { handler: EventHandler }): Consumer {
    const queueUrl = args.queueUrl ?? process.env[QUEUE_URL_ENV];
    if (!queueUrl || queueUrl.trim().length === 0) {
        throw new EventBusConfigError(
            `Missing required SQS queue URL. Pass \`queueUrl\` or set ${QUEUE_URL_ENV}.`,
        );
    }

    const maxRetries = args.maxRetries ?? DEFAULT_MAX_RETRIES;
    const waitTimeSeconds = Math.min(20, Math.max(0, args.waitTimeSeconds ?? 20));
    const maxMessages = Math.min(10, Math.max(1, args.maxMessages ?? 10));
    const visibilityTimeoutSeconds = Math.max(1, args.visibilityTimeoutSeconds ?? 60);

    async function emitAuditFailed(
        outcome: ProcessOutcome,
        message: SqsMessage,
    ): Promise<void> {
        if (!args.onAuditFailed) return;
        try {
            await args.onAuditFailed(outcome.parsedEvent ?? null, {
                messageId: message.MessageId ?? '<no-id>',
                snsMessageId: unwrapBody(message.Body ?? '').snsMessageId,
                attempt: outcome.attempt,
                maxRetries,
                lastError: outcome.lastError ?? 'unknown',
            });
        } catch (err) {
            logger.warn('[EventBus] AuditLog hook failed (non-fatal)', {
                error: err instanceof Error ? err.message : String(err),
            });
        }
    }

    return {
        queueUrl,
        maxRetries,

        async pollOnce(): Promise<void> {
            const response = await getSqsClient().send(new ReceiveMessageCommand({
                QueueUrl: queueUrl,
                MaxNumberOfMessages: maxMessages,
                WaitTimeSeconds: waitTimeSeconds,
                VisibilityTimeout: visibilityTimeoutSeconds,
                MessageAttributeNames: ['All'],
                AttributeNames: ['All'],
            }));

            const messages = response.Messages ?? [];
            if (messages.length === 0) return;

            for (const message of messages) {
                const outcome = await processOneMessage(message, args.handler, queueUrl, maxRetries);
                if (outcome.success) {
                    if (message.ReceiptHandle) {
                        await deleteMessage(queueUrl, message.ReceiptHandle);
                    }
                    continue;
                }

                if (outcome.exhausted) {
                    // Retry budget hit. Write the audit entry and STOP touching
                    // the message — the SQS native DLQ redrive policy moves it
                    // to UNS_DLQ_URL on the next visibility-timeout expiry,
                    // preserving original payload, attributes, and timestamps
                    // (REQ 3.10). We DO NOT delete here; deletion would mask
                    // the failure from the redrive policy.
                    await emitAuditFailed(outcome, message);

                    // Surface the exhaustion as a structured error in logs
                    // for operator visibility.
                    const err = new RetryBudgetExhaustedError(
                        `Retry budget exhausted for message ${message.MessageId} after ${outcome.attempt} attempts`,
                        outcome.attempt,
                        outcome.lastError ?? 'unknown',
                    );
                    logger.error('[EventBus] Retry budget exhausted — message will land in DLQ via SQS redrive', err.toJSON());
                    continue;
                }

                // Transient failure — leave the message in flight; SQS will
                // redeliver after the backoff visibility-timeout extension
                // applied in processOneMessage().
            }
        },

        async processSqsBatch(messages) {
            const batchItemFailures: { itemIdentifier: string }[] = [];
            for (const message of messages) {
                const outcome = await processOneMessage(message, args.handler, queueUrl, maxRetries);

                if (outcome.success) continue;

                if (outcome.exhausted) {
                    await emitAuditFailed(outcome, message);
                    // Reporting as a failure in the partial-batch response
                    // tells SQS to keep the message and let the redrive
                    // policy move it to the DLQ (REQ 3.10).
                    if (message.MessageId) {
                        batchItemFailures.push({ itemIdentifier: message.MessageId });
                    }
                    continue;
                }

                // Transient failure — report partial-batch failure so SQS
                // redelivers after the backoff window.
                if (message.MessageId) {
                    batchItemFailures.push({ itemIdentifier: message.MessageId });
                }
            }
            return { batchItemFailures };
        },
    };
}

/**
 * Convenience accessor for the configured DLQ URL. Operators / replay tools
 * use this to reach the DLQ; the consumer itself never writes to it because
 * SQS's native redrive policy handles the move.
 */
export function getDlqUrl(): string | undefined {
    const raw = process.env[DLQ_URL_ENV];
    return raw && raw.trim().length > 0 ? raw : undefined;
}
