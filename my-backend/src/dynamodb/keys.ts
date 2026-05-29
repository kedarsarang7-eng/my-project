// ============================================================================
// DynamoDB Key Builders — Type-Safe Partition & Sort Key Construction
// ============================================================================
// Ported from sls/app-backend/src/dynamodb/keys.ts
// SECURITY INVARIANT: Every partition key (PK) includes tenant_id.
// ============================================================================

import { TenantContext } from './types';

// ---- Partition Key Builders ----

function validateKeySegment(value: string, name: string): void {
  if (!value || value.trim() === '') {
    throw new Error(`SECURITY: ${name} is required for PK construction`);
  }
  if (value.includes('#')) {
    throw new Error(
      `SECURITY: ${name} contains illegal '#' character. Possible key injection attack.`,
    );
  }
}

export function tenantPK(tenantId: string): string {
  validateKeySegment(tenantId, 'tenantId');
  return `TENANT#${tenantId}`;
}

export function businessPK(tenantId: string, businessId: string): string {
  validateKeySegment(tenantId, 'tenantId');
  validateKeySegment(businessId, 'businessId');
  return `TENANT#${tenantId}#BIZ#${businessId}`;
}

export function businessPKFromContext(ctx: TenantContext): string {
  return businessPK(ctx.tenantId, ctx.businessId);
}

// ---- Sort Key Builders ----

export function businessSK(businessId: string): string {
  return `BUSINESS#${businessId}`;
}

export function billSK(billId: string): string {
  return `BILL#${billId}`;
}

export const BILL_SK_PREFIX = 'BILL#';

export function productSK(productId: string): string {
  return `PRODUCT#${productId}`;
}

export const PRODUCT_SK_PREFIX = 'PRODUCT#';

export function customerSK(customerId: string): string {
  return `CUSTOMER#${customerId}`;
}

export const CUSTOMER_SK_PREFIX = 'CUSTOMER#';

export function staffSK(staffId: string): string {
  return `STAFF#${staffId}`;
}

export const STAFF_SK_PREFIX = 'STAFF#';

export function inventorySK(productId: string): string {
  return `INVENTORY#${productId}`;
}

export const INVENTORY_SK_PREFIX = 'INVENTORY#';

export function auditSK(timestamp: string, eventId: string): string {
  return `AUDIT#${timestamp}#${eventId}`;
}

export const AUDIT_SK_PREFIX = 'AUDIT#';

// ---- GSI1 Key Builders (ByDate) ----

export function gsi1PK(
  tenantId: string,
  businessId: string,
  entityType: string,
): string {
  return `TENANT#${tenantId}#BIZ#${businessId}#${entityType}`;
}

export function gsi1SK(isoDate: string, entityId: string): string {
  return `${isoDate}#${entityId}`;
}

// ---- GSI2 Key Builders (CrossBusiness) ----

export function gsi2PK(tenantId: string, entityType: string): string {
  return `TENANT#${tenantId}#${entityType}`;
}

export function gsi2SK(
  isoDate: string,
  businessId: string,
  entityId: string,
): string {
  return `${isoDate}#${businessId}#${entityId}`;
}

// ---- GSI3 Key Builders (CustomerLookup by phone) ----

export function gsi3PK(tenantId: string, phone: string): string {
  const normalized = phone.replace(/\s+/g, '').replace(/^0+/, '');
  return `TENANT#${tenantId}#PHONE#${normalized}`;
}

export function gsi3SK(businessId: string, customerId: string): string {
  return `BIZ#${businessId}#CUSTOMER#${customerId}`;
}

// ---- Entity Key Builders ----

export interface EntityKeys {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  GSI2PK?: string;
  GSI2SK?: string;
  GSI3PK?: string;
  GSI3SK?: string;
}

export function buildBillKeys(
  tenantId: string,
  businessId: string,
  billId: string,
  isoDate: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: billSK(billId),
    GSI1PK: gsi1PK(tenantId, businessId, 'BILL'),
    GSI1SK: gsi1SK(isoDate, billId),
    GSI2PK: gsi2PK(tenantId, 'BILL'),
    GSI2SK: gsi2SK(isoDate, businessId, billId),
  };
}

export function buildCustomerKeys(
  tenantId: string,
  businessId: string,
  customerId: string,
  customerName: string,
  customerPhone?: string,
): EntityKeys {
  const keys: EntityKeys = {
    PK: businessPK(tenantId, businessId),
    SK: customerSK(customerId),
    GSI2PK: gsi2PK(tenantId, 'CUSTOMER'),
    GSI2SK: `${customerName}#${businessId}#${customerId}`,
  };
  if (customerPhone && customerPhone.trim() !== '') {
    keys.GSI3PK = gsi3PK(tenantId, customerPhone);
    keys.GSI3SK = gsi3SK(businessId, customerId);
  }
  return keys;
}

export function buildProductKeys(
  tenantId: string,
  businessId: string,
  productId: string,
  productName: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: productSK(productId),
    GSI1PK: gsi1PK(tenantId, businessId, 'PRODUCT'),
    GSI1SK: `${productName}#${productId}`,
  };
}

export function buildAuditKeys(
  tenantId: string,
  businessId: string,
  timestamp: string,
  eventId: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: auditSK(timestamp, eventId),
    GSI1PK: gsi1PK(tenantId, businessId, 'AUDIT'),
    GSI1SK: gsi1SK(timestamp, eventId),
  };
}

// ---- Petrol Pump Entity Keys ----

export const SHIFT_SK_PREFIX = 'SHIFT#';
export const NOZZLE_SK_PREFIX = 'NOZZLE#';
export const TANK_SK_PREFIX = 'TANK#';
export const FUEL_TYPE_SK_PREFIX = 'FUEL_TYPE#';
export const PRICE_CHANGE_SK_PREFIX = 'PRICE_CHANGE#';
export const DIP_READING_SK_PREFIX = 'DIP_READING#';
export const FUEL_RECEIPT_SK_PREFIX = 'FUEL_RECEIPT#';

export function shiftSK(shiftId: string): string {
  return `${SHIFT_SK_PREFIX}${shiftId}`;
}

export function nozzleSK(nozzleId: string): string {
  return `${NOZZLE_SK_PREFIX}${nozzleId}`;
}

export function tankSK(tankId: string): string {
  return `${TANK_SK_PREFIX}${tankId}`;
}

export function fuelTypeSK(fuelTypeId: string): string {
  return `${FUEL_TYPE_SK_PREFIX}${fuelTypeId}`;
}

export function priceChangeSK(changeId: string): string {
  return `${PRICE_CHANGE_SK_PREFIX}${changeId}`;
}

export function dipReadingSK(readingId: string): string {
  return `${DIP_READING_SK_PREFIX}${readingId}`;
}

export function fuelReceiptSK(receiptId: string): string {
  return `${FUEL_RECEIPT_SK_PREFIX}${receiptId}`;
}

export function buildShiftKeys(
  tenantId: string,
  businessId: string,
  shiftId: string,
  startTime: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: shiftSK(shiftId),
    GSI1PK: gsi1PK(tenantId, businessId, 'SHIFT'),
    GSI1SK: gsi1SK(startTime, shiftId),
    GSI2PK: gsi2PK(tenantId, 'SHIFT'),
    GSI2SK: `${startTime}#${shiftId}`,
  };
}

export function buildNozzleKeys(
  tenantId: string,
  businessId: string,
  nozzleId: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: nozzleSK(nozzleId),
    GSI1PK: gsi1PK(tenantId, businessId, 'NOZZLE'),
    GSI1SK: nozzleId,
  };
}

export function buildTankKeys(
  tenantId: string,
  businessId: string,
  tankId: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: tankSK(tankId),
    GSI1PK: gsi1PK(tenantId, businessId, 'TANK'),
    GSI1SK: tankId,
  };
}

export function buildFuelTypeKeys(
  tenantId: string,
  businessId: string,
  fuelTypeId: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: fuelTypeSK(fuelTypeId),
    GSI1PK: gsi1PK(tenantId, businessId, 'FUEL_TYPE'),
    GSI1SK: fuelTypeId,
  };
}

export function buildPriceChangeKeys(
  tenantId: string,
  businessId: string,
  changeId: string,
  effectiveFrom: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: priceChangeSK(changeId),
    GSI1PK: gsi1PK(tenantId, businessId, 'PRICE_CHANGE'),
    GSI1SK: gsi1SK(effectiveFrom, changeId),
  };
}

export function buildFuelReceiptKeys(
  tenantId: string,
  businessId: string,
  receiptId: string,
  date: string,
): EntityKeys {
  return {
    PK: businessPK(tenantId, businessId),
    SK: fuelReceiptSK(receiptId),
    GSI1PK: gsi1PK(tenantId, businessId, 'FUEL_RECEIPT'),
    GSI1SK: gsi1SK(date, receiptId),
  };
}
