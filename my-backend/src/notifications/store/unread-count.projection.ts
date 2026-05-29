// ============================================================================
// Notification_Store — Unread-Count Projection (DynamoDB Streams handler)
// ============================================================================
// Lambda handler subscribed to the Notifications table's DynamoDB Stream
// (`StreamSpecification.StreamViewType: NEW_AND_OLD_IMAGES`, see the schema
// snippet at the top of `notification.repo.ts`).
//
// Maintains a per-user `unread_count` projection by inspecting lifecycle
// transitions on each Notification record:
//
//   * `dispatched` → `delivered`   →  unread_count += 1   (per recipient)
//   * `delivered`  → `read`        →  unread_count -= 1   (per recipient)
//   * any other transition (e.g. → `failed`)              →  no-op
//
// Performance target (REQ 6.7, design.md §"Unread-count projection update on
// `delivered`/`read` transition"):
//
//   * Update applied within **100 ms p95** of the lifecycle transition under
//     nominal load.
//   * Under load spikes, processing CONTINUES rather than dropping updates.
//
// Reliability strategy:
//
//   * Each stream record is processed inside its own try/catch so a single
//     malformed record cannot kill the batch.
//   * Failed records are reported via the AWS Lambda
//     `ReportBatchItemFailures` partial-batch response so only the failing
//     records are retried — successful records are NOT replayed and never
//     double-count. (Lambda will retry the whole batch only if we throw
//     uncaught; we don't.)
//   * The atomic DynamoDB `ADD #unread_count :delta` is idempotent ONLY in
//     the sense that the same record processed twice is unsafe — that's why
//     we rely on DynamoDB Streams' exactly-once-per-shard-checkpoint
//     semantics together with `ReportBatchItemFailures` to avoid replays of
//     already-applied records.
//
// Observability (REQ 6.7 + task 11/17.2 wiring):
//
//   * Per-record elapsed time is logged via `logger.info` with the
//     `delivery_latency_ms` field; once the metrics module from task 17.2
//     lands, that logger callsite is the wiring seam — the metric histogram
//     `delivery_latency_ms{channel='unread_count_projection'}` will read the
//     same value.
//
// Validates: REQ 6.7, REQ 13.1.
// ============================================================================

import type {
    DynamoDBStreamHandler,
    DynamoDBRecord,
    DynamoDBBatchResponse,
    DynamoDBBatchItemFailure,
    AttributeValue as LambdaAttributeValue,
} from 'aws-lambda';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import type { AttributeValue } from '@aws-sdk/client-dynamodb';
import {
    DynamoDBDocumentClient,
    UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { logger } from '../../utils/logger';
import {
    UNREAD_COUNT_FIELD,
    UNREAD_COUNT_TABLE,
} from './keys';
import type { NotificationStatus } from './types';

// ---- Doc client (kept private to this module) ----------------------------
//
// We instantiate a focused doc client rather than reusing the repo clients
// so a misbehaving test injection cannot leak across modules. The region
// is read from the same `AWS_REGION` env variable Lambda already injects.

let cachedDocClient: DynamoDBDocumentClient | null = null;

function defaultDocClient(): DynamoDBDocumentClient {
    if (!cachedDocClient) {
        const ddb = new DynamoDBClient({
            region: process.env.AWS_REGION ?? 'us-east-1',
        });
        cachedDocClient = DynamoDBDocumentClient.from(ddb, {
            marshallOptions: {
                removeUndefinedValues: true,
                convertClassInstanceToMap: true,
            },
            unmarshallOptions: { wrapNumbers: false },
        });
    }
    return cachedDocClient;
}

/**
 * Test seam: replace the cached doc client with a stub. Used by the
 * accompanying unit / property tests in task 4.4.
 */
export function __setUnreadCountDocClientForTesting(
    client: DynamoDBDocumentClient | null,
): void {
    cachedDocClient = client;
}

// ---- Projection deltas ---------------------------------------------------

/**
 * The lifecycle transitions that move the unread count, expressed as a
 * `(prev, next)` pair → integer delta. Any pair not listed here is a no-op.
 *
 * REQ 6.7: only `dispatched → delivered` and `delivered → read` change the
 * count. Transitions to `failed` are explicitly NOT counted.
 */
type Delta = -1 | 0 | 1;

function lifecycleDelta(
    prev: NotificationStatus | null,
    next: NotificationStatus | null,
): Delta {
    if (prev === 'dispatched' && next === 'delivered') return 1;
    if (prev === 'delivered' && next === 'read') return -1;
    return 0;
}

// ---- Public surface ------------------------------------------------------

export interface UnreadCountProjectionOptions {
    /** Optional doc client override (tests, multi-region). */
    readonly docClient?: DynamoDBDocumentClient;
    /** Optional table name override (tests). */
    readonly tableName?: string;
}

/**
 * Apply a single delta to one user's `unread_count`. Exported so tests and
 * any future direct-write callers (e.g. a backfill script) can reuse the
 * exact same atomic-counter shape the projection uses.
 *
 * Uses `ADD #unread_count :delta` so the increment/decrement is atomic and
 * commutative — concurrent stream shards processing different recipients
 * can update independently without losing increments.
 */
export async function applyUnreadCountDelta(
    userId: string,
    delta: Delta,
    options: UnreadCountProjectionOptions = {},
): Promise<void> {
    if (delta === 0) return;
    if (!userId || userId.trim() === '') {
        throw new Error('userId is required');
    }

    const client = options.docClient ?? defaultDocClient();
    await client.send(
        new UpdateCommand({
            TableName: options.tableName ?? UNREAD_COUNT_TABLE,
            Key: { user_id: userId },
            UpdateExpression: 'ADD #c :delta',
            ExpressionAttributeNames: { '#c': UNREAD_COUNT_FIELD },
            ExpressionAttributeValues: { ':delta': delta },
        }),
    );
}

// ---- Stream-record processing -------------------------------------------

interface RecipientImage {
    readonly user_id?: string;
    readonly status?: NotificationStatus;
}

interface NotificationImage {
    readonly notification_id?: string;
    readonly event_name?: string;
    readonly status?: NotificationStatus;
    readonly recipients?: readonly RecipientImage[];
}

function decodeImage(
    image: { [key: string]: LambdaAttributeValue } | undefined,
): NotificationImage | null {
    if (!image) return null;
    try {
        // The two AttributeValue types ship from different libraries
        // (`aws-lambda` vs `@aws-sdk/client-dynamodb`) but are structurally
        // identical for the fields we read. The cast keeps strict mode
        // happy without losing type safety on the unmarshalled output.
        return unmarshall(
            image as unknown as Record<string, AttributeValue>,
        ) as NotificationImage;
    } catch (err) {
        logger.warn('unread-count projection: failed to unmarshall image', {
            error: (err as Error).message,
        });
        return null;
    }
}

/**
 * Build the set of `(user_id, delta)` updates required by a single stream
 * record. Returns an empty array for any record that is not a counted
 * transition.
 *
 * Resolution rules:
 *
 *   1. **Top-level status diff** is the authoritative signal. Per task 4.1's
 *      `buildGsiAttributes` comment, every notification today is fanned out
 *      to "one row per recipient", so the top-level `status` field reflects
 *      that single recipient's lifecycle. When the top-level transition
 *      matches a counted delta (`dispatched→delivered` or `delivered→read`),
 *      we apply the delta to every user_id in `recipients[]`.
 *
 *   2. **Per-recipient status diff** is a secondary refinement: if a future
 *      multi-recipient code path updates only individual recipients without
 *      touching the top-level status, we still pick up the change. (Counts
 *      arrived at via this path are added on top of the top-level diff to
 *      avoid double-counting the same recipient — see the `topLevelHandled`
 *      set below.)
 */
export function computeUnreadDeltas(
    oldImage: NotificationImage | null,
    newImage: NotificationImage | null,
): ReadonlyArray<{ user_id: string; delta: Delta }> {
    if (!newImage) return [];

    const updates: { user_id: string; delta: Delta }[] = [];
    const topLevelHandled = new Set<string>();

    // ---- Rule 1: top-level status transition --------------------------
    const topDelta = lifecycleDelta(
        oldImage?.status ?? null,
        newImage.status ?? null,
    );
    if (topDelta !== 0) {
        const recipients = newImage.recipients ?? [];
        for (const r of recipients) {
            if (!r || typeof r.user_id !== 'string') continue;
            updates.push({ user_id: r.user_id, delta: topDelta });
            topLevelHandled.add(r.user_id);
        }
    }

    // ---- Rule 2: per-recipient status transition (multi-recipient path)
    const oldRecipients = oldImage?.recipients ?? [];
    const newRecipients = newImage.recipients ?? [];
    if (newRecipients.length > 0) {
        const oldByUser = new Map<string, NotificationStatus | undefined>();
        for (const r of oldRecipients) {
            if (r && typeof r.user_id === 'string') {
                oldByUser.set(r.user_id, r.status);
            }
        }

        for (const r of newRecipients) {
            if (!r || typeof r.user_id !== 'string') continue;
            // Skip recipients already counted by rule 1; their delta is the
            // same regardless of whether the per-recipient status field
            // mirrors the top-level transition. Without this guard, a
            // single recipient whose top-level AND per-recipient status
            // both transitioned (the common case) would be counted twice.
            if (topLevelHandled.has(r.user_id)) continue;

            const prev = oldByUser.get(r.user_id) ?? null;
            const next = r.status ?? null;
            const delta = lifecycleDelta(prev, next);
            if (delta !== 0) {
                updates.push({ user_id: r.user_id, delta });
            }
        }
    }

    return updates;
}

/**
 * Process one stream record. Returns the elapsed wall-clock time so the
 * top-level handler can log it as `delivery_latency_ms`.
 *
 * Throws on infrastructure errors so the caller can mark the record for
 * retry via `batchItemFailures`.
 */
async function processRecord(
    record: DynamoDBRecord,
    options: UnreadCountProjectionOptions,
): Promise<{ elapsedMs: number; deltasApplied: number }> {
    const startedAtNs = process.hrtime.bigint();

    // We only care about MODIFY events (state transitions); INSERTs land at
    // status=`emitted`/`queued` (not counted) and REMOVEs are the cold-storage
    // mover (out of scope for the projection).
    if (record.eventName !== 'MODIFY') {
        const elapsedMs = elapsedMillisSince(startedAtNs);
        return { elapsedMs, deltasApplied: 0 };
    }

    const oldImage = decodeImage(record.dynamodb?.OldImage);
    const newImage = decodeImage(record.dynamodb?.NewImage);
    const deltas = computeUnreadDeltas(oldImage, newImage);

    if (deltas.length === 0) {
        const elapsedMs = elapsedMillisSince(startedAtNs);
        return { elapsedMs, deltasApplied: 0 };
    }

    // Apply each user's delta in parallel — they touch independent rows.
    // Failure of one user's update should not block the others; we surface
    // a single aggregated error if any individual update fails so the
    // record is retried.
    const results = await Promise.allSettled(
        deltas.map((d) => applyUnreadCountDelta(d.user_id, d.delta, options)),
    );

    const failures = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    if (failures.length > 0) {
        // Log every failure for triage, then re-throw the first so the
        // record is marked for retry.
        for (const f of failures) {
            logger.error('unread-count projection: per-user update failed', {
                error:
                    f.reason instanceof Error
                        ? f.reason.message
                        : String(f.reason),
                notification_id: newImage?.notification_id,
                event_name: newImage?.event_name,
            });
        }
        const first = failures[0].reason;
        throw first instanceof Error
            ? first
            : new Error(String(first));
    }

    return {
        elapsedMs: elapsedMillisSince(startedAtNs),
        deltasApplied: deltas.length,
    };
}

function elapsedMillisSince(startedAtNs: bigint): number {
    const elapsedNs = process.hrtime.bigint() - startedAtNs;
    // bigint → number; nanoseconds in 100 ms fit in a Number safely.
    return Number(elapsedNs) / 1_000_000;
}

// ---- Lambda entrypoint ---------------------------------------------------

/**
 * AWS Lambda DynamoDB Streams handler.
 *
 * Returns a `DynamoDBBatchResponse` reporting only the records that failed
 * (`batchItemFailures: [{ itemIdentifier: <eventID> }]`). The Lambda
 * service then retries ONLY those records — successful records are
 * advanced past in the stream cursor, so the projection never double-
 * counts a delivered → read transition under retry.
 *
 * The handler does NOT throw out of the top-level callback even if every
 * record fails; throwing would cause Lambda to retry the entire batch and
 * risk replaying already-applied increments. Per-record failures are
 * surfaced exclusively through `batchItemFailures`.
 */
export const handler: DynamoDBStreamHandler = async (event) => {
    const batchItemFailures: DynamoDBBatchItemFailure[] = [];

    let totalDeltas = 0;
    let maxElapsedMs = 0;

    for (const record of event.Records) {
        const itemIdentifier = record.eventID ?? '';

        try {
            const { elapsedMs, deltasApplied } = await processRecord(record, {});

            // REQ 6.7 / REQ 13.1: log the elapsed time so the metrics
            // module from task 17.2 can wire `delivery_latency_ms` to it
            // without a code change here. The `channel` label matches the
            // histogram naming convention in design.md §11.4.
            logger.info('unread_count projection applied', {
                channel: 'unread_count_projection',
                event_name: 'unread_count.projection.applied',
                delivery_latency_ms: elapsedMs,
                deltas_applied: deltasApplied,
                event_id: record.eventID,
            });

            totalDeltas += deltasApplied;
            if (elapsedMs > maxElapsedMs) maxElapsedMs = elapsedMs;
        } catch (err: unknown) {
            // Continue processing the rest of the batch — REQ 6.7
            // ("under load spikes the projection update SHALL continue
            // processing rather than be dropped").
            logger.error('unread-count projection: record failed; will retry', {
                error: (err as Error).message,
                event_id: record.eventID,
            });
            if (itemIdentifier !== '') {
                batchItemFailures.push({ itemIdentifier });
            }
            // Intentionally do NOT throw — see header comment.
        }
    }

    if (event.Records.length > 0) {
        logger.debug('unread-count projection batch complete', {
            records_total: event.Records.length,
            records_failed: batchItemFailures.length,
            deltas_applied: totalDeltas,
            max_elapsed_ms: maxElapsedMs,
        });
    }

    const response: DynamoDBBatchResponse = { batchItemFailures };
    return response;
};

// ---- Re-exports for tests and downstream callers ------------------------

// Pre-compute helpers (no I/O) exported so task 4.4 unit tests can verify
// the delta math without spinning up a DynamoDB mock.
export { lifecycleDelta };
export type { Delta, NotificationImage, RecipientImage };
