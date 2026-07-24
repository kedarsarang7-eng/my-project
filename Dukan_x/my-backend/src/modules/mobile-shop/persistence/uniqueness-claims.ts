/**
 * Uniqueness Claims Persistence — MobileShop DynamoDB
 *
 * Manages tenant-scoped IMEI and reservation claim records.
 * - First-write wins via `attribute_not_exists(PK) AND attribute_not_exists(SK)` condition
 * - Conditional release requires matching owner and version
 * - Claims prevent concurrent use of the same IMEI or reservation slot
 *
 * Key shape:
 *   PK = TENANT#<tenantId>#CLAIM
 *   SK = IMEI#<normalizedImei>       (for IMEI claims)
 *   SK = RESERVATION#<unitId>        (for reservation claims)
 *
 * Requirements: 3.7–3.9, 6.7–6.13, 6.26–6.27; GR-4.3
 */

import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../schemas/common.schema';
import type { Result } from '../domain/device-lifecycle';
import { buildClaimPK, encodeSK } from './key-codec';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Error codes for claim operations */
export type ClaimErrorCode =
  | 'CLAIM_ALREADY_EXISTS'
  | 'RESERVATION_ALREADY_EXISTS'
  | 'CLAIM_RELEASE_FAILED'
  | 'OWNER_MISMATCH';

/** Shape of a persisted IMEI claim */
export interface ImeiClaimRecord {
  readonly PK: string;
  readonly SK: string;
  readonly tenantId: string;
  readonly claimType: 'IMEI';
  readonly normalizedImei: string;
  readonly ownerEntityId: string;
  readonly ownerVersion: number;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** Shape of a persisted reservation claim */
export interface ReservationClaimRecord {
  readonly PK: string;
  readonly SK: string;
  readonly tenantId: string;
  readonly claimType: 'RESERVATION';
  readonly unitId: string;
  readonly reservationId: string;
  readonly reservationVersion: number;
  readonly expiresAt: number; // TTL epoch seconds
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

// ─── Create IMEI Claim ───────────────────────────────────────────────────────

/**
 * Creates a tenant-scoped IMEI claim using `attribute_not_exists` condition.
 * First claim wins — concurrent attempts for the same IMEI will fail.
 *
 * Returns success with the claim record, or CLAIM_ALREADY_EXISTS if taken.
 */
export async function createImeiClaim(
  client: DynamoDBDocumentClient,
  tableName: string,
  ctx: TenantContextWire,
  normalizedImei: string,
  ownerEntityId: string,
  ownerVersion: number,
): Promise<Result<ImeiClaimRecord, { code: ClaimErrorCode; message: string }>> {
  const { PutCommand } = await import('@aws-sdk/lib-dynamodb');

  const now = new Date().toISOString();
  const pk = buildClaimPK(ctx.tenantId);
  const sk = encodeSK('IMEI', normalizedImei);

  const record: ImeiClaimRecord = {
    PK: pk,
    SK: sk,
    tenantId: ctx.tenantId,
    claimType: 'IMEI',
    normalizedImei,
    ownerEntityId,
    ownerVersion,
    dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
    createdAt: now,
    updatedAt: now,
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
          code: 'CLAIM_ALREADY_EXISTS',
          message: `IMEI claim already exists for: ${normalizedImei}`,
        },
      };
    }
    throw error;
  }
}

// ─── Create Reservation Claim ────────────────────────────────────────────────

/**
 * Creates a tenant-scoped reservation claim for a unit using `attribute_not_exists` condition.
 * First reservation wins — concurrent reservations for the same unit will fail.
 *
 * Returns success with the claim record, or RESERVATION_ALREADY_EXISTS if taken.
 */
export async function createReservationClaim(
  client: DynamoDBDocumentClient,
  tableName: string,
  ctx: TenantContextWire,
  unitId: string,
  reservationId: string,
  reservationVersion: number,
  expiresAt: number,
): Promise<Result<ReservationClaimRecord, { code: ClaimErrorCode; message: string }>> {
  const { PutCommand } = await import('@aws-sdk/lib-dynamodb');

  const now = new Date().toISOString();
  const pk = buildClaimPK(ctx.tenantId);
  const sk = encodeSK('RESERVATION', unitId);

  const record: ReservationClaimRecord = {
    PK: pk,
    SK: sk,
    tenantId: ctx.tenantId,
    claimType: 'RESERVATION',
    unitId,
    reservationId,
    reservationVersion,
    expiresAt,
    dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
    createdAt: now,
    updatedAt: now,
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
          code: 'RESERVATION_ALREADY_EXISTS',
          message: `Reservation claim already exists for unit: ${unitId}`,
        },
      };
    }
    throw error;
  }
}

// ─── Release IMEI Claim ──────────────────────────────────────────────────────

/**
 * Conditionally deletes an IMEI claim. Only succeeds if the stored
 * ownerEntityId and ownerVersion match the expected values.
 *
 * Prevents accidental release of claims owned by a different entity/version.
 */
export async function releaseImeiClaim(
  client: DynamoDBDocumentClient,
  tableName: string,
  ctx: TenantContextWire,
  normalizedImei: string,
  expectedOwnerEntityId: string,
  expectedVersion: number,
): Promise<Result<void, { code: ClaimErrorCode; message: string }>> {
  const { DeleteCommand } = await import('@aws-sdk/lib-dynamodb');

  const pk = buildClaimPK(ctx.tenantId);
  const sk = encodeSK('IMEI', normalizedImei);

  try {
    await client.send(
      new DeleteCommand({
        TableName: tableName,
        Key: { PK: pk, SK: sk },
        ConditionExpression:
          '#tenantId = :tenantId AND #ownerEntityId = :ownerId AND #ownerVersion = :ownerVersion',
        ExpressionAttributeNames: {
          '#tenantId': 'tenantId',
          '#ownerEntityId': 'ownerEntityId',
          '#ownerVersion': 'ownerVersion',
        },
        ExpressionAttributeValues: {
          ':tenantId': ctx.tenantId,
          ':ownerId': expectedOwnerEntityId,
          ':ownerVersion': expectedVersion,
        },
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    return { ok: true, value: undefined };
  } catch (error: unknown) {
    if (isConditionalCheckFailed(error)) {
      return {
        ok: false,
        error: {
          code: 'OWNER_MISMATCH',
          message: `Cannot release IMEI claim for ${normalizedImei}: owner or version mismatch`,
        },
      };
    }
    throw error;
  }
}

// ─── Release Reservation Claim ───────────────────────────────────────────────

/**
 * Conditionally deletes a reservation claim. Only succeeds if the stored
 * reservationId and reservationVersion match the expected values.
 *
 * Prevents accidental release of reservations owned by a different entity/version.
 */
export async function releaseReservationClaim(
  client: DynamoDBDocumentClient,
  tableName: string,
  ctx: TenantContextWire,
  unitId: string,
  expectedReservationId: string,
  expectedVersion: number,
): Promise<Result<void, { code: ClaimErrorCode; message: string }>> {
  const { DeleteCommand } = await import('@aws-sdk/lib-dynamodb');

  const pk = buildClaimPK(ctx.tenantId);
  const sk = encodeSK('RESERVATION', unitId);

  try {
    await client.send(
      new DeleteCommand({
        TableName: tableName,
        Key: { PK: pk, SK: sk },
        ConditionExpression:
          '#tenantId = :tenantId AND #reservationId = :resId AND #reservationVersion = :resVersion',
        ExpressionAttributeNames: {
          '#tenantId': 'tenantId',
          '#reservationId': 'reservationId',
          '#reservationVersion': 'reservationVersion',
        },
        ExpressionAttributeValues: {
          ':tenantId': ctx.tenantId,
          ':resId': expectedReservationId,
          ':resVersion': expectedVersion,
        },
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    return { ok: true, value: undefined };
  } catch (error: unknown) {
    if (isConditionalCheckFailed(error)) {
      return {
        ok: false,
        error: {
          code: 'OWNER_MISMATCH',
          message: `Cannot release reservation claim for unit ${unitId}: reservation or version mismatch`,
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
