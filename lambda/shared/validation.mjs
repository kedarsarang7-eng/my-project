// ============================================================================
// VALIDATION SCHEMAS - Zod schemas for all Lambda handlers (P0 FIX)
// ============================================================================

import { z } from 'zod';

// ============================================================================
// COMMON VALIDATORS
// ============================================================================

export const TenantIdSchema = z.string().min(1).max(50);
export const UUIDSchema = z.string().uuid();
export const EmailSchema = z.string().email();
export const PhoneSchema = z.string().regex(/^\+?[\d\s-]{10,20}$/);
export const MoneySchema = z.number().nonnegative().max(999999999.99);
export const PercentageSchema = z.number().min(0).max(100);
export const GSTINSchema = z.string().regex(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/);

// ============================================================================
// BILLING VALIDATION
// ============================================================================

export const BillItemSchema = z.object({
  productId: z.string().min(1).max(100),
  name: z.string().min(1).max(200),
  quantity: z.number().positive().max(999999),
  price: z.number().nonnegative().max(999999999.99),
  discountPercent: z.number().min(0).max(100).default(0),
  discountAmount: z.number().nonnegative().default(0),
  gstPercent: z.number().min(0).max(100).default(0),
  gstAmount: z.number().nonnegative().default(0),
  hsnCode: z.string().optional(),
  uom: z.string().min(1).max(20).default('PCS'),
  batchId: z.string().optional(),
  expiryDate: z.string().datetime().optional(),
}).refine((data) => {
  // Validate discount consistency
  const calculatedDiscount = (data.quantity * data.price) * (data.discountPercent / 100);
  return Math.abs(calculatedDiscount - data.discountAmount) < 0.01;
}, { message: 'Discount amount does not match discount percentage' });

export const BillCreateSchema = z.object({
  tenantId: TenantIdSchema,
  customerId: z.string().min(1).max(100),
  customerName: z.string().min(1).max(200).optional(),
  customerPhone: PhoneSchema.optional(),
  customerGSTIN: GSTINSchema.optional(),
  items: z.array(BillItemSchema).min(1).max(500),
  paymentMethod: z.enum(['cash', 'card', 'upi', 'credit', 'cheque', 'bank_transfer', 'wallet']),
  paymentStatus: z.enum(['paid', 'pending', 'partial', 'failed']).default('paid'),
  subtotal: MoneySchema,
  discountTotal: z.number().nonnegative().default(0),
  gstTotal: z.number().nonnegative().default(0),
  total: MoneySchema,
  amountPaid: MoneySchema.default(0),
  roundOff: z.number().min(-1).max(1).default(0),
  notes: z.string().max(1000).optional(),
  prescriptionId: z.string().optional(),
  doctorId: z.string().optional(),
  reference: z.string().max(100).optional(),
  businessType: z.enum(['grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics', 'mobileShop', 'computerShop', 'hardware', 'service', 'wholesale', 'petrolPump', 'vegetablesBroker', 'clinic', 'bookStore', 'jewellery', 'autoParts', 'other']),
}).refine((data) => {
  // Validate totals consistency
  const calculatedSubtotal = data.items.reduce((sum, item) => 
    sum + (item.quantity * item.price), 0);
  const calculatedDiscount = data.items.reduce((sum, item) => 
    sum + item.discountAmount, 0) + data.discountTotal;
  const calculatedGST = data.items.reduce((sum, item) => 
    sum + item.gstAmount, 0);
  const expectedTotal = calculatedSubtotal - calculatedDiscount + calculatedGST + data.roundOff;
  
  return Math.abs(expectedTotal - data.total) < 0.10; // 10 paise tolerance
}, { message: 'Bill totals do not match item calculations' }).refine((data) => {
  // Validate payment amount
  if (data.paymentStatus === 'paid') {
    return data.amountPaid >= data.total;
  }
  return true;
}, { message: 'Paid bills must have amountPaid >= total' });

export const BillUpdateSchema = BillCreateSchema.partial().extend({
  billId: z.string().min(1),
  reason: z.string().min(5).max(500).optional(),
}).refine((data) => data.billId, { message: 'billId is required for updates' });

export const BillCancelSchema = z.object({
  tenantId: TenantIdSchema,
  billId: z.string().min(1),
  reason: z.string().min(5).max(500),
  refundAmount: z.number().nonnegative().optional(),
});

// ============================================================================
// SUBSCRIPTION/BILLING VALIDATION
// ============================================================================

export const SubscriptionSchema = z.object({
  planId: z.enum(['basic', 'pro', 'premium', 'enterprise']),
  seats: z.number().int().min(1).max(500).default(1),
  billingCycle: z.enum(['monthly', 'yearly']).default('monthly'),
});

export const CancelSubscriptionSchema = z.object({
  reason: z.enum(['cost', 'features', 'support', 'switching', 'other']).optional(),
  feedback: z.string().max(1000).optional(),
  immediate: z.boolean().default(false),
});

// ============================================================================
// PRODUCT VALIDATION
// ============================================================================

export const ProductCreateSchema = z.object({
  tenantId: TenantIdSchema,
  name: z.string().min(1).max(200),
  description: z.string().max(2000).optional(),
  sku: z.string().min(1).max(100).optional(),
  barcode: z.string().max(50).optional(),
  category: z.string().min(1).max(100),
  subcategory: z.string().max(100).optional(),
  purchasePrice: MoneySchema.default(0),
  salePrice: MoneySchema.default(0),
  mrp: MoneySchema.optional(),
  gstPercent: PercentageSchema.default(0),
  hsnCode: z.string().max(20).optional(),
  uom: z.string().min(1).max(20).default('PCS'),
  minStock: z.number().nonnegative().default(0),
  maxStock: z.number().nonnegative().optional(),
  reorderPoint: z.number().nonnegative().default(0),
  isActive: z.boolean().default(true),
  isBatchManaged: z.boolean().default(false),
  expiryTracking: z.boolean().default(false),
  drugSchedule: z.enum(['H', 'H1', 'X', 'X1', 'G', 'OT', 'C', 'C1', '']).optional(),
  businessType: z.string().min(1),
});

// ============================================================================
// CUSTOMER VALIDATION
// ============================================================================

export const CustomerCreateSchema = z.object({
  tenantId: TenantIdSchema,
  name: z.string().min(1).max(200),
  phone: PhoneSchema,
  email: EmailSchema.optional(),
  gstin: GSTINSchema.optional(),
  address: z.string().max(500).optional(),
  city: z.string().max(100).optional(),
  state: z.string().max(100).optional(),
  pincode: z.string().regex(/^\d{6}$/).optional(),
  creditLimit: z.number().nonnegative().default(0),
  isActive: z.boolean().default(true),
  customerType: z.enum(['retail', 'wholesale', 'distributor', 'corporate']).default('retail'),
});

// ============================================================================
// AUTH VALIDATION
// ============================================================================

export const LoginSchema = z.object({
  email: EmailSchema,
  password: z.string().min(8).max(100),
  deviceId: z.string().optional(),
  deviceFingerprint: z.string().optional(),
});

export const RegisterSchema = z.object({
  email: EmailSchema,
  password: z.string().min(8).max(100)
    .regex(/[A-Z]/, 'Must contain uppercase')
    .regex(/[a-z]/, 'Must contain lowercase')
    .regex(/[0-9]/, 'Must contain number')
    .regex(/[^A-Za-z0-9]/, 'Must contain special character'),
  name: z.string().min(1).max(200),
  businessName: z.string().min(1).max(200),
  businessType: z.string().min(1),
  phone: PhoneSchema,
});

// ============================================================================
// PAGINATION VALIDATION
// ============================================================================

export const PaginationSchema = z.object({
  limit: z.number().int().min(1).max(100).default(50),
  cursor: z.string().optional(),
  sortBy: z.string().optional(),
  sortOrder: z.enum(['asc', 'desc']).default('desc'),
});

export const DateRangeSchema = z.object({
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
}).refine((data) => {
  if (data.startDate && data.endDate) {
    return new Date(data.startDate) <= new Date(data.endDate);
  }
  return true;
}, { message: 'startDate must be before endDate' });

// ============================================================================
// VALIDATION HELPERS
// ============================================================================

export function validate(schema, data) {
  const result = schema.safeParse(data);
  
  if (!result.success) {
    const errors = result.error.errors.map(e => ({
      field: e.path.join('.'),
      message: e.message,
      code: e.code,
    }));
    
    return {
      success: false,
      errors,
      formatted: result.error.flatten(),
    };
  }
  
  return {
    success: true,
    data: result.data,
  };
}

export function validateOrThrow(schema, data) {
  const result = validate(schema, data);
  
  if (!result.success) {
    const error = new Error('Validation failed');
    error.name = 'ValidationError';
    error.details = result.errors;
    error.code = 'VALIDATION_ERROR';
    throw error;
  }
  
  return result.data;
}

// ============================================================================
// TENANT ISOLATION HELPERS
// ============================================================================

export function withTenantContext(schema, tenantId) {
  return schema.refine((data) => {
    if (data.tenantId && data.tenantId !== tenantId) {
      return false;
    }
    return true;
  }, { 
    message: 'Tenant ID mismatch - cross-tenant access attempted',
    path: ['tenantId']
  });
}

export function enforceTenantScope(data, userContext) {
  if (!data.tenantId) {
    data.tenantId = userContext.tenantId;
  }
  
  if (data.tenantId !== userContext.tenantId) {
    throw new Error('TENANT_ISOLATION_VIOLATION: Cross-tenant access detected');
  }
  
  return data;
}
