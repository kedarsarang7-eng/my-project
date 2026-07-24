/**
 * Exchange Handler — MobileShop Application Layer
 *
 * Manages device exchanges: creation (with atomic dual-device lifecycle transitions)
 * and listing. Every handler follows: idempotency check → validate → transaction plan → execute → map outcome.
 *
 * Exchange transitions BOTH devices atomically:
 *   Old device → EXCHANGED (terminal state)
 *   New device → SOLD (or remains IN_STOCK if exchange is a trade-in credit)
 *
 * Requirements: 5.4, 5.8, 8.12
 */

import { randomUUID } from 'crypto';
import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire, Money, PaginatedResponse } from '../../schemas/common.schema';
import type { ExchangeStatus } from '../../schemas/exchange.schema';
import { DeviceLifecycleState } from '../../domain/device-lifecycle';
import { validateMoney } from '../../domain/monetary-validator';
import { AuditEventService } from '../audit-service';
import { checkIdempotency } from '../../persistence/idempotency';
import { buildIdempotencyTransactItem } from '../../persistence/transaction-items';
import { mapDynamoDbError, type ErrorMappingContext } from '../error-mapper';
import { MobileShopRepository } from '../../persistence/mobile-shop.repository';
import {
  buildEntityAggregatePK,
  encodeMetaSK,
  buildStatusGSI1PK,
  encodeGSI1SK,
} from '../../persistence/key-codec';
import { MODEL_VERSION_CONFIG } from '../../config/model-version.config';
import { ERROR_CODES } from '../../config/error-codes.config';
import type { DeterministicOutcome } from '../error-mapper';
import type { Result } from '../../domain/device-lifecycle';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface CreateExchangeParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly customerId: string;
  readonly customerName: string;

  // Old device (being exchanged in)
  readonly oldDeviceImei: string;
  readonly oldDeviceUnitId: string;
  readonly oldDeviceBrand: string;
  readonly oldDeviceModel: string;
  readonly oldDeviceCondition: string;
  readonly oldDeviceValuation: Money;

  // New device (being given out)
  readonly newDeviceImei: string;
  readonly newDeviceUnitId: string;
  readonly newDeviceBrand: string;
  readonly newDeviceModel: string;
  readonly newDeviceSalePrice: Money;

  // Financial
  readonly adjustmentAmount: Money;
  readonly adjustmentDirection: 'CUSTOMER_PAYS' | 'CUSTOMER_RECEIVES';

  // Approval
  readonly approvedBy: string;

  readonly invoiceId?: string;
  readonly notes?: string;
  readonly dataModelVersion: number;
}

export interface ListExchangesFilters {
  readonly status: string;
  readonly limit?: number;
  readonly continuationToken?: string;
  readonly exclusiveStartKey?: Record<string, unknown>;
  readonly scanForward?: boolean;
}

export interface ExchangeOutcome {
  readonly exchangeId: string;
  readonly status: ExchangeStatus;
  readonly version: number;
  readonly operationId: string;
}

// ─── Handler Context ─────────────────────────────────────────────────────────

export interface ExchangeHandlerDeps {
  readonly client: DynamoDBDocumentClient;
  readonly tableName: string;
  readonly repository: MobileShopRepository;
  readonly auditService: AuditEventService;
}

// ─── Saleable states for old device (must be tenant-owned and saleable) ──────

const OLD_DEVICE_ALLOWED_STATES: ReadonlySet<string> = new Set([
  DeviceLifecycleState.SOLD,
  DeviceLifecycleState.IN_STOCK,
  DeviceLifecycleState.RETURNED,
]);

const NEW_DEVICE_ALLOWED_STATES: ReadonlySet<string> = new Set([
  DeviceLifecycleState.IN_STOCK,
  DeviceLifecycleState.RESERVED,
]);

// ─── Create Exchange ─────────────────────────────────────────────────────────

/**
 * Creates a device exchange, transitioning both devices atomically:
 * - Old device → EXCHANGED
 * - New device → SOLD
 *
 * Validates:
 * - Old device is tenant-owned and in a saleable state
 * - New device IMEI exists and is in stock
 * - Valuation and financial adjustment
 * - Approval
 */
export async function createExchange(
  deps: ExchangeHandlerDeps,
  ctx: TenantContextWire,
  params: CreateExchangeParams,
): Promise<Result<ExchangeOutcome, DeterministicOutcome>> {
  const { client, tableName, repository, auditService } = deps;

  // 1. Idempotency check
  const idempotencyResult = await checkIdempotency(
    client, tableName, ctx, params.operationId, params.mutationFingerprint,
  );

  if (idempotencyResult.outcome === 'REPLAY') {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.IDEMPOTENCY_REPLAY, ctx.correlationId, []),
    };
  }
  if (idempotencyResult.outcome === 'FINGERPRINT_MISMATCH') {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.IDEMPOTENCY_MISMATCH, ctx.correlationId, ['operationId', 'mutationFingerprint']),
    };
  }

  // 2. Validate old device — must be tenant-owned
  const oldClaimResult = await repository.lookupImeiClaim(ctx, params.oldDeviceImei);
  if (!oldClaimResult.item) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['oldDeviceImei']),
    };
  }

  const oldClaim = oldClaimResult.item as Record<string, unknown>;
  if (oldClaim['tenantId'] !== ctx.tenantId) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['oldDeviceImei']),
    };
  }

  // 3. Read old device unit (strong consistency)
  const oldUnitAgg = await repository.getEntityAggregate(ctx, 'UNIT', params.oldDeviceUnitId, {
    consistency: 'strong',
    skPrefix: 'META#',
  });
  const oldUnit = oldUnitAgg.items[0] as Record<string, unknown> | undefined;
  if (!oldUnit) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['oldDeviceUnitId']),
    };
  }

  const oldUnitState = oldUnit['lifecycleState'] as string;
  if (!OLD_DEVICE_ALLOWED_STATES.has(oldUnitState)) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.IMEI_LIFECYCLE_INVALID, ctx.correlationId, ['oldDeviceImei']),
    };
  }
  const oldUnitVersion = oldUnit['version'] as number;

  // 4. Validate new device — must be in stock
  const newClaimResult = await repository.lookupImeiClaim(ctx, params.newDeviceImei);
  if (!newClaimResult.item) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['newDeviceImei']),
    };
  }

  const newClaim = newClaimResult.item as Record<string, unknown>;
  if (newClaim['tenantId'] !== ctx.tenantId) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['newDeviceImei']),
    };
  }

  const newUnitAgg = await repository.getEntityAggregate(ctx, 'UNIT', params.newDeviceUnitId, {
    consistency: 'strong',
    skPrefix: 'META#',
  });
  const newUnit = newUnitAgg.items[0] as Record<string, unknown> | undefined;
  if (!newUnit) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['newDeviceUnitId']),
    };
  }

  const newUnitState = newUnit['lifecycleState'] as string;
  if (!NEW_DEVICE_ALLOWED_STATES.has(newUnitState)) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.IMEI_LIFECYCLE_INVALID, ctx.correlationId, ['newDeviceImei']),
    };
  }
  const newUnitVersion = newUnit['version'] as number;

  // 5. Validate financial adjustment
  const valuationResult = validateMoney(params.oldDeviceValuation, 'oldDeviceValuation');
  if (!valuationResult.ok) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.MONETARY_VALUE_INVALID, ctx.correlationId, ['oldDeviceValuation']),
    };
  }

  const adjustmentResult = validateMoney(params.adjustmentAmount, 'adjustmentAmount');
  if (!adjustmentResult.ok) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.MONETARY_VALUE_INVALID, ctx.correlationId, ['adjustmentAmount']),
    };
  }

  // 6. Validate approval
  if (!params.approvedBy) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['approvedBy']),
    };
  }

  // 7. Build exchange entity
  const exchangeId = randomUUID();
  const now = new Date().toISOString();

  const exchangeItem: Record<string, unknown> = {
    PK: buildEntityAggregatePK(ctx.tenantId, 'EXCHANGE', exchangeId),
    SK: encodeMetaSK('EXCHANGE'),
    GSI1PK: buildStatusGSI1PK(ctx.tenantId, 'EXCHANGE', 'COMPLETED'),
    GSI1SK: encodeGSI1SK(now, exchangeId),
    tenantId: ctx.tenantId,
    entityType: 'EXCHANGE',
    entityId: exchangeId,
    customerId: params.customerId,
    customerName: params.customerName,
    status: 'COMPLETED' as ExchangeStatus,
    oldDeviceImei: params.oldDeviceImei,
    oldDeviceUnitId: params.oldDeviceUnitId,
    oldDeviceBrand: params.oldDeviceBrand,
    oldDeviceModel: params.oldDeviceModel,
    oldDeviceCondition: params.oldDeviceCondition,
    oldDeviceValuation: params.oldDeviceValuation,
    newDeviceImei: params.newDeviceImei,
    newDeviceUnitId: params.newDeviceUnitId,
    newDeviceBrand: params.newDeviceBrand,
    newDeviceModel: params.newDeviceModel,
    newDeviceSalePrice: params.newDeviceSalePrice,
    adjustmentAmount: params.adjustmentAmount,
    adjustmentDirection: params.adjustmentDirection,
    approvedBy: params.approvedBy,
    approvedAt: now,
    invoiceId: params.invoiceId ?? null,
    notes: params.notes ?? null,
    operationId: params.operationId,
    version: 1,
    dataModelVersion: params.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
    createdAt: now,
    updatedAt: now,
  };

  // 8. Build old device transition: current → EXCHANGED
  const oldDeviceTransition = buildDeviceLifecycleUpdateItem(
    tableName, ctx, params.oldDeviceUnitId, oldUnitVersion,
    DeviceLifecycleState.EXCHANGED, now, exchangeId,
  );

  // 9. Build new device transition: IN_STOCK/RESERVED → SOLD
  const newDeviceTransition = buildDeviceLifecycleUpdateItem(
    tableName, ctx, params.newDeviceUnitId, newUnitVersion,
    DeviceLifecycleState.SOLD, now, undefined, params.customerId,
  );

  // 10. Build audit event
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'EXCHANGE',
    entityId: exchangeId,
    action: 'EXCHANGE_COMPLETED',
    operationId: params.operationId,
    afterState: {
      oldDeviceImei: params.oldDeviceImei,
      newDeviceImei: params.newDeviceImei,
      adjustmentDirection: params.adjustmentDirection,
    },
    reason: `Exchange: ${params.oldDeviceBrand} ${params.oldDeviceModel} → ${params.newDeviceBrand} ${params.newDeviceModel}`,
  });

  // 11. Build idempotency item
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint,
    'COMMITTED', exchangeId, params.dataModelVersion,
  );

  // 12. Execute transaction — all items atomically
  const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');

  const transactItems: any[] = [
    { Put: { TableName: tableName, Item: exchangeItem, ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)' } },
    oldDeviceTransition,
    newDeviceTransition,
    auditResult.transactItem,
    idempotencyItem,
  ];

  try {
    await client.send(new TransactWriteCommand({
      TransactItems: transactItems,
      ReturnConsumedCapacity: 'TOTAL',
    }));
  } catch (error: unknown) {
    const errCtx: ErrorMappingContext = {
      correlationId: ctx.correlationId,
      conditionType: 'COMPOSITE',
      fields: ['oldDeviceImei', 'newDeviceImei', 'operationId'],
    };
    return { ok: false, error: mapDynamoDbError(error, errCtx) };
  }

  return {
    ok: true,
    value: { exchangeId, status: 'COMPLETED', version: 1, operationId: params.operationId },
  };
}

// ─── List Exchanges ──────────────────────────────────────────────────────────

/**
 * Lists exchanges filtered by status using AP-08 (bounded GSI1 Query).
 */
export async function listExchanges(
  deps: ExchangeHandlerDeps,
  ctx: TenantContextWire,
  filters: ListExchangesFilters,
): Promise<Result<PaginatedResponse<Record<string, unknown>>, DeterministicOutcome>> {
  const { repository } = deps;

  if (!filters.status) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['status']),
    };
  }

  try {
    const result = await repository.queryByTypeAndStatus(
      ctx,
      'EXCHANGE',
      filters.status,
      {
        limit: filters.limit,
        exclusiveStartKey: filters.exclusiveStartKey,
      },
      { scanForward: filters.scanForward ?? false },
    );

    return {
      ok: true,
      value: {
        items: result.items,
        continuationToken: result.lastEvaluatedKey
          ? JSON.stringify(result.lastEvaluatedKey)
          : undefined,
        hasMore: !!result.lastEvaluatedKey,
      },
    };
  } catch (error: unknown) {
    const errCtx: ErrorMappingContext = {
      correlationId: ctx.correlationId,
      conditionType: 'UNKNOWN',
      fields: ['status'],
    };
    return { ok: false, error: mapDynamoDbError(error, errCtx) };
  }
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

function buildValidationOutcome(
  errorCode: typeof ERROR_CODES[keyof typeof ERROR_CODES],
  correlationId: string,
  fields: string[],
): DeterministicOutcome {
  return {
    code: errorCode.code,
    category: errorCode.category,
    retryable: errorCode.retryable,
    statePreserved: true,
    fields: fields.length > 0 ? fields : [...errorCode.fields],
    httpStatus: errorCode.httpStatus,
    correlationId,
  };
}

/**
 * Builds a transact Update item to change a device's lifecycle state.
 * Includes version condition for optimistic concurrency.
 */
function buildDeviceLifecycleUpdateItem(
  tableName: string,
  ctx: TenantContextWire,
  unitId: string,
  expectedVersion: number,
  targetState: DeviceLifecycleState,
  updatedAt: string,
  exchangeId?: string,
  customerId?: string,
): unknown {
  const pk = buildEntityAggregatePK(ctx.tenantId, 'UNIT', unitId);
  const sk = encodeMetaSK('UNIT');
  const newVersion = expectedVersion + 1;

  let updateExpression = 'SET #lifecycleState = :targetState, #version = :newVersion, #updatedAt = :updatedAt';
  const exprNames: Record<string, string> = {
    '#lifecycleState': 'lifecycleState',
    '#version': 'version',
    '#updatedAt': 'updatedAt',
    '#tenantId': 'tenantId',
  };
  const exprValues: Record<string, unknown> = {
    ':targetState': targetState,
    ':newVersion': newVersion,
    ':expectedVersion': expectedVersion,
    ':updatedAt': updatedAt,
    ':tenantId': ctx.tenantId,
  };

  if (exchangeId) {
    updateExpression += ', #exchangeId = :exchangeId';
    exprNames['#exchangeId'] = 'exchangeId';
    exprValues[':exchangeId'] = exchangeId;
  }
  if (customerId) {
    updateExpression += ', #customerId = :customerId, #soldAt = :soldAt';
    exprNames['#customerId'] = 'customerId';
    exprNames['#soldAt'] = 'soldAt';
    exprValues[':customerId'] = customerId;
    exprValues[':soldAt'] = updatedAt;
  }

  return {
    Update: {
      TableName: tableName,
      Key: { PK: pk, SK: sk },
      UpdateExpression: updateExpression,
      ConditionExpression: '#version = :expectedVersion AND #tenantId = :tenantId',
      ExpressionAttributeNames: exprNames,
      ExpressionAttributeValues: exprValues,
    },
  };
}
