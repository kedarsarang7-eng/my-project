// ============================================================================
// WITH REQUEST CONTEXT - Lambda handler wrapper
// ============================================================================

import { extractRequestContext, validateTenantIsolation } from './request-context.mjs';
import { setLogContext, info, error } from './logger.mjs';
import { getShortReference } from './rid-generator.mjs';

/**
 * Higher-order function that wraps Lambda handlers with RID context
 */
export function withRequestContext(handler) {
  return async (event) => {
    // Extract or generate request context
    const requestContext = extractRequestContext(event);
    
    // Set logger context
    setLogContext(requestContext);
    
    const shortRef = getShortReference(requestContext.requestId);
    info(`[${shortRef}] Request started`, {
      path: event.path || event.routeKey,
      method: event.httpMethod || event.requestContext?.http?.method,
      sourceIp: requestContext.sourceIp,
    });
    
    // Validate tenant isolation
    const tenantValidation = validateTenantIsolation(event, requestContext);
    if (!tenantValidation.valid) {
      error(`[${shortRef}] Tenant validation failed`, new Error(tenantValidation.error));
      return createErrorResponse(requestContext, {
        message: tenantValidation.error,
        code: tenantValidation.errorCode,
        statusCode: 403,
      });
    }
    
    try {
      // Execute handler
      const result = await handler(event, requestContext);
      
      // Add RID to response headers
      result.headers = {
        ...result.headers,
        'X-Request-ID': requestContext.requestId,
        'X-Response-Time': `${Date.now() - requestContext.startTime}ms`,
      };
      
      info(`[${shortRef}] Request completed`, {
        statusCode: result.statusCode,
        duration: Date.now() - requestContext.startTime,
      });
      
      return result;
      
    } catch (err) {
      error(`[${shortRef}] Request failed`, err, {
        path: event.path,
        method: event.httpMethod,
      });
      
      // Return error response with RID
      return createErrorResponse(requestContext, err);
    }
  };
}

/**
 * Create standardized error response with RID
 */
function createErrorResponse(context, err) {
  const errorCode = err.code || 'INTERNAL_ERROR';
  const statusCode = err.statusCode || 500;
  
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-ID': context.requestId,
    },
    body: JSON.stringify({
      success: false,
      error: {
        code: errorCode,
        message: err.message || 'An unexpected error occurred',
        requestId: context.requestId,
        reference: getShortReference(context.requestId),
        timestamp: new Date().toISOString(),
      },
    }),
  };
}
