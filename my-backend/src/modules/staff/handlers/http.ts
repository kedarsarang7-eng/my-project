// ============================================================================
// Staff Module — Handler HTTP Helpers (Task 3.2)
// ============================================================================
// Small, shared request-parsing helpers reused by the entity CRUD handlers so
// each handler stays focused on business logic (route → repository/service).
// ============================================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { ValidationError } from '../../../utils/errors';

/** The HTTP method, upper-cased (defaults to GET). */
export function httpMethod(event: APIGatewayProxyEventV2): string {
    return (event.requestContext?.http?.method || 'GET').toUpperCase();
}

/** The `{id}` path parameter, if present. */
export function pathId(event: APIGatewayProxyEventV2): string | undefined {
    return event.pathParameters?.id;
}

/**
 * Parse and return the JSON request body as an object.
 * @throws ValidationError(400) when the body is missing or not valid JSON.
 */
export function parseJsonBody(event: APIGatewayProxyEventV2): Record<string, unknown> {
    if (!event.body) {
        throw new ValidationError('Request body is required');
    }
    try {
        const parsed = JSON.parse(event.body) as unknown;
        if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
            throw new ValidationError('Request body must be a JSON object');
        }
        return parsed as Record<string, unknown>;
    } catch (err) {
        if (err instanceof ValidationError) throw err;
        throw new ValidationError('Request body is not valid JSON');
    }
}

/**
 * Parse the `unmask` query parameter (comma-separated field names) into a list.
 * Example: `?unmask=pan,bankAccount` → ['pan', 'bankAccount'].
 * Returns an empty array when absent.
 */
export function unmaskFields(event: APIGatewayProxyEventV2): string[] {
    const raw = event.queryStringParameters?.unmask;
    if (!raw) return [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
}
