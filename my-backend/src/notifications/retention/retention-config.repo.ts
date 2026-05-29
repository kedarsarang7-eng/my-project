// ============================================================================
// Retention Configuration — Persistent Repository
// ============================================================================
// Persists a single `RetentionConfigRecord` row in the existing DynamoDB
// table used by `my-backend/`. We deliberately reuse the main table rather
// than provisioning a new one — the retention config is a singleton with
// strong-consistency requirements and no fan-out; a dedicated table would
// be overkill.
//
// Key shape:
//   PK = `NOTIFICATIONS#SYSTEM`
//   SK = `RETENTION_CONFIG`
//
// The `version` attribute is used as an optimistic-lock counter so two
// admins cannot lose each other's writes during concurrent updates.
//
// Validates: REQ 13.4, REQ 6.8, REQ 19.2 (reuse existing infra).
// ============================================================================

import {
    PutCommand,
    GetCommand,
    type DynamoDBDocumentClient,
} from '@aws-sdk/lib-dynamodb';
import {
    docClient as defaultDocClient,
    TABLE_NAME,
} from '../../config/dynamodb.config';
import { logger } from '../../utils/logger';
import type { RetentionConfigRecord } from './types';

// ---- Key helpers ---------------------------------------------------------

export const RETENTION_CONFIG_PK = 'NOTIFICATIONS#SYSTEM';
export const RETENTION_CONFIG_SK = 'RETENTION_CONFIG';

interface RetentionConfigItem extends RetentionConfigRecord {
    readonly PK: string;
    readonly SK: string;
    readonly entityType: 'NOTIFICATION_RETENTION_CONFIG';
}

function toItem(record: RetentionConfigRecord): RetentionConfigItem {
    return {
        PK: RETENTION_CONFIG_PK,
        SK: RETENTION_CONFIG_SK,
        entityType: 'NOTIFICATION_RETENTION_CONFIG',
        archive_period_days: record.archive_period_days,
        updated_at: record.updated_at,
        updated_by: record.updated_by,
        version: record.version,
    };
}

function fromItem(item: Record<string, unknown>): RetentionConfigRecord {
    return {
        archive_period_days: Number(item.archive_period_days),
        updated_at: String(item.updated_at),
        updated_by:
            item.updated_by === null || item.updated_by === undefined
                ? null
                : String(item.updated_by),
        version: Number(item.version ?? 0),
    };
}

// ---- Public API ----------------------------------------------------------

export interface RetentionConfigRepoOptions {
    /** Override the doc client — used by unit tests with a stub client. */
    readonly docClient?: DynamoDBDocumentClient;
    /** Override the table name — used by unit tests. */
    readonly tableName?: string;
}

/**
 * Read the persisted retention-config record. Returns `null` when no row
 * has been written yet — callers (typically the service) layer this with a
 * default value derived from environment configuration.
 */
export async function readRetentionConfig(
    options: RetentionConfigRepoOptions = {},
): Promise<RetentionConfigRecord | null> {
    const client = options.docClient ?? defaultDocClient;
    const result = await client.send(
        new GetCommand({
            TableName: options.tableName ?? TABLE_NAME,
            Key: { PK: RETENTION_CONFIG_PK, SK: RETENTION_CONFIG_SK },
        }),
    );
    if (!result.Item) return null;
    return fromItem(result.Item as Record<string, unknown>);
}

/**
 * Persist a new retention-config record. Uses an optimistic version check
 * to reject conflicting concurrent writes:
 *
 *   - When `expectedVersion` is `0`, the write requires that no row exists
 *     yet (first-time write, condition: `attribute_not_exists(PK)`).
 *   - Otherwise the write requires that the stored `version` equals
 *     `expectedVersion` (condition: `version = :expected`).
 *
 * The condition is evaluated server-side by DynamoDB, so two simultaneous
 * admins cannot accidentally overwrite each other.
 */
export async function writeRetentionConfig(
    record: RetentionConfigRecord,
    expectedVersion: number,
    options: RetentionConfigRepoOptions = {},
): Promise<RetentionConfigRecord> {
    const client = options.docClient ?? defaultDocClient;
    const tableName = options.tableName ?? TABLE_NAME;
    const item = toItem(record);

    if (expectedVersion === 0) {
        await client.send(
            new PutCommand({
                TableName: tableName,
                Item: item,
                ConditionExpression: 'attribute_not_exists(PK)',
            }),
        );
    } else {
        await client.send(
            new PutCommand({
                TableName: tableName,
                Item: item,
                ConditionExpression: '#v = :expected',
                ExpressionAttributeNames: { '#v': 'version' },
                ExpressionAttributeValues: { ':expected': expectedVersion },
            }),
        );
    }

    logger.info('Retention config persisted', {
        archive_period_days: record.archive_period_days,
        updated_by: record.updated_by,
        version: record.version,
    });

    return record;
}
