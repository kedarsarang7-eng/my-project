/**
 * Demo Unit Handler
 *
 * Manages assignment and return of demo units. Transitions units to DEMO state
 * (excluded from saleable quantity) and back to IN_STOCK or SOLD.
 *
 * Requirements: 4.5, 8.12
 */

import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../../schemas/common.schema';
import {
  DeviceLifecycleState,
  validateTransition,
  type TransitionCommand,
} from '../../domain/device-lifecycle';
import { applyTransition, type ImeiUnit } from '../../domain/imei-unit';
import { checkIdempotency } from '../../persistence/idempotency';
import { buildIdempotencyTransactItem } from '../../persistence/transaction-items';
import { AuditEventService } from '../audit-service';
import { mapDynamoDbError, type DeterministicOutcome } from '../error-mapper';
import {
  buildEntityAggregatePK,
  encodeSK,
  encodeGSI1SK,
  buildUnitLifecycleGSI1PK,
} from '../../persistence/key-codec';
import { MobileShopRepository } from '../../persistence/mobile-shop.repository';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface AssignDemoParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly expectedVersion: number;
  readonly reason: string;
  readonly assignedTo?: string;
}

export interface ReturnFromDemoParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly expectedVersion: number;
  readonly targetState: DeviceLifecycleState.IN_STOCK | DeviceLifecycleState.SOLD;
  readonly reason: string;
  readonly customerId?: string;
}

export interface DemoHandlerDependencies {
  readonly client: DynamoDBDocumentClient;
  readonly tableName: string;
  readonly repository: MobileShopRepository;
  readonly auditService: AuditEventService;
}

export type DemoOutcome<T> =
  | { readonly ok: true; readonly value: T; readonly confirmation: 'COMMITTED' }
  | { readonly ok: false; readonly outcome: DeterministicOutcome }
  | { readonly ok: true; readonly replay: true; readonly status: string };

// ─── Assign Demo ─────────────────────────────────────────────────────────────

/**
 * Assigns a device as a demo unit (IN_STOCK → DEMO).
 *
 * Flow:
 * 1. Check idempotency
 * 2. Read current unit (strong)
 * 3. Validate lifecycle transition to DEMO
 * 4. Execute transaction: unit update + idempotency + audit
 */
export async function assignDemoHandler(
  ctx: TenantContextWire,
  unitId: string,
  params: AssignDemoParams,
  deps: DemoHandlerDependencies,
): Promise<DemoOutcome<ImeiUnit>> {
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

  // 3. Validate transition to DEMO
  const transitionCmd: TransitionCommand = {
    targetState: DeviceLifecycleState.DEMO,
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

  // 4. Build and execute transaction
  const unitItem = buildDemoUnitDynamoItem(ctx, updatedUnit, params.assignedTo);
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', unitId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId: unitId,
    action: 'LIFECYCLE_TRANSITION',
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
      conditionType: 'VERSION',
      fields: ['expectedVersion'],
    });
    return { ok: false, outcome: mapped };
  }
}

// ─── Return From Demo ────────────────────────────────────────────────────────

/**
 * Returns a demo unit back to IN_STOCK or marks it as SOLD.
 *
 * Flow:
 * 1. Check idempotency
 * 2. Read current unit (strong, must be in DEMO state)
 * 3. Validate transition to target state
 * 4. Execute transaction: unit update + idempotency + audit
 */
export async function returnFromDemoHandler(
  ctx: TenantContextWire,
  unitId: string,
  params: ReturnFromDemoParams,
  deps: DemoHandlerDependencies,
): Promise<DemoOutcome<ImeiUnit>> {
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

  // 3. Validate transition from DEMO
  const transitionCmd: TransitionCommand = {
    targetState: params.targetState,
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

  // 4. Build and execute transaction
  const unitItem = buildDemoUnitDynamoItem(ctx, updatedUnit, undefined, params.customerId);
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', unitId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId: unitId,
    action: 'LIFECYCLE_TRANSITION',
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
      conditionType: 'VERSION',
      fields: ['expectedVersion'],
    });
    return { ok: false, outcome: mapped };
  }
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

function buildDemoUnitDynamoItem(
  ctx: TenantContextWire,
  unit: ImeiUnit,
  assignedTo?: string,
  customerId?: string,
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
    ...(assignedTo !== undefined && { demoAssignedTo: assignedTo }),
    createdAt: unit.createdAt,
    updatedAt: unit.updatedAt,
  };
}
