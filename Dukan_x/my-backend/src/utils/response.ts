// ============================================================================
// API Response Builder — Standardized Lambda Responses
// ============================================================================

import { APIGatewayProxyResultV2 } from 'aws-lambda';
import { ApiResponse } from '../types/api.types';

/**
 * Build a successful API response.
 */
export function success<T>(data: T, statusCode = 200, meta?: ApiResponse['meta']): APIGatewayProxyResultV2 {
    const body: ApiResponse<T> = {
        success: true,
        data,
        meta: {
            ...meta,
            timestamp: new Date().toISOString(),
        },
    };

    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify(body),
    };
}

/**
 * Build a paginated successful response.
 */
export function paginated<T>(
    data: T[],
    total: number,
    page: number,
    limit: number,
): APIGatewayProxyResultV2 {
    return success(data, 200, {
        page,
        limit,
        total,
        timestamp: new Date().toISOString(),
    });
}

/**
 * Build an error response.
 */
export function error(
    statusCode: number,
    code: string,
    message: string,
    details?: unknown,
): APIGatewayProxyResultV2 {
    const body: ApiResponse = {
        success: false,
        error: {
            code,
            message,
            ...(details ? { details } : {}),
        },
        meta: {
            timestamp: new Date().toISOString(),
        },
    };

    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify(body),
    };
}

// ── Common Error Shortcuts ──────────────────────────────────────────────

export const badRequest = (message: string, details?: unknown) =>
    error(400, 'BAD_REQUEST', message, details);

export const unauthorized = (message = 'Authentication required') =>
    error(401, 'UNAUTHORIZED', message);

export const forbidden = (message = 'Insufficient permissions') =>
    error(403, 'FORBIDDEN', message);

export const notFound = (resource = 'Resource') =>
    error(404, 'NOT_FOUND', `${resource} not found`);

export const conflict = (message: string) =>
    error(409, 'CONFLICT', message);

export const internalError = (message = 'An unexpected error occurred') =>
    error(500, 'INTERNAL_ERROR', message);
