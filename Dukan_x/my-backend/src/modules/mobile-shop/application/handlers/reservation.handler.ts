/**
 * Reservation Handler
 *
 * Creates and releases reservation claims on IMEI units through conditional writes.
 * Reservation binds one unit to a customer/order. Conflicting sale or reservation
 * claims are rejected atomically.
 *
 * Requirements: 4.6, 8.12
 */

import { randomUUID } from 'crypto';
import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../../schemas/common.schema';
import {
  DeviceLifecycleState,
  validateTransition,
  type TransitionCommand,
} from '../../domain/device-lifecycle';
import { applyTransition, type ImeiUnit } from '../../domain/imei-unit';
import { checkIdempotency } from '../../persistence/idempotency';
import {
  buildClaimTransactItem,
  buildIdempotencyTransactItem,
  buildReleaseClaimTransactItem,
} from '../../persistence/transaction-items';
import { AuditEventService } from '../audit-service';
import { mapDynamoDbError, type DeterministicOutcome } from '../error-mapper';
import {
  buildEntityAggregatePK,
  encodeSK,
  encodeGSI1SK,
  buildUnitLifecycleGSI1PK,
} from '../../persistence/key-codec';
import { MobileShopRepository } from '../../persistence/mobile-shop.repository';
import { RETENTION_CONFIG } from '../../config/retention.config';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface CreateReservationParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly expectedVersion: number;
  readonly customerId: string;
  readonly reason: string;
  readonly expiresInSeconds?: number;
}

export interface ReleaseReservationParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
}

export interface ReservationHandlerDependencies {
  readonly client: DynamoDBDocumentClient;
  readonly tableName: string;
  readonly repository: MobileShopRepository;
  readonly auditService: AuditEventService;
}

export type ReservationOutcome<T> =
  | { readonly ok: true; readonly value: T; readonly confirmation: 'COMMITTED' }
  | { readonly ok: false; readonly outcome: DeterministicOutcome }
  | { readonly ok: true; readonly replay: true; readonly status: string };

// ─── Create Reservation ──────────────────────────────────────────────────────

/**
 * Creates a reservation on an IMEI unit.
 *
 * Flow:
 * 1. Check idempotency
 * 2. Read current unit (strong)
 * 3. Validate lifecycle transition to RESERVED
 * 4. Execute transaction: unit update + reservation claim + idempotency + audit
 */
export async function createReservationHandler(
  ctx: TenantContextWire,
  unitId: string,
  params: CreateReservationParams,
  deps: ReservationHandlerDependencies,
): Promise<ReservationOutcome<ImeiUnit>> {
  const { client, tableName, repository, auditService } = deps;

  // 1. Idempotency check
  const idempotencyResult = await checkIdempotency(
    client, tableName, ctx, params.operationId, params.mutationFingerprint,
  );
  if (idempotencyResult.outcome === 'REPLAY') {
    return { ok: true, replay: true, status: idempotencyResult.status };
  }
  if (idempotencyResult.outcome === 'FINGERPRINT_MISMATCH') {
    return {
      ok: false,
      outcome: {
        code: 'IDEMPOTENCY_MISMATCH',
        category: 'conflict',
        retryable: false,
        statePreserved: true,
        fields: ['operationId', 'mutationFingerprint'],
        httpStatus: 409,
        correlationId: ctx.correlationId,
      },
    };
  }

  // 2. Read current unit
  const existing = await repository.getEntityAggregate(
    ctx, 'IMEI_UNIT', unitId, { consistency: 'strong', skPrefix: 'META#' },
  );
  if (existing.items.length === 0) {
    return {
      ok: false,
      outcome: {
        code: 'ENTITY_NOT_FOUND',
        category: 'not_found',
        retryable: false,
        statePreserved: true,
        fields: ['unitId'],
        httpStatus: 404,
        correlationId: ctx.correlationId,
      },
    };
  }

  const currentUnit = existing.items[0] as unknown as ImeiUnit;

  // 3. Validate lifecycle transition
  const transitionCmd: TransitionCommand = {
    targetState: DeviceLifecycleState.RESERVED,
    expectedVersion: params.expectedVersion,
    actor: ctx.subjectId,
    reason: params.reason,
  };
  const transitionResult = validateTransition(currentUnit, transitionCmd);
  if (!transitionResult.ok) {
    return {
      ok: false,
      outcome: {
        code: transitionResult.error.code === 'VERSION_MISMATCH'
          ? 'VERSION_CONFLICT'
          : 'LIFECYCLE_TRANSITION_DENIED',
        category: 'conflict',
        retryable: transitionResult.error.code === 'VERSION_MISMATCH',
        statePreserved: true,
        fields: transitionResult.error.code === 'VERSION_MISMATCH'
          ? ['expectedVersion']
          : ['lifecycleState'],
        httpStatus: 409,
        correlationId: ctx.correlationId,
      },
    };
  }

  const event = transitionResult.value;
  const updatedUnit = applyTransition(currentUnit, event);

  // 4. Build transaction
  const reservationId = randomUUID();
  const defaultExpiry = 24 * 60 * 60; // 24 hours default
  const expiresInSeconds = params.expiresInSeconds ?? defaultExpiry;
  const expiresAt = Math.floor(Date.now() / 1000) + expiresInSeconds;

  const unitItem = buildReservationUnitDynamoItem(ctx, updatedUnit, params.customerId);
  const reservationClaim = buildClaimTransactItem(
    tableName, ctx, 'RESERVATION', unitId, reservationId, event.newVersion, expiresAt,
  );
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', reservationId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId: unitId,
    action: 'RESERVATION_CREATED',
    operationId: params.operationId,
    beforeState: currentUnit,
    afterState: updatedUnit,
    reason: params.reason,
  });

  try {
    const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');
    await client.send(
      new TransactWriteCommand({
        TransactItems: [
          {
            Put: {
              TableName: tableName,
              Item: unitItem,
              ConditionExpression: '#version = :expectedVersion AND #tenantId = :tenantId',
              ExpressionAttributeNames: { '#version': 'version', '#tenantId': 'tenantId' },
              ExpressionAttributeValues: {
                ':expectedVersion': params.expectedVersion,
                ':tenantId': ctx.tenantId,
              },
            },
          },
          reservationClaim,
          idempotencyItem,
          auditResult.transactItem,
        ],
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    return { ok: true, value: updatedUnit, confirmation: 'COMMITTED' };
  } catch (error: unknown) {
    const mapped = mapDynamoDbError(error, {
      correlationId: ctx.correlationId,
      conditionType: 'COMPOSITE',
      fields: ['unitId', 'lifecycleState'],
    });
    return { ok: false, outcome: mapped };
  }
}

// ─── Release Reservation ─────────────────────────────────────────────────────

/**
 * Releases a reservation claim and transitions unit back to IN_STOCK.
 *
 * Flow:
 * 1. Check idempotency
 * 2. Read current unit (strong)
 * 3. Validate transition from RESERVED → IN_STOCK
 * 4. Execute transaction: unit update + release claim + idempotency + audit
 */
export async function releaseReservationHandler(
  ctx: TenantContextWire,
  unitId: string,
  reservationId: string,
  params: ReleaseReservationParams,
  deps: ReservationHandlerDependencies,
): Promise<ReservationOutcome<ImeiUnit>> {
  const { client, tableName, repository, auditService } = deps;

  // 1. Idempotency check
  const idempotencyResult = await checkIdempotency(
    client, tableName, ctx, params.operationId, params.mutationFingerprint,
  );
  if (idempotencyResult.outcome === 'REPLAY') {
    return { ok: true, replay: true, status: idempotencyResult.status };
  }
  if (idempotencyResult.outcome === 'FINGERPRINT_MISMATCH') {
    return {
      ok: false,
      outcome: {
        code: 'IDEMPOTENCY_MISMATCH',
        category: 'conflict',
        retryable: false,
        statePreserved: true,
        fields: ['operationId', 'mutationFingerprint'],
        httpStatus: 409,
        correlationId: ctx.correlationId,
      },
    };
  }

  // 2. Read current unit
  const existing = await repository.getEntityAggregate(
    ctx, 'IMEI_UNIT', unitId, { consistency: 'strong', skPrefix: 'META#' },
  );
  if (existing.items.length === 0) {
    return {
      ok: false,
      outcome: {
        code: 'ENTITY_NOT_FOUND',
        category: 'not_found',
        retryable: false,
        statePreserved: true,
        fields: ['unitId'],
        httpStatus: 404,
        correlationId: ctx.correlationId,
      },
    };
  }

  const currentUnit = existing.items[0] as unknown as ImeiUnit;

  // 3. Validate transition RESERVED → IN_STOCK
  const transitionCmd: TransitionCommand = {
    targetState: DeviceLifecycleState.IN_STOCK,
    expectedVersion: currentUnit.version,
    actor: ctx.subjectId,
    reason: 'Reservation released',
  };
  const transitionResult = validateTransition(currentUnit, transitionCmd);
  if (!transitionResult.ok) {
    return {
      ok: false,
      outcome: {
        code: 'LIFECYCLE_TRANSITION_DENIED',
        category: 'conflict',
        retryable: false,
        statePreserved: true,
        fields: ['lifecycleState'],
        httpStatus: 409,
        correlationId: ctx.correlationId,
      },
    };
  }

  const event = transitionResult.value;
  const updatedUnit = applyTransition(currentUnit, event);

  // 4. Build transaction: update unit + release claim + idempotency + audit
  const unitItem = buildReservationUnitDynamoItem(ctx, updatedUnit, undefined);
  const releaseClaimItem = buildReleaseClaimTransactItem(
    tableName, ctx, 'RESERVATION', unitId, reservationId, currentUnit.version,
  );
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', unitId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId: unitId,
    action: 'RESERVATION_RELEASED',
    operationId: params.operationId,
    beforeState: currentUnit,
    afterState: updatedUnit,
    reason: 'Reservation released',
  });

  try {
    const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');
    await client.send(
      new TransactWriteCommand({
        TransactItems: [
          {
            Put: {
              TableName: tableName,
              Item: unitItem,
              ConditionExpression: '#version = :expectedVersion AND #tenantId = :tenantId',
              ExpressionAttributeNames: { '#version': 'version', '#tenantId': 'tenantId' },
              ExpressionAttributeValues: {
                ':expectedVersion': currentUnit.version,
                ':tenantId': ctx.tenantId,
              },
            },
          },
          releaseClaimItem,
          idempotencyItem,
          auditResult.transactItem,
        ],
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    return { ok: true, value: updatedUnit, confirmation: 'COMMITTED' };
  } catch (error: unknown) {
    const mapped = mapDynamoDbError(error, {
      correlationId: ctx.correlationId,
      conditionType: 'COMPOSITE',
      fields: ['unitId', 'reservationId'],
    });
    return { ok: false, outcome: mapped };
  }
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

function buildReservationUnitDynamoItem(
  ctx: TenantContextWire,
  unit: ImeiUnit,
  customerId: string | undefined,
): Record<string, unknown> {
  const pk = buildEntityAggregatePK(ctx.tenantId, 'IMEI_UNIT', unit.entityId);
  const sk = encodeSK('META', 'IMEI_UNIT');
  const gsi1pk = buildUnitLifecycleGSI1PK(ctx.tenantId, unit.lifecycleState);
  const gsi1sk = encodeGSI1SK(unit.updatedAt, unit.entityId);

  return {
    PK: pk,
    SK: sk,
    GSI1PK: gsi1pk,
    GSI1SK: gsi1sk,
    tenantId: ctx.tenantId,
    entityType: 'IMEI_UNIT',
    entityId: unit.entityId,
    version: unit.version,
    dataModelVersion: unit.dataModelVersion,
    imei: unit.imei,
    lifecycleState: unit.lifecycleState,
    condition: unit.condition,
    ownershipSource: unit.ownershipSource,
    brand: unit.brand,
    model: unit.model,
    ...(unit.color !== undefined && { color: unit.color }),
    ...(unit.storage !== undefined && { storage: unit.storage }),
    acquisitionCost: unit.acquisitionCost,
    salePrice: unit.salePrice,
    ...(unit.marketValuation !== undefined && { marketValuation: unit.marketValuation }),
    ...(unit.warrantyStartDate !== undefined && { warrantyStartDate: unit.warrantyStartDate }),
    ...(unit.warrantyEndDate !== undefined && { warrantyEndDate: unit.warrantyEndDate }),
    ...(unit.warrantyProvider !== undefined && { warrantyProvider: unit.warrantyProvider }),
    ...(customerId !== undefined && { customerId }),
    ...(unit.saleInvoiceId !== undefined && { saleInvoiceId: unit.saleInvoiceId }),
    ...(unit.soldAt !== undefined && { soldAt: unit.soldAt }),
    ...(unit.supplierId !== undefined && { supplierId: unit.supplierId }),
    ...(unit.exchangeId !== undefined && { exchangeId: unit.exchangeId }),
    ...(unit.intakeId !== undefined && { intakeId: unit.intakeId }),
    ...(unit.evidenceRefs !== undefined && unit.evidenceRefs.length > 0 && { evidenceRefs: unit.evidenceRefs }),
    createdAt: unit.createdAt,
    updatedAt: unit.updatedAt,
  };
}
