/**
 * Device Return Handler
 *
 * Validates originating sale, return eligibility, physical IMEI match,
 * condition, and disposition. Transitions the IMEI unit to the target
 * lifecycle state and writes an immutable audit event.
 *
 * Requirements: 4.7, 8.12
 */

import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire, EvidenceReference } from '../../schemas/common.schema';
import {
  DeviceLifecycleState,
  validateTransition,
  type TransitionCommand,
} from '../../domain/device-lifecycle';
import { applyTransition, DeviceCondition, type ImeiUnit } from '../../domain/imei-unit';
import { validateImei, type NormalizedImei } from '../../domain/imei-validator';
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

export interface ProcessReturnParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly unitId: string;
  readonly saleInvoiceId: string;
  readonly physicalImei: string;
  readonly expectedVersion: number;
  readonly condition: DeviceCondition;
  readonly disposition: ReturnDisposition;
  readonly reason: string;
  readonly evidenceRefs?: readonly EvidenceReference[];
}

/** What happens to the device after return */
export type ReturnDisposition =
  | 'RETURN_TO_STOCK'
  | 'RETURN_AS_SECOND_HAND'
  | 'RETURN_AS_DAMAGED'
  | 'RETIRE';

export interface ReturnHandlerDependencies {
  readonly client: DynamoDBDocumentClient;
  readonly tableName: string;
  readonly repository: MobileShopRepository;
  readonly auditService: AuditEventService;
}

export type ReturnOutcome<T> =
  | { readonly ok: true; readonly value: T; readonly confirmation: 'COMMITTED' }
  | { readonly ok: false; readonly outcome: DeterministicOutcome }
  | { readonly ok: true; readonly replay: true; readonly status: string };

// ─── Disposition → Target State Mapping ──────────────────────────────────────

const DISPOSITION_STATE_MAP: Record<ReturnDisposition, DeviceLifecycleState> = {
  RETURN_TO_STOCK: DeviceLifecycleState.RETURNED,
  RETURN_AS_SECOND_HAND: DeviceLifecycleState.RETURNED,
  RETURN_AS_DAMAGED: DeviceLifecycleState.RETURNED,
  RETIRE: DeviceLifecycleState.RETURNED,
};

// ─── Process Return ──────────────────────────────────────────────────────────

/**
 * Processes a device return with full validation.
 *
 * Flow:
 * 1. Check idempotency
 * 2. Validate physical IMEI matches (normalization + comparison)
 * 3. Read current unit (strong consistency)
 * 4. Validate sale association and return eligibility
 * 5. Validate lifecycle transition (must be SOLD → RETURNED)
 * 6. Execute transaction: unit update + idempotency + audit
 */
export async function processReturnHandler(
  ctx: TenantContextWire,
  params: ProcessReturnParams,
  deps: ReturnHandlerDependencies,
): Promise<ReturnOutcome<ImeiUnit>> {
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

  // 2. Validate physical IMEI
  const imeiResult = validateImei(params.physicalImei);
  if (!imeiResult.ok) {
    return {
      ok: false,
      outcome: {
        code: imeiResult.error.code,
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['physicalImei'],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }
  const normalizedPhysicalImei: NormalizedImei = imeiResult.value;

  // 3. Read current unit
  const existing = await repository.getEntityAggregate(
    ctx, 'IMEI_UNIT', params.unitId, { consistency: 'strong', skPrefix: 'META#' },
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

  // 4. Validate sale association
  if (currentUnit.saleInvoiceId !== params.saleInvoiceId) {
    return {
      ok: false,
      outcome: {
        code: 'RETURN_SALE_MISMATCH',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['saleInvoiceId'],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }

  // Validate physical IMEI matches stored IMEI
  if (currentUnit.imei !== normalizedPhysicalImei) {
    return {
      ok: false,
      outcome: {
        code: 'RETURN_IMEI_MISMATCH',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['physicalImei'],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }

  // Validate return eligibility (unit must be SOLD)
  if (currentUnit.lifecycleState !== DeviceLifecycleState.SOLD) {
    return {
      ok: false,
      outcome: {
        code: 'RETURN_NOT_ELIGIBLE',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['lifecycleState'],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }

  // 5. Validate lifecycle transition SOLD → RETURNED
  const targetState = DeviceLifecycleState.RETURNED;
  const transitionCmd: TransitionCommand = {
    targetState,
    expectedVersion: params.expectedVersion,
    actor: ctx.subjectId,
    reason: params.reason,
    evidenceRefs: params.evidenceRefs,
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

  // 6. Build and execute transaction
  const unitItem = buildReturnedUnitDynamoItem(ctx, updatedUnit, params.condition, params.disposition);
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', params.unitId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId: params.unitId,
    action: 'RETURN_COMPLETED',
    operationId: params.operationId,
    beforeState: currentUnit,
    afterState: updatedUnit,
    reason: params.reason,
    evidenceRefs: params.evidenceRefs?.map(e => e.referenceId),
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

// ─── Process Return Disposition ──────────────────────────────────────────────

/** Parameters for processing the post-return disposition step */
export interface ProcessDispositionParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly unitId: string;
  readonly expectedVersion: number;
  readonly disposition: ReturnDisposition;
  readonly condition: DeviceCondition;
  readonly reason: string;
  readonly evidenceRefs?: readonly EvidenceReference[];
}

/**
 * Handles the RETURNED → target state based on disposition.
 * Called after processReturnHandler when the returned device needs final placement.
 *
 * Disposition mapping:
 * - RETURN_TO_STOCK → IN_STOCK
 * - RETURN_AS_SECOND_HAND → SECOND_HAND (via IN_STOCK intermediary in lifecycle graph)
 * - RETURN_AS_DAMAGED → DAMAGED
 * - RETIRE → RETIRED
 *
 * Flow:
 * 1. Check idempotency
 * 2. Read current unit (must be RETURNED)
 * 3. Validate lifecycle transition from RETURNED
 * 4. Execute transaction: unit update + idempotency + audit
 */
export async function processDispositionHandler(
  ctx: TenantContextWire,
  params: ProcessDispositionParams,
  deps: ReturnHandlerDependencies,
): Promise<ReturnOutcome<ImeiUnit>> {
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

  // 2. Read current unit (must be in RETURNED state)
  const existing = await repository.getEntityAggregate(
    ctx, 'IMEI_UNIT', params.unitId, { consistency: 'strong', skPrefix: 'META#' },
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

  // Validate unit is in RETURNED state
  if (currentUnit.lifecycleState !== DeviceLifecycleState.RETURNED) {
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

  // 3. Map disposition to target state
  const targetState = mapDispositionToTargetState(params.disposition);

  const transitionCmd: TransitionCommand = {
    targetState,
    expectedVersion: params.expectedVersion,
    actor: ctx.subjectId,
    reason: params.reason,
    evidenceRefs: params.evidenceRefs,
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
  const unitItem = buildReturnedUnitDynamoItem(ctx, updatedUnit, params.condition, params.disposition);
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', params.unitId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId: params.unitId,
    action: 'RETURN_DISPOSITION',
    operationId: params.operationId,
    beforeState: currentUnit,
    afterState: updatedUnit,
    reason: params.reason,
    evidenceRefs: params.evidenceRefs?.map(e => e.referenceId),
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

// ─── Disposition → Final State Mapping ───────────────────────────────────────

function mapDispositionToTargetState(disposition: ReturnDisposition): DeviceLifecycleState {
  switch (disposition) {
    case 'RETURN_TO_STOCK':
      return DeviceLifecycleState.IN_STOCK;
    case 'RETURN_AS_SECOND_HAND':
      return DeviceLifecycleState.SECOND_HAND;
    case 'RETURN_AS_DAMAGED':
      return DeviceLifecycleState.DAMAGED;
    case 'RETIRE':
      return DeviceLifecycleState.RETIRED;
  }
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

function buildReturnedUnitDynamoItem(
  ctx: TenantContextWire,
  unit: ImeiUnit,
  returnCondition: DeviceCondition,
  disposition: ReturnDisposition,
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
    condition: returnCondition,
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
    ...(unit.customerId !== undefined && { customerId: unit.customerId }),
    ...(unit.saleInvoiceId !== undefined && { saleInvoiceId: unit.saleInvoiceId }),
    ...(unit.soldAt !== undefined && { soldAt: unit.soldAt }),
    ...(unit.supplierId !== undefined && { supplierId: unit.supplierId }),
    ...(unit.exchangeId !== undefined && { exchangeId: unit.exchangeId }),
    ...(unit.intakeId !== undefined && { intakeId: unit.intakeId }),
    ...(unit.evidenceRefs !== undefined && unit.evidenceRefs.length > 0 && { evidenceRefs: unit.evidenceRefs }),
    returnDisposition: disposition,
    createdAt: unit.createdAt,
    updatedAt: unit.updatedAt,
  };
}
