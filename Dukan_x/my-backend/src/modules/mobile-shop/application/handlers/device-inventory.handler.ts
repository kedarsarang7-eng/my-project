/**
 * Device Inventory Handler
 *
 * Manages IMEI unit creation, version-conditional updates, and bounded list queries.
 * Every operation: check idempotency → validate → build transaction plan → execute → map outcome.
 *
 * Requirements: 4.1–4.7, 8.12
 */

import { randomUUID } from 'crypto';
import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire, Money, EvidenceReference } from '../../schemas/common.schema';
import type { Result } from '../../domain/device-lifecycle';
import { DeviceLifecycleState } from '../../domain/device-lifecycle';
import {
  DeviceCondition,
  OwnershipSource,
  CURRENT_IMEI_UNIT_DATA_MODEL_VERSION,
  createImeiUnit as domainCreateImeiUnit,
  type ImeiUnit,
  type CreateImeiUnitParams,
} from '../../domain/imei-unit';
import { validateImei, type NormalizedImei } from '../../domain/imei-validator';
import { checkIdempotency, type IdempotencyCheckResult } from '../../persistence/idempotency';
import {
  buildClaimTransactItem,
  buildIdempotencyTransactItem,
} from '../../persistence/transaction-items';
import { buildAuditTransactItem, buildAuditEventItem } from '../../persistence/audit-events';
import { AuditEventService, type AuditEventResult } from '../audit-service';
import { mapDynamoDbError, type DeterministicOutcome } from '../error-mapper';
import {
  buildEntityAggregatePK,
  encodeSK,
  encodeGSI1SK,
  buildUnitLifecycleGSI1PK,
} from '../../persistence/key-codec';
import { MODEL_VERSION_CONFIG } from '../../config/model-version.config';
import type { PaginationParams } from '../../persistence/access-patterns';
import { MobileShopRepository } from '../../persistence/mobile-shop.repository';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface CreateImeiUnitHandlerParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly imei: string;
  readonly condition: DeviceCondition;
  readonly ownershipSource: OwnershipSource;
  readonly brand: string;
  readonly model: string;
  readonly color?: string;
  readonly storage?: string;
  readonly acquisitionCost: Money;
  readonly salePrice: Money;
  readonly marketValuation?: Money;
  readonly warrantyStartDate?: string;
  readonly warrantyEndDate?: string;
  readonly warrantyProvider?: string;
  readonly supplierId?: string;
  readonly evidenceRefs?: readonly EvidenceReference[];
}

export interface UpdateImeiUnitHandlerParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly expectedVersion: number;
  readonly condition?: DeviceCondition;
  readonly brand?: string;
  readonly model?: string;
  readonly color?: string;
  readonly storage?: string;
  readonly salePrice?: Money;
  readonly marketValuation?: Money;
  readonly warrantyStartDate?: string;
  readonly warrantyEndDate?: string;
  readonly warrantyProvider?: string;
}

export interface ListImeiUnitsFilters {
  readonly lifecycleState?: string;
  readonly pagination?: PaginationParams;
  readonly scanForward?: boolean;
}

export type HandlerOutcome<T> =
  | { readonly ok: true; readonly value: T; readonly confirmation: 'COMMITTED' }
  | { readonly ok: false; readonly outcome: DeterministicOutcome }
  | { readonly ok: true; readonly replay: true; readonly status: string };

export interface HandlerDependencies {
  readonly client: DynamoDBDocumentClient;
  readonly tableName: string;
  readonly repository: MobileShopRepository;
  readonly auditService: AuditEventService;
}

// ─── Create IMEI Unit ────────────────────────────────────────────────────────

/**
 * Creates a new IMEI unit with atomic claim, idempotency, and audit event.
 *
 * Flow:
 * 1. Check idempotency (replay/fingerprint mismatch)
 * 2. Validate IMEI (normalization, length, Luhn)
 * 3. Build domain entity
 * 4. Execute DynamoDB TransactWriteItems: unit + IMEI claim + idempotency + audit
 * 5. Return committed outcome with authoritative confirmation
 */
export async function createImeiUnitHandler(
  ctx: TenantContextWire,
  params: CreateImeiUnitHandlerParams,
  deps: HandlerDependencies,
): Promise<HandlerOutcome<ImeiUnit>> {
  const { client, tableName, auditService } = deps;

  // 1. Idempotency check
  const idempotencyResult = await checkIdempotency(
    client,
    tableName,
    ctx,
    params.operationId,
    params.mutationFingerprint,
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

  // 2. Validate IMEI
  const imeiResult = validateImei(params.imei);
  if (!imeiResult.ok) {
    return {
      ok: false,
      outcome: {
        code: imeiResult.error.code,
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: [imeiResult.error.field],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }
  const normalizedImei: NormalizedImei = imeiResult.value;

  // 3. Build domain entity
  const entityId = randomUUID();
  const domainParams: CreateImeiUnitParams = {
    tenantId: ctx.tenantId,
    entityId,
    imei: normalizedImei,
    condition: params.condition,
    ownershipSource: params.ownershipSource,
    brand: params.brand,
    model: params.model,
    color: params.color,
    storage: params.storage,
    acquisitionCost: params.acquisitionCost,
    salePrice: params.salePrice,
    marketValuation: params.marketValuation,
    warrantyStartDate: params.warrantyStartDate,
    warrantyEndDate: params.warrantyEndDate,
    warrantyProvider: params.warrantyProvider,
    supplierId: params.supplierId,
    evidenceRefs: params.evidenceRefs,
    isSecondHand: false,
  };
  const unit = domainCreateImeiUnit(domainParams);

  // 4. Build transaction items
  const now = unit.createdAt;
  const unitItem = buildUnitDynamoItem(ctx, unit);
  const claimItem = buildClaimTransactItem(
    tableName, ctx, 'IMEI', normalizedImei, entityId, 1,
  );
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', entityId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId,
    action: 'LIFECYCLE_TRANSITION',
    operationId: params.operationId,
    afterState: unit,
    reason: 'Unit created',
  });

  // 5. Execute atomic transaction
  try {
    const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');
    await client.send(
      new TransactWriteCommand({
        TransactItems: [
          {
            Put: {
              TableName: tableName,
              Item: unitItem,
              ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
            },
          },
          claimItem,
          idempotencyItem,
          auditResult.transactItem,
        ],
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    return { ok: true, value: unit, confirmation: 'COMMITTED' };
  } catch (error: unknown) {
    const mapped = mapDynamoDbError(error, {
      correlationId: ctx.correlationId,
      conditionType: 'COMPOSITE',
      fields: ['imei'],
    });
    return { ok: false, outcome: mapped };
  }
}

// ─── Update IMEI Unit ────────────────────────────────────────────────────────

/**
 * Version-conditional update of an IMEI unit with audit trail.
 *
 * Flow:
 * 1. Check idempotency
 * 2. Read current unit (strong consistency)
 * 3. Apply update fields
 * 4. Execute conditional Put + idempotency + audit in one transaction
 */
export async function updateImeiUnitHandler(
  ctx: TenantContextWire,
  unitId: string,
  params: UpdateImeiUnitHandlerParams,
  deps: HandlerDependencies,
): Promise<HandlerOutcome<ImeiUnit>> {
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

  // 2. Read current unit with strong consistency
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

  const currentItem = existing.items[0] as unknown as ImeiUnit & { PK: string; SK: string };
  if (currentItem.version !== params.expectedVersion) {
    return {
      ok: false,
      outcome: {
        code: 'VERSION_CONFLICT',
        category: 'conflict',
        retryable: true,
        statePreserved: true,
        fields: ['expectedVersion'],
        httpStatus: 409,
        correlationId: ctx.correlationId,
      },
    };
  }

  // 3. Apply updates
  const now = new Date().toISOString();
  const updatedUnit: ImeiUnit = {
    ...currentItem,
    condition: params.condition ?? currentItem.condition,
    brand: params.brand ?? currentItem.brand,
    model: params.model ?? currentItem.model,
    color: params.color !== undefined ? params.color : currentItem.color,
    storage: params.storage !== undefined ? params.storage : currentItem.storage,
    salePrice: params.salePrice ?? currentItem.salePrice,
    marketValuation: params.marketValuation !== undefined ? params.marketValuation : currentItem.marketValuation,
    warrantyStartDate: params.warrantyStartDate !== undefined ? params.warrantyStartDate : currentItem.warrantyStartDate,
    warrantyEndDate: params.warrantyEndDate !== undefined ? params.warrantyEndDate : currentItem.warrantyEndDate,
    warrantyProvider: params.warrantyProvider !== undefined ? params.warrantyProvider : currentItem.warrantyProvider,
    version: currentItem.version + 1,
    updatedAt: now,
  };

  // 4. Build transaction items
  const unitItem = buildUnitDynamoItem(ctx, updatedUnit);
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', unitId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId: unitId,
    action: 'LIFECYCLE_TRANSITION',
    operationId: params.operationId,
    beforeState: currentItem,
    afterState: updatedUnit,
    reason: 'Unit updated',
  });

  // 5. Execute conditional transaction
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

// ─── List IMEI Units ─────────────────────────────────────────────────────────

/**
 * Lists IMEI units filtered by lifecycle state via bounded GSI query (AP-03).
 */
export async function listImeiUnitsHandler(
  ctx: TenantContextWire,
  filters: ListImeiUnitsFilters,
  deps: HandlerDependencies,
): Promise<Result<{ items: readonly Record<string, unknown>[]; hasMore: boolean }, DeterministicOutcome>> {
  const { repository } = deps;

  const state = filters.lifecycleState ?? DeviceLifecycleState.IN_STOCK;

  try {
    const result = await repository.queryUnitsByLifecycleState(
      ctx,
      state,
      filters.pagination,
      { scanForward: filters.scanForward },
    );

    return {
      ok: true,
      value: { items: result.items, hasMore: result.hasMore },
    };
  } catch (error: unknown) {
    const mapped = mapDynamoDbError(error, {
      correlationId: ctx.correlationId,
      conditionType: 'UNKNOWN',
    });
    return { ok: false, error: mapped };
  }
}

// ─── Get IMEI Unit by IMEI ───────────────────────────────────────────────────

/**
 * Looks up an IMEI unit by normalized IMEI value via AP-02 claim → AP-01 aggregate.
 *
 * Flow:
 * 1. Validate and normalize IMEI
 * 2. Look up claim via AP-02 (strong read)
 * 3. Extract ownerEntityId from claim
 * 4. Retrieve full unit aggregate via AP-01
 */
export async function getImeiUnitByImeiHandler(
  ctx: TenantContextWire,
  imei: string,
  deps: HandlerDependencies,
): Promise<HandlerOutcome<ImeiUnit>> {
  const { repository } = deps;

  // 1. Validate IMEI
  const imeiResult = validateImei(imei);
  if (!imeiResult.ok) {
    return {
      ok: false,
      outcome: {
        code: imeiResult.error.code,
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: [imeiResult.error.field],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }
  const normalizedImei: NormalizedImei = imeiResult.value;

  // 2. Look up IMEI claim via AP-02
  const claimResult = await repository.lookupImeiClaim(ctx, normalizedImei);
  if (!claimResult.item) {
    return {
      ok: false,
      outcome: {
        code: 'ENTITY_NOT_FOUND',
        category: 'not_found',
        retryable: false,
        statePreserved: true,
        fields: ['imei'],
        httpStatus: 404,
        correlationId: ctx.correlationId,
      },
    };
  }

  // 3. Extract owner entity ID from claim
  const claim = claimResult.item as { ownerEntityId?: string };
  if (!claim.ownerEntityId) {
    return {
      ok: false,
      outcome: {
        code: 'ENTITY_NOT_FOUND',
        category: 'not_found',
        retryable: false,
        statePreserved: true,
        fields: ['imei'],
        httpStatus: 404,
        correlationId: ctx.correlationId,
      },
    };
  }

  // 4. Retrieve full unit aggregate via AP-01
  const unitResult = await repository.getEntityAggregate(
    ctx, 'IMEI_UNIT', claim.ownerEntityId, { consistency: 'strong', skPrefix: 'META#' },
  );
  if (unitResult.items.length === 0) {
    return {
      ok: false,
      outcome: {
        code: 'ENTITY_NOT_FOUND',
        category: 'not_found',
        retryable: false,
        statePreserved: true,
        fields: ['imei'],
        httpStatus: 404,
        correlationId: ctx.correlationId,
      },
    };
  }

  const unit = unitResult.items[0] as unknown as ImeiUnit;
  return { ok: true, value: unit, confirmation: 'COMMITTED' };
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

/**
 * Builds a DynamoDB Put-ready item for an IMEI unit with proper key encoding.
 */
function buildUnitDynamoItem(
  ctx: TenantContextWire,
  unit: ImeiUnit,
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
    ...(unit.customerId !== undefined && { customerId: unit.customerId }),
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
