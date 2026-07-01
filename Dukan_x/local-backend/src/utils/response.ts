// ============================================================================
// Response Builder — Express adapter of the AWS API envelope
// ============================================================================
// Produces the SAME `ApiResponse` envelope the AWS backend returns (Req 3.2),
// so the Flutter repository layer receives byte-compatible response shapes in
// either mode. These helpers write directly to an Express `Response`.
// ============================================================================

import { Response } from 'express';
import { ApiResponse } from '../contracts/api.contract';

/** Build a successful API response and write it to the Express response. */
export function success<T>(
    res: Response,
    data: T,
    statusCode = 200,
    meta?: ApiResponse['meta'],
): void {
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
    res.status(statusCode).json(body);
}

/** Build a paginated successful response. */
export function paginated<T>(
    res: Response,
    data: T[],
    total: number,
    page: number,
    limit: number,
): void {
    success(res, data, 200, { page, limit, total, timestamp: new Date().toISOString() });
}

/** Build an error response and write it to the Express response. */
export function error(
    res: Response,
    statusCode: number,
    code: string,
    message: string,
    details?: unknown,
): void {
    const body: ApiResponse = {
        status: 'error',
        code: statusCode,
        message,
        success: false,
        error: {
            code,
            message,
            ...(details ? { details } : {}),
        },
        meta: { timestamp: new Date().toISOString() },
    };
    res.status(statusCode).json(body);
}

// ── Common Error Shortcuts (parity with AWS response.ts) ────────────────────

export const badRequest = (res: Response, message: string, details?: unknown) =>
    error(res, 400, 'BAD_REQUEST', message, details);

/**
 * VALIDATION_ERROR — request input failed schema validation (Req 17.8 / 17.15).
 * Returned by the validate-request middleware BEFORE any handler runs, so a
 * schema-invalid request is rejected without persisting anything. The standard
 * error envelope is preserved; the failed-field messages travel in `details`.
 */
export const validationError = (
    res: Response,
    errors: string[],
    message = 'Request input failed schema validation.',
) => error(res, 400, 'VALIDATION_ERROR', message, { errors });

export const unauthorized = (res: Response, message = 'Authentication required') =>
    error(res, 401, 'UNAUTHORIZED', message);

export const forbidden = (res: Response, message = 'Insufficient permissions') =>
    error(res, 403, 'FORBIDDEN', message);

export const notFound = (res: Response, resource = 'Resource') =>
    error(res, 404, 'NOT_FOUND', `${resource} not found`);

export const conflict = (res: Response, message: string) =>
    error(res, 409, 'CONFLICT', message);

export const internalError = (res: Response, message = 'An unexpected error occurred') =>
    error(res, 500, 'INTERNAL_ERROR', message);

/**
 * NOT_IMPLEMENTED — used by the route stubs created in this scaffold task.
 * The contract shape (path, method, envelope) is real; the behavior is filled
 * in by later tasks (auth, gating, store, queue, etc.). Returns the standard
 * error envelope so callers parse it exactly like any other response.
 */
export const notImplemented = (res: Response, feature: string) =>
    error(
        res,
        501,
        'NOT_IMPLEMENTED',
        `${feature} is not yet implemented in the Local_Backend scaffold`,
    );
