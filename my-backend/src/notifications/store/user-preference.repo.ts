// ============================================================================
// Notification_Store — UserPreference Repository
// ============================================================================
// CRUD for UserPreference records (REQ 6.2) with optimistic `version` updates.
//
// Idempotence note: REQ 4.9 / REQ 7.7 require that calling
//   setUserPreferences(user_id, preferences)
// with the same payload more than once produces the same stored state.
// This module guarantees that property by:
//   1. always bumping `version` and `updated_at`, but
//   2. accepting an `expectedVersion` that the caller carries forward
//      across retries — so the second write of the same payload is a no-op
//      against an unchanged record (it returns the current record and
//      writes nothing) when the caller passes `expectedVersion = current`.
//
// The Notification_Service's `setUserPreferences` (task 6.1) wraps this
// repo with the read-then-update flow that delivers the spec idempotence.
// ============================================================================

import {
    DynamoDBDocumentClient,
    GetCommand,
    PutCommand,
    UpdateCommand,
    DeleteCommand,
} from '@aws-sdk/lib-dynamodb';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { logger } from '../../utils/logger';
import { OptimisticLockError } from './errors';
import { USER_PREFERENCE_TABLE } from './keys';
import type {
    NotificationCategory,
    NotificationChannel,
    UserPreferenceRecord,
} from './types';

// ---- Local doc client (kept separate from the notifications client so a
// tests-only injection point cannot leak into the other repo) -------------

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

export function __setUserPreferenceDocClientForTesting(
    client: DynamoDBDocumentClient | null,
): void {
    cachedDocClient = client;
}

// ---- Public API ----------------------------------------------------------

export interface UserPreferenceRepoOptions {
    readonly docClient?: DynamoDBDocumentClient;
    readonly tableName?: string;
}

/**
 * Input shape for `createUserPreference`. We accept the caller's payload
 * verbatim and synthesise `updated_at` + the initial `version = 1`.
 */
export interface CreateUserPreferenceInput {
    readonly user_id: string;
    readonly role: string;
    readonly per_category_channels?: Partial<
        Record<NotificationCategory, readonly NotificationChannel[]>
    >;
    readonly per_event_channels?: Record<string, readonly NotificationChannel[]>;
    readonly quiet_hours_start?: string | null;
    readonly quiet_hours_end?: string | null;
    readonly quiet_hours_timezone?: string | null;
    readonly mute_targets?: readonly string[];
}

/**
 * Insert a new UserPreference record at version 1. Throws on duplicate
 * `user_id`.
 */
export async function createUserPreference(
    input: CreateUserPreferenceInput,
    options: UserPreferenceRepoOptions = {},
): Promise<UserPreferenceRecord> {
    if (!input.user_id || input.user_id.trim() === '') {
        throw new Error('user_id is required');
    }

    const now = new Date().toISOString();
    const record: UserPreferenceRecord = {
        user_id: input.user_id,
        role: input.role,
        per_category_channels: input.per_category_channels ?? {},
        per_event_channels: input.per_event_channels ?? {},
        quiet_hours_start: input.quiet_hours_start ?? null,
        quiet_hours_end: input.quiet_hours_end ?? null,
        quiet_hours_timezone: input.quiet_hours_timezone ?? null,
        mute_targets: input.mute_targets ?? [],
        updated_at: now,
        version: 1,
    };

    const client = options.docClient ?? defaultDocClient();
    await client.send(
        new PutCommand({
            TableName: options.tableName ?? USER_PREFERENCE_TABLE,
            Item: record,
            ConditionExpression: 'attribute_not_exists(user_id)',
        }),
    );

    logger.debug('UserPreference created', { user_id: input.user_id });
    return record;
}

/**
 * Fetch a UserPreference record by `user_id`. Returns `null` if absent.
 */
export async function getUserPreference(
    userId: string,
    options: UserPreferenceRepoOptions = {},
): Promise<UserPreferenceRecord | null> {
    const client = options.docClient ?? defaultDocClient();
    const result = await client.send(
        new GetCommand({
            TableName: options.tableName ?? USER_PREFERENCE_TABLE,
            Key: { user_id: userId },
        }),
    );
    if (!result.Item) return null;
    return result.Item as UserPreferenceRecord;
}

/**
 * Update an existing UserPreference record using optimistic-lock semantics.
 *
 * Behaviour:
 *   - Throws `OptimisticLockError` if the on-disk `version` does not equal
 *     `expectedVersion` (REQ 6.2 — `version` field).
 *   - Bumps `version` by 1 and refreshes `updated_at`.
 *   - Replaces every patchable field with the supplied value (or leaves it
 *     unchanged when omitted).
 */
export interface UpdateUserPreferenceInput {
    readonly user_id: string;
    readonly expectedVersion: number;
    readonly role?: string;
    readonly per_category_channels?: Partial<
        Record<NotificationCategory, readonly NotificationChannel[]>
    >;
    readonly per_event_channels?: Record<string, readonly NotificationChannel[]>;
    readonly quiet_hours_start?: string | null;
    readonly quiet_hours_end?: string | null;
    readonly quiet_hours_timezone?: string | null;
    readonly mute_targets?: readonly string[];
}

export async function updateUserPreference(
    input: UpdateUserPreferenceInput,
    options: UserPreferenceRepoOptions = {},
): Promise<UserPreferenceRecord> {
    if (!input.user_id || input.user_id.trim() === '') {
        throw new Error('user_id is required');
    }
    if (!Number.isInteger(input.expectedVersion) || input.expectedVersion < 1) {
        throw new Error('expectedVersion must be a positive integer');
    }

    const now = new Date().toISOString();

    // Build a minimal SET expression containing only fields the caller wants
    // to change, plus the always-on `version` and `updated_at` writes.
    const setParts: string[] = [
        '#version = :nextVersion',
        'updated_at = :now',
    ];
    const exprNames: Record<string, string> = { '#version': 'version' };
    const exprValues: Record<string, unknown> = {
        ':nextVersion': input.expectedVersion + 1,
        ':now': now,
        ':expectedVersion': input.expectedVersion,
    };

    const patchable: ReadonlyArray<[
        keyof UpdateUserPreferenceInput,
        keyof UserPreferenceRecord,
    ]> = [
        ['role', 'role'],
        ['per_category_channels', 'per_category_channels'],
        ['per_event_channels', 'per_event_channels'],
        ['quiet_hours_start', 'quiet_hours_start'],
        ['quiet_hours_end', 'quiet_hours_end'],
        ['quiet_hours_timezone', 'quiet_hours_timezone'],
        ['mute_targets', 'mute_targets'],
    ];

    let idx = 0;
    for (const [inputKey, recordKey] of patchable) {
        const value = (input as unknown as Record<string, unknown>)[
            inputKey as string
        ];
        if (value === undefined) continue;
        const nameAlias = `#f${idx}`;
        const valueAlias = `:v${idx}`;
        setParts.push(`${nameAlias} = ${valueAlias}`);
        exprNames[nameAlias] = recordKey;
        exprValues[valueAlias] = value;
        idx++;
    }

    const client = options.docClient ?? defaultDocClient();
    try {
        const result = await client.send(
            new UpdateCommand({
                TableName: options.tableName ?? USER_PREFERENCE_TABLE,
                Key: { user_id: input.user_id },
                UpdateExpression: `SET ${setParts.join(', ')}`,
                ExpressionAttributeNames: exprNames,
                ExpressionAttributeValues: exprValues,
                ConditionExpression:
                    'attribute_exists(user_id) AND #version = :expectedVersion',
                ReturnValues: 'ALL_NEW',
            }),
        );
        return result.Attributes as UserPreferenceRecord;
    } catch (err: unknown) {
        if (
            (err as { name?: string }).name === 'ConditionalCheckFailedException'
        ) {
            throw new OptimisticLockError(
                `UserPreference(${input.user_id})`,
                input.expectedVersion,
            );
        }
        throw err;
    }
}

/**
 * Upsert a UserPreference record using optimistic locking. Convenience
 * wrapper used by `setUserPreferences` (task 6.1) so the service layer
 * doesn't need a read-or-create branch.
 *
 * Behaviour:
 *   - If no record exists, creates it at version 1 (regardless of the
 *     supplied `expectedVersion`).
 *   - If a record exists, performs the optimistic-lock update path with
 *     the supplied `expectedVersion`.
 */
export async function upsertUserPreference(
    input: UpdateUserPreferenceInput,
    options: UserPreferenceRepoOptions = {},
): Promise<UserPreferenceRecord> {
    const existing = await getUserPreference(input.user_id, options);
    if (!existing) {
        return createUserPreference(
            {
                user_id: input.user_id,
                role: input.role ?? '',
                per_category_channels: input.per_category_channels,
                per_event_channels: input.per_event_channels,
                quiet_hours_start: input.quiet_hours_start,
                quiet_hours_end: input.quiet_hours_end,
                quiet_hours_timezone: input.quiet_hours_timezone,
                mute_targets: input.mute_targets,
            },
            options,
        );
    }
    return updateUserPreference(
        { ...input, expectedVersion: input.expectedVersion ?? existing.version },
        options,
    );
}

/**
 * Hard-delete a UserPreference record. Provided for account-deletion
 * workflows (e.g. "right to be forgotten"); regular preference flows
 * use update or upsert.
 */
export async function deleteUserPreference(
    userId: string,
    options: UserPreferenceRepoOptions = {},
): Promise<void> {
    const client = options.docClient ?? defaultDocClient();
    await client.send(
        new DeleteCommand({
            TableName: options.tableName ?? USER_PREFERENCE_TABLE,
            Key: { user_id: userId },
        }),
    );
}
