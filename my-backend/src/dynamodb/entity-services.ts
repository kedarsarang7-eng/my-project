// ============================================================================
// DynamoDB Entity Services — Built with CRUD Factory
// ============================================================================
// Each entity service wraps the generic CRUD factory with entity-specific
// key builders and GSI configurations.
//
// All services inherit: create, get, list, update, softDelete
// with built-in tenant isolation and optimistic locking.
// ============================================================================

import { createCrudService } from './crud-factory';
import {
  businessPK,
  customerSK,
  productSK,
  staffSK,
  inventorySK,
  gsi1PK,
  gsi2PK,
  gsi3PK,
  gsi3SK,
  CUSTOMER_SK_PREFIX,
  PRODUCT_SK_PREFIX,
  STAFF_SK_PREFIX,
  INVENTORY_SK_PREFIX,
  AUDIT_SK_PREFIX,
} from './keys';

// ---- Customer Service ----

export const customerService = createCrudService({
  entityType: 'CUSTOMER',
  skPrefix: CUSTOMER_SK_PREFIX,
  gsi1IndexName: 'GSI1Index',
  buildGsi1PK: (ctx) => gsi1PK(ctx.tenantId, ctx.businessId, 'CUSTOMER'),
  buildKeys: (ctx, id, data) => {
    const keys = {
      PK: businessPK(ctx.tenantId, ctx.businessId),
      SK: customerSK(id),
      GSI2PK: gsi2PK(ctx.tenantId, 'CUSTOMER'),
      GSI2SK: `${(data as any)?.name || ''}#${ctx.businessId}#${id}`,
    } as any;
    // Phone lookup GSI
    const phone = (data as any)?.phone;
    if (phone && phone.trim() !== '') {
      keys.GSI3PK = gsi3PK(ctx.tenantId, phone);
      keys.GSI3SK = gsi3SK(ctx.businessId, id);
    }
    return keys;
  },
  requiredFields: ['name'],
});

// ---- Product Service ----

export const productService = createCrudService({
  entityType: 'PRODUCT',
  skPrefix: PRODUCT_SK_PREFIX,
  gsi1IndexName: 'GSI1Index',
  buildGsi1PK: (ctx) => gsi1PK(ctx.tenantId, ctx.businessId, 'PRODUCT'),
  buildKeys: (ctx, id, data) => ({
    PK: businessPK(ctx.tenantId, ctx.businessId),
    SK: productSK(id),
    GSI1PK: gsi1PK(ctx.tenantId, ctx.businessId, 'PRODUCT'),
    GSI1SK: `${(data as any)?.name || ''}#${id}`,
  }),
  requiredFields: ['name', 'price'],
});

// ---- Payment Service ----

export const paymentService = createCrudService({
  entityType: 'PAYMENT',
  skPrefix: 'PAYMENT#',
  gsi1IndexName: 'GSI1Index',
  buildGsi1PK: (ctx) => gsi1PK(ctx.tenantId, ctx.businessId, 'PAYMENT'),
  buildKeys: (ctx, id, data) => ({
    PK: businessPK(ctx.tenantId, ctx.businessId),
    SK: `PAYMENT#${id}`,
    GSI1PK: gsi1PK(ctx.tenantId, ctx.businessId, 'PAYMENT'),
    GSI1SK: `${(data as any)?.date || new Date().toISOString()}#${id}`,
    GSI2PK: gsi2PK(ctx.tenantId, 'PAYMENT'),
    GSI2SK: `${(data as any)?.date || new Date().toISOString()}#${ctx.businessId}#${id}`,
  }),
  requiredFields: ['amountPaise', 'customerId'],
});

// ---- Estimate Service ----

export const estimateService = createCrudService({
  entityType: 'ESTIMATE',
  skPrefix: 'ESTIMATE#',
  gsi1IndexName: 'GSI1Index',
  buildGsi1PK: (ctx) => gsi1PK(ctx.tenantId, ctx.businessId, 'ESTIMATE'),
  buildKeys: (ctx, id, data) => ({
    PK: businessPK(ctx.tenantId, ctx.businessId),
    SK: `ESTIMATE#${id}`,
    GSI1PK: gsi1PK(ctx.tenantId, ctx.businessId, 'ESTIMATE'),
    GSI1SK: `${(data as any)?.date || new Date().toISOString()}#${id}`,
  }),
  requiredFields: ['customerName'],
});

// ---- Journal Entry Service ----

export const journalEntryService = createCrudService({
  entityType: 'JOURNAL_ENTRY',
  skPrefix: 'JOURNAL#',
  gsi1IndexName: 'GSI1Index',
  buildGsi1PK: (ctx) => gsi1PK(ctx.tenantId, ctx.businessId, 'JOURNAL_ENTRY'),
  buildKeys: (ctx, id, data) => ({
    PK: businessPK(ctx.tenantId, ctx.businessId),
    SK: `JOURNAL#${id}`,
    GSI1PK: gsi1PK(ctx.tenantId, ctx.businessId, 'JOURNAL_ENTRY'),
    GSI1SK: `${(data as any)?.date || new Date().toISOString()}#${id}`,
  }),
  requiredFields: ['type', 'amountPaise'],
});

// ---- Stock Movement Service ----

export const stockMovementService = createCrudService({
  entityType: 'STOCK_MOVEMENT',
  skPrefix: 'STOCK_MVT#',
  gsi1IndexName: 'GSI1Index',
  buildGsi1PK: (ctx) => gsi1PK(ctx.tenantId, ctx.businessId, 'STOCK_MOVEMENT'),
  buildKeys: (ctx, id, data) => ({
    PK: businessPK(ctx.tenantId, ctx.businessId),
    SK: `STOCK_MVT#${id}`,
    GSI1PK: gsi1PK(ctx.tenantId, ctx.businessId, 'STOCK_MOVEMENT'),
    GSI1SK: `${(data as any)?.date || new Date().toISOString()}#${id}`,
  }),
  requiredFields: ['productId', 'quantity', 'type'],
});

// ---- Backup Service ----

export const backupService = createCrudService({
  entityType: 'BACKUP',
  skPrefix: 'BACKUP#',
  buildKeys: (ctx, id) => ({
    PK: businessPK(ctx.tenantId, ctx.businessId),
    SK: `BACKUP#${id}`,
  }),
});

// ---- Business Service (tenant-level) ----

export const businessService = createCrudService({
  entityType: 'BUSINESS',
  skPrefix: 'BUSINESS#',
  buildKeys: (ctx, id) => ({
    PK: `TENANT#${ctx.tenantId}`,
    SK: `BUSINESS#${id}`,
  }),
  requiredFields: ['name', 'businessType'],
});

// ---- Vendor Profile Service ----

export const vendorProfileService = createCrudService({
  entityType: 'VENDOR_PROFILE',
  skPrefix: 'VENDOR_PROFILE#',
  buildKeys: (ctx, id) => ({
    PK: businessPK(ctx.tenantId, ctx.businessId),
    SK: `VENDOR_PROFILE#${id}`,
  }),
  requiredFields: ['name'],
});

// ---- Connection (Shop Link) Service ----

export const connectionService = createCrudService({
  entityType: 'CONNECTION',
  skPrefix: 'CONNECTION#',
  buildKeys: (ctx, id) => ({
    PK: businessPK(ctx.tenantId, ctx.businessId),
    SK: `CONNECTION#${id}`,
  }),
});
