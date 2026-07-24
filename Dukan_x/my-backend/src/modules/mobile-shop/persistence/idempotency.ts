/**
 * Idempotency Record Persistence — MobileShop DynamoDB
 *
 * Manages tenant-scoped Operation_Id records for idempotent mutation handling.
 * - Creates records with `attribute_not_exists` conditions (first-write wins)
 * - Checks existing records via strong Get (AP-14)
 * - Enforces configured retention independently of DynamoDB TTL cleanup
 * - Replays matching fingerprints, rejects mismatches without mutation
 *
 * Key shape:
 *   PK = TENANT#<tenantId>#IDEMPOTENCY
 *   SK = OP#<operationId>
 *
 * Requirements: 3.7–3.9, 6.7–6.13, 6.26–6.27; GR-4.3
 */

import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../schemas/common.schema';
import type { Result } from '../domain/device-lifecycle';
import { buildIdempotencyPK, encodeSK } from './key-codec';
import { RETENTION_CONFIG } from '../config/retention.config';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Status of an idempotency record */
export type IdempotencyStatus = 'PENDING' | 'COMMITTED' | 'ACCEPTED_PENDING' | 'FAILED' | 'REJECTED';

/** Result of checking idempotency state */
export type IdempotencyCheckResult =
  | { readonly outcome: 'NEW_OPERATION' }
  | { readonly outcome: 'REPLAY'; readonly status: IdempotencyStatus; readonly responseRef: string | null }
  | { readonly outcome: 'FINGERPRINT_MISMATCH' }
  | { readonly outcome: 'EXPIRED' };

/** Error codes for idempotency operations */
export type IdempotencyErrorCode = 'IDEMPOTENCY_CONFLICT' | 'CONDITION_FAILED' | 'STATUS_MISMATCH';

/** Shape of a persisted idempotency record */
export interface IdempotencyRecord {
  readonly PK: string;
  readonly SK: string;
  readonly tenantId: string;
  readonly operationId: string;
  readonly fingerprint: string;
  readonly status: IdempotencyStatus;
  readonly responseRef: string | null;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly expiresAt: number; // TTL epoch seconds
  readonly retentionExpiresAt: string; // ISO 8601 — business retention boundary
}

// ─── Create Idempotency Record ───────────────────────────────────────────────

/**
 * Creates a new idempotency record with attribute_not_exists condition.
 * Returns success if created, or IDEMPOTENCY_CONFLICT if the record already exists.
 *
 * The record is placed with:
 * - `expiresAt` for DynamoDB TTL cleanup
 * - `retentionExpiresAt` for business-level retention enforcement
 */
export async function createIdempotencyRecord(
  client: DynamoDBDocumentClient,
  tableName: string,
  ctx: TenantContextWire,
  operationId: string,
  fingerprint: string,
  status: IdempotencyStatus,
  responseRef: string | null,
  dataModelVersion?: number,
): Promise<Result<IdempotencyRecord, { code: IdempotencyErrorCode; message: string }>> {
  const { PutCommand } = await import('@aws-sdk/lib-dynamodb');

  const now = new Date();
  const nowIso = now.toISOString();
  const ttlEpoch = Math.floor(now.getTime() / 1000) + RETENTION_CONFIG.idempotency.ttlSeconds;
  const retentionExpiry = new Date(
    now.getTime() + RETENTION_CONFIG.idempotency.retentionSeconds * 1000,
  ).toISOString();

  const pk = buildIdempotencyPK(ctx.tenantId);
  const sk = encodeSK('OP', operationId);

  const record: IdempotencyRecord = {
    PK: pk,
    SK: sk,
    tenantId: ctx.tenantId,
    operationId,
    fingerprint,
    status,
    responseRef,
    dataModelVersion: dataModelVersion ?? MODEL_VERSION_CONFIG.currentVersion,
    createdAt: nowIso,
    updatedAt: nowIso,
    expiresAt: ttlEpoch,
    retentionExpiresAt: retentionExpiry,
  };

  try {
    await client.send(
      new PutCommand({
        TableName: tableName,
        Item: record as Record<string, unknown>,
        ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    return { ok: true, value: record };
  } catch (error: unknown) {
    if (isConditionalCheckFailed(error)) {
      return {
        ok: false,
        error: {
          code: 'IDEMPOTENCY_CONFLICT',
          message: `Idempotency record already exists for operationId: ${operationId}`,
        },
      };
    }
    throw error; // Unexpected errors propagate
  }
}

// ─── Check Idempotency ───────────────────────────────────────────────────────

/**
 * Checks the idempotency state for a given operationId using strong consistency (AP-14).
 *
 * Returns:
 * - NEW_OPERATION: no record exists, caller should proceed with the mutation
 * - REPLAY: fingerprint matches, return the recorded outcome without mutation
 * - FINGERPRINT_MISMATCH: different fingerprint for the same operationId
 * - EXPIRED: record exists but is past configured business retention
 */
export async function checkIdempotency(
  client: DynamoDBDocumentClient,
  tableName: string,
  ctx: TenantContextWire,
  operationId: string,
  fingerprint: string,
): Promise<IdempotencyCheckResult> {
  const { GetCommand } = await import('@aws-sdk/lib-dynamodb');

  const pk = buildIdempotencyPK(ctx.tenantId);
  const sk = encodeSK('OP', operationId);

  const result = await client.send(
    new GetCommand({
      TableName: tableName,
      Key: { PK: pk, SK: sk },
      ConsistentRead: true,
      ReturnConsumedCapacity: 'TOTAL',
    }),
  );

  const item = result.Item as IdempotencyRecord | undefined;

  if (!item) {
    return { outcome: 'NEW_OPERATION' };
  }

  // Verify tenant ownership (security check)
  if (item.tenantId !== ctx.tenantId) {
    // Treat as not found — never disclose cross-tenant existence
    return { outcome: 'NEW_OPERATION' };
  }

  // Enforce business retention independently of TTL cleanup
  const retentionExpiry = new Date(item.retentionExpiresAt).getTime();
  if (Date.now() > retentionExpiry) {
    return { outcome: 'EXPIRED' };
  }

  // Compare fingerprints
  if (item.fingerprint === fingerprint) {
    return {
      outcome: 'REPLAY',
      status: item.status,
      responseRef: item.responseRef,
    };
  }

  return { outcome: 'FINGERPRINT_MISMATCH' };
}

// ─── Update Idempotency Status ───────────────────────────────────────────────

/**
 * Conditionally updates the status of an existing idempotency record.
 * The update only succeeds if the current status matches `expectedStatus`.
 */
export async function updateIdempotencyStatus(
  client: DynamoDBDocumentClient,
  tableName: string,
  ctx: TenantContextWire,
  operationId: string,
  expectedStatus: IdempotencyStatus,
  newStatus: IdempotencyStatus,
  responseRef?: string | null,
): Promise<Result<{ status: IdempotencyStatus }, { code: IdempotencyErrorCode; message: string }>> {
  const { UpdateCommand } = await import('@aws-sdk/lib-dynamodb');

  const pk = buildIdempotencyPK(ctx.tenantId);
  const sk = encodeSK('OP', operationId);
  const now = new Date().toISOString();

  const updateExpr = responseRef !== undefined
    ? 'SET #status = :newStatus, #updatedAt = :now, #responseRef = :responseRef'
    : 'SET #status = :newStatus, #updatedAt = :now';

  const exprValues: Record<string, unknown> = {
    ':expectedStatus': expectedStatus,
    ':newStatus': newStatus,
    ':now': now,
    ':tenantId': ctx.tenantId,
  };

  if (responseRef !== undefined) {
    exprValues[':responseRef'] = responseRef;
  }

  try {
    await client.send(
      new UpdateCommand({
        TableName: tableName,
        Key: { PK: pk, SK: sk },
        UpdateExpression: updateExpr,
        ConditionExpression: '#status = :expectedStatus AND #tenantId = :tenantId',
        ExpressionAttributeNames: {
          '#status': 'status',
          '#updatedAt': 'updatedAt',
          '#tenantId': 'tenantId',
          ...(responseRef !== undefined ? { '#responseRef': 'responseRef' } : {}),
        },
        ExpressionAttributeValues: exprValues,
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    return { ok: true, value: { status: newStatus } };
  } catch (error: unknown) {
    if (isConditionalCheckFailed(error)) {
      return {
        ok: false,
        error: {
          code: 'STATUS_MISMATCH',
          message: `Cannot transition from expected status '${expectedStatus}' for operationId: ${operationId}`,
        },
      };
    }
    throw error;
  }
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

function isConditionalCheckFailed(error: unknown): boolean {
  if (error && typeof error === 'object' && 'name' in error) {
    return (
      (error as { name: string }).name === 'ConditionalCheckFailedException' ||
      (error as { name: string }).name === 'TransactionCanceledException'
    );
  }
  return false;
}
