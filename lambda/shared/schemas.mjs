import { z } from 'zod';

/**
 * Validation schemas for FuelPOS API
 * Uses Zod for runtime type checking and validation
 */

// QR Generation Request Schema
export const QRGenerateSchema = z.object({
  amount: z.number()
    .positive('Amount must be greater than 0')
    .max(50000, 'Amount exceeds maximum limit of ₹50,000'),
  vehicleNumber: z.string()
    .min(1, 'Vehicle number is required')
    .max(20, 'Vehicle number too long')
    .optional(),
  fuelType: z.enum(['Petrol', 'Diesel']).optional(),
  liters: z.number()
    .positive('Liters must be positive')
    .optional(),
});

// Payment Status Query Schema
export const PaymentStatusQuerySchema = z.object({
  orderId: z.string().min(1, 'Order ID is required'),
  stationId: z.string().min(1, 'Station ID is required'),
});

// Station ID Param Schema (used across multiple endpoints)
export const StationIdQuerySchema = z.object({
  stationId: z.string().min(1, 'Station ID is required'),
  date: z.string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format')
    .optional(),
});

// Pagination Schema
export const PaginationSchema = z.object({
  page: z.string()
    .regex(/^\d+$/)
    .transform(Number)
    .default('1'),
  limit: z.string()
    .regex(/^\d+$/)
    .transform(Number)
    .refine((n) => n <= 50, 'Limit cannot exceed 50')
    .default('10'),
});

// Razorpay Webhook Payload Schema
export const RazorpayWebhookSchema = z.object({
  event: z.string(),
  payload: z.object({
    payment: z.object({
      entity: z.object({
        id: z.string(),
        order_id: z.string(),
        amount: z.number(),
        status: z.string(),
        method: z.string().optional(),
      }),
    }).optional(),
  }),
});

// WebSocket Connection Query Schema
export const WebSocketConnectQuerySchema = z.object({
  token: z.string().min(1, 'Token is required'),
});

// Validation helper with detailed error messages
export function validateSchema(schema, data) {
  const result = schema.safeParse(data);
  
  if (!result.success) {
    const errors = result.error.errors.map((err) => ({
      field: err.path.join('.'),
      message: err.message,
    }));
    
    return {
      success: false,
      errors,
      message: errors.map((e) => `${e.field}: ${e.message}`).join(', '),
    };
  }
  
  return {
    success: true,
    data: result.data,
  };
}

// Sanitize string input (basic XSS prevention)
export function sanitizeString(str) {
  if (typeof str !== 'string') return str;
  
  return str
    .replace(/[<>]/g, '') // Remove < and >
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .trim();
}

// Sanitize object recursively
export function sanitizeObject(obj) {
  if (typeof obj !== 'object' || obj === null) {
    return obj;
  }
  
  if (Array.isArray(obj)) {
    return obj.map(sanitizeObject);
  }
  
  const sanitized = {};
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === 'string') {
      sanitized[key] = sanitizeString(value);
    } else if (typeof value === 'object') {
      sanitized[key] = sanitizeObject(value);
    } else {
      sanitized[key] = value;
    }
  }
  
  return sanitized;
}
