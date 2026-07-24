/**
 * Transaction Planner — MobileShop Application Layer
 *
 * PURE computation: builds the list of TransactWriteItems for an atomic
 * mobile sale, calculates fit against TRANSACTION_FIT_CONFIG, and returns
 * a TransactionPlan indicating whether the operation fits one DynamoDB
 * transaction or must overflow to accepted-pending + reconciliation.
 *
 * This module makes ZERO DynamoDB calls — it only constructs item shapes
 * and estimates encoded size.
 *
 * Requirements: 3.1–3.4, 3.7–3.9, 6.9–6.13, 6.31, 6.42
 */

import { randomUUID } from 'crypto';
import type { TenantContextWire, Money } from '../schemas/common.schema';
import type { InvoiceDeviceLine } from '../schemas/invoice.schema';
import { TRANSACTION_FIT_CONFIG } from '../config/transaction-fit.config';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import {
  encodePK,
  encodeMetaSK,
  encodeChildSK,
  buildInvoicePK,
  buildEntityAggregatePK,
  encodeGSI1PK,
  encodeGSI1SK,
  encodeGSI2PK,
  encodeGSI2SK,
} from '../persistence/key-codec';
import {
  buildClaimTransactItem,
  buildIdempotencyTransactItem,
  type TransactPutItem,
} from '../persistence/transaction-items';
import {
  AuditEventService,
  type CreateAuditEventParams,
} from './audit-service';
import type { TransactItemDescriptor, ConditionType } from './error-mapper';
import { DeviceLifecycleState } from '../domain/device-lifecycle';

// ─── Command Types ───────────────────────────────────────────────────────────

/** Sale command input for the transaction planner */
export interface MobileSaleCommand {
  readonly operationId: string;
  readonly mutationFingerprint: string;
  readonly invoiceId: string;
  readonly invoiceNumber: string;
  readonly customerId: string;
  readonly customerName: string;
  readonly totalAmount: Money;
  readonly taxAmount: Money;
  readonly discountAmount: Money;
  readonly netAmount: Money;
  readonly invoiceDate: string;
  readonly paymentMethod?: string;
  readonly paymentReference?: string;
  readonly dueDate?: string;
  readonly notes?: string;
  readonly deviceLines: readonly DeviceLineInput[];
  readonly expectedImeiVersions: Readonly<Record<string, number>>;
  readonly dataModelVersion: number;
}

/** Device line input within a sale command */
export interface DeviceLineInput {
  readonly lineId: string;
  readonly imei: string;
  readonly unitId: string;
  readonly description: string;
  readonly brand?: string;
  readonly model?: string;
  readonly quantity: number;
  readonly unitPrice: Money;
  readonly lineTax: Money;
  readonly lineDiscount: Money;
  readonly lineTotal: Money;
  readonly hsnCode?: string;
  readonly taxRateBasisPoints?: number;
  readonly warrantyMonths?: number;
  readonly warrantyStartDate?: string;
  readonly warrantyEndDate?: string;
}

// ─── Transaction Plan Types ──────────────────────────────────────────────────

/** A single item in the transaction write set */
export interface PlanItem {
  /** The TransactWriteItem entry (Put with condition) */
  readonly transactItem: TransactPutItem | TransactUpdateItem;
  /** Descriptor for error correlation */
  readonly descriptor: TransactItemDescriptor;
}

/** A TransactWriteItem Update entry */
export interface TransactUpdateItem {
  readonly Update: {
    readonly TableName: string;
    readonly Key: Record<string, string>;
    readonly UpdateExpression: string;
    readonly ConditionExpression: string;
    readonly ExpressionAttributeNames: Record<string, string>;
    readonly ExpressionAttributeValues: Record<string, unknown>;
  };
}

/** Result of transaction planning */
export interface TransactionPlan {
  /** Whether the operation fits within configured transaction limits */
  readonly fits: boolean;
  /** All TransactWriteItems entries */
  readonly items: readonly PlanItem[];
  /** Total distinct item count */
  readonly totalItems: number;
  /** Estimated aggregate encoded size in bytes */
  readonly estimatedSizeBytes: number;
  /** Configured maximum items */
  readonly maxItems: number;
  /** Configured maximum bytes */
  readonly maxBytes: number;
  /** Overflow info when fits=false */
  readonly overflow?: {
    readonly itemsOverBy: number;
    readonly bytesOverBy: number;
  };
}

// ─── Transaction Planner ─────────────────────────────────────────────────────

/**
 * Pure transaction planner: builds the complete write set for an atomic sale
 * and determines fit within configured DynamoDB transaction limits.
 */
export class TransactionPlanner {
  private readonly tableName: string;
  private readonly auditService: AuditEventService;

  constructor(tableName: string) {
    this.tableName = tableName;
    this.auditService = new AuditEventService(tableName);
  }

  /**
   * Plans a sale transaction by building all required items and checking fit.
   *
   * Items produced:
   * 1. Invoice header (Put with version condition)
   * 2. Device line/association items (one per device)
   * 3. IMEI state update items (Update with version+lifecycle condition)
   * 4. Customer/warranty association items
   * 5. IMEI uniqueness claims (Put with absence condition)
   * 6. Idempotency record (Put with absence condition)
   * 7. Immutable audit event (Put)
   * 8. Change-feed event (Put)
   */
  planSaleTransaction(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
  ): TransactionPlan {
    const items: PlanItem[] = [];

    // 1. Invoice header
    items.push(this.buildInvoiceHeaderItem(ctx, command));

    // 2. Device line/association items
    for (const line of command.deviceLines) {
      items.push(this.buildDeviceLineItem(ctx, command.invoiceId, line));
    }

    // 3. IMEI state updates (lifecycle transition to SOLD)
    for (const line of command.deviceLines) {
      const expectedVersion = command.expectedImeiVersions[line.imei];
      if (expectedVersion !== undefined) {
        items.push(this.buildImeiStateUpdateItem(ctx, line, expectedVersion));
      }
    }

    // 4. Customer/warranty associations
    for (const line of command.deviceLines) {
      items.push(
        this.buildCustomerAssociationItem(ctx, command, line),
      );
    }

    // 5. IMEI uniqueness claims
    for (const line of command.deviceLines) {
      items.push(this.buildImeiClaimItem(ctx, line, command.invoiceId));
    }

    // 6. Idempotency record
    items.push(this.buildIdempotencyItem(ctx, command));

    // 7. Audit event
    items.push(this.buildAuditEventItem(ctx, command));

    // 8. Change-feed event
    items.push(this.buildChangeEventItem(ctx, command));

    // Calculate fit
    const totalItems = items.length;
    const estimatedSizeBytes = this.estimateEncodedSize(items);
    const { configuredMaxItems, configuredMaxBytes } = TRANSACTION_FIT_CONFIG;

    const fits = totalItems <= configuredMaxItems && estimatedSizeBytes <= configuredMaxBytes;

    const plan: TransactionPlan = {
      fits,
      items,
      totalItems,
      estimatedSizeBytes,
      maxItems: configuredMaxItems,
      maxBytes: configuredMaxBytes,
    };

    if (!fits) {
      return {
        ...plan,
        overflow: {
          itemsOverBy: Math.max(0, totalItems - configuredMaxItems),
          bytesOverBy: Math.max(0, estimatedSizeBytes - configuredMaxBytes),
        },
      };
    }

    return plan;
  }

  // ─── Item Builders ─────────────────────────────────────────────────────────

  private buildInvoiceHeaderItem(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
  ): PlanItem {
    const pk = buildInvoicePK(ctx.tenantId, command.invoiceId);
    const sk = encodeMetaSK('INVOICE');
    const now = new Date().toISOString();

    const item: Record<string, unknown> = {
      PK: pk,
      SK: sk,
      tenantId: ctx.tenantId,
      entityId: command.invoiceId,
      entityType: 'INVOICE',
      invoiceNumber: command.invoiceNumber,
      status: 'COMMITTED',
      customerId: command.customerId,
      customerName: command.customerName,
      totalAmount: command.totalAmount,
      taxAmount: command.taxAmount,
      discountAmount: command.discountAmount,
      netAmount: command.netAmount,
      invoiceDate: command.invoiceDate,
      operationId: command.operationId,
      version: 1,
      dataModelVersion: command.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
      createdAt: now,
      updatedAt: now,
      ...(command.paymentMethod && { paymentMethod: command.paymentMethod }),
      ...(command.paymentReference && { paymentReference: command.paymentReference }),
      ...(command.dueDate && { dueDate: command.dueDate }),
      ...(command.notes && { notes: command.notes }),
    };

    // GSI2 for customer history (AP-05)
    item['GSI2PK'] = encodeGSI2PK(ctx.tenantId, 'CUSTOMER', command.customerId);
    item['GSI2SK'] = encodeGSI2SK(now, 'INVOICE', command.invoiceId);

    return {
      transactItem: {
        Put: {
          TableName: this.tableName,
          Item: item,
          ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        },
      },
      descriptor: {
        label: 'invoice-header',
        conditionType: 'VERSION' as ConditionType,
        fields: ['invoiceId'],
      },
    };
  }

  private buildDeviceLineItem(
    ctx: TenantContextWire,
    invoiceId: string,
    line: DeviceLineInput,
  ): PlanItem {
    const pk = buildInvoicePK(ctx.tenantId, invoiceId);
    const sk = encodeChildSK('DEVICE', line.lineId);
    const now = new Date().toISOString();

    const item: Record<string, unknown> = {
      PK: pk,
      SK: sk,
      tenantId: ctx.tenantId,
      entityId: line.lineId,
      entityType: 'INVOICE_DEVICE_LINE',
      invoiceId,
      lineType: 'DEVICE',
      imei: line.imei,
      unitId: line.unitId,
      description: line.description,
      quantity: line.quantity,
      unitPrice: line.unitPrice,
      lineTax: line.lineTax,
      lineDiscount: line.lineDiscount,
      lineTotal: line.lineTotal,
      version: 1,
      dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
      createdAt: now,
      updatedAt: now,
      ...(line.brand && { brand: line.brand }),
      ...(line.model && { model: line.model }),
      ...(line.hsnCode && { hsnCode: line.hsnCode }),
      ...(line.taxRateBasisPoints !== undefined && { taxRateBasisPoints: line.taxRateBasisPoints }),
      ...(line.warrantyMonths !== undefined && { warrantyMonths: line.warrantyMonths }),
    };

    return {
      transactItem: {
        Put: {
          TableName: this.tableName,
          Item: item,
          ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        },
      },
      descriptor: {
        label: `device-line:${line.imei}`,
        conditionType: 'UNIQUENESS' as ConditionType,
        fields: ['imei'],
      },
    };
  }

  private buildImeiStateUpdateItem(
    ctx: TenantContextWire,
    line: DeviceLineInput,
    expectedVersion: number,
  ): PlanItem {
    const pk = buildEntityAggregatePK(ctx.tenantId, 'UNIT', line.unitId);
    const sk = encodeMetaSK('UNIT');
    const now = new Date().toISOString();

    return {
      transactItem: {
        Update: {
          TableName: this.tableName,
          Key: { PK: pk, SK: sk },
          UpdateExpression:
            'SET #lifecycleState = :newState, #version = :newVersion, #updatedAt = :now, ' +
            '#GSI1PK = :newGsi1pk, #GSI1SK = :newGsi1sk',
          ConditionExpression:
            '#tenantId = :tenantId AND #version = :expectedVersion AND #lifecycleState IN (:saleable1, :saleable2, :saleable3)',
          ExpressionAttributeNames: {
            '#lifecycleState': 'lifecycleState',
            '#version': 'version',
            '#updatedAt': 'updatedAt',
            '#tenantId': 'tenantId',
            '#GSI1PK': 'GSI1PK',
            '#GSI1SK': 'GSI1SK',
          },
          ExpressionAttributeValues: {
            ':tenantId': ctx.tenantId,
            ':expectedVersion': expectedVersion,
            ':newVersion': expectedVersion + 1,
            ':newState': DeviceLifecycleState.SOLD,
            ':now': now,
            ':saleable1': DeviceLifecycleState.IN_STOCK,
            ':saleable2': DeviceLifecycleState.RESERVED,
            ':saleable3': DeviceLifecycleState.SALE_PENDING,
            ':newGsi1pk': encodeGSI1PK(ctx.tenantId, 'UNIT', DeviceLifecycleState.SOLD),
            ':newGsi1sk': encodeGSI1SK(now, line.unitId),
          },
        },
      },
      descriptor: {
        label: `imei-state:${line.imei}`,
        conditionType: 'LIFECYCLE' as ConditionType,
        fields: ['imei', 'lifecycleState', 'expectedVersion'],
      },
    };
  }

  private buildCustomerAssociationItem(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
    line: DeviceLineInput,
  ): PlanItem {
    const pk = buildEntityAggregatePK(ctx.tenantId, 'UNIT', line.unitId);
    const sk = encodeChildSK('CUSTOMER_ASSOC', command.customerId);
    const now = new Date().toISOString();

    const item: Record<string, unknown> = {
      PK: pk,
      SK: sk,
      tenantId: ctx.tenantId,
      entityType: 'CUSTOMER_ASSOCIATION',
      entityId: `${line.unitId}_${command.customerId}`,
      unitId: line.unitId,
      customerId: command.customerId,
      customerName: command.customerName,
      invoiceId: command.invoiceId,
      soldAt: now,
      dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
      createdAt: now,
      updatedAt: now,
      // GSI2 for customer device history (AP-05)
      GSI2PK: encodeGSI2PK(ctx.tenantId, 'CUSTOMER', command.customerId),
      GSI2SK: encodeGSI2SK(now, 'UNIT', line.unitId),
    };

    // Add warranty if present
    if (line.warrantyStartDate && line.warrantyEndDate) {
      item['warrantyStartDate'] = line.warrantyStartDate;
      item['warrantyEndDate'] = line.warrantyEndDate;
      item['warrantyMonths'] = line.warrantyMonths;
    }

    return {
      transactItem: {
        Put: {
          TableName: this.tableName,
          Item: item,
          ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        },
      },
      descriptor: {
        label: `customer-assoc:${line.unitId}`,
        conditionType: 'UNIQUENESS' as ConditionType,
        fields: ['customerId', 'unitId'],
      },
    };
  }

  private buildImeiClaimItem(
    ctx: TenantContextWire,
    line: DeviceLineInput,
    invoiceId: string,
  ): PlanItem {
    const transactItem = buildClaimTransactItem(
      this.tableName,
      ctx,
      'IMEI',
      line.imei,
      invoiceId,
      1, // First claim version
    );

    return {
      transactItem,
      descriptor: {
        label: `imei-claim:${line.imei}`,
        conditionType: 'UNIQUENESS' as ConditionType,
        fields: ['imei'],
      },
    };
  }

  private buildIdempotencyItem(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
  ): PlanItem {
    const transactItem = buildIdempotencyTransactItem(
      this.tableName,
      ctx,
      command.operationId,
      command.mutationFingerprint,
      'COMMITTED',
      command.invoiceId, // response reference = invoice ID
      command.dataModelVersion || MODEL_VERSION_CONFIG.currentVersion,
    );

    return {
      transactItem,
      descriptor: {
        label: 'idempotency',
        conditionType: 'IDEMPOTENCY' as ConditionType,
        fields: ['operationId', 'mutationFingerprint'],
      },
    };
  }

  private buildAuditEventItem(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
  ): PlanItem {
    const auditParams: CreateAuditEventParams = {
      entityType: 'INVOICE',
      entityId: command.invoiceId,
      action: 'SALE_COMMITTED',
      operationId: command.operationId,
      afterState: {
        invoiceId: command.invoiceId,
        invoiceNumber: command.invoiceNumber,
        customerId: command.customerId,
        deviceCount: command.deviceLines.length,
        netAmount: command.netAmount,
      },
    };

    const { transactItem } = this.auditService.createAuditEvent(ctx, auditParams);

    return {
      transactItem,
      descriptor: {
        label: 'audit-event',
        conditionType: 'UNIQUENESS' as ConditionType,
        fields: [],
      },
    };
  }

  private buildChangeEventItem(
    ctx: TenantContextWire,
    command: MobileSaleCommand,
  ): PlanItem {
    const now = Date.now();
    const sequence = `${now.toString().padStart(16, '0')}`;

    const { transactItem } = this.auditService.createChangeEvent(ctx, {
      entityType: 'INVOICE',
      entityId: command.invoiceId,
      entityVersion: 1,
      action: 'SALE_COMMITTED',
      pullRef: command.invoiceId,
      sequence,
    });

    return {
      transactItem,
      descriptor: {
        label: 'change-event',
        conditionType: 'UNIQUENESS' as ConditionType,
        fields: [],
      },
    };
  }

  // ─── Size Estimation ───────────────────────────────────────────────────────

  /**
   * Estimates the aggregate encoded size of all items in the transaction.
   * Uses JSON.stringify as a reasonable proxy for DynamoDB's wire format.
   */
  private estimateEncodedSize(items: readonly PlanItem[]): number {
    let totalBytes = 0;

    for (const { transactItem } of items) {
      if ('Put' in transactItem) {
        totalBytes += Buffer.byteLength(JSON.stringify(transactItem.Put.Item), 'utf8');
      } else if ('Update' in transactItem) {
        // Updates are smaller — estimate key + expression values
        const update = transactItem.Update;
        totalBytes += Buffer.byteLength(JSON.stringify(update.Key), 'utf8');
        totalBytes += Buffer.byteLength(JSON.stringify(update.ExpressionAttributeValues), 'utf8');
        totalBytes += 200; // Overhead for expressions
      }
    }

    return totalBytes;
  }
}
