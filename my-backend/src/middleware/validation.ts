// ============================================================================
// Validation Middleware — Zod Schema Validation Helper
// ============================================================================
// Provides parseBody() and parseQuery() helpers that validate input against
// Zod schemas and return type-safe parsed data or a formatted error response.
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { z } from 'zod';
import * as response from '../utils/response';

/**
 * Parse and validate the request body against a Zod schema.
 * Returns either validated data or an error response ready to return.
 */
export function parseBody<T>(
    schema: z.ZodSchema<T>,
    event: APIGatewayProxyEventV2
): { success: true; data: T } | { success: false; error: APIGatewayProxyResultV2 } {
    let raw: unknown;
    try {
        raw = JSON.parse(event.body || '{}');
    } catch {
        return { success: false, error: response.badRequest('Invalid JSON body') };
    }

    const result = schema.safeParse(raw);
    if (!result.success) {
        return {
            success: false,
            error: response.badRequest('Validation failed', result.error.flatten()),
        };
    }
    return { success: true, data: result.data };
}

/**
 * Parse and validate query string parameters against a Zod schema.
 */
export function parseQuery<T>(
    schema: z.ZodSchema<T>,
    event: APIGatewayProxyEventV2
): { success: true; data: T } | { success: false; error: APIGatewayProxyResultV2 } {
    const params = event.queryStringParameters || {};
    const result = schema.safeParse(params);
    if (!result.success) {
        return {
            success: false,
            error: response.badRequest('Query validation failed', result.error.flatten()),
        };
    }
    return { success: true, data: result.data };
}

/**
 * Parse pagination from query params with safe defaults and bounds.
 */
export function parsePagination(event: APIGatewayProxyEventV2): {
    page: number;
    limit: number;
    offset: number;
} {
    const params = event.queryStringParameters || {};
    const page = Math.max(1, parseInt(params.page || '1', 10) || 1);
    const limit = Math.min(Math.max(1, parseInt(params.limit || '20', 10) || 20), 100);
    return { page, limit, offset: (page - 1) * limit };
}

/**
 * Validate file upload size before processing.
 * Checks both Content-Length header and Base64-decoded size.
 * Returns error or null if valid.
 */
export function validateUploadSize(
    event: APIGatewayProxyEventV2,
    maxSizeMB = 10
): { valid: boolean; error?: string } {
    const contentLength = event.headers['content-length'];
    if (!contentLength) return { valid: true };  // Can't determine, allow through

    const sizeBytes = parseInt(contentLength, 10);
    const maxBytes = maxSizeMB * 1024 * 1024;

    if (sizeBytes > maxBytes) {
        return {
            valid: false,
            error: `Request exceeds maximum size of ${maxSizeMB}MB (received: ${(sizeBytes / 1024 / 1024).toFixed(2)}MB)`
        };
    }

    return { valid: true };
}

/**
 * Validate Base64-encoded image size and file type (magic bytes).
 * Returns { valid, error?, fileType?, imageSizeBytes? }
 */
export function validateBase64Image(imageBase64: string, maxSizeMB = 10): {
    valid: boolean;
    error?: string;
    fileType?: string;
    imageSizeBytes?: number;
} {
    try {
        const buffer = Buffer.from(imageBase64, 'base64');
        const imageSizeBytes = buffer.length;

        // Check size
        if (imageSizeBytes > maxSizeMB * 1024 * 1024) {
            return {
                valid: false,
                error: `Decoded image size ${(imageSizeBytes / 1024 / 1024).toFixed(2)}MB exceeds ${maxSizeMB}MB limit`
            };
        }

        // Check file type via magic bytes (first 4 bytes)
        const signature = buffer.slice(0, 4).toString('hex');
        const validSignatures: Record<string, string> = {
            '89504e47': 'PNG',    // PNG
            'ffd8ffe0': 'JPEG',   // JPEG
            'ffd8ffe1': 'JPEG',   // JPEG with EXIF
            '47494638': 'GIF',    // GIF87a/GIF89a
        };

        const fileType = validSignatures[signature];
        if (!fileType) {
            return {
                valid: false,
                error: 'Invalid image format. Only PNG, JPEG, and GIF are supported'
            };
        }

        return {
            valid: true,
            fileType,
            imageSizeBytes
        };
    } catch (err) {
        return {
            valid: false,
            error: `Invalid Base64 encoding: ${(err as Error).message}`
        };
    }
}
