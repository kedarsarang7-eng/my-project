// ============================================================================
// Local_Queue — SQS/SNS equivalent (SQLite-backed FIFO queue)
// ============================================================================
// Requirement 4.6: the Local_Backend provides the local equivalent of SQS and
// SNS by enqueuing messages into a SQLite-backed queue and making each enqueued
// message available for retrieval in the ORDER it was enqueued (FIFO).
//
// Design notes:
//   - Backed by a single SQLite table with an AUTOINCREMENT primary key. SQLite
//     assigns strictly increasing keys in insertion order, so ordering rows by
//     that key (ASC) reproduces enqueue order exactly — this is the FIFO
//     guarantee exercised by Property 18 (task 8.4).
//   - Named queues/topics are supported (SQS queues / SNS topics). FIFO order is
//     preserved per topic; messages from different topics never interleave on a
//     topic-scoped dequeue.
//   - ALL SQL uses parameterized statements only — no string interpolation of
//     values into SQL (Req 17.9 / 17.15).
//   - better-sqlite3 is synchronous; each multi-step mutation runs inside a
//     transaction so it commits as a unit. If the transaction body throws,
//     better-sqlite3 rolls it back, so a failed enqueue leaves no half-written
//     message and a failed dequeue neither loses nor duplicates a message. Any
//     such failure is reported to the service layer as a typed `QueueError`
//     (Req 4.7, task 8.3). An empty-topic dequeue returns null — that is an
//     expected outcome, not a failure.
// ============================================================================

import fs from 'fs';
import path from 'path';
import Database from 'better-sqlite3';
import { resolveQueueDbPath } from '../config/paths';
import { logger } from '../utils/logger';
import { QueueError, describeError } from './storage-errors';

/** Default topic used when an enqueue/dequeue does not name one. */
export const DEFAULT_TOPIC = 'default';

/** A message as stored and returned by the Local_Queue. */
export interface QueueMessage {
    /** Monotonic enqueue sequence number, assigned on enqueue. Higher = later. */
    id: number;
    /** Queue/topic name (SQS queue / SNS topic). */
    topic: string;
    /** Opaque message payload. Callers own serialization. */
    body: string;
    /** ISO-8601 timestamp recorded at enqueue time. */
    enqueuedAt: string;
}

/** Options accepted when enqueuing a message. */
export interface EnqueueOptions {
    /** Target topic; defaults to {@link DEFAULT_TOPIC}. */
    topic?: string;
}

/** Shape of a raw database row (snake_case columns). */
interface QueueRow {
    id: number;
    topic: string;
    body: string;
    enqueued_at: string;
}

/**
 * SQLite-backed FIFO message queue — the offline equivalent of SQS/SNS.
 *
 * Construct with no arguments to use the on-disk queue database under the
 * DukanX data directory, or pass an explicit path / pre-opened database
 * (used by tests, including the Property 18 round-trip in task 8.4).
 */
export class LocalQueue {
    private readonly db: Database.Database;
    private readonly ownsDb: boolean;

    constructor(dbOrPath?: string | Database.Database) {
        if (dbOrPath && typeof dbOrPath !== 'string') {
            // Caller-supplied database (e.g. an in-memory test instance).
            this.db = dbOrPath;
            this.ownsDb = false;
        } else {
            const dbPath = dbOrPath ?? resolveQueueDbPath();
            // Ensure the parent directory exists before opening the database.
            fs.mkdirSync(path.dirname(dbPath), { recursive: true });
            this.db = new Database(dbPath);
            this.ownsDb = true;
        }

        // WAL mode matches the Local_Store durability/concurrency posture and
        // keeps readers from blocking the single writer.
        this.db.pragma('journal_mode = WAL');
        this.db.pragma('synchronous = NORMAL');

        this.initSchema();
    }

    /** Create the queue table and supporting index if they do not yet exist. */
    private initSchema(): void {
        this.db.exec(
            `CREATE TABLE IF NOT EXISTS queue_messages (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                topic       TEXT NOT NULL,
                body        TEXT NOT NULL,
                enqueued_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_queue_messages_topic_id
                ON queue_messages (topic, id);`,
        );
    }

    /**
     * Enqueue a message onto a topic. The returned message carries the assigned
     * monotonic {@link QueueMessage.id}, which fixes its FIFO position.
     *
     * The insert runs inside a SQLite transaction: if it fails, the transaction
     * rolls back so NO partially enqueued message remains, and the failure is
     * reported to the service layer as a {@link QueueError} (Req 4.7).
     */
    enqueue(body: string, options: EnqueueOptions = {}): QueueMessage {
        const topic = options.topic ?? DEFAULT_TOPIC;
        const enqueuedAt = new Date().toISOString();

        const insert = this.db.prepare(
            `INSERT INTO queue_messages (topic, body, enqueued_at)
             VALUES (@topic, @body, @enqueuedAt)`,
        );

        // The transaction wrapper is the rollback seam: better-sqlite3 rolls the
        // transaction back automatically if the body throws, so a failed insert
        // can never leave a half-written row behind.
        const runInsert = this.db.transaction((): QueueMessage => {
            const info = insert.run({ topic, body, enqueuedAt });
            return {
                id: Number(info.lastInsertRowid),
                topic,
                body,
                enqueuedAt,
            };
        });

        try {
            return runInsert();
        } catch (err) {
            throw this.report('enqueue', topic, err);
        }
    }

    /**
     * Remove and return the oldest message for a topic (FIFO). Returns `null`
     * when the topic is empty (an expected outcome, not a failure). The
     * select-then-delete pair runs in a single transaction so a message is never
     * returned without being removed and is never removed without being
     * returned; if the transaction fails it rolls back (the message stays in the
     * queue) and the failure is reported as a {@link QueueError} (Req 4.7).
     */
    dequeue(topic: string = DEFAULT_TOPIC): QueueMessage | null {
        const selectOldest = this.db.prepare(
            `SELECT id, topic, body, enqueued_at
             FROM queue_messages
             WHERE topic = @topic
             ORDER BY id ASC
             LIMIT 1`,
        );
        const deleteById = this.db.prepare(
            `DELETE FROM queue_messages WHERE id = @id`,
        );

        // Select + delete in ONE transaction. If the delete throws, the prior
        // select is rolled back with it, so the message is neither lost nor
        // duplicated — it remains available for a subsequent dequeue.
        const runDequeue = this.db.transaction((): QueueMessage | null => {
            const row = selectOldest.get({ topic }) as QueueRow | undefined;
            if (!row) return null;
            deleteById.run({ id: row.id });
            return this.toMessage(row);
        });

        try {
            return runDequeue();
        } catch (err) {
            throw this.report('dequeue', topic, err);
        }
    }

    /**
     * Return the oldest message for a topic without removing it, or `null` when
     * the topic is empty.
     */
    peek(topic: string = DEFAULT_TOPIC): QueueMessage | null {
        const row = this.db
            .prepare(
                `SELECT id, topic, body, enqueued_at
                 FROM queue_messages
                 WHERE topic = @topic
                 ORDER BY id ASC
                 LIMIT 1`,
            )
            .get({ topic }) as QueueRow | undefined;
        return row ? this.toMessage(row) : null;
    }

    /** Number of pending messages on a topic. */
    size(topic: string = DEFAULT_TOPIC): number {
        const row = this.db
            .prepare(
                `SELECT COUNT(*) AS count
                 FROM queue_messages
                 WHERE topic = @topic`,
            )
            .get({ topic }) as { count: number };
        return row.count;
    }

    /** Close the underlying database if this instance opened it. */
    close(): void {
        if (this.ownsDb) {
            this.db.close();
        }
    }

    /** Map a raw snake_case row into the public camelCase message shape. */
    private toMessage(row: QueueRow): QueueMessage {
        return {
            id: row.id,
            topic: row.topic,
            body: row.body,
            enqueuedAt: row.enqueued_at,
        };
    }

    /**
     * Translate a raw failure into the service-layer {@link QueueError} contract
     * (Req 4.7). Logs through the secret-scrubbing logger, then returns the typed
     * error for the caller to throw. By the time this runs the surrounding
     * transaction has already rolled back, so no partial message remains.
     */
    private report(operation: 'enqueue' | 'dequeue', topic: string, cause: unknown): QueueError {
        logger.error('Local_Queue operation failed', {
            operation,
            topic,
            cause: describeError(cause),
        });
        return new QueueError(operation, topic, cause);
    }
}
