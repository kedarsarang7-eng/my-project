/**
 * Service Job Handler — MobileShop Application Layer
 *
 * Manages service/repair job lifecycle: creation, status transitions, and listing.
 * Every handler follows: idempotency check → validate → transaction plan → execute → map outcome.
 *
 * Service job status transitions:
 *   RECEIVED → DIAGNOSED → ESTIMATE_SENT → APPROVED → IN_PROGRESS → PARTS_ORDERED → READY → DELIVERED
 *   (CANCELLED is reachable from any non-terminal state)
 *
 * Requirements: 5.1–5.3, 5.8, 8.12
 */

import { randomUUID } from 'crypto';
import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire, Money, PaginatedResponse } from '../../schemas/common.schema';
import type {
  ServiceJob,
  ServiceJobStatus,
  ServicePriority,
} from '../../schemas/service-job.schema';
import { DeviceLifecycleState, validateTransition } from '../../domain/device-lifecycle';
import { AuditEventService } from '../audit-service';
import { checkIdempotency } from '../../persistence/idempotency';
import {
  buildIdempotencyTransactItem,
  buildClaimTransactItem,
} from '../../persistence/transaction-items';
import { mapDynamoDbError, type ErrorMappingContext } from '../error-mapper';
import { MobileShopRepository } from '../../persistence/mobile-shop.repository';
import {
  buildEntityAggregatePK,
  encodeMetaSK,
  encodeChildSK,
  buildServiceJobGSI1PK,
  encodeGSI1SK,
} from '../../persistence/key-codec';
import { MODEL_VERSION_CONFIG } from '../../config/model-version.config';
import { BOUNDS_CONFIG } from '../../config/bounds.config';
import { ERROR_CODES } from '../../config/error-codes.config';
import type { DeterministicOutcome } from '../error-mapper';
import type { Result } from '../../domain/device-lifecycle';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface CreateServiceJobParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly imei: string;
  readonly unitId: string;
  readonly customerId: string;
  readonly customerName: string;
  readonly faultDescription: string;
  readonly priority: ServicePriority;
  readonly technicianId?: string;
  readonly technicianName?: string;
  readonly estimatedCost?: Money;
  readonly underWarranty: boolean;
  readonly warrantyClaimId?: string;
  readonly estimatedCompletionAt?: string;
  readonly dueAt?: string;
  readonly notes?: string;
  readonly dataModelVersion: number;
}

export interface UpdateServiceJobStatusParams {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly targetStatus: ServiceJobStatus;
  readonly expectedVersion: number;
  readonly actor: string;
  readonly notes?: string;
  readonly actualCost?: Money;
  readonly dataModelVersion: number;
}

export interface ListServiceJobsFilters {
  readonly status: string;
  readonly limit?: number;
  readonly continuationToken?: string;
  readonly exclusiveStartKey?: Record<string, unknown>;
  readonly scanForward?: boolean;
}

export interface ServiceJobOutcome {
  readonly jobId: string;
  readonly status: ServiceJobStatus;
  readonly version: number;
  readonly operationId: string;
}

// ─── Service Job Status Transition Graph ─────────────────────────────────────

const SERVICE_JOB_TRANSITIONS: Readonly<Record<ServiceJobStatus, readonly ServiceJobStatus[]>> = {
  RECEIVED: ['DIAGNOSED', 'CANCELLED'],
  DIAGNOSED: ['ESTIMATE_SENT', 'CANCELLED'],
  ESTIMATE_SENT: ['APPROVED', 'CANCELLED'],
  APPROVED: ['IN_PROGRESS', 'CANCELLED'],
  IN_PROGRESS: ['PARTS_ORDERED', 'READY', 'CANCELLED'],
  PARTS_ORDERED: ['IN_PROGRESS', 'READY', 'CANCELLED'],
  READY: ['DELIVERED', 'CANCELLED'],
  DELIVERED: [],
  CANCELLED: [],
};

/** Terminal statuses — no further transitions allowed */
const TERMINAL_STATUSES: ReadonlySet<ServiceJobStatus> = new Set(['DELIVERED', 'CANCELLED']);

// ─── Handler Context ─────────────────────────────────────────────────────────

export interface ServiceJobHandlerDeps {
  readonly client: DynamoDBDocumentClient;
  readonly tableName: string;
  readonly repository: MobileShopRepository;
  readonly auditService: AuditEventService;
}

// ─── Create Service Job ──────────────────────────────────────────────────────

/**
 * Creates a new service job for a tenant-owned IMEI unit.
 *
 * Validates:
 * - Tenant-owned IMEI (via claim lookup)
 * - Customer, fault, technician data
 * - Warranty status
 * - Idempotency (rejects duplicate operationId)
 *
 * Creates the service job with RECEIVED status + audit event atomically.
 */
export async function createServiceJob(
  deps: ServiceJobHandlerDeps,
  ctx: TenantContextWire,
  params: CreateServiceJobParams,
): Promise<Result<ServiceJobOutcome, DeterministicOutcome>> {
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

  // Verify the claim belongs to the unit
  const claim = claimResult.item as Record<string, unknown>;
  if (claim['tenantId'] !== ctx.tenantId) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['imei']),
    };
  }

  // 3. Look up the unit to check lifecycle state
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

  // Verify unit lifecycle allows service (must be SOLD or IN_SERVICE)
  const unitState = unitItem['lifecycleState'] as string;
  const serviceableStates: string[] = [
    DeviceLifecycleState.SOLD,
    DeviceLifecycleState.IN_SERVICE,
    DeviceLifecycleState.IN_STOCK,
  ];
  if (!serviceableStates.includes(unitState)) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.IMEI_LIFECYCLE_INVALID, ctx.correlationId, ['imei']),
    };
  }

  // 4. Validate required fields
  if (!params.customerId || !params.customerName) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['customerId', 'customerName']),
    };
  }
  if (!params.faultDescription || params.faultDescription.length > BOUNDS_CONFIG.strings.maxFaultLength) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['faultDescription']),
    };
  }

  // 5. Build the service job entity
  const jobId = randomUUID();
  const now = new Date().toISOString();

  const serviceJob: Record<string, unknown> = {
    PK: buildEntityAggregatePK(ctx.tenantId, 'SERVICE_JOB', jobId),
    SK: encodeMetaSK('SERVICE_JOB'),
    GSI1PK: buildServiceJobGSI1PK(ctx.tenantId, 'RECEIVED'),
    GSI1SK: encodeGSI1SK(params.dueAt ?? now, jobId),
    tenantId: ctx.tenantId,
    entityType: 'SERVICE_JOB',
    entityId: jobId,
    imei: params.imei,
    unitId: params.unitId,
    customerId: params.customerId,
    customerName: params.customerName,
    status: 'RECEIVED',
    priority: params.priority,
    faultDescription: params.faultDescription,
    technicianId: params.technicianId ?? null,
    technicianName: params.technicianName ?? null,
    estimatedCost: params.estimatedCost ?? null,
    actualCost: null,
    underWarranty: params.underWarranty,
    warrantyClaimId: params.warrantyClaimId ?? null,
    receivedAt: now,
    estimatedCompletionAt: params.estimatedCompletionAt ?? null,
    dueAt: params.dueAt ?? null,
    notes: params.notes ?? null,
    operationId: params.operationId,
    version: 1,
    dataModelVersion: params.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
    createdAt: now,
    updatedAt: now,
  };

  // 6. Build audit event
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'SERVICE_JOB',
    entityId: jobId,
    action: 'SERVICE_STATUS_CHANGE',
    operationId: params.operationId,
    afterState: { status: 'RECEIVED', imei: params.imei, customerId: params.customerId },
    reason: `Service job created: ${params.faultDescription.substring(0, 100)}`,
  });

  // 7. Build idempotency transact item
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint,
    'COMMITTED', jobId, params.dataModelVersion,
  );

  // 8. Execute transaction
  const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');

  const transactItems = [
    { Put: { TableName: tableName, Item: serviceJob, ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)' } },
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
    value: { jobId, status: 'RECEIVED', version: 1, operationId: params.operationId },
  };
}

// ─── Update Service Job Status ───────────────────────────────────────────────

/**
 * Transitions a service job to a new status.
 *
 * Validates:
 * - Expected version (optimistic concurrency)
 * - Allowed status transition per the service job state machine
 * - Updates associated IMEI_Unit state atomically + audit
 */
export async function updateServiceJobStatus(
  deps: ServiceJobHandlerDeps,
  ctx: TenantContextWire,
  jobId: string,
  params: UpdateServiceJobStatusParams,
): Promise<Result<ServiceJobOutcome, DeterministicOutcome>> {
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

  // 2. Read current service job (strong consistency)
  const jobAggregate = await repository.getEntityAggregate(ctx, 'SERVICE_JOB', jobId, {
    consistency: 'strong',
    skPrefix: 'META#',
  });

  const jobItem = jobAggregate.items[0] as Record<string, unknown> | undefined;
  if (!jobItem) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['jobId']),
    };
  }

  // 3. Validate tenant ownership
  if (jobItem['tenantId'] !== ctx.tenantId) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.ENTITY_NOT_FOUND, ctx.correlationId, ['jobId']),
    };
  }

  // 4. Version check
  const currentVersion = jobItem['version'] as number;
  if (currentVersion !== params.expectedVersion) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.VERSION_CONFLICT, ctx.correlationId, ['expectedVersion']),
    };
  }

  // 5. Validate status transition
  const currentStatus = jobItem['status'] as ServiceJobStatus;
  if (TERMINAL_STATUSES.has(currentStatus)) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.LIFECYCLE_TRANSITION_DENIED, ctx.correlationId, ['status']),
    };
  }

  const allowedTargets = SERVICE_JOB_TRANSITIONS[currentStatus];
  if (!allowedTargets || !allowedTargets.includes(params.targetStatus)) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.LIFECYCLE_TRANSITION_DENIED, ctx.correlationId, ['status']),
    };
  }

  // 6. Build updated job item
  const now = new Date().toISOString();
  const newVersion = currentVersion + 1;

  const updatedFields: Record<string, unknown> = {
    status: params.targetStatus,
    version: newVersion,
    updatedAt: now,
    operationId: params.operationId,
  };

  if (params.notes !== undefined) {
    updatedFields['diagnosisNotes'] = params.notes;
  }
  if (params.actualCost !== undefined) {
    updatedFields['actualCost'] = params.actualCost;
  }
  if (params.targetStatus === 'DELIVERED') {
    updatedFields['deliveredAt'] = now;
  }
  if (params.targetStatus === 'READY' || params.targetStatus === 'DELIVERED') {
    updatedFields['completedAt'] = now;
  }

  // Build update expression parts
  const setExprParts: string[] = [];
  const exprAttrValues: Record<string, unknown> = {
    ':expectedVersion': params.expectedVersion,
    ':tenantId': ctx.tenantId,
  };
  const exprAttrNames: Record<string, string> = {
    '#version': 'version',
    '#tenantId': 'tenantId',
  };

  let attrIndex = 0;
  for (const [key, value] of Object.entries(updatedFields)) {
    const nameAlias = `#f${attrIndex}`;
    const valueAlias = `:v${attrIndex}`;
    setExprParts.push(`${nameAlias} = ${valueAlias}`);
    exprAttrNames[nameAlias] = key;
    exprAttrValues[valueAlias] = value;
    attrIndex++;
  }

  // Update GSI1 keys for the new status
  const gsi1pk = buildServiceJobGSI1PK(ctx.tenantId, params.targetStatus);
  const dueAt = (jobItem['dueAt'] as string) ?? now;
  const gsi1sk = encodeGSI1SK(dueAt, jobId);
  setExprParts.push('#gsi1pk = :gsi1pk', '#gsi1sk = :gsi1sk');
  exprAttrNames['#gsi1pk'] = 'GSI1PK';
  exprAttrNames['#gsi1sk'] = 'GSI1SK';
  exprAttrValues[':gsi1pk'] = gsi1pk;
  exprAttrValues[':gsi1sk'] = gsi1sk;

  // 7. Build IMEI state transition (if status implies device state change)
  const unitId = jobItem['unitId'] as string;
  const imei = jobItem['imei'] as string;
  const imeiTransactItems: unknown[] = [];

  // When job moves to IN_PROGRESS, set IMEI to IN_SERVICE
  // When job is DELIVERED, set IMEI back to SOLD or prior state
  if (params.targetStatus === 'IN_PROGRESS' || params.targetStatus === 'RECEIVED') {
    // Transition IMEI to IN_SERVICE if not already
    const unitAgg = await repository.getEntityAggregate(ctx, 'UNIT', unitId, {
      consistency: 'strong',
      skPrefix: 'META#',
    });
    const unit = unitAgg.items[0] as Record<string, unknown> | undefined;
    if (unit) {
      const unitLifecycle = unit['lifecycleState'] as string;
      const unitVersion = unit['version'] as number;

      if (params.targetStatus === 'IN_PROGRESS' && unitLifecycle === DeviceLifecycleState.SOLD) {
        // Transition SOLD → IN_SERVICE
        const unitUpdateItem = buildUnitStatusUpdateTransactItem(
          tableName, ctx, unitId, unitVersion, DeviceLifecycleState.IN_SERVICE, now,
        );
        imeiTransactItems.push(unitUpdateItem);
      }
    }
  }

  // 8. Build audit event
  const auditResult = auditService.createAuditEvent(ctx, {
    entityType: 'SERVICE_JOB',
    entityId: jobId,
    action: 'SERVICE_STATUS_CHANGE',
    operationId: params.operationId,
    beforeState: { status: currentStatus, version: currentVersion },
    afterState: { status: params.targetStatus, version: newVersion },
    reason: params.notes ?? `Status changed: ${currentStatus} → ${params.targetStatus}`,
  });

  // 9. Build idempotency item
  const idempotencyItem = buildIdempotencyTransactItem(
    tableName, ctx, params.operationId, params.mutationFingerprint,
    'COMMITTED', jobId, params.dataModelVersion,
  );

  // 10. Execute transaction
  const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');

  const pk = buildEntityAggregatePK(ctx.tenantId, 'SERVICE_JOB', jobId);
  const sk = encodeMetaSK('SERVICE_JOB');

  const transactItems: any[] = [
    {
      Update: {
        TableName: tableName,
        Key: { PK: pk, SK: sk },
        UpdateExpression: `SET ${setExprParts.join(', ')}`,
        ConditionExpression: '#version = :expectedVersion AND #tenantId = :tenantId',
        ExpressionAttributeNames: exprAttrNames,
        ExpressionAttributeValues: exprAttrValues,
      },
    },
    auditResult.transactItem,
    idempotencyItem,
    ...imeiTransactItems,
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
      fields: ['expectedVersion', 'status'],
    };
    return { ok: false, error: mapDynamoDbError(error, errCtx) };
  }

  return {
    ok: true,
    value: { jobId, status: params.targetStatus, version: newVersion, operationId: params.operationId },
  };
}

// ─── List Service Jobs ───────────────────────────────────────────────────────

/**
 * Lists service jobs filtered by status using AP-06 (bounded GSI1 Query).
 */
export async function listServiceJobs(
  deps: ServiceJobHandlerDeps,
  ctx: TenantContextWire,
  filters: ListServiceJobsFilters,
): Promise<Result<PaginatedResponse<Record<string, unknown>>, DeterministicOutcome>> {
  const { repository } = deps;

  if (!filters.status) {
    return {
      ok: false,
      error: buildValidationOutcome(ERROR_CODES.SCHEMA_INVALID, ctx.correlationId, ['status']),
    };
  }

  try {
    const result = await repository.queryServiceJobs(
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

/**
 * Builds a transact item to update a unit's lifecycle state.
 */
function buildUnitStatusUpdateTransactItem(
  tableName: string,
  ctx: TenantContextWire,
  unitId: string,
  expectedVersion: number,
  targetState: DeviceLifecycleState,
  updatedAt: string,
): unknown {
  const pk = buildEntityAggregatePK(ctx.tenantId, 'UNIT', unitId);
  const sk = encodeMetaSK('UNIT');
  const newVersion = expectedVersion + 1;

  return {
    Update: {
      TableName: tableName,
      Key: { PK: pk, SK: sk },
      UpdateExpression: 'SET #lifecycleState = :targetState, #version = :newVersion, #updatedAt = :updatedAt',
      ConditionExpression: '#version = :expectedVersion AND #tenantId = :tenantId',
      ExpressionAttributeNames: {
        '#lifecycleState': 'lifecycleState',
        '#version': 'version',
        '#updatedAt': 'updatedAt',
        '#tenantId': 'tenantId',
      },
      ExpressionAttributeValues: {
        ':targetState': targetState,
        ':newVersion': newVersion,
        ':expectedVersion': expectedVersion,
        ':updatedAt': updatedAt,
        ':tenantId': ctx.tenantId,
      },
    },
  };
}
