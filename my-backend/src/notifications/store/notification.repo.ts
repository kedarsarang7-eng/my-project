// ============================================================================
// Notification_Store — Notification Repository
// ============================================================================
// CRUD + cursor pagination for `Notification` records (REQ 6.1).
// Enforces the lifecycle ordering invariant
//   created_at <= dispatched_at <= delivered_at <= read_at
// on EVERY transition (REQ 6.7a).
//
// Validates: REQ 6.1, 6.4, 6.5, 6.6, 6.7a, 6.8, 6.9, 19.2.
// ----------------------------------------------------------------------------
// SERVERLESS SCHEMA SNIPPET (do NOT auto-merge — copy into serverless.yml or a
// separate `notifications.resources.yml` after operator review). The shape
// below matches the keys constructed in `keys.ts` and used by this repo,
// `audit-log.repo.ts`, and `user-preference.repo.ts`. Values in `${...}` are
// serverless variables already used by `my-backend/serverless.yml`.
// ----------------------------------------------------------------------------
//
// resources:
//   Resources:
//
//     # ---- Notification table (REQ 6.1, 6.4-6.6, 6.7a, 6.9) ----
//     NotificationsTable:
//       Type: AWS::DynamoDB::Table
//       Properties:
//         TableName: ${self:service}-${sls:stage}-notifications
//         BillingMode: PAY_PER_REQUEST
//         AttributeDefinitions:
//           - AttributeName: notification_id
//             AttributeType: S
//           - AttributeName: user_status_pk
//             AttributeType: S
//           - AttributeName: user_status_sk
//             AttributeType: S
//           - AttributeName: user_category_pk
//             AttributeType: S
//           - AttributeName: user_category_sk
//             AttributeType: S
//           - AttributeName: dedup_key
//             AttributeType: S
//           - AttributeName: created_at_id_sk
//             AttributeType: S
//         KeySchema:
//           - AttributeName: notification_id
//             KeyType: HASH
//         GlobalSecondaryIndexes:
//           - IndexName: by-user-status
//             KeySchema:
//               - AttributeName: user_status_pk
//                 KeyType: HASH
//               - AttributeName: user_status_sk
//                 KeyType: RANGE
//             Projection:
//               ProjectionType: ALL
//           - IndexName: by-user-category
//             KeySchema:
//               - AttributeName: user_category_pk
//                 KeyType: HASH
//               - AttributeName: user_category_sk
//                 KeyType: RANGE
//             Projection:
//               ProjectionType: ALL
//           - IndexName: by-dedup-key
//             KeySchema:
//               - AttributeName: dedup_key
//                 KeyType: HASH
//               - AttributeName: created_at_id_sk
//                 KeyType: RANGE
//             Projection:
//               ProjectionType: ALL
//         StreamSpecification:
//           StreamViewType: NEW_AND_OLD_IMAGES   # for unread-count projection (task 4.2)
//         PointInTimeRecoverySpecification:
//           PointInTimeRecoveryEnabled: true
//
//     # ---- UserPreference table (REQ 6.2) ----
//     UserPreferencesTable:
//       Type: AWS::DynamoDB::Table
//       Properties:
//         TableName: ${self:service}-${sls:stage}-user-preferences
//         BillingMode: PAY_PER_REQUEST
//         AttributeDefinitions:
//           - AttributeName: user_id
//             AttributeType: S
//         KeySchema:
//           - AttributeName: user_id
//             KeyType: HASH
//         PointInTimeRecoverySpecification:
//           PointInTimeRecoveryEnabled: true
//
//     # ---- AuditLog table (REQ 6.3, append-only) ----
//     AuditLogTable:
//       Type: AWS::DynamoDB::Table
//       Properties:
//         TableName: ${self:service}-${sls:stage}-audit-log
//         BillingMode: PAY_PER_REQUEST
//         AttributeDefinitions:
//           - AttributeName: notification_id
//             AttributeType: S
//           - AttributeName: audit_sort_key
//             AttributeType: S
//         KeySchema:
//           - AttributeName: notification_id
//             KeyType: HASH
//           - AttributeName: audit_sort_key
//             KeyType: RANGE
//         PointInTimeRecoverySpecification:
//           PointInTimeRecoveryEnabled: true
//
//     # ---- UnreadCount projection table (REQ 6.7, task 4.2) ----
//     UnreadCountsTable:
//       Type: AWS::DynamoDB::Table
//       Properties:
//         TableName: ${self:service}-${sls:stage}-unread-counts
//         BillingMode: PAY_PER_REQUEST
//         AttributeDefinitions:
//           - AttributeName: user_id
//             AttributeType: S
//         KeySchema:
//           - AttributeName: user_id
//             KeyType: HASH
//         PointInTimeRecoverySpecification:
//           PointInTimeRecoveryEnabled: true
//
//   # ---- Stream subscription for unread-count projection (task 4.2) ----
//   #
//   # functions:
//   #   notificationsUnreadCountProjection:
//   #     handler: dist/notifications/store/unread-count.projection.handler
//   #     events:
//   #       - stream:
//   #           type: dynamodb
//   #           arn: !GetAtt NotificationsTable.StreamArn
//   #           startingPosition: LATEST
//   #           batchSize: 25
//   #           maximumRetryAttempts: 3
//   #           bisectBatchOnFunctionError: true
//   #           functionResponseType: ReportBatchItemFailures
//   #           filterPatterns:
//   #             - eventName: [MODIFY]
//
// ----------------------------------------------------------------------------

import { configureAwsClient } from '../../config/aws.config';
import {
    DynamoDBDocumentClient,
    GetCommand,
    PutCommand,
    QueryCommand,
    UpdateCommand,
    DeleteCommand,
    type QueryCommandInput,
} from '@aws-sdk/lib-dynamodb';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { logger } from '../../utils/logger';
import {
    LifecycleOrderingViolationError,
    OptimisticLockError,
} from './errors';
import {
    GSI_BY_DEDUP_KEY,
    GSI_BY_USER_CATEGORY,
    GSI_BY_USER_STATUS,
    NOTIFICATION_TABLE,
    dedupGsiKey,
    userCategoryGsiKey,
    userStatusGsiKey,
} from './keys';
import {
    cursorFromNotification,
    decodeCursor,
    encodeCursor,
    type PaginationCursor,
} from './cursor';
import type {
    LifecycleTimestamps,
    NotificationCategory,
    NotificationRecord,
    NotificationStatus,
    PaginatedNotifications,
} from './types';

// ---- Shared DynamoDB client ----------------------------------------------
// We instantiate a focused client here rather than reusing the bizmate
// `docClient` because the Notification_Store is a separate logical store
// with different tables. The region is read from the same `AWS_REGION`
// environment variable AWS Lambda already injects. Tests inject a custom
// client via `__setNotificationDocClientForTesting` (kept private to the
// store package).

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

/**
 * Test seam: replace the cached doc client with a stub. Repos accept an
 * explicit client per call; this is a convenience for callers that don't
 * pass one.
 */
export function __setNotificationDocClientForTesting(
    client: DynamoDBDocumentClient | null,
): void {
    cachedDocClient = client;
}

// ---- Lifecycle ordering invariant ----------------------------------------
//
// REQ 6.7a — every Notification record at all times satisfies
//     created_at <= dispatched_at <= delivered_at <= read_at
// with `null` permitted for any unset trailing timestamp. Out-of-order
// transitions are rejected.
//
// `assertLifecycleOrdering` is intentionally exposed so tasks 4.3 (property
// test) and 6.1 (`lifecycle.ts`) can reuse the same predicate.

/**
 * Returns true iff the supplied lifecycle timestamps satisfy the
 * non-decreasing ordering invariant, treating `null` trailing values as
 * "unset" (and therefore not violating order).
 *
 * The check is strict on prefixes: as soon as a `null` appears, every
 * subsequent timestamp must also be `null`. A delivered_at without a
 * dispatched_at, for instance, is rejected.
 */
export function lifecycleTimestampsAreOrdered(
    ts: LifecycleTimestamps,
): boolean {
    const seq: readonly (string | null)[] = [
        ts.created_at,
        ts.dispatched_at,
        ts.delivered_at,
        ts.read_at,
    ];

    // created_at is mandatory.
    if (typeof seq[0] !== 'string' || seq[0].length === 0) return false;

    let sawNull = false;
    let previous = seq[0] as string;
    for (let i = 1; i < seq.length; i++) {
        const current = seq[i];
        if (current === null) {
            sawNull = true;
            continue;
        }
        // Once a null appears, any later non-null breaks the prefix rule.
        if (sawNull) return false;
        if (current < previous) return false;
        previous = current;
    }
    return true;
}

/**
 * Throws `LifecycleOrderingViolationError` if the ordering invariant is
 * broken; returns silently otherwise. Always called BEFORE writing the
 * proposed transition to DynamoDB.
 */
export function assertLifecycleOrdering(
    notificationId: string,
    attemptedStatus: NotificationStatus,
    current: LifecycleTimestamps,
    proposed: LifecycleTimestamps,
): void {
    if (!lifecycleTimestampsAreOrdered(proposed)) {
        throw new LifecycleOrderingViolationError(
            notificationId,
            attemptedStatus,
            current,
            proposed,
        );
    }
}

// ---- Internal helpers ----------------------------------------------------

interface NotificationItem extends NotificationRecord {
    /** Per-recipient denormalised fields used by the GSIs (sparse). */
    user_status_pk?: string;
    user_status_sk?: string;
    user_category_pk?: string;
    user_category_sk?: string;
    /** Mirrors `dedup_key` to feed the `by-dedup-key` GSI. */
    created_at_id_sk?: string;
}

function timestamps(record: NotificationRecord): LifecycleTimestamps {
    return {
        created_at: record.created_at,
        dispatched_at: record.dispatched_at,
        delivered_at: record.delivered_at,
        read_at: record.read_at,
    };
}

/**
 * Build the GSI denormalisation attributes for a single-recipient row.
 *
 * We attach the GSI keys to the row only when the record has exactly ONE
 * primary recipient — this is the common case for all events in the
 * registry today and keeps the GSI shape simple. Multi-recipient rows
 * (broadcasts) live on the base table only; per-user history is built
 * by the dispatch layer using one row per recipient (task 6.1).
 */
function buildGsiAttributes(
    record: NotificationRecord,
): Partial<NotificationItem> {
    const result: Partial<NotificationItem> = {};

    // by-dedup-key — always populated (every notification has a dedup_key)
    const dedup = dedupGsiKey(
        record.dedup_key,
        record.created_at,
        record.notification_id,
    );
    result.created_at_id_sk = dedup.created_at_id_sk;

    // by-user-status / by-user-category — populate when there is exactly one
    // primary recipient so a single GSI write supports the per-user
    // unread/history queries (REQ 6.4-6.5). Multi-recipient fan-out is the
    // dispatcher's responsibility (task 6.1) and writes one row per recipient.
    // For a multi-recipient row the GSI keys are intentionally LEFT UNSET —
    // sparse-index semantics mean DynamoDB simply skips the row in those
    // GSIs, avoiding ambiguous "which user does this row belong to" reads.
    if (record.recipients.length === 1) {
        const r = record.recipients[0];
        const us = userStatusGsiKey(
            r.user_id,
            record.status,
            record.created_at,
            record.notification_id,
        );
        const uc = userCategoryGsiKey(
            r.user_id,
            record.category,
            record.created_at,
            record.notification_id,
        );
        result.user_status_pk = us.user_status_pk;
        result.user_status_sk = us.user_status_sk;
        result.user_category_pk = uc.user_category_pk;
        result.user_category_sk = uc.user_category_sk;
    }

    return result;
}

function stripGsiAttributes(item: NotificationItem): NotificationRecord {
    const {
        user_status_pk: _us_pk,
        user_status_sk: _us_sk,
        user_category_pk: _uc_pk,
        user_category_sk: _uc_sk,
        created_at_id_sk: _cias,
        ...rest
    } = item;
    return rest;
}

// ---- Public repository API -----------------------------------------------

export interface NotificationRepoOptions {
    /** Optional doc client override (tests, multi-region). */
    readonly docClient?: DynamoDBDocumentClient;
    /** Optional table name override (tests). */
    readonly tableName?: string;
}

/**
 * Insert a new Notification record. The lifecycle ordering invariant is
 * checked before the write; mismatches throw
 * `LifecycleOrderingViolationError`.
 *
 * Callers are responsible for supplying a unique `notification_id`; we
 * use a `attribute_not_exists` condition so duplicate inserts surface as
 * a structured DynamoDB conditional-check error rather than silently
 * overwriting.
 */
export async function createNotification(
    record: NotificationRecord,
    options: NotificationRepoOptions = {},
): Promise<NotificationRecord> {
    assertLifecycleOrdering(
        record.notification_id,
        record.status,
        timestamps(record),
        timestamps(record),
    );

    const item: NotificationItem = {
        ...record,
        ...buildGsiAttributes(record),
    };

    const client = options.docClient ?? defaultDocClient();
    await client.send(
        new PutCommand({
            TableName: options.tableName ?? NOTIFICATION_TABLE,
            Item: item,
            ConditionExpression: 'attribute_not_exists(notification_id)',
        }),
    );

    logger.debug('Notification created', {
        notification_id: record.notification_id,
        event_name: record.event_name,
        status: record.status,
    });

    return record;
}

/**
 * Fetch a Notification by id. Returns `null` if the record does not exist.
 */
export async function getNotification(
    notificationId: string,
    options: NotificationRepoOptions = {},
): Promise<NotificationRecord | null> {
    const client = options.docClient ?? defaultDocClient();
    const result = await client.send(
        new GetCommand({
            TableName: options.tableName ?? NOTIFICATION_TABLE,
            Key: { notification_id: notificationId },
        }),
    );
    if (!result.Item) return null;
    return stripGsiAttributes(result.Item as NotificationItem);
}

/**
 * Update a Notification's lifecycle status and timestamps. Enforces the
 * lifecycle ordering invariant against BOTH the existing on-disk record
 * AND the proposed update; either failing throws
 * `LifecycleOrderingViolationError` and the DynamoDB write is not
 * attempted.
 *
 * Returns the updated record.
 *
 * Validates: REQ 6.7a (rejection on violation).
 */
export interface UpdateLifecycleInput {
    readonly notificationId: string;
    readonly status: NotificationStatus;
    readonly dispatched_at?: string | null;
    readonly delivered_at?: string | null;
    readonly read_at?: string | null;
}

export async function updateLifecycle(
    input: UpdateLifecycleInput,
    options: NotificationRepoOptions = {},
): Promise<NotificationRecord> {
    const existing = await getNotification(input.notificationId, options);
    if (!existing) {
        throw new LifecycleOrderingViolationError(
            input.notificationId,
            input.status,
            // Use sentinel timestamps so the message stays informative.
            {
                created_at: '<missing>',
                dispatched_at: null,
                delivered_at: null,
                read_at: null,
            },
            {
                created_at: '<missing>',
                dispatched_at: input.dispatched_at ?? null,
                delivered_at: input.delivered_at ?? null,
                read_at: input.read_at ?? null,
            },
            `Notification ${input.notificationId} does not exist; cannot ` +
                `transition to '${input.status}'.`,
        );
    }

    const proposed: LifecycleTimestamps = {
        created_at: existing.created_at,
        dispatched_at:
            input.dispatched_at !== undefined
                ? input.dispatched_at
                : existing.dispatched_at,
        delivered_at:
            input.delivered_at !== undefined
                ? input.delivered_at
                : existing.delivered_at,
        read_at:
            input.read_at !== undefined ? input.read_at : existing.read_at,
    };

    assertLifecycleOrdering(
        input.notificationId,
        input.status,
        timestamps(existing),
        proposed,
    );

    // Recompute the user_status_pk so the by-user-status GSI reflects the
    // new lifecycle status (sparse rows would otherwise still index the
    // old status).
    const updatedRecord: NotificationRecord = {
        ...existing,
        status: input.status,
        dispatched_at: proposed.dispatched_at,
        delivered_at: proposed.delivered_at,
        read_at: proposed.read_at,
    };
    const gsiAttrs = buildGsiAttributes(updatedRecord);

    const client = options.docClient ?? defaultDocClient();
    await client.send(
        new UpdateCommand({
            TableName: options.tableName ?? NOTIFICATION_TABLE,
            Key: { notification_id: input.notificationId },
            UpdateExpression:
                'SET #status = :status, ' +
                'dispatched_at = :dispatched_at, ' +
                'delivered_at = :delivered_at, ' +
                'read_at = :read_at, ' +
                'user_status_pk = :user_status_pk, ' +
                'user_status_sk = :user_status_sk, ' +
                'user_category_pk = :user_category_pk, ' +
                'user_category_sk = :user_category_sk',
            ExpressionAttributeNames: { '#status': 'status' },
            ExpressionAttributeValues: {
                ':status': input.status,
                ':dispatched_at': proposed.dispatched_at,
                ':delivered_at': proposed.delivered_at,
                ':read_at': proposed.read_at,
                ':user_status_pk': gsiAttrs.user_status_pk ?? null,
                ':user_status_sk': gsiAttrs.user_status_sk ?? null,
                ':user_category_pk': gsiAttrs.user_category_pk ?? null,
                ':user_category_sk': gsiAttrs.user_category_sk ?? null,
            },
            ConditionExpression: 'attribute_exists(notification_id)',
        }),
    );

    return updatedRecord;
}

/**
 * Hard-delete a Notification record. Used only by the cold-storage move
 * job (task 4.1: archive_period eviction hook); regular workflow uses
 * `updateLifecycle` to mark records as `failed` / `read` instead.
 *
 * Validates: REQ 6.8 retention move (the actual cold-storage write is
 * outside this task's scope; this helper exposes the delete primitive).
 */
export async function deleteNotification(
    notificationId: string,
    options: NotificationRepoOptions = {},
): Promise<void> {
    const client = options.docClient ?? defaultDocClient();
    await client.send(
        new DeleteCommand({
            TableName: options.tableName ?? NOTIFICATION_TABLE,
            Key: { notification_id: notificationId },
        }),
    );
}

// ---- Cursor-paginated reads (REQ 6.4, 6.5, 6.9) --------------------------

export interface ListByUserStatusInput {
    readonly user_id: string;
    readonly status: NotificationStatus;
    /** Hard ceiling on page size (DynamoDB also caps at 1 MB / 1000 rows). */
    readonly limit?: number;
    /** Opaque cursor returned by a prior page. */
    readonly cursor?: string | null;
    /** Default: descending (newest first). */
    readonly scanForward?: boolean;
}

/**
 * Page through a recipient's notifications filtered by lifecycle status.
 * Backed by the `by-user-status` GSI (REQ 6.4). Cursor is the opaque
 * base64url-encoded `(user_id, created_at, notification_id)` tuple
 * required by REQ 6.9.
 */
export async function listByUserStatus(
    input: ListByUserStatusInput,
    options: NotificationRepoOptions = {},
): Promise<PaginatedNotifications> {
    const client = options.docClient ?? defaultDocClient();
    const exclusiveStart = cursorToExclusiveStartKey(input.cursor, 'user_status', input.status);

    const params: QueryCommandInput = {
        TableName: options.tableName ?? NOTIFICATION_TABLE,
        IndexName: GSI_BY_USER_STATUS,
        KeyConditionExpression: 'user_status_pk = :pk',
        ExpressionAttributeValues: {
            ':pk': `${input.user_id}#${input.status}`,
        },
        Limit: input.limit ?? 50,
        ScanIndexForward: input.scanForward ?? false,
        ExclusiveStartKey: exclusiveStart ?? undefined,
    };

    return runPagedQuery(client, params, input.user_id);
}

export interface ListByUserCategoryInput {
    readonly user_id: string;
    readonly category: NotificationCategory;
    readonly limit?: number;
    readonly cursor?: string | null;
    readonly scanForward?: boolean;
}

/**
 * Page through a recipient's notifications filtered by category. Backed
 * by the `by-user-category` GSI (REQ 6.5).
 */
export async function listByUserCategory(
    input: ListByUserCategoryInput,
    options: NotificationRepoOptions = {},
): Promise<PaginatedNotifications> {
    const client = options.docClient ?? defaultDocClient();
    const exclusiveStart = cursorToExclusiveStartKey(input.cursor, 'user_category', input.category);

    const params: QueryCommandInput = {
        TableName: options.tableName ?? NOTIFICATION_TABLE,
        IndexName: GSI_BY_USER_CATEGORY,
        KeyConditionExpression: 'user_category_pk = :pk',
        ExpressionAttributeValues: {
            ':pk': `${input.user_id}#${input.category}`,
        },
        Limit: input.limit ?? 50,
        ScanIndexForward: input.scanForward ?? false,
        ExclusiveStartKey: exclusiveStart ?? undefined,
    };

    return runPagedQuery(client, params, input.user_id);
}

export interface FindByDedupKeyInput {
    readonly dedup_key: string;
    /** Inclusive lower bound on `created_at` (used by Deduplication_Window). */
    readonly since?: string;
    readonly limit?: number;
}

/**
 * Look up notifications by `dedup_key`. Backed by the `by-dedup-key` GSI
 * (REQ 6.6). The `dedup.ts` step (task 6.1) calls this with `since =
 * now - Deduplication_Window` to detect duplicate deliveries in
 * constant time.
 */
export async function findByDedupKey(
    input: FindByDedupKeyInput,
    options: NotificationRepoOptions = {},
): Promise<readonly NotificationRecord[]> {
    const client = options.docClient ?? defaultDocClient();

    const params: QueryCommandInput = {
        TableName: options.tableName ?? NOTIFICATION_TABLE,
        IndexName: GSI_BY_DEDUP_KEY,
        KeyConditionExpression: input.since
            ? 'dedup_key = :pk AND created_at_id_sk >= :since'
            : 'dedup_key = :pk',
        ExpressionAttributeValues: {
            ':pk': input.dedup_key,
            ...(input.since ? { ':since': input.since } : {}),
        },
        Limit: input.limit ?? 25,
        ScanIndexForward: false,
    };

    const result = await client.send(new QueryCommand(params));
    return ((result.Items ?? []) as NotificationItem[]).map(stripGsiAttributes);
}

// ---- Archive_Period eviction hook (REQ 6.8) ------------------------------

export interface GetRecordsOlderThanInput {
    /** Number of days to look back. Default Archive_Period is 90 days. */
    readonly daysAgo: number;
    /** Maximum rows to scan in one call. */
    readonly batchSize: number;
    /** Optional pagination cursor for follow-up batches. */
    readonly exclusiveStartKey?: Record<string, unknown> | null;
}

export interface GetRecordsOlderThanResult {
    readonly items: readonly NotificationRecord[];
    readonly lastEvaluatedKey: Record<string, unknown> | null;
}

/**
 * Returns Notification records older than `daysAgo` so the cold-storage
 * mover (out of scope for this task) can copy them to S3 and call
 * `deleteNotification`.
 *
 * NOTE: This uses a DynamoDB Scan with a filter expression because the
 * Archive_Period sweep is a low-frequency batch job; switching to a
 * dedicated TTL-driven approach is a separate optimisation. The function
 * is paginated so large tables can be processed in chunks.
 *
 * Validates: REQ 6.8 (Archive_Period default 90 days; eviction job
 * reads, the move-to-cold-storage write is out of scope).
 */
export async function getRecordsOlderThan(
    input: GetRecordsOlderThanInput,
    options: NotificationRepoOptions = {},
): Promise<GetRecordsOlderThanResult> {
    if (!Number.isFinite(input.daysAgo) || input.daysAgo < 0) {
        throw new Error('daysAgo must be a non-negative finite number');
    }
    if (!Number.isInteger(input.batchSize) || input.batchSize <= 0) {
        throw new Error('batchSize must be a positive integer');
    }

    const cutoff = new Date(
        Date.now() - input.daysAgo * 24 * 60 * 60 * 1000,
    ).toISOString();

    // We do a Query-less Scan here because Archive_Period sweeps are not
    // recipient-scoped. The lib-dynamodb Scan command is in lib-dynamodb.
    const { ScanCommand } = await import('@aws-sdk/lib-dynamodb');
    const client = options.docClient ?? defaultDocClient();
    const result = await client.send(
        new ScanCommand({
            TableName: options.tableName ?? NOTIFICATION_TABLE,
            FilterExpression: 'created_at < :cutoff',
            ExpressionAttributeValues: { ':cutoff': cutoff },
            Limit: input.batchSize,
            ExclusiveStartKey: input.exclusiveStartKey ?? undefined,
        }),
    );

    const items = ((result.Items ?? []) as NotificationItem[]).map(
        stripGsiAttributes,
    );

    return {
        items,
        lastEvaluatedKey: result.LastEvaluatedKey
            ? (result.LastEvaluatedKey as Record<string, unknown>)
            : null,
    };
}

// ---- Internal pagination plumbing ----------------------------------------
//
// DynamoDB returns a `LastEvaluatedKey` whose shape depends on which GSI
// the query used. We translate it to/from the opaque cursor required by
// REQ 6.9 so the cursor remains stable across infrastructure changes.

type GsiName = 'user_status' | 'user_category';

function exclusiveStartKeyFromCursor(
    cursor: PaginationCursor,
    gsi: GsiName,
    keyAxis: string,
): Record<string, unknown> {
    const sortKey = `${cursor.created_at}#${cursor.notification_id}`;
    if (gsi === 'user_status') {
        return {
            notification_id: cursor.notification_id,
            user_status_pk: `${cursor.user_id}#${keyAxis}`,
            user_status_sk: sortKey,
        };
    }
    return {
        notification_id: cursor.notification_id,
        user_category_pk: `${cursor.user_id}#${keyAxis}`,
        user_category_sk: sortKey,
    };
}

function cursorToExclusiveStartKey(
    cursor: string | null | undefined,
    gsi: GsiName,
    keyAxis: string,
): Record<string, unknown> | null {
    if (!cursor) return null;
    const decoded = decodeCursor(cursor);
    return exclusiveStartKeyFromCursor(decoded, gsi, keyAxis);
}

async function runPagedQuery(
    client: DynamoDBDocumentClient,
    params: QueryCommandInput,
    userId: string,
): Promise<PaginatedNotifications> {
    const result = await client.send(new QueryCommand(params));
    const items = ((result.Items ?? []) as NotificationItem[]).map(
        stripGsiAttributes,
    );

    let nextCursor: string | null = null;
    if (result.LastEvaluatedKey && items.length > 0) {
        const last = items[items.length - 1];
        nextCursor = cursorFromNotification({
            user_id: userId,
            created_at: last.created_at,
            notification_id: last.notification_id,
        });
    }

    return { items, next_cursor: nextCursor };
}

// Re-export so callers don't have to import from cursor.ts separately.
export { encodeCursor, decodeCursor };
