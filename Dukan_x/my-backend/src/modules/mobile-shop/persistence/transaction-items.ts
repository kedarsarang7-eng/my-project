/**
 * Transaction Item Builders — MobileShop DynamoDB
 *
 * Helpers to construct TransactWriteItems entries for claims and idempotency
 * records. These are included in atomic DynamoDB transactions by the sale handler
 * (task 6.1) and other domain handlers that need atomicity across multiple items.
 *
 * Each builder returns a typed Put/Delete with the appropriate condition expression,
 * ready for inclusion in a TransactWriteItems request.
 *
 * Key patterns:
 *   Claims:      PK=TENANT#t#CLAIM,        SK=<TYPE>#<value>
 *   Idempotency: PK=TENANT#t#IDEMPOTENCY,  SK=OP#<operationId>
 *
 * Requirements: 3.7–3.9, 6.9–6.13, 6.26–6.27, 6.31; GR-4.3
 */

import type { TenantContextWire } from '../schemas/common.schema';
import type { IdempotencyStatus } from './idempotency';
import { buildClaimPK, buildIdempotencyPK, encodeSK } from './key-codec';
import { RETENTION_CONFIG } from '../config/retention.config';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Claim type discriminator */
export type ClaimType = 'IMEI' | 'RESERVATION';

/** A TransactWriteItem Put entry */
export interface TransactPutItem {
  readonly Put: {
    readonly TableName: string;
    readonly Item: Record<string, unknown>;
    readonly ConditionExpression: string;
  };
}

/** A TransactWriteItem Delete entry */
export interface TransactDeleteItem {
  readonly Delete: {
    readonly TableName: string;
    readonly Key: Record<string, string>;
    readonly ConditionExpression: string;
    readonly ExpressionAttributeNames: Record<string, string>;
    readonly ExpressionAttributeValues: Record<string, unknown>;
  };
}

// ─── Claim Transaction Item Builder ──────────────────────────────────────────

/**
 * Builds a TransactWriteItem Put entry for a uniqueness claim (IMEI or RESERVATION).
 *
 * Uses `attribute_not_exists(PK) AND attribute_not_exists(SK)` to guarantee first-write wins.
 * The resulting item is included alongside domain mutations in one DynamoDB transaction.
 *
 * @param tableName - DynamoDB table name
 * @param ctx - Authenticated tenant context
 * @param claimType - 'IMEI' or 'RESERVATION'
 * @param key - Normalized IMEI value or unit ID (depending on claim type)
 * @param ownerEntityId - Entity that owns this claim
 * @param version - Owner entity version at time of claim
 * @param expiresAt - Optional TTL epoch seconds (used for reservation expiry)
 */
export function buildClaimTransactItem(
  tableName: string,
  ctx: TenantContextWire,
  claimType: ClaimType,
  key: string,
  ownerEntityId: string,
  version: number,
  expiresAt?: number,
): TransactPutItem {
  const now = new Date().toISOString();
  const pk = buildClaimPK(ctx.tenantId);
  const sk = encodeSK(claimType, key);

  const item: Record<string, unknown> = {
    PK: pk,
    SK: sk,
    tenantId: ctx.tenantId,
    claimType,
    ownerEntityId,
    ownerVersion: version,
    dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
    createdAt: now,
    updatedAt: now,
  };

  // Add claim-type specific fields
  if (claimType === 'IMEI') {
    item['normalizedImei'] = key;
  } else {
    item['unitId'] = key;
    item['reservationId'] = ownerEntityId;
    item['reservationVersion'] = version;
  }

  if (expiresAt !== undefined) {
    item['expiresAt'] = expiresAt;
  }

  return {
    Put: {
      TableName: tableName,
      Item: item,
      ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
    },
  };
}

// ─── Idempotency Transaction Item Builder ────────────────────────────────────

/**
 * Builds a TransactWriteItem Put entry for an idempotency record.
 *
 * Uses `attribute_not_exists(PK) AND attribute_not_exists(SK)` to guarantee
 * first-write wins. The resulting item is included in the same DynamoDB
 * transaction as domain mutations and claims.
 *
 * @param tableName - DynamoDB table name
 * @param ctx - Authenticated tenant context
 * @param operationId - Unique operation identifier
 * @param fingerprint - Mutation fingerprint for replay detection
 * @param status - Initial idempotency status
 * @param responseRef - Optional reference to stored response
 * @param dataModelVersion - Optional data model version override
 */
export function buildIdempotencyTransactItem(
  tableName: string,
  ctx: TenantContextWire,
  operationId: string,
  fingerprint: string,
  status: IdempotencyStatus,
  responseRef: string | null,
  dataModelVersion?: number,
): TransactPutItem {
  const now = new Date();
  const nowIso = now.toISOString();
  const ttlEpoch = Math.floor(now.getTime() / 1000) + RETENTION_CONFIG.idempotency.ttlSeconds;
  const retentionExpiry = new Date(
    now.getTime() + RETENTION_CONFIG.idempotency.retentionSeconds * 1000,
  ).toISOString();

  const pk = buildIdempotencyPK(ctx.tenantId);
  const sk = encodeSK('OP', operationId);

  const item: Record<string, unknown> = {
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

  return {
    Put: {
      TableName: tableName,
      Item: item,
      ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
    },
  };
}

// ─── Release Claim Transaction Item Builder ──────────────────────────────────

/**
 * Builds a TransactWriteItem Delete entry for releasing a claim conditionally.
 *
 * The delete only succeeds when the stored owner and version match expected values.
 * Used in transactions that reassign or cancel ownership (e.g., invoice cancellation).
 *
 * @param tableName - DynamoDB table name
 * @param ctx - Authenticated tenant context
 * @param claimType - 'IMEI' or 'RESERVATION'
 * @param key - Normalized IMEI value or unit ID
 * @param expectedOwnerEntityId - Expected current owner
 * @param expectedVersion - Expected current version
 */
export function buildReleaseClaimTransactItem(
  tableName: string,
  ctx: TenantContextWire,
  claimType: ClaimType,
  key: string,
  expectedOwnerEntityId: string,
  expectedVersion: number,
): TransactDeleteItem {
  const pk = buildClaimPK(ctx.tenantId);
  const sk = encodeSK(claimType, key);

  const ownerField = claimType === 'IMEI' ? 'ownerEntityId' : 'reservationId';
  const versionField = claimType === 'IMEI' ? 'ownerVersion' : 'reservationVersion';

  return {
    Delete: {
      TableName: tableName,
      Key: { PK: pk, SK: sk },
      ConditionExpression: '#tenantId = :tenantId AND #owner = :ownerId AND #version = :version',
      ExpressionAttributeNames: {
        '#tenantId': 'tenantId',
        '#owner': ownerField,
        '#version': versionField,
      },
      ExpressionAttributeValues: {
        ':tenantId': ctx.tenantId,
        ':ownerId': expectedOwnerEntityId,
        ':version': expectedVersion,
      },
    },
  };
}
