/**
 * Warranty Handler — MobileShop Application Layer
 *
 * Manages warranty lifecycle: registration, claim filing, claim resolution, and listing.
 * Every handler follows: idempotency check → validate → transaction plan → execute → map outcome.
 *
 * Warranty dates use month-end calculation from warranty-validator (AF-43 fix).
 * All mutations require expected version (optimistic concurrency) and produce audit events.
 *
 * Requirements: 5.5–5.8, 8.12
 */

import { randomUUID } from 'crypto';
import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire, Money, PaginatedResponse, EvidenceReference } from '../../schemas/common.schema';
import type { WarrantyStatus, WarrantyClaimStatus, WarrantyType } from '../../schemas/warranty.schema';
import { validateWarrantyMonths, calculateWarrantyEndDate } from '../../domain/warranty-validator';
import { AuditEventService } from '../audit-service';
import { checkIdempotency } from '../../persistence/idempotency';
import { buildIdempotencyTransactItem } from '../../persistence/transaction-items';
import { mapDynamoDbError, type ErrorMappingContext } from '../error-mapper';
import { MobileShopRepository } from '../../persistence/mobile-shop.repository';
import {
  buildEntityAggregatePK,
  encodeMetaSK,
  encodeChildSK,
  buildWarrantyGSI1PK,
  encodeGSI1SK,
} from '../../persistence/key-codec';
import { MODEL_VERSION_CONFIG } from '../../config/model-version.config';
import { ERROR_CODES } from '../../config/error-codes.config';
import type { DeterministicOutcome } from '../error-mapper';
import type { Result } from '../../domain/device-lifecycle';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface RegisterWarrantyParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly imei: string;
  readonly unitId: string;
  readonly saleInvoiceId: string;
  readonly customerId: string;
  readonly warrantyType: WarrantyType;
  readonly provider: string;
  readonly durationMonths: number;
  readonly saleDate: string;
  readonly providerReference?: string;
  readonly cost?: Money;
  readonly notes?: string;
  readonly dataModelVersion: number;
}

export interface FileWarrantyClaimParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly faultDescription: string;
  readonly evidenceRefs?: readonly EvidenceReference[];
  readonly serviceJobId?: string;
  readonly expectedVersion: number;
  readonly dataModelVersion: number;
}

export interface ResolveWarrantyClaimParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly claimId: string;
  readonly resolution: string;
  readonly resolutionCost?: Money;
  readonly expectedVersion: number;
  readonly dataModelVersion: number;
}

export interface ListWarrantiesFilters {
  readonly status: string;
  readonly limit?: number;
  readonly continuationToken?: string;
  readonly exclusiveStartKey?: Record<string, unknown>;
  readonly scanForward?: boolean;
}

export interface WarrantyOutcome {
  readonly warrantyId: string;
  readonly status: WarrantyStatus;
  readonly version: number;
  readonly operationId: string;
  readonly endDate?: string;
}

export interface WarrantyClaimOutcome {
  readonly claimId: string;
  readonly warrantyId: string;
  readonly status: WarrantyClaimStatus;
  readonly version: number;
  readonly operationId: string;
}

// ─── Handler Context ─────────────────────────────────────────────────────────

export interface WarrantyHandlerDeps {
  readonly client: DynamoDBDocumentClient;
  readonly tableName: string;
  readonly repository: MobileShopRepository;
  readonly auditService: AuditEventService;
}

// ─── Register Warranty ───────────────────────────────────────────────────────

/**
 * Registers a warranty for a sold IMEI unit.
 *
 * Validates:
 * - IMEI is tenant-owned and in SOLD state
 * - Warranty period (via warranty-validator, using configured bounds)
 * - Provider presence
 * - End date uses month-end calculation (AF-43 fix)
 * - Idempotency
 *
 * Creates warranty record + audit event atomically.
 */
export async function registerWarranty(
  deps: WarrantyHandlerDeps,
  ctx: TenantContextWire,
  params: RegisterWarrantyParams,
): Promise<Result<WarrantyOutcome, DeterministicOutcome>> {
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
  if (idempotencyResult.outcome === 'EXPIRED') {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.IDEMPOTENCY_EXPIRED, ctx.correlationId, ['operationId']),
    };
  }

  // 2. Validate tenant-owned IMEI
  const claimResult = await repository.lookupImeiClaim(ctx, params.imei);
  if (!claimResult.item) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['imei']),
    };
  }

  const claim = claimResult.item as Record<string, unknown>;
  if (claim['tenantId'] !== ctx.tenantId) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['imei']),
    };
  }

  // 3. Verify unit exists and is in SOLD state (warranty is post-sale)
  const unitAggregate = await repository.getEntityAggregate(ctx, 'UNIT', params.unitId, {
    consistency: 'strong',
    skPrefix: 'META#',
  });

  const unitItem = unitAggregate.items[0] as Record<string, unknown> | undefined;
  if (!unitItem) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['unitId']),
    };
  }

  const unitState = unitItem['lifecycleState'] as string;
  if (unitState !== 'SOLD' && unitState !== 'IN_SERVICE') {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.IMEI_LIFECYCLE_INVALID, ctx.correlationId, ['imei']),
    };
  }

  // 4. Validate warranty months (using warranty-validator with configured bounds)
  const monthsResult = validateWarrantyMonths(params.durationMonths);
  if (!monthsResult.ok) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.WARRANTY_MONTHS_OUT_OF_RANGE, ctx.correlationId, ['durationMonths']),
    };
  }

  // 5. Validate provider
  if (!params.provider || params.provider.trim().length === 0) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['provider']),
    };
  }

  // 6. Validate sale date
  if (!params.saleDate) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['saleDate']),
    };
  }

  const saleDate = new Date(params.saleDate);
  if (isNaN(saleDate.getTime())) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['saleDate']),
    };
  }

  // 7. Calculate warranty end date using month-end calculation
  const endDate = calculateWarrantyEndDate(saleDate, params.durationMonths);

  // 8. Build warranty entity
  const warrantyId = randomUUID();
  const now = new Date().toISOString();

  const warrantyItem: Record<string, unknown> = {
    PK: buildEntityAggregatePK(ctx.tenantId, 'WARRANTY', warrantyId),
    SK: encodeMetaSK('WARRANTY'),
    GSI1PK: buildWarrantyGSI1PK(ctx.tenantId, 'ACTIVE'),
    GSI1SK: encodeGSI1SK(endDate, warrantyId),
    tenantId: ctx.tenantId,
    entityType: 'WARRANTY',
    entityId: warrantyId,
    imei: params.imei,
    unitId: params.unitId,
    saleInvoiceId: params.saleInvoiceId,
    customerId: params.customerId,
    warrantyType: params.warrantyType,
    status: 'ACTIVE' as WarrantyStatus,
    provider: params.provider,
    durationMonths: params.durationMonths,
    startDate: params.saleDate,
    endDate,
    providerReference: params.providerReference ?? null,
    cost: params.cost ?? null,
    notes: params.notes ?? null,
    operationId: params.operationId,
    version: 1,
    dataModelVersion: params.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
    createdAt: now,
    updatedAt: now,
  };

  // 9. Build audit event
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'WARRANTY',
    entityId: warrantyId,
    action: 'WARRANTY_REGISTERED',
    operationId: params.operationId,
    afterState: {
      imei: params.imei,
      provider: params.provider,
      durationMonths: params.durationMonths,
      endDate,
    },
    reason: `Warranty registered: ${params.warrantyType} by ${params.provider} for ${params.durationMonths} months`,
  });

  // 10. Build idempotency item
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint,
    'COMMITTED', warrantyId, params.dataModelVersion,
  );

  // 11. Execute transaction
  const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');

  const transactItems = [
    { Put: { TableName: tableName, Item: warrantyItem, ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)' } },
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
      fields: ['operationId', 'imei'],
    };
    return { ok: false, error: mapDynamoDbError(error, errCtx) };
  }

  return {
    ok: true,
    value: { warrantyId, status: 'ACTIVE', version: 1, operationId: params.operationId, endDate },
  };
}

// ─── File Warranty Claim ─────────────────────────────────────────────────────

/**
 * Files a warranty claim against an active, non-expired warranty.
 *
 * Validates:
 * - Warranty exists and is tenant-owned
 * - Warranty status is ACTIVE
 * - Warranty is not expired (endDate >= now)
 * - Expected version (optimistic concurrency)
 * - Creates claim child record + updates warranty status + audit event
 */
export async function fileWarrantyClaim(
  deps: WarrantyHandlerDeps,
  ctx: TenantContextWire,
  warrantyId: string,
  params: FileWarrantyClaimParams,
): Promise<Result<WarrantyClaimOutcome, DeterministicOutcome>> {
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

  // 2. Look up warranty (strong consistency)
  const warrantyAgg = await repository.getEntityAggregate(ctx, 'WARRANTY', warrantyId, {
    consistency: 'strong',
    skPrefix: 'META#',
  });

  const warrantyItem = warrantyAgg.items[0] as Record<string, unknown> | undefined;
  if (!warrantyItem) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['warrantyId']),
    };
  }

  // 3. Validate tenant ownership
  if (warrantyItem['tenantId'] !== ctx.tenantId) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['warrantyId']),
    };
  }

  // 4. Version check
  const currentVersion = warrantyItem['version'] as number;
  if (currentVersion !== params.expectedVersion) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.VERSION_CONFLICT, ctx.correlationId, ['expectedVersion']),
    };
  }

  // 5. Validate warranty is ACTIVE
  const warrantyStatus = warrantyItem['status'] as WarrantyStatus;
  if (warrantyStatus !== 'ACTIVE') {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.LIFECYCLE_TRANSITION_DENIED, ctx.correlationId, ['status']),
    };
  }

  // 6. Check warranty is not expired
  const endDate = warrantyItem['endDate'] as string;
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  if (endDate < today) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.LIFECYCLE_TRANSITION_DENIED, ctx.correlationId, ['endDate']),
    };
  }

  // 7. Validate fault description
  if (!params.faultDescription || params.faultDescription.trim().length === 0) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['faultDescription']),
    };
  }

  // 8. Build claim child entity
  const claimId = randomUUID();
  const now = new Date().toISOString();
  const newVersion = currentVersion + 1;

  const claimItem: Record<string, unknown> = {
    PK: buildEntityAggregatePK(ctx.tenantId, 'WARRANTY', warrantyId),
    SK: encodeChildSK('CLAIM', claimId),
    tenantId: ctx.tenantId,
    entityType: 'WARRANTY_CLAIM',
    entityId: claimId,
    warrantyId,
    imei: warrantyItem['imei'],
    unitId: warrantyItem['unitId'],
    customerId: warrantyItem['customerId'],
    status: 'SUBMITTED' as WarrantyClaimStatus,
    faultDescription: params.faultDescription,
    claimDate: now,
    evidenceRefs: params.evidenceRefs ?? null,
    serviceJobId: params.serviceJobId ?? null,
    resolution: null,
    resolvedAt: null,
    resolutionCost: null,
    operationId: params.operationId,
    version: 1,
    dataModelVersion: params.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
    createdAt: now,
    updatedAt: now,
  };

  // 9. Build warranty status update (ACTIVE → CLAIMED)
  const warrantyPK = buildEntityAggregatePK(ctx.tenantId, 'WARRANTY', warrantyId);
  const warrantySK = encodeMetaSK('WARRANTY');

  const warrantyUpdateItem = {
    Update: {
      TableName: tableName,
      Key: { PK: warrantyPK, SK: warrantySK },
      UpdateExpression: 'SET #status = :newStatus, #version = :newVersion, #updatedAt = :updatedAt, #GSI1PK = :gsi1pk',
      ConditionExpression: '#version = :expectedVersion AND #tenantId = :tenantId',
      ExpressionAttributeNames: {
        '#status': 'status',
        '#version': 'version',
        '#updatedAt': 'updatedAt',
        '#tenantId': 'tenantId',
        '#GSI1PK': 'GSI1PK',
      },
      ExpressionAttributeValues: {
        ':newStatus': 'CLAIMED',
        ':newVersion': newVersion,
        ':expectedVersion': currentVersion,
        ':updatedAt': now,
        ':tenantId': ctx.tenantId,
        ':gsi1pk': buildWarrantyGSI1PK(ctx.tenantId, 'CLAIMED'),
      },
    },
  };

  // 10. Build audit event
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'WARRANTY',
    entityId: warrantyId,
    action: 'WARRANTY_CLAIMED',
    operationId: params.operationId,
    beforeState: { status: warrantyStatus, version: currentVersion },
    afterState: { status: 'CLAIMED', claimId, faultDescription: params.faultDescription },
    reason: `Warranty claim filed: ${params.faultDescription.substring(0, 100)}`,
  });

  // 11. Build idempotency item
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint,
    'COMMITTED', claimId, params.dataModelVersion,
  );

  // 12. Execute transaction
  const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');

  const transactItems = [
    { Put: { TableName: tableName, Item: claimItem, ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)' } },
    warrantyUpdateItem,
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
      fields: ['warrantyId', 'expectedVersion'],
    };
    return { ok: false, error: mapDynamoDbError(error, errCtx) };
  }

  return {
    ok: true,
    value: {
      claimId,
      warrantyId,
      status: 'SUBMITTED',
      version: 1,
      operationId: params.operationId,
    },
  };
}

// ─── Resolve Warranty Claim ──────────────────────────────────────────────────

/**
 * Resolves a warranty claim with a resolution decision.
 *
 * Validates:
 * - Warranty exists and is tenant-owned
 * - Expected version (optimistic concurrency)
 * - Claim exists as child of warranty
 * - Claim is in a resolvable status (SUBMITTED or UNDER_REVIEW or APPROVED)
 * - Resolution text present
 *
 * Updates claim status to RESOLVED + audit event atomically.
 */
export async function resolveWarrantyClaim(
  deps: WarrantyHandlerDeps,
  ctx: TenantContextWire,
  warrantyId: string,
  params: ResolveWarrantyClaimParams,
): Promise<Result<WarrantyClaimOutcome, DeterministicOutcome>> {
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

  // 2. Look up warranty (strong consistency)
  const warrantyAgg = await repository.getEntityAggregate(ctx, 'WARRANTY', warrantyId, {
    consistency: 'strong',
  });

  // Find the META item (warranty root)
  const warrantyItem = warrantyAgg.items.find(
    (item) => (item as Record<string, unknown>)['entityType'] === 'WARRANTY',
  ) as Record<string, unknown> | undefined;

  if (!warrantyItem) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['warrantyId']),
    };
  }

  // 3. Validate tenant ownership
  if (warrantyItem['tenantId'] !== ctx.tenantId) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['warrantyId']),
    };
  }

  // 4. Version check on warranty
  const currentVersion = warrantyItem['version'] as number;
  if (currentVersion !== params.expectedVersion) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.VERSION_CONFLICT, ctx.correlationId, ['expectedVersion']),
    };
  }

  // 5. Find the claim child record
  const claimItem = warrantyAgg.items.find(
    (item) => (item as Record<string, unknown>)['entityId'] === params.claimId,
  ) as Record<string, unknown> | undefined;

  if (!claimItem) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['claimId']),
    };
  }

  // 6. Validate claim is in a resolvable status
  const claimStatus = claimItem['status'] as WarrantyClaimStatus;
  const resolvableStatuses: ReadonlySet<WarrantyClaimStatus> = new Set([
    'SUBMITTED', 'UNDER_REVIEW', 'APPROVED',
  ]);
  if (!resolvableStatuses.has(claimStatus)) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.LIFECYCLE_TRANSITION_DENIED, ctx.correlationId, ['status']),
    };
  }

  // 7. Validate resolution text
  if (!params.resolution || params.resolution.trim().length === 0) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['resolution']),
    };
  }

  // 8. Build claim update
  const now = new Date().toISOString();
  const claimPK = buildEntityAggregatePK(ctx.tenantId, 'WARRANTY', warrantyId);
  const claimSK = encodeChildSK('CLAIM', params.claimId);

  let claimUpdateExpression = 'SET #status = :resolved, #resolution = :resolution, #resolvedAt = :resolvedAt, #updatedAt = :updatedAt, #version = :newClaimVersion';
  const claimExprNames: Record<string, string> = {
    '#status': 'status',
    '#resolution': 'resolution',
    '#resolvedAt': 'resolvedAt',
    '#updatedAt': 'updatedAt',
    '#version': 'version',
    '#tenantId': 'tenantId',
  };
  const claimExprValues: Record<string, unknown> = {
    ':resolved': 'RESOLVED' as WarrantyClaimStatus,
    ':resolution': params.resolution,
    ':resolvedAt': now,
    ':updatedAt': now,
    ':newClaimVersion': (claimItem['version'] as number) + 1,
    ':expectedClaimVersion': claimItem['version'],
    ':tenantId': ctx.tenantId,
  };

  if (params.resolutionCost) {
    claimUpdateExpression += ', #resolutionCost = :resolutionCost';
    claimExprNames['#resolutionCost'] = 'resolutionCost';
    claimExprValues[':resolutionCost'] = params.resolutionCost;
  }

  const claimUpdateItem = {
    Update: {
      TableName: tableName,
      Key: { PK: claimPK, SK: claimSK },
      UpdateExpression: claimUpdateExpression,
      ConditionExpression: '#version = :expectedClaimVersion AND #tenantId = :tenantId',
      ExpressionAttributeNames: claimExprNames,
      ExpressionAttributeValues: claimExprValues,
    },
  };

  // 9. Build warranty version bump (increment version for concurrency tracking)
  const newWarrantyVersion = currentVersion + 1;
  const warrantyPK = buildEntityAggregatePK(ctx.tenantId, 'WARRANTY', warrantyId);
  const warrantySK = encodeMetaSK('WARRANTY');

  const warrantyVersionBump = {
    Update: {
      TableName: tableName,
      Key: { PK: warrantyPK, SK: warrantySK },
      UpdateExpression: 'SET #version = :newVersion, #updatedAt = :updatedAt',
      ConditionExpression: '#version = :expectedVersion AND #tenantId = :tenantId',
      ExpressionAttributeNames: {
        '#version': 'version',
        '#updatedAt': 'updatedAt',
        '#tenantId': 'tenantId',
      },
      ExpressionAttributeValues: {
        ':newVersion': newWarrantyVersion,
        ':expectedVersion': currentVersion,
        ':updatedAt': now,
        ':tenantId': ctx.tenantId,
      },
    },
  };

  // 10. Build audit event
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'WARRANTY',
    entityId: warrantyId,
    action: 'WARRANTY_CLAIMED',
    operationId: params.operationId,
    beforeState: { claimStatus, claimId: params.claimId },
    afterState: { claimStatus: 'RESOLVED', resolution: params.resolution },
    reason: `Warranty claim resolved: ${params.resolution.substring(0, 100)}`,
  });

  // 11. Build idempotency item
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint,
    'COMMITTED', params.claimId, params.dataModelVersion,
  );

  // 12. Execute transaction
  const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');

  const transactItems = [
    claimUpdateItem,
    warrantyVersionBump,
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
      fields: ['warrantyId', 'claimId', 'expectedVersion'],
    };
    return { ok: false, error: mapDynamoDbError(error, errCtx) };
  }

  return {
    ok: true,
    value: {
      claimId: params.claimId,
      warrantyId,
      status: 'RESOLVED',
      version: newWarrantyVersion,
      operationId: params.operationId,
    },
  };
}

// ─── List Warranties ─────────────────────────────────────────────────────────

/**
 * Lists warranties filtered by status using AP-07 (bounded GSI1 Query).
 */
export async function listWarranties(
  deps: WarrantyHandlerDeps,
  ctx: TenantContextWire,
  filters: ListWarrantiesFilters,
): Promise<Result<PaginatedResponse<Record<string, unknown>>, DeterministicOutcome>> {
  const { repository } = deps;

  if (!filters.status) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['status']),
    };
  }

  try {
    const result = await repository.queryWarranties(
      ctx,
      filters.status,
      {
        limit: filters.limit,
        exclusiveStartKey: filters.exclusiveStartKey,
      },
      { scanForward: filters.scanForward ?? true },
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
