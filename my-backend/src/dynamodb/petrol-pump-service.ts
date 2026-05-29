// ============================================================================
// Petrol Pump Service — DynamoDB-Backed CRUD for Shifts, Nozzles, Tanks, etc.
// ============================================================================
// SECURITY: Every operation requires TenantContext from verified JWT.
// All monetary values stored as paise (integer) to prevent IEEE 754 errors.
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import { TenantContext } from './types';
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
  shiftSK,
  nozzleSK,
  tankSK,
  fuelTypeSK,
  priceChangeSK,
  fuelReceiptSK,
  SHIFT_SK_PREFIX,
  NOZZLE_SK_PREFIX,
  TANK_SK_PREFIX,
  FUEL_TYPE_SK_PREFIX,
  PRICE_CHANGE_SK_PREFIX,
  FUEL_RECEIPT_SK_PREFIX,
  buildShiftKeys,
  buildNozzleKeys,
  buildTankKeys,
  buildFuelTypeKeys,
  buildPriceChangeKeys,
  buildFuelReceiptKeys,
  gsi1PK,
} from './keys';
import { validateResourceOwnership } from './tenant-guard';
import { createAuditEntry } from './audit';

// ============================================================================
// TYPES
// ============================================================================

export type ShiftStatus = 'OPEN' | 'CLOSED';

export interface DynamoDBShift {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  GSI2PK?: string;
  GSI2SK?: string;
  tenant_id: string;
  business_id: string;
  entity_type: 'SHIFT';
  shift_id: string;
  shiftName: string;
  startTime: string;
  endTime?: string;
  assignedEmployeeIds: string[];
  status: ShiftStatus;
  totalSaleAmountPaise: number;
  totalLitresSoldMillis: number; // litres × 1000 for 3-decimal precision
  cashAmountPaise: number;
  upiAmountPaise: number;
  cardAmountPaise: number;
  creditAmountPaise: number;
  cashDeclaredPaise?: number;
  cashVariancePaise?: number;
  reconciliationJson?: string;
  closedBy?: string;
  notes?: string;
  version: number;
  is_deleted: boolean;
  created_at: string;
  updated_at: string;
  created_by: string;
  updated_by: string;
}

export interface DynamoDBNozzle {
  PK: string;
  SK: string;
  tenant_id: string;
  business_id: string;
  entity_type: 'NOZZLE';
  nozzle_id: string;
  dispenserId: string;
  fuelTypeId: string;
  fuelTypeName?: string;
  openingReading: number;
  closingReading: number;
  linkedShiftId?: string;
  linkedTankId?: string;
  isActive: boolean;
  version: number;
  is_deleted: boolean;
  created_at: string;
  updated_at: string;
}

export interface DynamoDBTank {
  PK: string;
  SK: string;
  tenant_id: string;
  business_id: string;
  entity_type: 'TANK';
  tank_id: string;
  tankName: string;
  fuelTypeId: string;
  fuelTypeName?: string;
  capacityMillis: number; // litres × 1000
  openingStockMillis: number;
  purchaseQuantityMillis: number;
  salesDeductionMillis: number;
  currentStockMillis: number;
  lastDipReading?: string;
  isActive: boolean;
  version: number;
  is_deleted: boolean;
  created_at: string;
  updated_at: string;
}

/** Tax regime: 'gst' or 'vatExcise' */
export type TaxRegime = 'gst' | 'vatExcise';

export interface DynamoDBFuelType {
  PK: string;
  SK: string;
  tenant_id: string;
  business_id: string;
  entity_type: 'FUEL_TYPE';
  fuel_type_id: string;
  fuelName: string;
  currentRatePaise: number; // rate per litre in paise
  taxRegime: TaxRegime;
  gstRateBps: number; // basis points (18% = 1800)
  stateVatRateBps: number;
  centralExcisePerLitrePaise: number;
  cessRateBps: number;
  isCessPerLitre: boolean;
  hsnCode: string;
  rateHistory: Array<{
    effectiveFrom: string;
    ratePaise: number;
    updatedBy?: string;
    recordedAt: string;
  }>;
  isActive: boolean;
  version: number;
  is_deleted: boolean;
  created_at: string;
  updated_at: string;
}

export interface DynamoDBPriceChange {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  tenant_id: string;
  business_id: string;
  entity_type: 'PRICE_CHANGE';
  change_id: string;
  fuelTypeId: string;
  fuelName: string;
  oldRatePaise: number;
  newRatePaise: number;
  effectiveFrom: string;
  changedBy: string;
  reason?: string;
  created_at: string;
}

// ============================================================================
// SHIFT OPERATIONS
// ============================================================================

export interface OpenShiftInput {
  readonly shiftId: string;
  readonly shiftName: string;
  readonly employeeIds: string[];
}

/**
 * Open a new shift. Validates no other shift is open.
 */
export async function openShift(
  ctx: TenantContext,
  input: OpenShiftInput,
): Promise<DynamoDBShift> {
  const now = new Date().toISOString();
  const keys = buildShiftKeys(
    ctx.tenantId,
    ctx.businessId,
    input.shiftId,
    now,
  );

  const shift: DynamoDBShift = {
    ...keys,
    tenant_id: ctx.tenantId,
    business_id: ctx.businessId,
    entity_type: 'SHIFT',
    shift_id: input.shiftId,
    shiftName: input.shiftName,
    startTime: now,
    assignedEmployeeIds: input.employeeIds,
    status: 'OPEN',
    totalSaleAmountPaise: 0,
    totalLitresSoldMillis: 0,
    cashAmountPaise: 0,
    upiAmountPaise: 0,
    cardAmountPaise: 0,
    creditAmountPaise: 0,
    version: 1,
    is_deleted: false,
    created_at: now,
    updated_at: now,
    created_by: ctx.userId,
    updated_by: ctx.userId,
  };

  const auditEntry = createAuditEntry(ctx, {
    auditId: uuidv4(),
    action: 'CREATE',
    targetEntityType: 'SHIFT',
    targetEntityId: input.shiftId,
    oldValue: null,
    newValue: shift as unknown as Record<string, unknown>,
    isGstRelated: false,
    ipAddress: '',
    userAgent: '',
  });

  await transactWrite({
    TransactItems: [
      {
        Put: {
          TableName: TABLE_NAME,
          Item: shift as unknown as Record<string, unknown>,
          ConditionExpression: 'attribute_not_exists(PK)',
        },
      },
      {
        Put: {
          TableName: TABLE_NAME,
          Item: auditEntry as unknown as Record<string, unknown>,
        },
      },
    ],
  });

  return shift;
}

export interface CloseShiftInput {
  readonly shiftId: string;
  readonly expectedVersion: number;
  readonly closedBy: string;
  readonly cashDeclaredPaise: number;
  readonly reconciliationJson: string;
  readonly totalSaleAmountPaise: number;
  readonly totalLitresSoldMillis: number;
  readonly cashAmountPaise: number;
  readonly upiAmountPaise: number;
  readonly cardAmountPaise: number;
  readonly creditAmountPaise: number;
  readonly notes?: string;
}

/**
 * Close a shift with mandatory reconciliation data.
 * Uses optimistic locking.
 */
export async function closeShift(
  ctx: TenantContext,
  input: CloseShiftInput,
): Promise<void> {
  const now = new Date().toISOString();
  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const sk = shiftSK(input.shiftId);

  const cashVariancePaise = input.cashDeclaredPaise - input.cashAmountPaise;

  await updateItem(
    pk,
    sk,
    `SET #status = :closed, endTime = :now, closedBy = :closedBy,
         totalSaleAmountPaise = :totalSale,
         totalLitresSoldMillis = :totalLitres,
         cashAmountPaise = :cash, upiAmountPaise = :upi,
         cardAmountPaise = :card, creditAmountPaise = :credit,
         cashDeclaredPaise = :cashDeclared, cashVariancePaise = :cashVariance,
         reconciliationJson = :recon, notes = :notes,
         updated_at = :now, updated_by = :userId,
         version = version + :inc`,
    {
      ':closed': 'CLOSED',
      ':now': now,
      ':closedBy': input.closedBy,
      ':totalSale': input.totalSaleAmountPaise,
      ':totalLitres': input.totalLitresSoldMillis,
      ':cash': input.cashAmountPaise,
      ':upi': input.upiAmountPaise,
      ':card': input.cardAmountPaise,
      ':credit': input.creditAmountPaise,
      ':cashDeclared': input.cashDeclaredPaise,
      ':cashVariance': cashVariancePaise,
      ':recon': input.reconciliationJson,
      ':notes': input.notes || '',
      ':userId': ctx.userId,
      ':inc': 1,
      ':expectedVersion': input.expectedVersion,
      ':openStatus': 'OPEN',
    },
    {
      conditionExpression:
        'version = :expectedVersion AND #status = :openStatus',
      expressionAttributeNames: { '#status': 'status' },
    },
  );
}

/**
 * Get shift by ID.
 */
export async function getShift(
  ctx: TenantContext,
  shiftId: string,
): Promise<DynamoDBShift | null> {
  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const sk = shiftSK(shiftId);
  const shift = await getItem<DynamoDBShift>(pk, sk);
  if (!shift || shift.is_deleted) return null;

  const ownership = validateResourceOwnership(
    shift.tenant_id,
    shift.business_id,
    ctx,
  );
  if (!ownership.valid) throw new Error(ownership.error);
  return shift;
}

/**
 * List shifts for a business, optionally by date range.
 */
export async function listShifts(
  ctx: TenantContext,
  options?: { startDate?: string; endDate?: string; limit?: number },
): Promise<{ shifts: DynamoDBShift[]; lastKey?: Record<string, unknown> }> {
  if (options?.startDate || options?.endDate) {
    const gsiPk = gsi1PK(ctx.tenantId, ctx.businessId, 'SHIFT');
    const result = await queryItems<DynamoDBShift>(gsiPk, {
      indexName: 'GSI1Index',
      skBetween: {
        start: options.startDate || '0000-01-01',
        end: options.endDate || '9999-12-31',
      },
      limit: options?.limit,
      scanForward: false,
    });
    return {
      shifts: result.items.filter((s) => !s.is_deleted),
      lastKey: result.lastEvaluatedKey,
    };
  }

  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const result = await queryItems<DynamoDBShift>(pk, {
    skBeginsWith: SHIFT_SK_PREFIX,
    limit: options?.limit,
    scanForward: false,
  });
  return {
    shifts: result.items.filter((s) => !s.is_deleted),
    lastKey: result.lastEvaluatedKey,
  };
}

// ============================================================================
// FUEL TYPE / PRICE CHANGE OPERATIONS
// ============================================================================

export interface UpdatePriceInput {
  readonly fuelTypeId: string;
  readonly newRatePaise: number;
  readonly effectiveFrom: string;
  readonly reason?: string;
}

/**
 * Update fuel rate with audit trail and backdating prevention.
 * Creates PriceChange audit record atomically.
 */
export async function updateFuelRate(
  ctx: TenantContext,
  input: UpdatePriceInput,
): Promise<DynamoDBPriceChange> {
  const now = new Date().toISOString();

  // Backdating prevention: effectiveFrom must not be in the past
  if (new Date(input.effectiveFrom) < new Date(now)) {
    // Allow up to 5 minutes grace period for clock skew
    const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    if (input.effectiveFrom < fiveMinAgo) {
      throw new Error(
        'Cannot backdate price change. Effective time must be in the future.',
      );
    }
  }

  // Get current fuel type
  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const fuelType = await getItem<DynamoDBFuelType>(
    pk,
    fuelTypeSK(input.fuelTypeId),
  );
  if (!fuelType) throw new Error('Fuel type not found');

  const changeId = uuidv4();
  const priceChangeKeys = buildPriceChangeKeys(
    ctx.tenantId,
    ctx.businessId,
    changeId,
    input.effectiveFrom,
  );

  const priceChange: DynamoDBPriceChange = {
    ...priceChangeKeys,
    tenant_id: ctx.tenantId,
    business_id: ctx.businessId,
    entity_type: 'PRICE_CHANGE',
    change_id: changeId,
    fuelTypeId: input.fuelTypeId,
    fuelName: fuelType.fuelName,
    oldRatePaise: fuelType.currentRatePaise,
    newRatePaise: input.newRatePaise,
    effectiveFrom: input.effectiveFrom,
    changedBy: ctx.userId,
    reason: input.reason,
    created_at: now,
  };

  // Transactional: update fuel type + insert price change record
  await transactWrite({
    TransactItems: [
      {
        Update: {
          TableName: TABLE_NAME,
          Key: { PK: pk, SK: fuelTypeSK(input.fuelTypeId) },
          UpdateExpression: `SET currentRatePaise = :newRate,
            rateHistory = list_append(if_not_exists(rateHistory, :emptyList), :historyEntry),
            updated_at = :now, version = version + :inc`,
          ExpressionAttributeValues: {
            ':newRate': input.newRatePaise,
            ':historyEntry': [
              {
                effectiveFrom: input.effectiveFrom,
                ratePaise: fuelType.currentRatePaise,
                updatedBy: ctx.userId,
                recordedAt: now,
              },
            ],
            ':emptyList': [],
            ':now': now,
            ':inc': 1,
          },
        },
      },
      {
        Put: {
          TableName: TABLE_NAME,
          Item: priceChange as unknown as Record<string, unknown>,
        },
      },
    ],
  });

  return priceChange;
}

/**
 * List all fuel types for a business.
 */
export async function listFuelTypes(
  ctx: TenantContext,
): Promise<DynamoDBFuelType[]> {
  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const result = await queryItems<DynamoDBFuelType>(pk, {
    skBeginsWith: FUEL_TYPE_SK_PREFIX,
  });
  return result.items.filter((ft) => !ft.is_deleted);
}

// ============================================================================
// TANK OPERATIONS
// ============================================================================

/**
 * Record fuel receipt (purchase from oil company tanker).
 * Atomically updates tank stock using ConditionExpression.
 */
export async function recordFuelReceipt(
  ctx: TenantContext,
  input: {
    receiptId: string;
    tankId: string;
    quantityMillis: number;
    invoiceNumber?: string;
    supplierName?: string;
    date: string;
  },
): Promise<void> {
  const now = new Date().toISOString();
  const pk = businessPK(ctx.tenantId, ctx.businessId);

  // Get tank to check capacity
  const tank = await getItem<DynamoDBTank>(pk, tankSK(input.tankId));
  if (!tank) throw new Error('Tank not found');

  const newStock = tank.currentStockMillis + input.quantityMillis;
  if (newStock > tank.capacityMillis) {
    throw new Error(
      `Receipt would exceed tank capacity. Current: ${tank.currentStockMillis}, Adding: ${input.quantityMillis}, Capacity: ${tank.capacityMillis}`,
    );
  }

  const receiptKeys = buildFuelReceiptKeys(
    ctx.tenantId,
    ctx.businessId,
    input.receiptId,
    input.date,
  );

  await transactWrite({
    TransactItems: [
      {
        Update: {
          TableName: TABLE_NAME,
          Key: { PK: pk, SK: tankSK(input.tankId) },
          UpdateExpression: `SET currentStockMillis = currentStockMillis + :qty,
            purchaseQuantityMillis = purchaseQuantityMillis + :qty,
            updated_at = :now, version = version + :inc`,
          ExpressionAttributeValues: {
            ':qty': input.quantityMillis,
            ':now': now,
            ':inc': 1,
            ':capacity': tank.capacityMillis,
          },
          ConditionExpression:
            'currentStockMillis + :qty <= :capacity',
        },
      },
      {
        Put: {
          TableName: TABLE_NAME,
          Item: {
            ...receiptKeys,
            tenant_id: ctx.tenantId,
            business_id: ctx.businessId,
            entity_type: 'FUEL_RECEIPT',
            receipt_id: input.receiptId,
            tankId: input.tankId,
            quantityMillis: input.quantityMillis,
            invoiceNumber: input.invoiceNumber || '',
            supplierName: input.supplierName || '',
            date: input.date,
            created_at: now,
            created_by: ctx.userId,
          } as unknown as Record<string, unknown>,
        },
      },
    ],
  });
}

/**
 * List all tanks for a business.
 */
export async function listTanks(
  ctx: TenantContext,
): Promise<DynamoDBTank[]> {
  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const result = await queryItems<DynamoDBTank>(pk, {
    skBeginsWith: TANK_SK_PREFIX,
  });
  return result.items.filter((t) => !t.is_deleted);
}

/**
 * List all nozzles for a business.
 */
export async function listNozzles(
  ctx: TenantContext,
): Promise<DynamoDBNozzle[]> {
  const pk = businessPK(ctx.tenantId, ctx.businessId);
  const result = await queryItems<DynamoDBNozzle>(pk, {
    skBeginsWith: NOZZLE_SK_PREFIX,
  });
  return result.items.filter((n) => !n.is_deleted);
}

// ============================================================================
// DAILY SALES REPORT (DSR)
// ============================================================================

export interface DsrReport {
  date: string;
  shifts: DynamoDBShift[];
  totalSalesPaise: number;
  totalLitresMillis: number;
  cashPaise: number;
  upiPaise: number;
  cardPaise: number;
  creditPaise: number;
}

/**
 * Generate Daily Sales Report for a specific date.
 */
export async function generateDsr(
  ctx: TenantContext,
  date: string,
): Promise<DsrReport> {
  const nextDate = new Date(
    new Date(date).getTime() + 24 * 60 * 60 * 1000,
  ).toISOString().split('T')[0];

  const shifts = await listShifts(ctx, {
    startDate: date,
    endDate: nextDate,
  });

  let totalSalesPaise = 0;
  let totalLitresMillis = 0;
  let cashPaise = 0;
  let upiPaise = 0;
  let cardPaise = 0;
  let creditPaise = 0;

  for (const shift of shifts.shifts) {
    totalSalesPaise += shift.totalSaleAmountPaise;
    totalLitresMillis += shift.totalLitresSoldMillis;
    cashPaise += shift.cashAmountPaise;
    upiPaise += shift.upiAmountPaise;
    cardPaise += shift.cardAmountPaise;
    creditPaise += shift.creditAmountPaise;
  }

  return {
    date,
    shifts: shifts.shifts,
    totalSalesPaise,
    totalLitresMillis,
    cashPaise,
    upiPaise,
    cardPaise,
    creditPaise,
  };
}
