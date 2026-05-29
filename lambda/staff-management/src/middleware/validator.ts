// ============================================================================
// VALIDATOR MIDDLEWARE - Zod-based request validation
// ============================================================================

import { z, ZodSchema, ZodError } from 'zod';
import { APIGatewayProxyEvent } from 'aws-lambda';
import { ValidationError } from './errorHandler';

// Staff validation schemas
export const createStaffSchema = z.object({
  fullName: z.string().min(2, 'Full name must be at least 2 characters').max(100),
  phoneNumber: z.string().min(10, 'Phone number must be at least 10 digits').max(15),
  email: z.string().email('Invalid email format').optional(),
  role: z.enum(['pump_operator', 'cashier', 'supervisor', 'manager', 'admin']),
  shiftTiming: z.object({
    start: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time format (HH:MM)'),
    end: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time format (HH:MM)'),
    days: z.array(z.enum(['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']))
      .min(1, 'At least one working day required')
  }),
  permissions: z.object({
    canDispenseFuel: z.boolean().optional(),
    canEditFuelLogs: z.boolean().optional(),
    canViewSalesReport: z.boolean().optional(),
    canProcessPayments: z.boolean().optional(),
    canApplyDiscounts: z.boolean().optional(),
    canViewCashDrawer: z.boolean().optional(),
    canCloseDayShift: z.boolean().optional(),
    canViewInventory: z.boolean().optional(),
    canUpdateInventory: z.boolean().optional(),
    canOrderStock: z.boolean().optional(),
    canViewOtherStaff: z.boolean().optional(),
    canManageAttendance: z.boolean().optional(),
    canExportReports: z.boolean().optional(),
    canViewAllShiftReports: z.boolean().optional(),
    canViewOwnShiftReport: z.boolean().optional()
  }).optional(),
  emergencyContact: z.object({
    name: z.string().min(2),
    phone: z.string().min(10),
    relation: z.string().min(2)
  }).optional(),
  petrolPumpId: z.string().min(1, 'Petrol pump ID is required')
});

export const updateStaffSchema = z.object({
  fullName: z.string().min(2).max(100).optional(),
  phoneNumber: z.string().min(10).max(15).optional(),
  email: z.string().email().optional(),
  role: z.enum(['pump_operator', 'cashier', 'supervisor', 'manager', 'admin']).optional(),
  shiftTiming: z.object({
    start: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/),
    end: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/),
    days: z.array(z.enum(['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'])).min(1)
  }).optional(),
  permissions: z.object({
    canDispenseFuel: z.boolean().optional(),
    canEditFuelLogs: z.boolean().optional(),
    canViewSalesReport: z.boolean().optional(),
    canProcessPayments: z.boolean().optional(),
    canApplyDiscounts: z.boolean().optional(),
    canViewCashDrawer: z.boolean().optional(),
    canCloseDayShift: z.boolean().optional(),
    canViewInventory: z.boolean().optional(),
    canUpdateInventory: z.boolean().optional(),
    canOrderStock: z.boolean().optional(),
    canViewOtherStaff: z.boolean().optional(),
    canManageAttendance: z.boolean().optional(),
    canExportReports: z.boolean().optional(),
    canViewAllShiftReports: z.boolean().optional(),
    canViewOwnShiftReport: z.boolean().optional()
  }).optional(),
  isActive: z.boolean().optional(),
  emergencyContact: z.object({
    name: z.string().min(2),
    phone: z.string().min(10),
    relation: z.string().min(2)
  }).optional()
});

export const listStaffQuerySchema = z.object({
  role: z.enum(['pump_operator', 'cashier', 'supervisor', 'manager', 'admin']).optional(),
  isActive: z.preprocess((val) => val === 'true', z.boolean().optional()),
  limit: z.preprocess((val) => val ? parseInt(val as string, 10) || 20 : 20, z.number().optional()),
  lastKey: z.string().optional()
});

export const staffIdParamSchema = z.object({
  staffId: z.string().regex(/^PP-\d{4}-\d{4}$/, 'Invalid staff ID format (PP-YYYY-XXXX)')
});

export const resetPasswordSchema = z.object({
  reason: z.string().max(200).optional()
});

// Type exports inferred from schemas
export type CreateStaffInput = z.infer<typeof createStaffSchema>;
export type UpdateStaffInput = z.infer<typeof updateStaffSchema>;

/**
 * Validate request body against Zod schema
 */
export function validateBody<T>(schema: ZodSchema<T>, body: string | null): T {
  if (!body) {
    throw new ValidationError('Request body is required');
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    throw new ValidationError('Invalid JSON in request body');
  }

  try {
    return schema.parse(parsed);
  } catch (error: unknown) {
    if (error instanceof ZodError) {
      const fields: Record<string, string> = {};
      error.errors.forEach((err: { path: (string | number)[]; message: string }) => {
        const path = err.path.join('.');
        fields[path] = err.message;
      });
      throw new ValidationError('Validation failed', fields);
    }
    throw error;
  }
}

/**
 * Validate query parameters against Zod schema
 */
export function validateQuery<T>(schema: ZodSchema<T>, query: Record<string, string | undefined> | null): T {
  try {
    return schema.parse(query || {});
  } catch (error: unknown) {
    if (error instanceof ZodError) {
      const fields: Record<string, string> = {};
      error.errors.forEach((err: { path: (string | number)[]; message: string }) => {
        const path = err.path.join('.');
        fields[path] = err.message;
      });
      throw new ValidationError('Query parameter validation failed', fields);
    }
    throw error;
  }
}

/**
 * Validate path parameters against Zod schema
 */
export function validateParams<T>(schema: ZodSchema<T>, params: Record<string, string | undefined> | null): T {
  if (!params || Object.keys(params).length === 0) {
    throw new ValidationError('Path parameters are required');
  }

  try {
    return schema.parse(params);
  } catch (error: unknown) {
    if (error instanceof ZodError) {
      const fields: Record<string, string> = {};
      error.errors.forEach((err: { path: (string | number)[]; message: string }) => {
        const path = err.path.join('.');
        fields[path] = err.message;
      });
      throw new ValidationError('Path parameter validation failed', fields);
    }
    throw error;
  }
}

/**
 * Sanitize staff output - remove sensitive fields
 */
export function sanitizeStaffOutput(staff: Record<string, unknown>): Record<string, unknown> {
  const {
    cognitoUserId,
    createdBy,
    SK,
    GSI1PK,
    GSI1SK,
    GSI2PK,
    GSI2SK,
    ...safeFields
  } = staff;

  return safeFields;
}
