/**
 * Accepted-Pending Handler — MobileShop Application Layer
 *
 * Handles oversized sale operations that exceed DynamoDB transaction limits.
 * Persists a SMALLER transaction containing:
 *   1. Accepted aggregate state (invoice header with status=ACCEPTED_PENDING)
 *   2. IMEI reservation/claim items (keep IMEIs unavailable to competing sales)
 *   3. Idempotency record (status=ACCEPTED_PENDING, responseRef=reconciliationId)
 *   4. Initial audit event (SALE_ACCEPTED_PENDING)
 *   5. Reconciliation_Record (ordered steps for remaining effects)
 *
 * After DynamoDB confirms the write, returns SaleAcceptedPending with
 * AuthoritativeConfirmation. Workers (task 8.1) pick up the reconciliation
 * record and complete remaining effects.
 *
 * Requirements: 3.4–3.6, 6.9, 6.32, 6.42; GR-2.3, GR-3.3
 */

import { randomUUID } from 'crypto';
import type { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import type { TenantContextWire } from '../schemas/common.schema';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import {
  encodePK,
  encodeMetaSK,
  buildInvoicePK,
  buildClaimPK,
  encodeSK,
  encodeGSI1PK,
  encodeGSI1SK,
  encodeGSI2PK,
  encodeGSI2SK,
} from '../persistence/key-codec';
import {
  buildClaimTransactItem,
  buildIdempotencyTransactItem,
} from '../persistence/transaction-items';
import { AuditEventService } from './audit-service';
import type {
  AuthoritativeConfirmation,
  SaleAcceptedPending,
  AcceptedPendingHandler,
} from './sale-outcome';
import type {
  MobileSaleCommand,
  TransactionPlan,
  DeviceLineInput,
} from './transaction-planner';

// ─── Reconciliation Record Types ─────────────────────────────────────────────

/** A single ordered step in the reconciliation plan */
export interface ReconciliationStep {
  readonly stepId: string;
  readonly type: string;
  readonly entityType: string;
  readonly entityId: string;
  readonly payload: Readonly<Record<string, unknown>>;
}

/** Lease state for reconciliation workers */
export interface ReconciliationLease {
  readonly workerId: string;
  readonly acquiredAt: string;
  readonly expiresAt: string;
}

/** The durable Reconciliation_Record persisted in DynamoDB */
export interface ReconciliationRecord {
  readonly PK: string;
  readonly SK: string;
  readonly tenantId: string;
  readonly reconciliationId: string;
  readonly operationId: string;
  readonly invoiceId: string;
  readonly status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED';
  readonly plan: readonly ReconciliationStep[];
  readonly completedSteps: readonly string[];
  readonly attempts: number;
  readonly lease: ReconciliationLease | null;
  readonly nextAttemptAt: string;
  readonly lastError: string | null;
  readonly dataModelVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
  // GSI1 for worker pickup (AP-12)
  readonly GSI1PK: string;
  readonly GSI1SK: string;
}

// ─── Accepted-Pending Handler Implementation ─────────────────────────────────

/**
 * Implements the AcceptedPendingHandler interface.
 *
 * When the transaction planner determines a sale exceeds configured limits,
 * this handler persists a smaller acceptance transaction that:
 * - Reserves all involved IMEIs (claims prevent competing sales)
 * - Records the accepted invoice state
 * - Creates a Reconciliation_Record with ordered steps for remaining work
 * - Returns AuthoritativeConfirmation only after DynamoDB confirms
 */
export class AcceptedPendingHandlerImpl implements AcceptedPendingHandler {
  private readonly tableName: string;
  private readonly auditService: AuditEventService;

  constructor(tableName: string) {
    this.tableName = tableName;
    this.auditService = new AuditEventService(tableName);
  }

  /**
   * Handles an oversized sale by persisting acceptance state and a reconciliation record.
   *
   * The transaction is deliberately SMALLER than the full sale — it contains only:
   * 1. Invoice header (ACCEPTED_PENDING status)
   * 2. IMEI reservation claims (one per device line)
   * 3. Idempotency record (ACCEPTED_PENDING, responseRef = reconciliationId)
   * 4. Audit event (SALE_ACCEPTED_PENDING)
   * 5. Reconciliation_Record (ordered steps for remaining effects)
   */
  async handleOversizedSale(
    client: DynamoDBDocumentClient,
    ctx: TenantContextWire,
    command: MobileSaleCommand,
    plan: TransactionPlan,
  ): Promise<SaleAcceptedPending> {
    const { TransactWriteCommand } = await import('@aws-sdk/lib-dynamodb');

    const now = new Date().toISOString();
    const reconciliationId = randomUUID();

    // Build the smaller accepted-pending transaction items
    const transactItems: Record<string, unknown>[] = [];

    // 1. Invoice header with ACCEPTED_PENDING status
    transactItems.push(
      this.buildAcceptedInvoiceHeader(ctx, command, reconciliationId, now),
    );

    // 2. IMEI reservation claims — keep IMEIs unavailable to competing sales
    for (const line of command.deviceLines) {
      const claimItem = buildClaimTransactItem(
        this.tableName,
        ctx,
        'RESERVATION',
        line.unitId,
        command.invoiceId,
        1,
      );
      transactItems.push(claimItem);
    }

    // 3. Idempotency record with ACCEPTED_PENDING status
    const idempotencyItem = buildIdempotencyTransactItem(
      this.tableName,
      ctx,
      command.operationId,
      command.mutationFingerprint,
      'ACCEPTED_PENDING',
      reconciliationId,
      command.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
    );
    transactItems.push(idempotencyItem);

    // 4. Audit event — SALE_ACCEPTED_PENDING
    const { transactItem: auditItem } = this.auditService.createAuditEvent(ctx, {
      entityType: 'INVOICE',
      entityId: command.invoiceId,
      action: 'SALE_ACCEPTED_PENDING',
      operationId: command.operationId,
      afterState: {
        invoiceId: command.invoiceId,
        invoiceNumber: command.invoiceNumber,
        customerId: command.customerId,
        deviceCount: command.deviceLines.length,
        netAmount: command.netAmount,
        reconciliationId,
      },
    });
    transactItems.push(auditItem);

    // 5. Reconciliation_Record with ordered steps
    const reconRecord = this.buildReconciliationRecord(
      ctx,
      command,
      plan,
      reconciliationId,
      now,
    );
    transactItems.push({
      Put: {
        TableName: this.tableName,
        Item: reconRecord,
        ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
      },
    });

    // Execute the smaller transaction — MUST fit within DynamoDB limits
    await client.send(
      new TransactWriteCommand({
        TransactItems: transactItems as unknown[],
        ReturnConsumedCapacity: 'TOTAL',
      }),
    );

    // Build entity versions for confirmation
    const entityVersions: Record<string, number> = {};
    entityVersions[command.invoiceId] = 1;
    for (const line of command.deviceLines) {
      // IMEIs are reserved but not yet transitioned — version unchanged
      const expectedVersion = command.expectedImeiVersions[line.imei];
      if (expectedVersion !== undefined) {
        entityVersions[line.imei] = expectedVersion;
      }
    }

    const confirmation: AuthoritativeConfirmation = {
      authority: 'AWS_DYNAMODB',
      state: 'ACCEPTED_PENDING',
      operationId: command.operationId,
      confirmedAt: now,
      dataModelVersion: command.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
      entityVersions,
      reconciliationId,
    };

    return {
      type: 'acceptedPending',
      invoiceId: command.invoiceId,
      reconciliationId,
      confirmation,
    };
  }

  // ─── Private: Invoice Header ─────────────────────────────────────────────

  private buildAcceptedInvoiceHeader(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
    reconciliationId: string,
    now: string,
  ): Record<string, unknown> {
    const pk = buildInvoicePK(ctx.tenantId, command.invoiceId);
    const sk = encodeMetaSK('INVOICE');

    const item: Record<string, unknown> = {
      PK: pk,
      SK: sk,
      tenantId: ctx.tenantId,
      entityId: command.invoiceId,
      entityType: 'INVOICE',
      invoiceNumber: command.invoiceNumber,
      status: 'ACCEPTED_PENDING',
      customerId: command.customerId,
      customerName: command.customerName,
      totalAmount: command.totalAmount,
      taxAmount: command.taxAmount,
      discountAmount: command.discountAmount,
      netAmount: command.netAmount,
      invoiceDate: command.invoiceDate,
      operationId: command.operationId,
      reconciliationId,
      version: 1,
      dataModelVersion: command.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
      createdAt: now,
      updatedAt: now,
      ...(command.paymentMethod && { paymentMethod: command.paymentMethod }),
      ...(command.paymentReference && { paymentReference: command.paymentReference }),
      ...(command.dueDate && { dueDate: command.dueDate }),
      ...(command.notes && { notes: command.notes }),
      // GSI2 for customer history (AP-05)
      GSI2PK: encodeGSI2PK(ctx.tenantId, 'CUSTOMER', command.customerId),
      GSI2SK: encodeGSI2SK(now, 'INVOICE', command.invoiceId),
    };

    return {
      Put: {
        TableName: this.tableName,
        Item: item,
        ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
      },
    };
  }

  // ─── Private: Reconciliation Record ──────────────────────────────────────

  private buildReconciliationRecord(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
    plan: TransactionPlan,
    reconciliationId: string,
    now: string,
  ): ReconciliationRecord {
    const pk = encodePK(ctx.tenantId, 'RECON', reconciliationId);
    const sk = encodeMetaSK('RECON');

    // Build ordered steps for effects that didn't fit the first transaction
    const steps = this.buildReconciliationSteps(command);

    // GSI1 for worker pickup (AP-12): TENANT#t#RECON#PENDING#ROOT
    const gsi1pk = encodeGSI1PK(ctx.tenantId, 'RECON', 'PENDING#ROOT');
    const gsi1sk = encodeGSI1SK(now, reconciliationId);

    return {
      PK: pk,
      SK: sk,
      tenantId: ctx.tenantId,
      reconciliationId,
      operationId: command.operationId,
      invoiceId: command.invoiceId,
      status: 'PENDING',
      plan: steps,
      completedSteps: [],
      attempts: 0,
      lease: null,
      nextAttemptAt: now, // Immediately available for pickup
      lastError: null,
      dataModelVersion: command.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
      createdAt: now,
      updatedAt: now,
      GSI1PK: gsi1pk,
      GSI1SK: gsi1sk,
    };
  }

  /**
   * Builds ordered reconciliation steps from the full plan.
   *
   * The steps represent effects that remain after the accepted-pending
   * transaction. Workers execute these in order:
   * 1. Device line/association items (per device)
   * 2. IMEI lifecycle state transitions (per device)
   * 3. Customer associations (per device)
   * 4. Change-feed event
   * 5. Final status transition (ACCEPTED_PENDING → COMMITTED)
   */
  private buildReconciliationSteps(command: MobileSaleCommand): ReconciliationStep[] {
    const steps: ReconciliationStep[] = [];

    // Step group: Device line items
    for (const line of command.deviceLines) {
      steps.push({
        stepId: randomUUID(),
        type: 'WRITE_DEVICE_LINE',
        entityType: 'INVOICE_DEVICE_LINE',
        entityId: line.lineId,
        payload: {
          invoiceId: command.invoiceId,
          imei: line.imei,
          unitId: line.unitId,
          description: line.description,
          brand: line.brand,
          model: line.model,
          quantity: line.quantity,
          unitPrice: line.unitPrice,
          lineTax: line.lineTax,
          lineDiscount: line.lineDiscount,
          lineTotal: line.lineTotal,
          hsnCode: line.hsnCode,
          taxRateBasisPoints: line.taxRateBasisPoints,
          warrantyMonths: line.warrantyMonths,
          warrantyStartDate: line.warrantyStartDate,
          warrantyEndDate: line.warrantyEndDate,
        },
      });
    }

    // Step group: IMEI lifecycle transitions (IN_STOCK/RESERVED → SOLD)
    for (const line of command.deviceLines) {
      const expectedVersion = command.expectedImeiVersions[line.imei];
      steps.push({
        stepId: randomUUID(),
        type: 'TRANSITION_IMEI_STATE',
        entityType: 'UNIT',
        entityId: line.unitId,
        payload: {
          imei: line.imei,
          expectedVersion: expectedVersion ?? 1,
          targetState: 'SOLD',
        },
      });
    }

    // Step group: Customer associations
    for (const line of command.deviceLines) {
      steps.push({
        stepId: randomUUID(),
        type: 'WRITE_CUSTOMER_ASSOCIATION',
        entityType: 'CUSTOMER_ASSOCIATION',
        entityId: `${line.unitId}_${command.customerId}`,
        payload: {
          unitId: line.unitId,
          customerId: command.customerId,
          customerName: command.customerName,
          invoiceId: command.invoiceId,
          warrantyStartDate: line.warrantyStartDate,
          warrantyEndDate: line.warrantyEndDate,
          warrantyMonths: line.warrantyMonths,
        },
      });
    }

    // Step: Change-feed event
    steps.push({
      stepId: randomUUID(),
      type: 'WRITE_CHANGE_EVENT',
      entityType: 'INVOICE',
      entityId: command.invoiceId,
      payload: {
        action: 'SALE_COMMITTED',
        entityVersion: 1,
      },
    });

    // Step: Final status transition (ACCEPTED_PENDING → COMMITTED)
    steps.push({
      stepId: randomUUID(),
      type: 'FINALIZE_INVOICE_STATUS',
      entityType: 'INVOICE',
      entityId: command.invoiceId,
      payload: {
        expectedStatus: 'ACCEPTED_PENDING',
        targetStatus: 'COMMITTED',
        expectedVersion: 1,
      },
    });

    return steps;
  }
}
