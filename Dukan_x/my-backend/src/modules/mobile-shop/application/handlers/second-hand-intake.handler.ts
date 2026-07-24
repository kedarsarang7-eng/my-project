/**
 * Second-Hand Intake Handler
 *
 * Validates IMEI, seller identity, evidence status, inspection, valuation,
 * and exchange linkage. Creates a unit with SECOND_HAND initial state,
 * an IMEI claim, and an immutable audit event atomically.
 *
 * Requirements: 4.1–4.4, 8.12
 */

import { randomUUID } from 'crypto';
import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire, Money, EvidenceReference } from '../../schemas/common.schema';
import {
  DeviceCondition,
  OwnershipSource,
  createImeiUnit as domainCreateImeiUnit,
  type ImeiUnit,
  type CreateImeiUnitParams,
} from '../../domain/imei-unit';
import { validateImei, type NormalizedImei } from '../../domain/imei-validator';
import { checkIdempotency } from '../../persistence/idempotency';
import {
  buildClaimTransactItem,
  buildIdempotencyTransactItem,
} from '../../persistence/transaction-items';
import { AuditEventService } from '../audit-service';
import { mapDynamoDbError, type DeterministicOutcome } from '../error-mapper';
import {
  buildEntityAggregatePK,
  encodeSK,
  encodeGSI1SK,
  buildUnitLifecycleGSI1PK,
} from '../../persistence/key-codec';
import type { MobileShopRepository } from '../../persistence/mobile-shop.repository';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface CreateIntakeParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly imei: string;
  readonly sellerIdentityRef: string;
  readonly condition: DeviceCondition;
  readonly brand: string;
  readonly model: string;
  readonly color?: string;
  readonly storage?: string;
  readonly acquisitionCost: Money;
  readonly salePrice: Money;
  readonly marketValuation?: Money;
  readonly inspectionResult: 'PASS' | 'CONDITIONAL' | 'FAIL';
  readonly valuationApproved: boolean;
  readonly evidenceStatus: 'COMPLETE' | 'PARTIAL' | 'PENDING';
  readonly exchangeId?: string;
  readonly evidenceRefs?: readonly EvidenceReference[];
  readonly reason?: string;
}

export interface IntakeHandlerDependencies {
  readonly client: DynamoDBDocumentClient;
  readonly tableName: string;
  readonly repository: MobileShopRepository;
  readonly auditService: AuditEventService;
}

export type IntakeOutcome<T> =
  | { readonly ok: true; readonly value: T; readonly confirmation: 'COMMITTED' }
  | { readonly ok: false; readonly outcome: DeterministicOutcome }
  | { readonly ok: true; readonly replay: true; readonly status: string };

// ─── Create Intake ───────────────────────────────────────────────────────────

/**
 * Accepts a second-hand device intake after full validation.
 *
 * Flow:
 * 1. Check idempotency
 * 2. Validate IMEI format
 * 3. Validate business rules (inspection, valuation, evidence)
 * 4. Build IMEI unit with SECOND_HAND initial state
 * 5. Execute atomic transaction: unit + claim + idempotency + audit
 */
export async function createIntakeHandler(
  ctx: TenantContextWire,
  params: CreateIntakeParams,
  deps: IntakeHandlerDependencies,
): Promise<IntakeOutcome<ImeiUnit>> {
  const { client, tableName, auditService } = deps;

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

  // 3. Business rule validation
  if (!params.sellerIdentityRef || params.sellerIdentityRef.trim() === '') {
    return {
      ok: false,
      outcome: {
        code: 'VALIDATION_FAILED',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['sellerIdentityRef'],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }

  if (params.inspectionResult === 'FAIL') {
    return {
      ok: false,
      outcome: {
        code: 'INTAKE_INSPECTION_FAILED',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['inspectionResult'],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }

  if (!params.valuationApproved) {
    return {
      ok: false,
      outcome: {
        code: 'INTAKE_VALUATION_NOT_APPROVED',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['valuationApproved'],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }

  if (params.evidenceStatus === 'PENDING') {
    return {
      ok: false,
      outcome: {
        code: 'INTAKE_EVIDENCE_INCOMPLETE',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['evidenceStatus'],
        httpStatus: 422,
        correlationId: ctx.correlationId,
      },
    };
  }

  // 4. Build domain entity with SECOND_HAND initial state
  const entityId = randomUUID();
  const intakeId = randomUUID();
  const domainParams: CreateImeiUnitParams = {
    tenantId: ctx.tenantId,
    entityId,
    imei: normalizedImei,
    condition: params.condition,
    ownershipSource: OwnershipSource.SECOND_HAND_INTAKE,
    brand: params.brand,
    model: params.model,
    color: params.color,
    storage: params.storage,
    acquisitionCost: params.acquisitionCost,
    salePrice: params.salePrice,
    marketValuation: params.marketValuation,
    exchangeId: params.exchangeId,
    intakeId,
    evidenceRefs: params.evidenceRefs,
    isSecondHand: true,
  };
  const unit = domainCreateImeiUnit(domainParams);

  // 5. Build transaction items
  const unitItem = buildIntakeUnitDynamoItem(ctx, unit, params.sellerIdentityRef, params.inspectionResult);
  const claimItem = buildClaimTransactItem(
    tableName, ctx, 'IMEI', normalizedImei, entityId, 1,
  );
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint, 'COMMITTED', entityId,
  );
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'IMEI_UNIT',
    entityId,
    action: 'INTAKE_ACCEPTED',
    operationId: params.operationId,
    afterState: unit,
    reason: params.reason ?? 'Second-hand device intake accepted',
  });

  // 6. Execute atomic transaction
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

// ─── Internal Helpers ────────────────────────────────────────────────────────

function buildIntakeUnitDynamoItem(
  ctx: TenantContextWire,
  unit: ImeiUnit,
  sellerIdentityRef: string,
  inspectionResult: string,
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
    ...(unit.exchangeId !== undefined && { exchangeId: unit.exchangeId }),
    ...(unit.intakeId !== undefined && { intakeId: unit.intakeId }),
    ...(unit.evidenceRefs !== undefined && unit.evidenceRefs.length > 0 && { evidenceRefs: unit.evidenceRefs }),
    sellerIdentityRef,
    inspectionResult,
    createdAt: unit.createdAt,
    updatedAt: unit.updatedAt,
  };
}
