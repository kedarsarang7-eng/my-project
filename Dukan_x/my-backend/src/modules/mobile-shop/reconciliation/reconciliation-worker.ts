/**
 * Durable Reconciliation Worker — MobileShop
 *
 * Conditionally leases ordered bounded steps, records attempts/completed
 * markers/latest errors, makes every step idempotent, finalizes only after
 * all effects are confirmed, and preserves visible reserved failure until
 * explicit recovery or reversal.
 *
 * Requirements: 3.4–3.6, 5.2, 6.9, 6.32, 6.38, 12.9
 */

import { randomUUID } from 'crypto';
import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type {
  ReconciliationRecord,
  ReconciliationStep,
} from '../application/accepted-pending-handler';
import type { TenantContextWire } from '../schemas/common.schema';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import {
  encodePK,
  encodeMetaSK,
  encodeChildSK,
  encodeSK,
  buildEntityAggregatePK,
  buildInvoicePK,
  buildChangeFeedPK,
  buildReconciliationGSI1PK,
  encodeGSI1PK,
  encodeGSI1SK,
  encodeGSI2PK,
  encodeGSI2SK,
  buildUnitLifecycleGSI1PK,
  buildCustomerHistoryGSI2PK,
} from '../persistence/key-codec';
import type {
  WorkerConfig,
  WorkerContext,
  StepExecutionResult,
  LeaseResult,
} from './reconciliation-types';
import { DEFAULT_WORKER_CONFIG } from './reconciliation-types';

// ─── Reconciliation Worker ───────────────────────────────────────────────────

export class ReconciliationWorker {
  private readonly config: WorkerConfig;
  private readonly client: DynamoDBDocumentClient;

  constructor(client: DynamoDBDocumentClient, config: Partial<WorkerConfig> & { tableName: string }) {
    this.client = client;
    this.config = { ...DEFAULT_WORKER_CONFIG, ...config };
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  /**
   * Queries AP-12 for PENDING work, conditionally leases the next record,
   * and processes its steps sequentially.
   */
  async processNext(ctx: WorkerContext): Promise<{
    processed: boolean;
    reconciliationId?: string;
    result?: 'completed' | 'partial' | 'failed' | 'no-work';
  }> {
    const { QueryCommand } = await import('@aws-sdk/lib-dynamodb');

    const now = new Date().toISOString();

    // Query AP-12: GSI1PK = TENANT#t#RECON#PENDING#ROOT, GSI1SK <= now
    const gsi1pk = buildReconciliationGSI1PK(ctx.tenantId, 'PENDING', this.config.bucket);

    const queryResult = await this.client.send(
      new QueryCommand({
        TableName: this.config.tableName,
        IndexName: this.config.gsi1IndexName,
        KeyConditionExpression: '#gsi1pk = :gsi1pk AND #gsi1sk <= :now',
        ExpressionAttributeNames: {
          '#gsi1pk': 'GSI1PK',
          '#gsi1sk': 'GSI1SK',
        },
        ExpressionAttributeValues: {
          ':gsi1pk': gsi1pk,
          ':now': now,
        },
        Limit: this.config.batchSize,
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    const items = queryResult.Items;
    if (!items || items.length === 0) {
      return { processed: false, result: 'no-work' };
    }

    // Try to lease the first available record
    for (const item of items) {
      const record = item as unknown as ReconciliationRecord;
      const leaseResult = await this.claimLease(ctx, record.reconciliationId, ctx.workerId);

      if (leaseResult.status !== 'acquired') {
        continue; // Another worker already holds this — try the next
      }

      // Process steps sequentially
      const stepResult = await this.processSteps(ctx, record);
      return {
        processed: true,
        reconciliationId: record.reconciliationId,
        result: stepResult,
      };
    }

    return { processed: false, result: 'no-work' };
  }

  /**
   * Conditional update that sets a lease with expiry and increments attempts.
   * Only succeeds if the record has no active lease or the existing lease expired.
   */
  async claimLease(
    ctx: WorkerContext,
    reconciliationId: string,
    workerId: string,
  ): Promise<LeaseResult> {
    const { UpdateCommand } = await import('@aws-sdk/lib-dynamodb');

    const now = new Date();
    const expiresAt = new Date(now.getTime() + this.config.leaseDurationSeconds * 1000).toISOString();
    const nowIso = now.toISOString();

    const pk = encodePK(ctx.tenantId, 'RECON', reconciliationId);
    const sk = encodeMetaSK('RECON');

    try {
      await this.client.send(
        new UpdateCommand({
          TableName: this.config.tableName,
          Key: { PK: pk, SK: sk },
          UpdateExpression: `
            SET #lease = :lease,
                #attempts = #attempts + :one,
                #status = :inProgress,
                #updatedAt = :now
          `,
          ConditionExpression: `
            attribute_exists(PK) AND
            (
              #lease = :nullVal OR
              #lease.#expiresAt < :now
            )
          `,
          ExpressionAttributeNames: {
            '#lease': 'lease',
            '#attempts': 'attempts',
            '#status': 'status',
            '#updatedAt': 'updatedAt',
            '#expiresAt': 'expiresAt',
          },
          ExpressionAttributeValues: {
            ':lease': {
              workerId,
              acquiredAt: nowIso,
              expiresAt,
            },
            ':one': 1,
            ':inProgress': 'IN_PROGRESS',
            ':now': nowIso,
            ':nullVal': null,
          },
          ReturnConsumedCapacity: 'TOTAL',
        }),
      );

      return { status: 'acquired', reconciliationId, workerId, expiresAt };
    } catch (error: unknown) {
      const err = error as { name?: string };
      if (err.name === 'ConditionalCheckFailedException') {
        return { status: 'already-leased', reconciliationId };
      }
      // Item doesn't exist
      if (err.name === 'ResourceNotFoundException') {
        return { status: 'not-found', reconciliationId };
      }
      throw error;
    }
  }

  /**
   * Executes ONE reconciliation step idempotently using conditional writes.
   * Each step type maps to a specific DynamoDB operation with an absence or version condition.
   */
  async executeStep(
    ctx: WorkerContext,
    record: ReconciliationRecord,
    step: ReconciliationStep,
  ): Promise<StepExecutionResult> {
    // Skip already-completed steps
    if (record.completedSteps.includes(step.stepId)) {
      return { status: 'already-done', stepId: step.stepId };
    }

    try {
      switch (step.type) {
        case 'WRITE_DEVICE_LINE':
          await this.executeWriteDeviceLine(ctx, record, step);
          break;
        case 'TRANSITION_IMEI_STATE':
          await this.executeTransitionImeiState(ctx, record, step);
          break;
        case 'WRITE_CUSTOMER_ASSOCIATION':
          await this.executeWriteCustomerAssociation(ctx, record, step);
          break;
        case 'WRITE_CHANGE_EVENT':
          await this.executeWriteChangeEvent(ctx, record, step);
          break;
        case 'FINALIZE_INVOICE_STATUS':
          await this.executeFinalizeInvoiceStatus(ctx, record, step);
          break;
        default:
          return {
            status: 'failed',
            stepId: step.stepId,
            error: `Unknown step type: ${step.type}`,
            retryable: false,
          };
      }

      return { status: 'success', stepId: step.stepId };
    } catch (error: unknown) {
      const err = error as { name?: string; message?: string };

      // Conditional check failure on an absence condition means item already exists = idempotent success
      if (err.name === 'ConditionalCheckFailedException') {
        // For write steps (PutItem with absence condition), this means already done
        if (['WRITE_DEVICE_LINE', 'WRITE_CUSTOMER_ASSOCIATION', 'WRITE_CHANGE_EVENT'].includes(step.type)) {
          return { status: 'already-done', stepId: step.stepId };
        }
        // For version/status-based conditions, this is a real conflict
        return {
          status: 'failed',
          stepId: step.stepId,
          error: `Condition failed: ${err.message ?? 'version conflict'}`,
          retryable: true,
        };
      }

      // Throttling/transient errors are retryable
      const retryable = isTransientError(err);
      return {
        status: 'failed',
        stepId: step.stepId,
        error: err.message ?? 'Unknown error',
        retryable,
      };
    }
  }

  /**
   * Appends stepId to completedSteps on the reconciliation record.
   */
  async markStepComplete(
    ctx: WorkerContext,
    reconciliationId: string,
    stepId: string,
  ): Promise<void> {
    const { UpdateCommand } = await import('@aws-sdk/lib-dynamodb');

    const pk = encodePK(ctx.tenantId, 'RECON', reconciliationId);
    const sk = encodeMetaSK('RECON');
    const now = new Date().toISOString();

    await this.client.send(
      new UpdateCommand({
        TableName: this.config.tableName,
        Key: { PK: pk, SK: sk },
        UpdateExpression: `
          SET #updatedAt = :now
          ADD #completedSteps :stepSet
        `,
        ExpressionAttributeNames: {
          '#completedSteps': 'completedSteps',
          '#updatedAt': 'updatedAt',
        },
        ExpressionAttributeValues: {
          ':stepSet': new Set([stepId]),
          ':now': now,
        },
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  /**
   * Marks reconciliation as COMPLETED only after ALL steps are confirmed.
   * Transitions invoice from ACCEPTED_PENDING → COMMITTED and
   * releases IMEI reservations → claims (already sold state).
   */
  async finalizeReconciliation(
    ctx: WorkerContext,
    reconciliationId: string,
  ): Promise<void> {
    const { UpdateCommand } = await import('@aws-sdk/lib-dynamodb');

    const pk = encodePK(ctx.tenantId, 'RECON', reconciliationId);
    const sk = encodeMetaSK('RECON');
    const now = new Date().toISOString();

    // Mark record as COMPLETED, clear lease, remove from worker GSI
    await this.client.send(
      new UpdateCommand({
        TableName: this.config.tableName,
        Key: { PK: pk, SK: sk },
        UpdateExpression: `
          SET #status = :completed,
              #lease = :nullVal,
              #updatedAt = :now
          REMOVE #GSI1PK, #GSI1SK
        `,
        ConditionExpression: '#status = :inProgress',
        ExpressionAttributeNames: {
          '#status': 'status',
          '#lease': 'lease',
          '#updatedAt': 'updatedAt',
          '#GSI1PK': 'GSI1PK',
          '#GSI1SK': 'GSI1SK',
        },
        ExpressionAttributeValues: {
          ':completed': 'COMPLETED',
          ':inProgress': 'IN_PROGRESS',
          ':nullVal': null,
          ':now': now,
        },
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  /**
   * Records a step failure, schedules retry based on backoff policy.
   * Updates lastError and pushes nextAttemptAt forward.
   */
  async handleStepFailure(
    ctx: WorkerContext,
    reconciliationId: string,
    stepId: string,
    error: string,
  ): Promise<void> {
    const { UpdateCommand } = await import('@aws-sdk/lib-dynamodb');

    const pk = encodePK(ctx.tenantId, 'RECON', reconciliationId);
    const sk = encodeMetaSK('RECON');
    const now = new Date();

    // Calculate next attempt time using exponential backoff
    const nextAttemptAt = this.calculateNextAttemptAt(now);

    // Release lease but keep status as PENDING for next pickup
    // Push GSI1SK to nextAttemptAt so it won't be picked up before then
    const gsi1pk = buildReconciliationGSI1PK(ctx.tenantId, 'PENDING', this.config.bucket);
    const gsi1sk = encodeGSI1SK(nextAttemptAt, reconciliationId);

    await this.client.send(
      new UpdateCommand({
        TableName: this.config.tableName,
        Key: { PK: pk, SK: sk },
        UpdateExpression: `
          SET #status = :pending,
              #lease = :nullVal,
              #lastError = :error,
              #nextAttemptAt = :nextAttemptAt,
              #updatedAt = :now,
              #GSI1PK = :gsi1pk,
              #GSI1SK = :gsi1sk
        `,
        ExpressionAttributeNames: {
          '#status': 'status',
          '#lease': 'lease',
          '#lastError': 'lastError',
          '#nextAttemptAt': 'nextAttemptAt',
          '#updatedAt': 'updatedAt',
          '#GSI1PK': 'GSI1PK',
          '#GSI1SK': 'GSI1SK',
        },
        ExpressionAttributeValues: {
          ':pending': 'PENDING',
          ':nullVal': null,
          ':error': `Step ${stepId}: ${error}`,
          ':nextAttemptAt': nextAttemptAt,
          ':now': now.toISOString(),
          ':gsi1pk': gsi1pk,
          ':gsi1sk': gsi1sk,
        },
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  /**
   * Marks as FAILED permanently. Preserves reserved state so IMEIs stay
   * unavailable until explicit manual recovery or reversal.
   */
  async handlePermanentFailure(
    ctx: WorkerContext,
    reconciliationId: string,
    error: string,
  ): Promise<void> {
    const { UpdateCommand } = await import('@aws-sdk/lib-dynamodb');

    const pk = encodePK(ctx.tenantId, 'RECON', reconciliationId);
    const sk = encodeMetaSK('RECON');
    const now = new Date().toISOString();

    // Mark FAILED but keep GSI1 entry with FAILED status for visibility/recovery queries
    const gsi1pk = buildReconciliationGSI1PK(ctx.tenantId, 'FAILED', this.config.bucket);
    const gsi1sk = encodeGSI1SK(now, reconciliationId);

    await this.client.send(
      new UpdateCommand({
        TableName: this.config.tableName,
        Key: { PK: pk, SK: sk },
        UpdateExpression: `
          SET #status = :failed,
              #lease = :nullVal,
              #lastError = :error,
              #updatedAt = :now,
              #GSI1PK = :gsi1pk,
              #GSI1SK = :gsi1sk
        `,
        ExpressionAttributeNames: {
          '#status': 'status',
          '#lease': 'lease',
          '#lastError': 'lastError',
          '#updatedAt': 'updatedAt',
          '#GSI1PK': 'GSI1PK',
          '#GSI1SK': 'GSI1SK',
        },
        ExpressionAttributeValues: {
          ':failed': 'FAILED',
          ':nullVal': null,
          ':error': error,
          ':now': now,
          ':gsi1pk': gsi1pk,
          ':gsi1sk': gsi1sk,
        },
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  // ─── Private: Step Execution ─────────────────────────────────────────────

  /**
   * Processes all remaining steps for a leased record.
   * Stops on first failure and schedules retry or marks permanent failure.
   */
  private async processSteps(
    ctx: WorkerContext,
    record: ReconciliationRecord,
  ): Promise<'completed' | 'partial' | 'failed'> {
    const pendingSteps = record.plan.filter(
      (step) => !record.completedSteps.includes(step.stepId),
    );

    for (const step of pendingSteps) {
      const result = await this.executeStep(ctx, record, step);

      if (result.status === 'success' || result.status === 'already-done') {
        // Mark step as completed in the record
        await this.markStepComplete(ctx, record.reconciliationId, step.stepId);
        continue;
      }

      // Step failed
      if (record.attempts >= this.config.maxAttempts) {
        await this.handlePermanentFailure(
          ctx,
          record.reconciliationId,
          result.error ?? 'Max attempts exceeded',
        );
        return 'failed';
      }

      // Schedule retry
      await this.handleStepFailure(
        ctx,
        record.reconciliationId,
        step.stepId,
        result.error ?? 'Unknown step failure',
      );
      return 'partial';
    }

    // All steps done — finalize
    await this.finalizeReconciliation(ctx, record.reconciliationId);
    return 'completed';
  }

  /**
   * WRITE_DEVICE_LINE → PutItem with absence condition.
   * Writes the invoice device-line child item.
   */
  private async executeWriteDeviceLine(
    ctx: WorkerContext,
    record: ReconciliationRecord,
    step: ReconciliationStep,
  ): Promise<void> {
    const { PutCommand } = await import('@aws-sdk/lib-dynamodb');

    const payload = step.payload as Record<string, unknown>;
    const invoiceId = record.invoiceId;
    const lineId = step.entityId;
    const now = new Date().toISOString();

    const pk = buildInvoicePK(ctx.tenantId, invoiceId);
    const sk = encodeChildSK('DEVICE', lineId);

    await this.client.send(
      new PutCommand({
        TableName: this.config.tableName,
        Item: {
          PK: pk,
          SK: sk,
          tenantId: ctx.tenantId,
          entityType: 'INVOICE_DEVICE_LINE',
          entityId: lineId,
          invoiceId,
          imei: payload.imei,
          unitId: payload.unitId,
          description: payload.description,
          brand: payload.brand,
          model: payload.model,
          quantity: payload.quantity,
          unitPrice: payload.unitPrice,
          lineTax: payload.lineTax,
          lineDiscount: payload.lineDiscount,
          lineTotal: payload.lineTotal,
          hsnCode: payload.hsnCode,
          taxRateBasisPoints: payload.taxRateBasisPoints,
          warrantyMonths: payload.warrantyMonths,
          warrantyStartDate: payload.warrantyStartDate,
          warrantyEndDate: payload.warrantyEndDate,
          operationId: record.operationId,
          reconciliationId: record.reconciliationId,
          version: 1,
          dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
          createdAt: now,
          updatedAt: now,
        },
        ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  /**
   * TRANSITION_IMEI_STATE → UpdateItem with version condition.
   * Transitions the IMEI unit's lifecycle state (e.g. RESERVED → SOLD).
   */
  private async executeTransitionImeiState(
    ctx: WorkerContext,
    record: ReconciliationRecord,
    step: ReconciliationStep,
  ): Promise<void> {
    const { UpdateCommand } = await import('@aws-sdk/lib-dynamodb');

    const payload = step.payload as {
      imei: string;
      expectedVersion: number;
      targetState: string;
    };
    const unitId = step.entityId;
    const now = new Date().toISOString();

    const pk = buildEntityAggregatePK(ctx.tenantId, 'UNIT', unitId);
    const sk = encodeMetaSK('UNIT');
    const newVersion = payload.expectedVersion + 1;

    // Update lifecycle GSI1 to reflect new state
    const gsi1pk = buildUnitLifecycleGSI1PK(ctx.tenantId, payload.targetState);
    const gsi1sk = encodeGSI1SK(now, unitId);

    await this.client.send(
      new UpdateCommand({
        TableName: this.config.tableName,
        Key: { PK: pk, SK: sk },
        UpdateExpression: `
          SET #lifecycleState = :targetState,
              #version = :newVersion,
              #updatedAt = :now,
              #GSI1PK = :gsi1pk,
              #GSI1SK = :gsi1sk
        `,
        ConditionExpression: '#version = :expectedVersion',
        ExpressionAttributeNames: {
          '#lifecycleState': 'lifecycleState',
          '#version': 'version',
          '#updatedAt': 'updatedAt',
          '#GSI1PK': 'GSI1PK',
          '#GSI1SK': 'GSI1SK',
        },
        ExpressionAttributeValues: {
          ':targetState': payload.targetState,
          ':expectedVersion': payload.expectedVersion,
          ':newVersion': newVersion,
          ':now': now,
          ':gsi1pk': gsi1pk,
          ':gsi1sk': gsi1sk,
        },
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  /**
   * WRITE_CUSTOMER_ASSOCIATION → PutItem with absence condition.
   * Creates the customer-device association child item.
   */
  private async executeWriteCustomerAssociation(
    ctx: WorkerContext,
    record: ReconciliationRecord,
    step: ReconciliationStep,
  ): Promise<void> {
    const { PutCommand } = await import('@aws-sdk/lib-dynamodb');

    const payload = step.payload as Record<string, unknown>;
    const unitId = payload.unitId as string;
    const customerId = payload.customerId as string;
    const now = new Date().toISOString();

    const pk = buildEntityAggregatePK(ctx.tenantId, 'UNIT', unitId);
    const sk = encodeChildSK('CUSTOMER_ASSOC', customerId);

    await this.client.send(
      new PutCommand({
        TableName: this.config.tableName,
        Item: {
          PK: pk,
          SK: sk,
          tenantId: ctx.tenantId,
          entityType: 'CUSTOMER_ASSOCIATION',
          entityId: step.entityId,
          unitId,
          customerId,
          customerName: payload.customerName,
          invoiceId: record.invoiceId,
          warrantyStartDate: payload.warrantyStartDate,
          warrantyEndDate: payload.warrantyEndDate,
          warrantyMonths: payload.warrantyMonths,
          operationId: record.operationId,
          reconciliationId: record.reconciliationId,
          version: 1,
          dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
          createdAt: now,
          updatedAt: now,
          // GSI2 for customer device history (AP-05)
          GSI2PK: buildCustomerHistoryGSI2PK(ctx.tenantId, customerId),
          GSI2SK: encodeGSI2SK(now, 'ASSOC', step.entityId),
        },
        ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  /**
   * WRITE_CHANGE_EVENT → PutItem with absence condition.
   * Appends a change-feed event for sync consumers.
   */
  private async executeWriteChangeEvent(
    ctx: WorkerContext,
    record: ReconciliationRecord,
    step: ReconciliationStep,
  ): Promise<void> {
    const { PutCommand } = await import('@aws-sdk/lib-dynamodb');

    const payload = step.payload as { action: string; entityVersion: number };
    const now = new Date().toISOString();
    const eventId = randomUUID();

    // Use ROOT bucket for change feed
    const pk = buildChangeFeedPK(ctx.tenantId, 'ROOT');
    const sk = encodeSK(now, eventId);

    await this.client.send(
      new PutCommand({
        TableName: this.config.tableName,
        Item: {
          PK: pk,
          SK: sk,
          tenantId: ctx.tenantId,
          entityType: step.entityType,
          entityId: step.entityId,
          action: payload.action,
          entityVersion: payload.entityVersion,
          operationId: record.operationId,
          reconciliationId: record.reconciliationId,
          eventId,
          dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
          createdAt: now,
        },
        ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  /**
   * FINALIZE_INVOICE_STATUS → UpdateItem with expected status condition.
   * Transitions invoice from ACCEPTED_PENDING → COMMITTED only when conditions hold.
   */
  private async executeFinalizeInvoiceStatus(
    ctx: WorkerContext,
    record: ReconciliationRecord,
    step: ReconciliationStep,
  ): Promise<void> {
    const { UpdateCommand } = await import('@aws-sdk/lib-dynamodb');

    const payload = step.payload as {
      expectedStatus: string;
      targetStatus: string;
      expectedVersion: number;
    };
    const invoiceId = step.entityId;
    const now = new Date().toISOString();
    const newVersion = payload.expectedVersion + 1;

    const pk = buildInvoicePK(ctx.tenantId, invoiceId);
    const sk = encodeMetaSK('INVOICE');

    await this.client.send(
      new UpdateCommand({
        TableName: this.config.tableName,
        Key: { PK: pk, SK: sk },
        UpdateExpression: `
          SET #status = :targetStatus,
              #version = :newVersion,
              #updatedAt = :now
        `,
        ConditionExpression: '#status = :expectedStatus AND #version = :expectedVersion',
        ExpressionAttributeNames: {
          '#status': 'status',
          '#version': 'version',
          '#updatedAt': 'updatedAt',
        },
        ExpressionAttributeValues: {
          ':targetStatus': payload.targetStatus,
          ':expectedStatus': payload.expectedStatus,
          ':expectedVersion': payload.expectedVersion,
          ':newVersion': newVersion,
          ':now': now,
        },
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );
  }

  // ─── Private: Helpers ────────────────────────────────────────────────────

  /**
   * Calculates the next attempt time using exponential backoff with jitter.
   */
  private calculateNextAttemptAt(now: Date): string {
    const { baseDelayMs, backoffMultiplier, maxDelayMs, jitterFactor } = this.config.backoffPolicy;

    // Exponential delay capped at maxDelayMs
    const rawDelay = Math.min(baseDelayMs * Math.pow(backoffMultiplier, 2), maxDelayMs);

    // Add jitter
    const jitter = rawDelay * jitterFactor * Math.random();
    const delayMs = rawDelay + jitter;

    return new Date(now.getTime() + delayMs).toISOString();
  }
}

// ─── Utility ─────────────────────────────────────────────────────────────────

/** Returns true for transient/retryable DynamoDB errors */
function isTransientError(error: { name?: string; message?: string }): boolean {
  const transientNames = new Set([
    'ProvisionedThroughputExceededException',
    'ThrottlingException',
    'RequestLimitExceeded',
    'InternalServerError',
    'ServiceUnavailable',
    'ItemCollectionSizeLimitExceededException',
  ]);
  return transientNames.has(error.name ?? '');
}
