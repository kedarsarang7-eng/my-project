/**
 * Atomic Sale Handler — MobileShop Application Layer
 *
 * Orchestrates the complete sale flow:
 * 1. Check idempotency (replay/mismatch/expired/new)
 * 2. Validate IMEI, schema, lifecycle preconditions
 * 3. Build transaction plan
 * 4. If fits → execute TransactWriteItems atomically
 * 5. Map success → committed outcome with AuthoritativeConfirmation
 * 6. Map ConditionalCheckFailed/TransactionCancelled → deterministic error
 * 7. Map ambiguous → handleAmbiguousOutcome
 * 8. If doesn't fit → delegate to accepted-pending handler (task 6.2)
 *
 * Requirements: 3.1–3.4, 3.7–3.9, 6.9–6.13, 6.31, 6.42
 */

import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../schemas/common.schema';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import { checkIdempotency, type IdempotencyCheckResult } from '../persistence/idempotency';
import {
  mapTransactionCancellation,
  mapDynamoDbError,
  type DeterministicOutcome,
  type TransactItemDescriptor,
} from './error-mapper';
import { handleAmbiguousOutcome } from './ambiguous-outcome-handler';
import {
  TransactionPlanner,
  type MobileSaleCommand,
  type TransactionPlan,
} from './transaction-planner';
import type {
  AuthoritativeConfirmation,
  SaleOutcome,
  AcceptedPendingHandler,
} from './sale-outcome';

// Re-export types for backward compatibility with barrel export
export type {
  AuthoritativeConfirmation,
  SaleOutcome,
  SaleCommitted,
  SaleAcceptedPending,
  SaleConflict,
  SaleRejected,
  SaleReplay,
  AcceptedPendingHandler,
} from './sale-outcome';

// ─── Atomic Sale Handler ─────────────────────────────────────────────────────

/**
 * Atomic sale handler: orchestrates idempotency, validation, planning,
 * and execution of an atomic DynamoDB transaction for mobile device sales.
 */
export class AtomicSaleHandler {
  private readonly client: DynamoDBDocumentClient;
  private readonly tableName: string;
  private readonly planner: TransactionPlanner;
  private readonly acceptedPendingHandler: AcceptedPendingHandler | null;

  constructor(
    client: DynamoDBDocumentClient,
    tableName: string,
    acceptedPendingHandler?: AcceptedPendingHandler,
  ) {
    this.client = client;
    this.tableName = tableName;
    this.planner = new TransactionPlanner(tableName);
    this.acceptedPendingHandler = acceptedPendingHandler ?? null;
  }

  /**
   * Handles a mobile sale command end-to-end.
   *
   * Steps:
   * 1. Check idempotency
   * 2. Validate preconditions
   * 3. Plan transaction
   * 4. Execute or delegate
   */
  async handleSale(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
  ): Promise<SaleOutcome> {
    // ─── Step 1: Idempotency Check ─────────────────────────────────────────
    const idempotencyResult = await this.checkIdempotency(ctx, command);
    if (idempotencyResult) {
      return idempotencyResult;
    }

    // ─── Step 2: Validate Preconditions ────────────────────────────────────
    const validationError = this.validatePreconditions(ctx, command);
    if (validationError) {
      return { type: 'rejected', outcome: validationError };
    }

    // ─── Step 3: Plan Transaction ──────────────────────────────────────────
    const plan = this.planner.planSaleTransaction(ctx, command);

    // ─── Step 4: Execute or Delegate ───────────────────────────────────────
    if (plan.fits) {
      return this.executeAtomicTransaction(ctx, command, plan);
    }

    // Oversized — delegate to accepted-pending handler
    return this.delegateToAcceptedPending(ctx, command, plan);
  }

  // ─── Private: Idempotency ──────────────────────────────────────────────────

  private async checkIdempotency(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
  ): Promise<SaleOutcome | null> {
    let result: IdempotencyCheckResult;

    try {
      result = await checkIdempotency(
        this.client,
        this.tableName,
        ctx,
        command.operationId,
        command.mutationFingerprint,
      );
    } catch {
      // Cannot check idempotency — this is a system error, not ambiguous
      // Proceeding would risk duplicate. Return system error.
      return {
        type: 'rejected',
        outcome: {
          code: 'INTERNAL_ERROR',
          category: 'system',
          retryable: true,
          statePreserved: true,
          fields: [],
          httpStatus: 500,
          correlationId: ctx.correlationId,
        },
      };
    }

    switch (result.outcome) {
      case 'REPLAY':
        return {
          type: 'replay',
          operationId: command.operationId,
          status: result.status,
          responseRef: result.responseRef,
        };

      case 'FINGERPRINT_MISMATCH':
        return {
          type: 'conflict',
          outcome: {
            code: 'IDEMPOTENCY_MISMATCH',
            category: 'idempotency',
            retryable: false,
            statePreserved: true,
            fields: ['operationId', 'mutationFingerprint'],
            httpStatus: 409,
            correlationId: ctx.correlationId,
          },
        };

      case 'EXPIRED':
        return {
          type: 'rejected',
          outcome: {
            code: 'IDEMPOTENCY_EXPIRED',
            category: 'idempotency',
            retryable: false,
            statePreserved: true,
            fields: ['operationId'],
            httpStatus: 409,
            correlationId: ctx.correlationId,
          },
        };

      case 'NEW_OPERATION':
        // Proceed with the sale
        return null;
    }
  }

  // ─── Private: Validation ───────────────────────────────────────────────────

  private validatePreconditions(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
  ): DeterministicOutcome | null {
    // Validate operationId presence
    if (!command.operationId || command.operationId.trim().length === 0) {
      return {
        code: 'OPERATION_ID_MISSING',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['operationId'],
        httpStatus: 400,
        correlationId: ctx.correlationId,
      };
    }

    // Validate fingerprint presence
    if (!command.mutationFingerprint || command.mutationFingerprint.trim().length === 0) {
      return {
        code: 'FINGERPRINT_MISSING',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['mutationFingerprint'],
        httpStatus: 400,
        correlationId: ctx.correlationId,
      };
    }

    // Validate at least one device line
    if (!command.deviceLines || command.deviceLines.length === 0) {
      return {
        code: 'SCHEMA_INVALID',
        category: 'validation',
        retryable: false,
        statePreserved: true,
        fields: ['deviceLines'],
        httpStatus: 400,
        correlationId: ctx.correlationId,
      };
    }

    // Validate all device lines have expected IMEI versions
    for (const line of command.deviceLines) {
      if (command.expectedImeiVersions[line.imei] === undefined) {
        return {
          code: 'SCHEMA_INVALID',
          category: 'validation',
          retryable: false,
          statePreserved: true,
          fields: ['expectedImeiVersions', 'imei'],
          httpStatus: 400,
          correlationId: ctx.correlationId,
        };
      }
    }

    // Validate data model version is supported
    const { minSupportedVersion, maxSupportedVersion } = MODEL_VERSION_CONFIG;
    if (
      command.dataModelVersion < minSupportedVersion ||
      command.dataModelVersion > maxSupportedVersion
    ) {
      return {
        code: 'MODEL_VERSION_UNSUPPORTED',
        category: 'version',
        retryable: false,
        statePreserved: true,
        fields: ['dataModelVersion'],
        httpStatus: 400,
        correlationId: ctx.correlationId,
      };
    }

    return null;
  }

  // ─── Private: Atomic Execution ─────────────────────────────────────────────

  private async executeAtomicTransaction(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
    plan: TransactionPlan,
  ): Promise<SaleOutcome> {
    const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');

    // Build the TransactWriteItems array
    const transactItems = plan.items.map((item) => item.transactItem);
    const descriptors = plan.items.map((item) => item.descriptor);

    try {
      await this.client.send(
        new TransactWriteCommand({
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          TransactItems: transactItems as any,
          ReturnConsumedCapacity: 'TOTAL',
        }),
      );

      // Success — build authoritative confirmation
      const entityVersions: Record<string, number> = {};
      for (const line of command.deviceLines) {
        const expectedVersion = command.expectedImeiVersions[line.imei];
        if (expectedVersion !== undefined) {
          entityVersions[line.imei] = expectedVersion + 1;
        }
      }
      entityVersions[command.invoiceId] = 1;

      const confirmation: AuthoritativeConfirmation = {
        authority: 'AWS_DYNAMODB',
        state: 'COMMITTED',
        operationId: command.operationId,
        confirmedAt: new Date().toISOString(),
        dataModelVersion: command.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
        entityVersions,
      };

      return {
        type: 'committed',
        invoiceId: command.invoiceId,
        confirmation,
      };
    } catch (error: unknown) {
      return this.handleTransactionError(ctx, command, error, descriptors);
    }
  }

  // ─── Private: Error Handling ───────────────────────────────────────────────

  private async handleTransactionError(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
    error: unknown,
    descriptors: readonly TransactItemDescriptor[],
  ): Promise<SaleOutcome> {
    const errorName = this.extractErrorName(error);

    // TransactionCanceledException — per-item reason decoding
    if (errorName === 'TransactionCanceledException') {
      const reasons = this.extractCancellationReasons(error);
      const outcome = mapTransactionCancellation(reasons, descriptors, ctx.correlationId);
      return { type: 'conflict', outcome };
    }

    // ConditionalCheckFailedException (shouldn't happen in transaction, but handle)
    if (errorName === 'ConditionalCheckFailedException') {
      const outcome = mapDynamoDbError(error, {
        correlationId: ctx.correlationId,
        conditionType: 'COMPOSITE',
      });
      return { type: 'conflict', outcome };
    }

    // Ambiguous — SDK timeout or unknown response
    if (this.isAmbiguous(error)) {
      const resolution = await handleAmbiguousOutcome(
        this.client,
        this.tableName,
        ctx,
        command.operationId,
        command.mutationFingerprint,
      );

      if (resolution.resolved) {
        return {
          type: 'replay',
          operationId: command.operationId,
          status: resolution.outcome.status,
          responseRef: resolution.outcome.responseRef,
        };
      }

      // Unresolved ambiguous — return deterministic error
      return { type: 'rejected', outcome: resolution.outcome };
    }

    // Throttling or other mapped errors
    const outcome = mapDynamoDbError(error, {
      correlationId: ctx.correlationId,
      conditionType: 'COMPOSITE',
    });
    return { type: 'rejected', outcome };
  }

  // ─── Private: Delegation ───────────────────────────────────────────────────

  private async delegateToAcceptedPending(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
    plan: TransactionPlan,
  ): Promise<SaleOutcome> {
    if (!this.acceptedPendingHandler) {
      // No handler configured — report that the operation is too large
      return {
        type: 'rejected',
        outcome: {
          code: 'INTERNAL_ERROR',
          category: 'system',
          retryable: false,
          statePreserved: true,
          fields: [],
          httpStatus: 500,
          correlationId: ctx.correlationId,
          details: {
            cancellationReasons: [
              `Transaction exceeds limits: ${plan.totalItems} items (max ${plan.maxItems}), ` +
              `${plan.estimatedSizeBytes} bytes (max ${plan.maxBytes})`,
            ],
          },
        },
      };
    }

    return this.acceptedPendingHandler.handleOversizedSale(
      this.client,
      ctx,
      command,
      plan,
    );
  }

  // ─── Private: Error Utilities ──────────────────────────────────────────────

  private extractErrorName(error: unknown): string | undefined {
    if (error && typeof error === 'object') {
      if ('name' in error && typeof (error as { name: unknown }).name === 'string') {
        return (error as { name: string }).name;
      }
      if ('__type' in error && typeof (error as { __type: unknown }).__type === 'string') {
        const type = (error as { __type: string }).__type;
        return type.includes('#') ? type.split('#')[1] : type;
      }
    }
    return undefined;
  }

  private extractCancellationReasons(error: unknown): string[] {
    if (!error || typeof error !== 'object') return [];

    if ('CancellationReasons' in error) {
      const reasons = (error as { CancellationReasons: unknown[] }).CancellationReasons;
      if (Array.isArray(reasons)) {
        return reasons.map((r) => {
          if (r && typeof r === 'object' && 'Code' in r) {
            return (r as { Code: string }).Code;
          }
          return 'None';
        });
      }
    }

    return [];
  }

  private isAmbiguous(error: unknown): boolean {
    if (!error || typeof error !== 'object') return false;

    const name = this.extractErrorName(error);
    if (name === 'TimeoutError' || name === 'RequestTimeout' || name === 'NetworkingError') {
      return true;
    }

    if ('code' in error) {
      const code = (error as { code: unknown }).code;
      if (typeof code === 'string') {
        return ['ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND', 'EPIPE', 'ECONNRESET'].includes(code);
      }
    }

    if ('$metadata' in error) {
      const meta = (error as { $metadata: unknown }).$metadata;
      if (meta && typeof meta === 'object' && !('httpStatusCode' in meta)) {
        return true;
      }
    }

    return false;
  }
}
