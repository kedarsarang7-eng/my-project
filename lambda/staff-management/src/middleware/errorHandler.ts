// ============================================================================
// ERROR HANDLER MIDDLEWARE
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { AuthError } from '../utils/auth';

export interface ErrorResponse {
  success: false;
  error: string;
  message: string;
  fields?: Record<string, string>;
  correlationId?: string;
}

export interface SuccessResponse<T> {
  success: true;
  data: T;
  meta?: {
    page?: number;
    limit?: number;
    total?: number;
    hasMore?: boolean;
    lastKey?: string;
  };
}

export type ApiResponse<T> = SuccessResponse<T> | ErrorResponse;

/**
 * Wrap Lambda handler with error handling
 */
export function withErrorHandler<T>(
  handler: (event: APIGatewayProxyEvent) => Promise<APIGatewayProxyResult>
): (event: APIGatewayProxyEvent) => Promise<APIGatewayProxyResult> {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const correlationId = generateCorrelationId();
    
    try {
      // Log request
      console.log(JSON.stringify({
        correlationId,
        timestamp: new Date().toISOString(),
        method: event.httpMethod,
        path: event.path,
        queryParams: event.queryStringParameters,
        pathParams: event.pathParameters
      }));

      const result = await handler(event);
      
      // Add correlation ID to response
      const body = JSON.parse(result.body || '{}');
      if (result.statusCode < 400) {
        body.correlationId = correlationId;
      }
      
      return {
        ...result,
        headers: {
          ...corsHeaders,
          ...result.headers,
          'X-Correlation-Id': correlationId
        },
        body: JSON.stringify(body)
      };
      
    } catch (error) {
      console.error(JSON.stringify({
        correlationId,
        timestamp: new Date().toISOString(),
        error: error instanceof Error ? error.message : 'Unknown error',
        stack: error instanceof Error ? error.stack : undefined
      }));

      return formatError(error, correlationId);
    }
  };
}

/**
 * Format error into API response
 */
function formatError(error: unknown, correlationId: string): APIGatewayProxyResult {
  // Auth errors
  if (error instanceof AuthError) {
    return {
      statusCode: error.statusCode,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        error: error.statusCode === 401 ? 'UNAUTHORIZED' : 'FORBIDDEN',
        message: error.message,
        correlationId
      } as ErrorResponse)
    };
  }

  // Validation errors
  if (error instanceof ValidationError) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        error: 'VALIDATION_ERROR',
        message: error.message,
        fields: error.fields,
        correlationId
      } as ErrorResponse)
    };
  }

  // Not found errors
  if (error instanceof NotFoundError) {
    return {
      statusCode: 404,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        error: 'NOT_FOUND',
        message: error.message,
        correlationId
      } as ErrorResponse)
    };
  }

  // Conflict errors
  if (error instanceof ConflictError) {
    return {
      statusCode: 409,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        error: 'CONFLICT',
        message: error.message,
        correlationId
      } as ErrorResponse)
    };
  }

  // Default: internal server error
  return {
    statusCode: 500,
    headers: corsHeaders,
    body: JSON.stringify({
      success: false,
      error: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
      correlationId
    } as ErrorResponse)
  };
}

/**
 * CORS headers for all responses
 */
export const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,PATCH,OPTIONS'
};

/**
 * Generate correlation ID for request tracing
 */
function generateCorrelationId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// Custom error classes
export class ValidationError extends Error {
  public fields?: Record<string, string>;

  constructor(message: string, fields?: Record<string, string>) {
    super(message);
    this.name = 'ValidationError';
    this.fields = fields;
  }
}

export class NotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NotFoundError';
  }
}

export class ConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConflictError';
  }
}

/**
 * Success response helper
 */
export function success<T>(
  data: T, 
  statusCode: number = 200, 
  meta?: SuccessResponse<T>['meta']
): APIGatewayProxyResult {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify({
      success: true,
      data,
      meta
    } as SuccessResponse<T>)
  };
}

/**
 * Error response helper
 */
export function error(
  message: string, 
  statusCode: number = 400, 
  errorCode: string = 'ERROR',
  fields?: Record<string, string>
): APIGatewayProxyResult {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify({
      success: false,
      error: errorCode,
      message,
      fields
    } as ErrorResponse)
  };
}

/**
 * Options response for CORS preflight
 */
export function optionsResponse(): APIGatewayProxyResult {
  return {
    statusCode: 200,
    headers: {
      ...corsHeaders,
      'Access-Control-Max-Age': '86400'
    },
    body: ''
  };
}
