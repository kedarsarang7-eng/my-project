import { config } from '../config/environment';
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
        status: 'success',
        code: statusCode,
        message: 'Operation successful',
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
 * HIGH FIX: Sanitizes details in production to prevent stack trace leakage.
 */
export function error(
    statusCode: number,
    code: string,
    message: string,
    details?: unknown,
): APIGatewayProxyResultV2 {
    // HIGH FIX: Sanitize details in production - never leak stack traces or internals
    const isProduction = config.app.env === 'production';
    const safeDetails = isProduction && details
        ? sanitizeErrorDetails(details)
        : details;

    const body: ApiResponse = {
        status: 'error',
        code: statusCode,
        message,
        success: false,
        error: {
            code,
            message,
            ...(safeDetails ? { details: safeDetails } : {}),
        },
        meta: {
            timestamp: new Date().toISOString(),
        },
    };

    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
    };
}

/**
 * HIGH FIX: Sanitize error details to prevent stack trace leakage in production.
 * Removes 'stack', 'trace', and other internal fields from error responses.
 */
function sanitizeErrorDetails(details: unknown): unknown {
    if (typeof details !== 'object' || details === null) {
        return details;
    }

    // List of fields that should never be exposed in production
    const sensitiveFields = ['stack', 'trace', 'stackTrace', 'frames', 'raw', 'internal'];

    if (Array.isArray(details)) {
        return details.map(sanitizeErrorDetails);
    }

    const sanitized: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(details as Record<string, unknown>)) {
        if (sensitiveFields.includes(key.toLowerCase())) {
            continue; // Skip sensitive fields
        }
        if (typeof value === 'object' && value !== null) {
            sanitized[key] = sanitizeErrorDetails(value);
        } else {
            sanitized[key] = value;
        }
    }
    return sanitized;
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

// L-7: Service unavailable with Retry-After header
export function serviceUnavailable(message = 'Service temporarily unavailable', retryAfterSeconds = 5): APIGatewayProxyResultV2 {
    const body: ApiResponse = {
        status: 'error',
        code: 503,
        message,
        success: false,
        error: { code: 'SERVICE_UNAVAILABLE', message },
        meta: { timestamp: new Date().toISOString() },
    };
    return {
        statusCode: 503,
        headers: {
            'Content-Type': 'application/json',
            'Retry-After': String(retryAfterSeconds),
        },
        body: JSON.stringify(body),
    };
}

// L-7: Rate limit exceeded response
export function tooManyRequests(message = 'Rate limit exceeded', retryAfterSeconds = 10): APIGatewayProxyResultV2 {
    const body: ApiResponse = {
        status: 'error',
        code: 429,
        message,
        success: false,
        error: { code: 'TOO_MANY_REQUESTS', message },
        meta: { timestamp: new Date().toISOString() },
    };
    return {
        statusCode: 429,
        headers: {
            'Content-Type': 'application/json',
            'Retry-After': String(retryAfterSeconds),
        },
        body: JSON.stringify(body),
    };
}

