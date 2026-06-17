import { config } from '../config/environment';
import { APIGatewayProxyResultV2 } from 'aws-lambda';
import { ApiResponse } from '../types/api.types';

// ============================================================================
// API Response Builder — Standardized Lambda Responses
// ============================================================================

export function success<T>(
    arg1: T | number,
    arg2?: number | T,
    arg3?: ApiResponse['meta']
): APIGatewayProxyResultV2 {
    let data: any;
    let statusCode = 200;
    let meta: any = arg3;

    if (typeof arg1 === 'number') {
        statusCode = arg1;
        data = arg2;
    } else {
        data = arg1;
        if (typeof arg2 === 'number') {
            statusCode = arg2;
        }
    }

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
    statusCodeOrErr: number | any,
    code?: string,
    message?: string,
    details?: unknown,
): APIGatewayProxyResultV2 {
    let statusCode = 500;
    let errCode = 'INTERNAL_ERROR';
    let errMsg = 'An unexpected error occurred';
    let errDetails = details;

    if (typeof statusCodeOrErr !== 'number') {
        // It's a caught error object!
        const err = statusCodeOrErr;
        statusCode = err?.statusCode || err?.status || 500;
        errCode = err?.code || 'INTERNAL_ERROR';
        errMsg = err?.message || 'An unexpected error occurred';
        errDetails = err?.details;
    } else {
        statusCode = statusCodeOrErr;
        errCode = code || 'INTERNAL_ERROR';
        errMsg = message || 'An unexpected error occurred';
    }

    // HIGH FIX: Sanitize details in production - never leak stack traces or internals
    const isProduction = config.app.env === 'production';
    const safeDetails = isProduction && errDetails
        ? sanitizeErrorDetails(errDetails)
        : errDetails;

    const body: ApiResponse = {
        status: 'error',
        code: statusCode,
        message: errMsg,
        success: false,
        error: {
            code: errCode,
            message: errMsg,
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

// ── Compatibility Exports ────────────────────────────────────────────────
import { withRequestContext, generateRID } from './context';
export { withRequestContext, generateRID };

export interface ResponseFunction {
    (statusCode: number, body: any): APIGatewayProxyResultV2;
    success: typeof success;
    error: typeof error;
    paginated: typeof paginated;
    badRequest: typeof badRequest;
    unauthorized: typeof unauthorized;
    forbidden: typeof forbidden;
    notFound: typeof notFound;
    conflict: typeof conflict;
    internalError: typeof internalError;
    serviceUnavailable: typeof serviceUnavailable;
    tooManyRequests: typeof tooManyRequests;
}

const responseFn = function (statusCode: number, body: any): APIGatewayProxyResultV2 {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
        },
        body: typeof body === 'string' ? body : JSON.stringify(body),
    };
} as any;

responseFn.success = success;
responseFn.error = error;
responseFn.paginated = paginated;
responseFn.badRequest = badRequest;
responseFn.unauthorized = unauthorized;
responseFn.forbidden = forbidden;
responseFn.notFound = notFound;
responseFn.conflict = conflict;
responseFn.internalError = internalError;
responseFn.serviceUnavailable = serviceUnavailable;
responseFn.tooManyRequests = tooManyRequests;

export const response: ResponseFunction = responseFn;

export function errorResponse(err: any): APIGatewayProxyResultV2 {
    const statusCode = err.statusCode || err.status || 500;
    const code = err.code || 'INTERNAL_ERROR';
    const message = err.message || 'An unexpected error occurred';
    return error(statusCode, code, message, err.details);
}
