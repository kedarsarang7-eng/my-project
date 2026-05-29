// ============================================================================
// LAMBDA ERROR HANDLER - Standardized Error Responses (P2 FIX)
// ============================================================================

/**
 * Standardized error codes for API responses
 */
export const ErrorCodes = {
  // 400 - Bad Request
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  INVALID_INPUT: 'INVALID_INPUT',
  MISSING_REQUIRED_FIELD: 'MISSING_REQUIRED_FIELD',
  INVALID_FORMAT: 'INVALID_FORMAT',
  
  // 401 - Unauthorized
  AUTH_TOKEN_MISSING: 'AUTH_TOKEN_MISSING',
  AUTH_TOKEN_EXPIRED: 'AUTH_TOKEN_EXPIRED',
  AUTH_TOKEN_INVALID: 'AUTH_TOKEN_INVALID',
  INSUFFICIENT_PERMISSIONS: 'INSUFFICIENT_PERMISSIONS',
  
  // 403 - Forbidden
  ACCESS_DENIED: 'ACCESS_DENIED',
  TENANT_ISOLATION_VIOLATION: 'TENANT_ISOLATION_VIOLATION',
  ROLE_REQUIRED: 'ROLE_REQUIRED',
  
  // 404 - Not Found
  RESOURCE_NOT_FOUND: 'RESOURCE_NOT_FOUND',
  BILL_NOT_FOUND: 'BILL_NOT_FOUND',
  CUSTOMER_NOT_FOUND: 'CUSTOMER_NOT_FOUND',
  PRODUCT_NOT_FOUND: 'PRODUCT_NOT_FOUND',
  
  // 409 - Conflict
  CONCURRENT_MODIFICATION: 'CONCURRENT_MODIFICATION',
  DUPLICATE_ENTRY: 'DUPLICATE_ENTRY',
  RESOURCE_ALREADY_EXISTS: 'RESOURCE_ALREADY_EXISTS',
  
  // 422 - Unprocessable Entity
  BUSINESS_RULE_VIOLATION: 'BUSINESS_RULE_VIOLATION',
  INSUFFICIENT_STOCK: 'INSUFFICIENT_STOCK',
  PAYMENT_FAILED: 'PAYMENT_FAILED',
  PRESCRIPTION_REQUIRED: 'PRESCRIPTION_REQUIRED',
  PRODUCT_EXPIRED: 'PRODUCT_EXPIRED',
  
  // 429 - Rate Limited
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED',
  
  // 500 - Internal Server Error
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  DATABASE_ERROR: 'DATABASE_ERROR',
  EXTERNAL_SERVICE_ERROR: 'EXTERNAL_SERVICE_ERROR',
  
  // 503 - Service Unavailable
  SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',
  MAINTENANCE_MODE: 'MAINTENANCE_MODE',
};

/**
 * HTTP status codes mapping
 */
const STATUS_CODES = {
  [ErrorCodes.VALIDATION_ERROR]: 400,
  [ErrorCodes.INVALID_INPUT]: 400,
  [ErrorCodes.MISSING_REQUIRED_FIELD]: 400,
  [ErrorCodes.INVALID_FORMAT]: 400,
  [ErrorCodes.AUTH_TOKEN_MISSING]: 401,
  [ErrorCodes.AUTH_TOKEN_EXPIRED]: 401,
  [ErrorCodes.AUTH_TOKEN_INVALID]: 401,
  [ErrorCodes.INSUFFICIENT_PERMISSIONS]: 403,
  [ErrorCodes.ACCESS_DENIED]: 403,
  [ErrorCodes.TENANT_ISOLATION_VIOLATION]: 403,
  [ErrorCodes.ROLE_REQUIRED]: 403,
  [ErrorCodes.RESOURCE_NOT_FOUND]: 404,
  [ErrorCodes.BILL_NOT_FOUND]: 404,
  [ErrorCodes.CUSTOMER_NOT_FOUND]: 404,
  [ErrorCodes.PRODUCT_NOT_FOUND]: 404,
  [ErrorCodes.CONCURRENT_MODIFICATION]: 409,
  [ErrorCodes.DUPLICATE_ENTRY]: 409,
  [ErrorCodes.RESOURCE_ALREADY_EXISTS]: 409,
  [ErrorCodes.BUSINESS_RULE_VIOLATION]: 422,
  [ErrorCodes.INSUFFICIENT_STOCK]: 422,
  [ErrorCodes.PAYMENT_FAILED]: 422,
  [ErrorCodes.PRESCRIPTION_REQUIRED]: 422,
  [ErrorCodes.PRODUCT_EXPIRED]: 422,
  [ErrorCodes.RATE_LIMIT_EXCEEDED]: 429,
  [ErrorCodes.INTERNAL_ERROR]: 500,
  [ErrorCodes.DATABASE_ERROR]: 500,
  [ErrorCodes.EXTERNAL_SERVICE_ERROR]: 502,
  [ErrorCodes.SERVICE_UNAVAILABLE]: 503,
  [ErrorCodes.MAINTENANCE_MODE]: 503,
};

/**
 * User-friendly error messages
 */
const USER_MESSAGES = {
  [ErrorCodes.VALIDATION_ERROR]: 'Please check your input and try again.',
  [ErrorCodes.INVALID_INPUT]: 'Invalid data provided.',
  [ErrorCodes.MISSING_REQUIRED_FIELD]: 'Please fill in all required fields.',
  [ErrorCodes.INVALID_FORMAT]: 'Invalid format. Please check your input.',
  [ErrorCodes.AUTH_TOKEN_MISSING]: 'Please sign in to continue.',
  [ErrorCodes.AUTH_TOKEN_EXPIRED]: 'Your session has expired. Please sign in again.',
  [ErrorCodes.AUTH_TOKEN_INVALID]: 'Invalid credentials. Please sign in again.',
  [ErrorCodes.INSUFFICIENT_PERMISSIONS]: 'You do not have permission to perform this action.',
  [ErrorCodes.ACCESS_DENIED]: 'Access denied.',
  [ErrorCodes.TENANT_ISOLATION_VIOLATION]: 'Access denied.',
  [ErrorCodes.ROLE_REQUIRED]: 'You do not have the required role for this operation.',
  [ErrorCodes.RESOURCE_NOT_FOUND]: 'The requested item was not found.',
  [ErrorCodes.BILL_NOT_FOUND]: 'Bill not found.',
  [ErrorCodes.CUSTOMER_NOT_FOUND]: 'Customer not found.',
  [ErrorCodes.PRODUCT_NOT_FOUND]: 'Product not found.',
  [ErrorCodes.CONCURRENT_MODIFICATION]: 'This record was modified by another user. Please refresh and try again.',
  [ErrorCodes.DUPLICATE_ENTRY]: 'This item already exists.',
  [ErrorCodes.RESOURCE_ALREADY_EXISTS]: 'This item already exists.',
  [ErrorCodes.BUSINESS_RULE_VIOLATION]: 'This operation violates business rules.',
  [ErrorCodes.INSUFFICIENT_STOCK]: 'Insufficient stock for this operation.',
  [ErrorCodes.PAYMENT_FAILED]: 'Payment processing failed. Please try again.',
  [ErrorCodes.PRESCRIPTION_REQUIRED]: 'A valid prescription is required for this item.',
  [ErrorCodes.PRODUCT_EXPIRED]: 'This product has expired and cannot be sold.',
  [ErrorCodes.RATE_LIMIT_EXCEEDED]: 'Too many requests. Please try again later.',
  [ErrorCodes.INTERNAL_ERROR]: 'An unexpected error occurred. Please try again.',
  [ErrorCodes.DATABASE_ERROR]: 'Database error occurred. Please try again.',
  [ErrorCodes.EXTERNAL_SERVICE_ERROR]: 'External service error. Please try again.',
  [ErrorCodes.SERVICE_UNAVAILABLE]: 'Service temporarily unavailable. Please try again later.',
  [ErrorCodes.MAINTENANCE_MODE]: 'System is under maintenance. Please try again later.',
};

/**
 * P2 FIX: Structured API error
 */
export class ApiError extends Error {
  constructor(code, message, details = null, requestId = null) {
    super(message || USER_MESSAGES[code] || 'An error occurred');
    this.name = 'ApiError';
    this.code = code;
    this.statusCode = STATUS_CODES[code] || 500;
    this.details = details;
    this.requestId = requestId;
    this.timestamp = new Date().toISOString();
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
        statusCode: this.statusCode,
        ...(this.details && { details: this.details }),
        ...(this.requestId && { requestId: this.requestId }),
        timestamp: this.timestamp,
      },
    };
  }
}

/**
 * P2 FIX: Create standardized error response
 */
export function createErrorResponse(code, message, details, requestId) {
  const error = new ApiError(code, message, details, requestId);
  
  return {
    statusCode: error.statusCode,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-Id': requestId || 'unknown',
    },
    body: JSON.stringify(error.toJSON()),
  };
}

/**
 * P2 FIX: Create standardized success response
 */
export function createSuccessResponse(data, statusCode = 200, requestId = null) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-Id': requestId || 'unknown',
    },
    body: JSON.stringify({
      data,
      ...(requestId && { requestId }),
      timestamp: new Date().toISOString(),
    }),
  };
}

/**
 * P2 FIX: Global error handler for Lambda
 */
export function withErrorHandler(handler) {
  return async (event, context) => {
    const requestId = context.awsRequestId || 'unknown';
    
    try {
      const result = await handler(event, context);
      return result;
      
    } catch (err) {
      console.error(`[${requestId}] Error:`, err);
      
      // Handle known error types
      if (err instanceof ApiError) {
        return createErrorResponse(
          err.code,
          err.message,
          err.details,
          requestId
        );
      }
      
      // Handle validation errors
      if (err.name === 'ValidationError' || err.code === 'VALIDATION_ERROR') {
        return createErrorResponse(
          ErrorCodes.VALIDATION_ERROR,
          err.message,
          err.details,
          requestId
        );
      }
      
      // Handle authentication errors
      if (err.message?.includes('INVALID_TOKEN') || err.message?.includes('AUTH_')) {
        return createErrorResponse(
          ErrorCodes.AUTH_TOKEN_INVALID,
          'Authentication failed',
          null,
          requestId
        );
      }
      
      // Handle tenant isolation errors
      if (err.message?.includes('TENANT_ISOLATION')) {
        return createErrorResponse(
          ErrorCodes.TENANT_ISOLATION_VIOLATION,
          'Access denied',
          null,
          requestId
        );
      }
      
      // Handle DynamoDB errors
      if (err.name === 'ConditionalCheckFailedException') {
        return createErrorResponse(
          ErrorCodes.CONCURRENT_MODIFICATION,
          'This record was modified by another user',
          null,
          requestId
        );
      }
      
      if (err.name === 'ResourceNotFoundException') {
        return createErrorResponse(
          ErrorCodes.RESOURCE_NOT_FOUND,
          'Resource not found',
          null,
          requestId
        );
      }
      
      // Generic internal error - don't expose details
      return createErrorResponse(
        ErrorCodes.INTERNAL_ERROR,
        'An unexpected error occurred',
        process.env.NODE_ENV === 'development' ? { originalError: err.message } : null,
        requestId
      );
    }
  };
}

/**
 * P2 FIX: Async handler wrapper with all middleware
 */
export function createHandler(handler, options = {}) {
  const {
    requireAuth = true,
    allowedRoles = [],
    rateLimit = null,
  } = options;
  
  return withErrorHandler(async (event, context) => {
    // Add request context
    event.requestId = context.awsRequestId;
    
    // Handle auth if required
    if (requireAuth) {
      const { verifyToken } = await import('./utils.mjs');
      const authHeader = event.headers?.authorization || event.headers?.Authorization;
      
      if (!authHeader?.startsWith('Bearer ')) {
        throw new ApiError(ErrorCodes.AUTH_TOKEN_MISSING, 'Authorization required');
      }
      
      const user = await verifyToken(authHeader.substring(7));
      event.user = user;
      
      // Check roles if specified
      if (allowedRoles.length > 0) {
        const normalizedUserRole = (user.role || '').toLowerCase().trim();
        const normalizedAllowed = allowedRoles.map(r => r.toLowerCase().trim());
        
        if (!normalizedAllowed.includes(normalizedUserRole)) {
          throw new ApiError(
            ErrorCodes.ROLE_REQUIRED,
            `Required role: ${allowedRoles.join(' or ')}`
          );
        }
      }
    }
    
    // Call actual handler
    return await handler(event, context);
  });
}

/**
 * P2 FIX: Error logging with context
 */
export function logError(err, context = {}) {
  const errorLog = {
    timestamp: new Date().toISOString(),
    level: 'ERROR',
    code: err.code || 'UNKNOWN',
    message: err.message,
    stack: err.stack,
    ...context,
  };
  
  console.error(JSON.stringify(errorLog));
}

/**
 * P2 FIX: Convert legacy error format to new format
 */
export function normalizeLegacyError(err) {
  // Handle old-style error objects
  if (typeof err === 'string') {
    return new ApiError(ErrorCodes.INTERNAL_ERROR, err);
  }
  
  if (err.code && USER_MESSAGES[err.code]) {
    return new ApiError(err.code, err.message, err.details);
  }
  
  // Map common error messages to codes
  const messageMap = {
    'not found': ErrorCodes.RESOURCE_NOT_FOUND,
    'not authorized': ErrorCodes.ACCESS_DENIED,
    'forbidden': ErrorCodes.ACCESS_DENIED,
    'invalid': ErrorCodes.VALIDATION_ERROR,
    'required': ErrorCodes.MISSING_REQUIRED_FIELD,
    'duplicate': ErrorCodes.DUPLICATE_ENTRY,
    'conflict': ErrorCodes.CONCURRENT_MODIFICATION,
  };
  
  for (const [pattern, code] of Object.entries(messageMap)) {
    if (err.message?.toLowerCase().includes(pattern)) {
      return new ApiError(code, err.message);
    }
  }
  
  return new ApiError(ErrorCodes.INTERNAL_ERROR, err.message);
}
