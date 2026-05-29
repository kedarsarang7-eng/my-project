// ============================================================================
// Bill Service — DynamoDB-Backed Bill CRUD with Tenant Isolation
// ============================================================================
// SECURITY: Every operation requires TenantContext from verified JWT.
// Race conditions prevented via optimistic locking (version attribute).
// All monetary values stored as paise (integer) to prevent IEEE 754 errors.
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
  TenantContext,
  DynamoDBBill,
  DynamoDBBillItem,
  BusinessType,
} from './types';
import {
  getItem,
  putItem,
  updateItem,
  queryItems,
  transactWrite,
  TABLE_NAME,
} from './client';
import {
  businessPK,
  billSK,
  BILL_SK_PREFIX,
  buildBillKeys,
  gsi1PK,
  gsi2PK,
  customerSK,
} from './keys';
import { validateResourceOwnership } from './tenant-guard';
import { createAuditEntry } from './audit';

// ---- Types ----

export interface CreateBillInput {
  /** Pre-generated UUID — caller must generate for idempotency */
  readonly billId: string;
  readonly invoiceNumber: string;
  readonly customerId: string;
  readonly customerName: string;
  readonly customerPhone: string;
  readonly customerAddress: string;
  readonly customerGst: string;
  readonly customerEmail?: string;
  readonly date: string; // ISO 8601
  readonly items: DynamoDBBillItem[];
  readonly subtotalPaise: number;
  readonly totalTaxPaise: number;
  readonly grandTotalPaise: number;
  readonly paidAmountPaise: number;
  readonly cashPaidPaise: number;
  readonly onlinePaidPaise: number;
  readonly discountAppliedPaise: number;
  readonly status: 'Draft' | 'Unpaid' | 'Partial' | 'Paid';
  readonly paymentType: 'Cash' | 'Online' | 'Mixed';
  readonly businessType: BusinessType;
  readonly shopName: string;
  readonly shopAddress: string;
  readonly shopGst: string;
  readonly shopContact: string;
  readonly source: 'MANUAL' | 'VOICE' | 'POS' | 'API';
  // Optional business-specific
  readonly shiftId?: string;
  readonly prescriptionId?: string;
  readonly vehicleNumber?: string;
  readonly fuelType?: string;
  readonly tableNumber?: string;
  readonly waiterId?: string;
}

export interface UpdateBillInput {
  readonly billId: string;
  /** Current version for optimistic locking — MUST match DB version */
  readonly expectedVersion: number;
  // Only fields that can be updated (not all fields)
  readonly paidAmountPaise?: number;
  readonly cashPaidPaise?: number;
  readonly onlinePaidPaise?: number;
  readonly status?: 'Draft' | 'Unpaid' | 'Partial' | 'Paid';
  readonly paymentType?: 'Cash' | 'Online' | 'Mixed';
  readonly items?: DynamoDBBillItem[];
  readonly subtotalPaise?: number;
  readonly totalTaxPaise?: number;
  readonly grandTotalPaise?: number;
  readonly discountAppliedPaise?: number;
}

export interface ListBillsOptions {
  /** ISO date range for filtering */
  readonly startDate?: string;
  readonly endDate?: string;
  /** Maximum number of bills to return */
  readonly limit?: number;
  /** For pagination */
  readonly startKey?: Record<string, unknown>;
  /** Filter by status */
  readonly status?: string;
  /** Filter by customer */
  readonly customerId?: string;
}

// ---- Create Bill ----

/**
 * Create a new bill with full audit trail.
 *
 * Uses conditional PutItem to prevent duplicate bill IDs (idempotent).
 * Creates audit entry in same transaction as bill write.
 *
 * @param ctx - TenantContext from verified JWT (NEVER from user input)
 * @param input - Bill data with pre-generated UUID
 */
export async function createBill(
  ctx: TenantContext,
  input: CreateBillInput,
): Promise<DynamoDBBill> {
  const now = new Date().toISOString();

  // Validate bill ID is pre-generated
  if (!input.billId || input.billId.trim() === '') {
    throw new Error(
      'billId must be pre-generated (UUID) by the caller for idempotency.',
    );
  }

  // Build all DynamoDB keys
  const keys = buildBillKeys(
    ctx.tenantId,
    ctx.businessId,
    input.billId,
    input.date,
  );

  const bill: DynamoDBBill = {
    ...keys,
    tenant_id: ctx.tenantId,
    business_id: ctx.businessId,
    entity_type: 'BILL',
    bill_id: input.billId,
    invoiceNumber: input.invoiceNumber,
    customerId: input.customerId,
    customerName: input.customerName,
    customerPhone: input.customerPhone,
    customerAddress: input.customerAddress,
    customerGst: input.customerGst,
    customerEmail: input.customerEmail,
    date: input.date,
    items: input.items,
    subtotalPaise: input.subtotalPaise,
    totalTaxPaise: input.totalTaxPaise,
    grandTotalPaise: input.grandTotalPaise,
    paidAmountPaise: input.paidAmountPaise,
    cashPaidPaise: input.cashPaidPaise,
    onlinePaidPaise: input.onlinePaidPaise,
    discountAppliedPaise: input.discountAppliedPaise,
    status: input.status,
    paymentType: input.paymentType,
    businessType: input.businessType,
    shopName: input.shopName,
    shopAddress: input.shopAddress,
    shopGst: input.shopGst,
    shopContact: input.shopContact,
    source: input.source,
    printCount: 0,
    shiftId: input.shiftId,
    prescriptionId: input.prescriptionId,
    vehicleNumber: input.vehicleNumber,
    fuelType: input.fuelType,
    tableNumber: input.tableNumber,
    waiterId: input.waiterId,
    version: 1,
    is_deleted: false,
    created_at: now,
    updated_at: now,
    created_by: ctx.userId,
    updated_by: ctx.userId,
  };

  // Transactional write: bill + audit entry + customer balance update
  const auditId = uuidv4();
  const auditEntry = createAuditEntry(ctx, {
    auditId,
    action: 'CREATE',
    targetEntityType: 'BILL',
    targetEntityId: input.billId,
    oldValue: null,
    newValue: bill as unknown as Record<string, unknown>,
    isGstRelated: input.totalTaxPaise > 0,
    ipAddress: '', // filled by handler
    userAgent: '', // filled by handler
  });

  await transactWrite({
    TransactItems: [
      {
        Put: {
          TableName: TABLE_NAME,
          Item: bill as unknown as Record<string, unknown>,
          // Idempotency: fail if bill already exists
          ConditionExpression: 'attribute_not_exists(PK)',
        },
      },
      {
        Put: {
          TableName: TABLE_NAME,
          Item: auditEntry as unknown as Record<string, unknown>,
        },
      },
      // Update customer balance if bill has outstanding amount
      ...(input.grandTotalPaise > input.paidAmountPaise
        ? [
            {
              Update: {
                TableName: TABLE_NAME,
                Key: {
                  PK: businessPK(ctx.tenantId, ctx.businessId),
                  SK: customerSK(input.customerId),
                },
                UpdateExpression:
                  'SET totalDuesPaise = totalDuesPaise + :dueAmount, updated_at = :now',
                ExpressionAttributeValues: {
                  ':dueAmount':
                    input.grandTotalPaise - input.paidAmountPaise,
                  ':now': now,
                },
              },
            },
          ]
        : []),
    ],
  });

  return bill;
}

// ---- Get Bill ----

/**
 * Get a single bill by ID.
 * Validates that the bill belongs to caller's tenant and business.
 */
export async function getBill(
  ctx: TenantContext,
  billId: string,
): Promise<DynamoDBBill | null> {
  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const sk = billSK(billId);

  const bill = await getItem<DynamoDBBill>(pk, sk);

  if (!bill) return null;

  // Defense in depth: verify tenant ownership even though PK guarantees it
  const ownership = validateResourceOwnership(
    bill.tenant_id,
    bill.business_id,
    ctx,
  );
  if (!ownership.valid) {
    throw new Error(ownership.error);
  }

  // Don't return soft-deleted bills
  if (bill.is_deleted) return null;

  return bill;
}

// ---- List Bills ----

/**
 * List bills for caller's business with optional filtering.
 *
 * Uses GSI1 (ByDate) for date-range queries.
 * Uses main table SK prefix for unfiltered listing.
 */
export async function listBills(
  ctx: TenantContext,
  options?: ListBillsOptions,
): Promise<{
  bills: DynamoDBBill[];
  lastKey?: Record<string, unknown>;
}> {
  // Date-range query uses GSI1
  if (options?.startDate || options?.endDate) {
    const gsiPk = gsi1PK(ctx.tenantId, ctx.businessId, 'BILL');

    const skRange = {
      start: options.startDate || '0000-01-01',
      end: options.endDate || '9999-12-31',
    };

    const result = await queryItems<DynamoDBBill>(gsiPk, {
      indexName: 'GSI1Index',
      skBetween: skRange,
      limit: options?.limit,
      scanForward: false, // Newest first
      filterExpression: buildFilterExpression(options),
      expressionAttributeValues: buildFilterValues(options),
      exclusiveStartKey: options?.startKey,
    });

    return {
      bills: result.items.filter((b) => !b.is_deleted),
      lastKey: result.lastEvaluatedKey,
    };
  }

  // No date range: query main table by SK prefix
  const pk = businessPK(ctx.tenantId, ctx.businessId);

  const result = await queryItems<DynamoDBBill>(pk, {
    skBeginsWith: BILL_SK_PREFIX,
    limit: options?.limit,
    scanForward: false,
    filterExpression: buildFilterExpression(options),
    expressionAttributeValues: buildFilterValues(options),
    exclusiveStartKey: options?.startKey,
  });

  return {
    bills: result.items.filter((b) => !b.is_deleted),
    lastKey: result.lastEvaluatedKey,
  };
}

/**
 * List bills across ALL businesses for a tenant (owner-only).
 * Uses GSI2 (CrossBusiness index).
 *
 * SECURITY: Requires hasCrossBusinessAccess = true (owner role).
 */
export async function listBillsCrossBusiness(
  ctx: TenantContext,
  options?: ListBillsOptions,
): Promise<{ bills: DynamoDBBill[]; lastKey?: Record<string, unknown> }> {
  if (!ctx.hasCrossBusinessAccess) {
    throw new Error('Cross-business access requires owner role');
  }

  const gsiPk = gsi2PK(ctx.tenantId, 'BILL');

  const skRange = {
    start: options?.startDate || '0000-01-01',
    end: options?.endDate || '9999-12-31',
  };

  const result = await queryItems<DynamoDBBill>(gsiPk, {
    indexName: 'GSI2Index',
    skBetween: skRange,
    limit: options?.limit,
    scanForward: false,
    filterExpression: buildFilterExpression(options),
    expressionAttributeValues: buildFilterValues(options),
    exclusiveStartKey: options?.startKey,
  });

  return {
    bills: result.items.filter((b) => !b.is_deleted),
    lastKey: result.lastEvaluatedKey,
  };
}

// ---- Update Bill ----

/**
 * Update a bill with optimistic locking.
 *
 * Uses version attribute to prevent lost-update race conditions:
 * - Read bill (version = N)
 * - Modify fields
 * - Write with condition: version = N
 * - If another write happened between read and write, condition fails
 *
 * Creates audit entry with old and new values.
 */
export async function updateBill(
  ctx: TenantContext,
  input: UpdateBillInput,
  requestMeta: { ipAddress: string; userAgent: string },
): Promise<DynamoDBBill | null> {
  // Get current bill for audit trail (old values)
  const current = await getBill(ctx, input.billId);
  if (!current) return null;

  // Build update expression dynamically
  const updates: string[] = [
    'updated_at = :now',
    'updated_by = :userId',
    'version = version + :inc',
  ];
  const values: Record<string, unknown> = {
    ':now': new Date().toISOString(),
    ':userId': ctx.userId,
    ':inc': 1,
    ':expectedVersion': input.expectedVersion,
    ':notDeleted': false,
  };

  if (input.paidAmountPaise !== undefined) {
    updates.push('paidAmountPaise = :paidAmount');
    values[':paidAmount'] = input.paidAmountPaise;
  }
  if (input.cashPaidPaise !== undefined) {
    updates.push('cashPaidPaise = :cashPaid');
    values[':cashPaid'] = input.cashPaidPaise;
  }
  if (input.onlinePaidPaise !== undefined) {
    updates.push('onlinePaidPaise = :onlinePaid');
    values[':onlinePaid'] = input.onlinePaidPaise;
  }
  if (input.status !== undefined) {
    updates.push('#status = :status');
    values[':status'] = input.status;
  }
  if (input.paymentType !== undefined) {
    updates.push('paymentType = :paymentType');
    values[':paymentType'] = input.paymentType;
  }
  if (input.items !== undefined) {
    updates.push('items = :items');
    values[':items'] = input.items;
  }
  if (input.subtotalPaise !== undefined) {
    updates.push('subtotalPaise = :subtotal');
    values[':subtotal'] = input.subtotalPaise;
  }
  if (input.totalTaxPaise !== undefined) {
    updates.push('totalTaxPaise = :totalTax');
    values[':totalTax'] = input.totalTaxPaise;
  }
  if (input.grandTotalPaise !== undefined) {
    updates.push('grandTotalPaise = :grandTotal');
    values[':grandTotal'] = input.grandTotalPaise;
  }
  if (input.discountAppliedPaise !== undefined) {
    updates.push('discountAppliedPaise = :discount');
    values[':discount'] = input.discountAppliedPaise;
  }

  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const sk = billSK(input.billId);

  const result = await updateItem(
    pk,
    sk,
    `SET ${updates.join(', ')}`,
    values,
    {
      // Optimistic locking: fail if version changed since our read
      conditionExpression:
        'version = :expectedVersion AND is_deleted = :notDeleted',
      expressionAttributeNames: {
        '#status': 'status', // 'status' is a DDB reserved word
      },
      returnValues: 'ALL_NEW',
    },
  );

  // Create audit entry for update
  const auditId = uuidv4();
  await createAuditEntry(ctx, {
    auditId,
    action: 'UPDATE',
    targetEntityType: 'BILL',
    targetEntityId: input.billId,
    oldValue: current as unknown as Record<string, unknown>,
    newValue: result,
    isGstRelated:
      current.totalTaxPaise > 0 || (input.totalTaxPaise ?? 0) > 0,
    ipAddress: requestMeta.ipAddress,
    userAgent: requestMeta.userAgent,
  });

  return result as unknown as DynamoDBBill;
}

// ---- Soft Delete Bill ----

/**
 * Soft-delete a bill. Data preserved for audit/compliance.
 * Uses optimistic locking.
 */
export async function deleteBill(
  ctx: TenantContext,
  billId: string,
  expectedVersion: number,
  requestMeta: { ipAddress: string; userAgent: string },
): Promise<void> {
  const current = await getBill(ctx, billId);
  if (!current) {
    throw new Error(`Bill ${billId} not found`);
  }

  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const sk = billSK(billId);
  const now = new Date().toISOString();

  await updateItem(
    pk,
    sk,
    'SET is_deleted = :deleted, updated_at = :now, updated_by = :userId, version = version + :inc',
    {
      ':deleted': true,
      ':now': now,
      ':userId': ctx.userId,
      ':inc': 1,
      ':expectedVersion': expectedVersion,
      ':notDeleted': false,
    },
    {
      conditionExpression:
        'version = :expectedVersion AND is_deleted = :notDeleted',
    },
  );

  // Audit trail for deletion
  const auditId = uuidv4();
  await createAuditEntry(ctx, {
    auditId,
    action: 'SOFT_DELETE',
    targetEntityType: 'BILL',
    targetEntityId: billId,
    oldValue: current as unknown as Record<string, unknown>,
    newValue: null,
    isGstRelated: current.totalTaxPaise > 0,
    ipAddress: requestMeta.ipAddress,
    userAgent: requestMeta.userAgent,
  });
}

// ---- Filter Helpers ----

function buildFilterExpression(
  options?: ListBillsOptions,
): string | undefined {
  const filters: string[] = [];

  if (options?.status) {
    filters.push('#status = :filterStatus');
  }
  if (options?.customerId) {
    filters.push('customerId = :filterCustomerId');
  }

  return filters.length > 0 ? filters.join(' AND ') : undefined;
}

function buildFilterValues(
  options?: ListBillsOptions,
): Record<string, unknown> | undefined {
  const values: Record<string, unknown> = {};

  if (options?.status) {
    values[':filterStatus'] = options.status;
  }
  if (options?.customerId) {
    values[':filterCustomerId'] = options.customerId;
  }

  return Object.keys(values).length > 0 ? values : undefined;
}
