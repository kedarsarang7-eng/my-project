// ============================================================
// Dukan Marketplace - API Response Helpers
// Standardized response formatting with proper headers
// ============================================================

import { APIGatewayProxyResultV2 } from 'aws-lambda';
import { ApiResponse } from './types';
import { AppError } from './errors';

// ---------- CORS HEADERS ----------

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  'Access-Control-Allow-Credentials': 'true',
};

// ---------- SUCCESS RESPONSES ----------

export function success<T>(data: T, meta?: ApiResponse<T>['meta'], statusCode = 200): APIGatewayProxyResultV2 {
  const response: ApiResponse<T> = {
    success: true,
    data,
    meta,
  };

  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
    body: JSON.stringify(response),
  };
}

export function created<T>(data: T): APIGatewayProxyResultV2 {
  return success(data, undefined, 201);
}

export function noContent(): APIGatewayProxyResultV2 {
  return {
    statusCode: 204,
    headers: corsHeaders,
    body: '',
  };
}

// ---------- ERROR RESPONSES ----------

export function error(err: AppError | Error | string): APIGatewayProxyResultV2 {
  if (err instanceof AppError) {
    const response: ApiResponse = {
      success: false,
      error: err.toJSON(),
    };

    return {
      statusCode: err.statusCode,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders,
      },
      body: JSON.stringify(response),
    };
  }

  // Handle generic errors
  const message = err instanceof Error ? err.message : err;
  const response: ApiResponse = {
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message,
    },
  };

  return {
    statusCode: 500,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
    body: JSON.stringify(response),
  };
}

// ---------- PAGINATION HELPERS ----------

export interface PaginationParams {
  page: number;
  limit: number;
  offset: number;
}

export function getPaginationParams(event: { queryStringParameters?: Record<string, string | undefined> }): PaginationParams {
  const page = Math.max(1, parseInt(event.queryStringParameters?.page || '1', 10));
  const limit = Math.min(100, Math.max(1, parseInt(event.queryStringParameters?.limit || '20', 10)));
  const offset = (page - 1) * limit;

  return { page, limit, offset };
}

export function createMeta(params: PaginationParams, total: number) {
  return {
    page: params.page,
    limit: params.limit,
    total,
    hasMore: params.offset + params.limit < total,
  };
}
