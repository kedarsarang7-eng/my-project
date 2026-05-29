// ============================================================
// Dukan Marketplace - Error Handling
// Custom AppError class with structured error codes
// ============================================================

import { ErrorCodes } from './types';

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly errorCode: string;
  public readonly details?: unknown;

  constructor(
    message: string,
    statusCode: number,
    errorCode: string,
    details?: unknown
  ) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.details = details;
    Object.setPrototypeOf(this, AppError.prototype);
  }

  toJSON() {
    return {
      code: this.errorCode,
      message: this.message,
      details: this.details,
    };
  }
}

// ---------- PRE-DEFINED ERROR FACTORIES ----------

export const Errors = {
  // Auth Errors
  unauthorized: (message = 'Authentication required') => 
    new AppError(message, 401, ErrorCodes.UNAUTHORIZED),
  
  forbidden: (message = 'Access denied') => 
    new AppError(message, 403, ErrorCodes.FORBIDDEN),
  
  tokenExpired: () => 
    new AppError('Token has expired', 401, ErrorCodes.TOKEN_EXPIRED),
  
  // Data Isolation Errors
  businessMismatch: (tokenBiz: string, pathBiz: string) => 
    new AppError(
      `Business ID mismatch: token has ${tokenBiz}, path has ${pathBiz}`,
      403,
      ErrorCodes.BUSINESS_MISMATCH,
      { tokenBusinessId: tokenBiz, pathBusinessId: pathBiz }
    ),
  
  customerNotConnected: (customerId: string, businessId: string) => 
    new AppError(
      `Customer ${customerId} is not connected to business ${businessId}`,
      403,
      ErrorCodes.CUSTOMER_NOT_CONNECTED,
      { customerId, businessId }
    ),
  
  // Business Logic Errors
  invalidStatusTransition: (current: string, attempted: string) => 
    new AppError(
      `Cannot transition from ${current} to ${attempted}`,
      400,
      ErrorCodes.INVALID_STATUS_TRANSITION,
      { currentStatus: current, attemptedStatus: attempted }
    ),
  
  outOfStock: (productId: string, requested: number, available: number) => 
    new AppError(
      `Insufficient stock for product ${productId}`,
      400,
      ErrorCodes.OUT_OF_STOCK,
      { productId, requested, available }
    ),
  
  paymentRequired: () => 
    new AppError('Payment must be completed before placing order', 400, ErrorCodes.PAYMENT_REQUIRED),
  
  prescriptionRequired: () => 
    new AppError('Prescription required for this order', 400, ErrorCodes.PRESCRIPTION_REQUIRED),
  
  couponInvalid: (code: string) => 
    new AppError(`Coupon ${code} is invalid`, 400, ErrorCodes.COUPON_INVALID, { couponCode: code }),
  
  couponExpired: (code: string) => 
    new AppError(`Coupon ${code} has expired`, 400, ErrorCodes.COUPON_EXPIRED, { couponCode: code }),
  
  minOrderNotMet: (minValue: number, currentValue: number) => 
    new AppError(
      `Minimum order value of ₹${minValue} not met`,
      400,
      ErrorCodes.MIN_ORDER_NOT_MET,
      { minOrderValue: minValue, currentValue }
    ),
  
  // Resource Errors
  notFound: (resource: string, id: string) => 
    new AppError(`${resource} with id ${id} not found`, 404, ErrorCodes.NOT_FOUND, { resource, id }),
  
  alreadyExists: (resource: string, id: string) => 
    new AppError(`${resource} with id ${id} already exists`, 409, ErrorCodes.ALREADY_EXISTS, { resource, id }),
  
  // Validation Error
  validation: (message: string, details?: unknown) => 
    new AppError(message, 400, ErrorCodes.VALIDATION_ERROR, details),
  
  // System Error
  internal: (message = 'Internal server error') => 
    new AppError(message, 500, ErrorCodes.INTERNAL_ERROR),
};
