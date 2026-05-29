// ============================================================================
// UNS Event_Bus — Local Outbox Shim
// ============================================================================
// `OutboxPublisher` wraps the canonical SNS publisher with a local outbox
// fallback so events are never lost when the Event_Bus is transiently
// unreachable (REQ 9.7, 9.8).
//
// Storage:
//   - Default backend is DynamoDB-backed (`UNS_OUTBOX_TABLE`). We use the
//     existing `@aws-sdk/lib-dynamodb` document client so the writes match
//     the conventions used elsewhere in `my-backend/`.
//   - A small in-memory backend is provided for tests / dev environments
//     where the real table doesn't exist.
//
// Replay ordering:
//   - On `flushOutbox()` (manual or periodic), entries are read in
//     `created_at` ascending order and re-published one at a time.
//     Successfully republished entries are deleted from the outbox.
//   - If an entry still cannot be published (Bus still unavailable), the
//     `retry_count` is bumped and the entry is left in the outbox.
//
// Note: this module DOES NOT create the DynamoDB table. The table schema is
// documented below — operators provision the table via
// `serverless.yml` / IaC. The model lives close to the publisher so the
// schema is co-located with the consumer that uses it.
//
// Validates: REQ 9.7, 9.8.
// ============================================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
    DynamoDBDocumentClient,
    PutCommand,
    DeleteCommand,
    ScanCommand,
} from '@aws-sdk/lib-dynamodb';
import { config } from '../../config/environment';
import { logger } from '../../utils/logger';
import {
    EventBusUnavailableError,
} from './errors';
import {
    publishEvent as defaultPublishEvent,
} from './publisher';
import { validateEventContract } from './schema-validator';
import type {
    EventContract,
    OutboxEntry,
    PublishAck,
} from './types';

// ---------------------------------------------------------------------------
// Outbox table model (DynamoDB)
// ---------------------------------------------------------------------------
// Logical primary key: `id` (UUID v4) — same as the event id, so a buffered
// event survives a deduplicated retry. Reusing the event id (rather than
// minting a fresh outbox id) means a transient publish-failure replay
// produces the same SNS message body byte-for-byte, so the consumer's
// dedup_key lookup picks it up as the same event and the per-recipient
// dedupe in `service/dedup.ts` keeps the system idempotent end-to-end.
// Sort key for the recovery scan: `created_at` (ISO 8601 string sorts
// lexicographically in chronological order). For Phase 4 we use a simple
// table-wide scan ordered client-side; this is acceptable because the
// outbox is expected to be small (only populated during outages). A future
// optimization is a GSI on (created_at) when the outage volume warrants it.
//
//   PK: id            (string, UUID v4)
//   SK: created_at    (string, ISO 8601)
//   payload           (string, JSON-serialized Event_Contract)
//   buffered_at       (string, ISO 8601)
//   last_error        (string, optional)
//   retry_count       (number, optional, defaults to 0)
//
// The shape matches `OutboxEntry` in `types.ts`.

// ---------------------------------------------------------------------------
// Storage backend abstraction
// ---------------------------------------------------------------------------

export interface OutboxStorage {
    /** Persist an entry. Implementations MUST be idempotent on `id`. */
    put(entry: OutboxEntry): Promise<void>;
    /** Return all entries sorted by `created_at` ascending. */
    listAscending(): Promise<OutboxEntry[]>;
    /** Remove an entry by id. */
    remove(id: string): Promise<void>;
    /** Approximate count for observability. */
    size(): Promise<number>;
}

// --- DynamoDB-backed outbox -------------------------------------------------

const TABLE_ENV = 'UNS_OUTBOX_TABLE';

let docClient: DynamoDBDocumentClient | null = null;

function getDocClient(): DynamoDBDocumentClient {
    if (!docClient) {
        const base = new DynamoDBClient({ region: config.aws.region });
        docClient = DynamoDBDocumentClient.from(base);
    }
    return docClient;
}

/** Test-only hook — replaces the document client for unit tests. */
export function _setDocClientForTests(client: DynamoDBDocumentClient | null): void {
    docClient = client;
}

export class DynamoOutboxStorage implements OutboxStorage {
    constructor(private readonly tableName: string) {}

    async put(entry: OutboxEntry): Promise<void> {
        await getDocClient().send(new PutCommand({
            TableName: this.tableName,
            Item: { ...entry },
        }));
    }

    async listAscending(): Promise<OutboxEntry[]> {
        // Scan the whole table, sort client-side. Acceptable because the
        // outbox is bounded by the duration of an Event_Bus outage; in
        // steady-state the table is empty.
        const collected: OutboxEntry[] = [];
        let exclusiveStartKey: Record<string, unknown> | undefined;
        do {
            const response = await getDocClient().send(new ScanCommand({
                TableName: this.tableName,
                ExclusiveStartKey: exclusiveStartKey,
            }));
            for (const item of response.Items ?? []) {
                if (
                    typeof item.id === 'string' &&
                    typeof item.payload === 'string' &&
                    typeof item.created_at === 'string' &&
                    typeof item.buffered_at === 'string'
                ) {
                    collected.push({
                        id: item.id,
                        payload: item.payload,
                        created_at: item.created_at,
                        buffered_at: item.buffered_at,
                        last_error: typeof item.last_error === 'string' ? item.last_error : undefined,
                        retry_count: typeof item.retry_count === 'number' ? item.retry_count : 0,
                    });
                }
            }
            exclusiveStartKey = response.LastEvaluatedKey as Record<string, unknown> | undefined;
        } while (exclusiveStartKey);

        collected.sort((a, b) => a.created_at.localeCompare(b.created_at));
        return collected;
    }

    async remove(id: string): Promise<void> {
        await getDocClient().send(new DeleteCommand({
            TableName: this.tableName,
            Key: { id },
        }));
    }

    async size(): Promise<number> {
        // Conservative — `listAscending` already pages, so reuse it.
        const all = await this.listAscending();
        return all.length;
    }
}

// --- In-memory outbox (tests / dev) ----------------------------------------

export class InMemoryOutboxStorage implements OutboxStorage {
    private readonly entries = new Map<string, OutboxEntry>();

    async put(entry: OutboxEntry): Promise<void> {
        this.entries.set(entry.id, { ...entry });
    }

    async listAscending(): Promise<OutboxEntry[]> {
        return [...this.entries.values()].sort((a, b) =>
            a.created_at.localeCompare(b.created_at),
        );
    }

    async remove(id: string): Promise<void> {
        this.entries.delete(id);
    }

    async size(): Promise<number> {
        return this.entries.size;
    }
}

// ---------------------------------------------------------------------------
// OutboxPublisher
// ---------------------------------------------------------------------------

export interface OutboxPublisherOptions {
    /** Storage backend. Defaults to DynamoDB when `UNS_OUTBOX_TABLE` is set. */
    storage?: OutboxStorage;
    /**
     * The underlying SNS publish function. Defaults to the canonical
     * `publishEvent`. Tests override this to inject failures deterministically.
     */
    publish?: (event: EventContract) => Promise<PublishAck>;
}

function chooseStorage(custom?: OutboxStorage): OutboxStorage {
    if (custom) return custom;
    const tableName = process.env[TABLE_ENV];
    if (tableName && tableName.trim().length > 0) {
        return new DynamoOutboxStorage(tableName);
    }
    // Falling back to in-memory means the outbox loses entries on Lambda
    // cold-start. We log a warning so operators notice the misconfiguration.
    logger.warn(
        `[EventBus] Outbox falling back to in-memory storage — set ${TABLE_ENV} to enable durable outbox`,
    );
    return new InMemoryOutboxStorage();
}

export class OutboxPublisher {
    private readonly storage: OutboxStorage;
    private readonly publish: (event: EventContract) => Promise<PublishAck>;

    constructor(options: OutboxPublisherOptions = {}) {
        this.storage = chooseStorage(options.storage);
        this.publish = options.publish ?? defaultPublishEvent;
    }

    /**
     * Publish an event with outbox fallback.
     *
     * On schema-invalid input → throws (callers must fix the bug; the outbox
     * is for transport outages, not for invalid payloads).
     * On transport failure → buffers in the outbox, returns
     * `{ buffered: true }` so the caller knows the event was accepted but is
     * pending replay.
     * On success → returns `{ buffered: false, ack }`.
     */
    public async publishWithFallback(rawEvent: unknown): Promise<
        | { buffered: false; ack: PublishAck }
        | { buffered: true; entry: OutboxEntry }
    > {
        // Validate FIRST so we never buffer a payload the bus would reject —
        // schema errors are not transient and would just keep failing.
        const event = validateEventContract(rawEvent);

        try {
            const ack = await this.publish(event);
            return { buffered: false, ack };
        } catch (err) {
            if (err instanceof EventBusUnavailableError) {
                const entry = await this.bufferEvent(event, err.message);
                logger.warn('[EventBus] Event buffered to outbox', {
                    eventId: event.id,
                    eventName: event.event_name,
                    error: err.message,
                });
                return { buffered: true, entry };
            }
            // Permanent / unexpected error — surface to caller.
            throw err;
        }
    }

    private async bufferEvent(event: EventContract, reason: string): Promise<OutboxEntry> {
        const entry: OutboxEntry = {
            id: event.id,
            payload: JSON.stringify(event),
            created_at: event.created_at,
            buffered_at: new Date().toISOString(),
            last_error: reason,
            retry_count: 0,
        };
        await this.storage.put(entry);
        return entry;
    }

    /**
     * Replay every buffered event in `created_at` ascending order. Returns
     * the per-event outcome so operators / metrics can track recovery
     * progress.
     *
     * Replay is sequential to preserve ordering. If an entry still cannot be
     * published, replay STOPS for that entry (later entries are still
     * attempted) and the entry remains in the outbox with an incremented
     * `retry_count`.
     */
    public async flushOutbox(): Promise<{
        attempted: number;
        published: number;
        stillBuffered: number;
        failures: Array<{ id: string; error: string }>;
    }> {
        const entries = await this.storage.listAscending();
        let published = 0;
        const failures: Array<{ id: string; error: string }> = [];

        for (const entry of entries) {
            let event: EventContract;
            try {
                const parsed = JSON.parse(entry.payload);
                event = validateEventContract(parsed);
            } catch (err) {
                // Stored payload no longer validates — likely a schema rollout
                // mismatch. Drop the entry and log so an operator can chase
                // the upgrade gap.
                logger.error('[EventBus] Outbox entry failed re-validation, dropping', {
                    id: entry.id,
                    error: err instanceof Error ? err.message : String(err),
                });
                await this.storage.remove(entry.id);
                continue;
            }

            try {
                await this.publish(event);
                await this.storage.remove(entry.id);
                published += 1;
            } catch (err) {
                const message = err instanceof Error ? err.message : String(err);
                failures.push({ id: entry.id, error: message });

                // Re-write the entry with bumped retry count + new last_error.
                await this.storage.put({
                    ...entry,
                    last_error: message,
                    retry_count: (entry.retry_count ?? 0) + 1,
                });

                // For non-transport failures, leave the entry as-is and move on
                // so a single bad event doesn't stall the queue. Transport
                // failures usually affect every entry; we still keep going so
                // recovery is per-entry.
            }
        }

        const stillBuffered = await this.storage.size();
        logger.info('[EventBus] Outbox flush complete', {
            attempted: entries.length,
            published,
            stillBuffered,
            failures: failures.length,
        });

        return {
            attempted: entries.length,
            published,
            stillBuffered,
            failures,
        };
    }

    /** Read-only accessor for diagnostics / metrics. */
    public async pendingCount(): Promise<number> {
        return this.storage.size();
    }
}
