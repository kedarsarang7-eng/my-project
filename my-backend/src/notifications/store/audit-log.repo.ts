// ============================================================================
// Notification_Store — AuditLog Repository (append-only)
// ============================================================================
// REQ 6.3 / REQ 12.6: AuditLog records are append-only. The Notification_System
// MUST NOT permit update or delete operations on existing AuditLog records.
//
// PUBLIC SURFACE:
//   - append(record)  — add a single AuditLog entry
//   - appendBatch(records) — add up to 25 entries in one call
//   - query(filter)   — read entries (by notification_id, by recipient, etc.)
//
// We deliberately do NOT export `update` or `delete`. Two stub functions
// (`update` and `delete`) are exposed solely so a misuse can be caught with a
// clear, structured error rather than missing methods. They throw
// `AuditLogImmutableError` immediately and write nothing to DynamoDB.
// ============================================================================

import { configureAwsClient } from '../../config/aws.config';
import {
    DynamoDBDocumentClient,
    PutCommand,
    QueryCommand,
    BatchWriteCommand,
    type QueryCommandInput,
} from '@aws-sdk/lib-dynamodb';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { logger } from '../../utils/logger';
import {
    AuditLogImmutableError,
    DuplicateAuditEntryError,
} from './errors';
import {
    AUDIT_LOG_TABLE,
    AUDIT_PK_FIELD,
    AUDIT_SORT_KEY_FIELD,
    auditSortKey,
} from './keys';
import type { AuditLogRecord } from './types';

// ---- Local doc client (separate from the other repos) -------------------

let cachedDocClient: DynamoDBDocumentClient | null = null;

function defaultDocClient(): DynamoDBDocumentClient {
    if (!cachedDocClient) {
        const ddb = new DynamoDBClient(configureAwsClient({
            region: process.env.AWS_REGION ?? 'us-east-1',
        }));
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

export function __setAuditLogDocClientForTesting(
    client: DynamoDBDocumentClient | null,
): void {
    cachedDocClient = client;
}

// ---- Public types --------------------------------------------------------

export interface AuditLogRepoOptions {
    readonly docClient?: DynamoDBDocumentClient;
    readonly tableName?: string;
}

interface AuditLogItem extends AuditLogRecord {
    /** Composite sort key on the AuditLog table (see `keys.ts`). */
    audit_sort_key: string;
}

function toItem(record: AuditLogRecord): AuditLogItem {
    return {
        ...record,
        audit_sort_key: auditSortKey(record.timestamp, record.audit_id),
    };
}

function fromItem(item: AuditLogItem): AuditLogRecord {
    const { audit_sort_key: _ask, ...rest } = item;
    return rest;
}

// ---- Public API: append --------------------------------------------------

/**
 * Append a single AuditLog entry. The write uses an
 * `attribute_not_exists` condition on the primary key so duplicate
 * `audit_id`s surface as `DuplicateAuditEntryError` (defensive — a
 * conforming caller generates a fresh UUID per entry).
 */
export async function append(
    record: AuditLogRecord,
    options: AuditLogRepoOptions = {},
): Promise<AuditLogRecord> {
    if (!record.audit_id || record.audit_id.trim() === '') {
        throw new Error('audit_id is required');
    }
    if (!record.notification_id || record.notification_id.trim() === '') {
        throw new Error('notification_id is required');
    }
    if (!record.timestamp || record.timestamp.trim() === '') {
        throw new Error('timestamp is required');
    }

    const item = toItem(record);
    const client = options.docClient ?? defaultDocClient();

    try {
        await client.send(
            new PutCommand({
                TableName: options.tableName ?? AUDIT_LOG_TABLE,
                Item: item,
                ConditionExpression:
                    'attribute_not_exists(notification_id) AND ' +
                    'attribute_not_exists(audit_sort_key)',
            }),
        );
    } catch (err: unknown) {
        if (
            (err as { name?: string }).name === 'ConditionalCheckFailedException'
        ) {
            throw new DuplicateAuditEntryError(record.audit_id);
        }
        throw err;
    }

    logger.debug('AuditLog appended', {
        audit_id: record.audit_id,
        notification_id: record.notification_id,
        lifecycle_state: record.lifecycle_state,
        outcome: record.outcome,
    });

    return record;
}

/**
 * Append multiple AuditLog entries in one call. DynamoDB's BatchWriteItem
 * caps at 25 items per call; we enforce that ceiling explicitly so the
 * caller knows up-front rather than receiving a confusing AWS error.
 *
 * BatchWriteItem does NOT support a per-item ConditionExpression, so this
 * helper is best-effort with respect to the duplicate-id check. Callers
 * that need strict duplicate detection should use `append` per-item.
 */
export async function appendBatch(
    records: readonly AuditLogRecord[],
    options: AuditLogRepoOptions = {},
): Promise<readonly AuditLogRecord[]> {
    if (records.length === 0) return records;
    if (records.length > 25) {
        throw new Error(
            'appendBatch accepts at most 25 records (DynamoDB BatchWrite limit).' +
                ` Received ${records.length}.`,
        );
    }

    const tableName = options.tableName ?? AUDIT_LOG_TABLE;
    const client = options.docClient ?? defaultDocClient();

    await client.send(
        new BatchWriteCommand({
            RequestItems: {
                [tableName]: records.map((r) => ({
                    PutRequest: { Item: toItem(r) },
                })),
            },
        }),
    );

    return records;
}

// ---- Public API: query ---------------------------------------------------

export interface QueryAuditLogInput {
    /** All entries for a single notification_id (most common access pattern). */
    readonly notification_id: string;
    /** Optional inclusive lower bound on `timestamp`. */
    readonly since?: string;
    /** Optional inclusive upper bound on `timestamp`. */
    readonly until?: string;
    readonly limit?: number;
    /** Default: ascending (chronological order for trail viewing). */
    readonly scanForward?: boolean;
    /** DynamoDB pagination key from a prior page. */
    readonly exclusiveStartKey?: Record<string, unknown> | null;
}

export interface QueryAuditLogResult {
    readonly items: readonly AuditLogRecord[];
    readonly lastEvaluatedKey: Record<string, unknown> | null;
}

/**
 * Read AuditLog entries for a given notification, optionally bounded by
 * a time window. The trail is a chronological view — pass
 * `scanForward = false` for newest-first.
 */
export async function query(
    input: QueryAuditLogInput,
    options: AuditLogRepoOptions = {},
): Promise<QueryAuditLogResult> {
    if (!input.notification_id || input.notification_id.trim() === '') {
        throw new Error('notification_id is required for AuditLog query');
    }

    const client = options.docClient ?? defaultDocClient();

    let keyExpr = '#nid = :nid';
    const exprValues: Record<string, unknown> = {
        ':nid': input.notification_id,
    };
    const exprNames: Record<string, string> = { '#nid': AUDIT_PK_FIELD };

    if (input.since && input.until) {
        keyExpr += ' AND #ask BETWEEN :since AND :until';
        exprValues[':since'] = `${input.since}#`;
        exprValues[':until'] = `${input.until}#~`; // `~` sorts after any UUID
        exprNames['#ask'] = AUDIT_SORT_KEY_FIELD;
    } else if (input.since) {
        keyExpr += ' AND #ask >= :since';
        exprValues[':since'] = `${input.since}#`;
        exprNames['#ask'] = AUDIT_SORT_KEY_FIELD;
    } else if (input.until) {
        keyExpr += ' AND #ask <= :until';
        // `~` (0x7E) sorts AFTER every printable ASCII character including
        // every UUID-v4 hex digit, so `<timestamp>#~` is a stable upper bound
        // that includes every audit_id at exactly `until`.
        exprValues[':until'] = `${input.until}#~`;
        exprNames['#ask'] = AUDIT_SORT_KEY_FIELD;
    }

    const params: QueryCommandInput = {
        TableName: options.tableName ?? AUDIT_LOG_TABLE,
        KeyConditionExpression: keyExpr,
        ExpressionAttributeValues: exprValues,
        ExpressionAttributeNames: exprNames,
        Limit: input.limit ?? 100,
        ScanIndexForward: input.scanForward ?? true,
        ExclusiveStartKey: input.exclusiveStartKey ?? undefined,
    };

    const result = await client.send(new QueryCommand(params));
    const items = ((result.Items ?? []) as AuditLogItem[]).map(fromItem);

    return {
        items,
        lastEvaluatedKey: result.LastEvaluatedKey
            ? (result.LastEvaluatedKey as Record<string, unknown>)
            : null,
    };
}

// ---- Disallowed operations (REQ 6.3, REQ 12.6) --------------------------
//
// AuditLog is append-only. We expose `update` and `delete` as explicit
// failure points so any caller that mistakenly imports them sees a clear
// runtime error and a structured response code, rather than a missing-
// method `TypeError`. They write nothing to DynamoDB.

/**
 * @deprecated AuditLog is append-only. Always throws.
 * Validates: REQ 6.3, REQ 12.6.
 */
export function update(auditId: string): never {
    throw new AuditLogImmutableError('update', auditId);
}

/**
 * @deprecated AuditLog is append-only. Always throws.
 * Validates: REQ 6.3, REQ 12.6.
 */
// eslint-disable-next-line @typescript-eslint/no-shadow
function _delete(auditId: string): never {
    throw new AuditLogImmutableError('delete', auditId);
}
export { _delete as delete };
