// ============================================================================
// Event Factory — Construct Lambda API Gateway Events for Testing
// ============================================================================
// Builds APIGatewayProxyEventV2 shapes for driving handler tests.
// Supports headers, path params, query params, and body injection.
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// ── Types ────────────────────────────────────────────────────────────────────

export interface EventOptions {
    method?: string;
    path?: string;
    headers?: Record<string, string>;
    pathParameters?: Record<string, string>;
    queryStringParameters?: Record<string, string>;
    body?: string | Record<string, unknown>;
    authToken?: string;
    tenantIdHeader?: string;
    businessIdHeader?: string;
    requestId?: string;
    sourceIp?: string;
}

// ── Factory ──────────────────────────────────────────────────────────────────

/**
 * Build a minimal but valid APIGatewayProxyEventV2 for handler testing.
 */
export function makeEvent(opts: EventOptions = {}): APIGatewayProxyEventV2 {
    const method = opts.method || 'GET';
    const path = opts.path || '/test';
    const requestId = opts.requestId || 'test-req-' + Date.now();

    const headers: Record<string, string> = {
        'content-type': 'application/json',
        ...(opts.headers || {}),
    };

    // Add auth token if provided
    if (opts.authToken) {
        headers['authorization'] = `Bearer ${opts.authToken}`;
    }

    // Add tenant header if provided (for testing Finding #1)
    if (opts.tenantIdHeader) {
        headers['x-tenant-id'] = opts.tenantIdHeader;
    }

    // Add business header if provided
    if (opts.businessIdHeader) {
        headers['x-business-id'] = opts.businessIdHeader;
    }

    const event: any = {
        version: '2.0',
        routeKey: `${method} ${path}`,
        rawPath: path,
        rawQueryString: '',
        headers,
        requestContext: {
            accountId: '123456789012',
            apiId: 'test-api',
            http: {
                method,
                path,
                protocol: 'HTTP/1.1',
                sourceIp: opts.sourceIp || '127.0.0.1',
                userAgent: 'DukanX-SecurityTest/1.0',
            },
            requestId,
            routeKey: `${method} ${path}`,
            stage: '$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
    };

    if (opts.pathParameters) {
        event.pathParameters = opts.pathParameters;
    }

    if (opts.queryStringParameters) {
        event.queryStringParameters = opts.queryStringParameters;
        event.rawQueryString = Object.entries(opts.queryStringParameters)
            .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
            .join('&');
    }

    if (opts.body) {
        event.body = typeof opts.body === 'string'
            ? opts.body
            : JSON.stringify(opts.body);
    }

    return event as APIGatewayProxyEventV2;
}

/**
 * Create a minimal Lambda Context for handler invocation.
 */
export function makeContext(overrides?: Partial<Context>): Context {
    return {
        callbackWaitsForEmptyEventLoop: true,
        functionName: 'test-function',
        functionVersion: '$LATEST',
        invokedFunctionArn: 'arn:aws:lambda:ap-south-1:123456789012:function:test',
        memoryLimitInMB: '256',
        awsRequestId: 'test-' + Date.now(),
        logGroupName: '/aws/lambda/test',
        logStreamName: 'test-stream',
        getRemainingTimeInMillis: () => 30000,
        done: () => {},
        fail: () => {},
        succeed: () => {},
        ...overrides,
    } as Context;
}

// ── Convenience Builders ─────────────────────────────────────────────────────

/**
 * Build a cross-tenant attack event: Valid JWT for Tenant A,
 * but x-tenant-id header set to Tenant B.
 */
export function makeHeaderInjectionEvent(
    authToken: string,
    targetTenantId: string,
    opts?: Partial<EventOptions>,
): APIGatewayProxyEventV2 {
    return makeEvent({
        method: 'GET',
        path: '/api/data',
        authToken,
        tenantIdHeader: targetTenantId,
        ...opts,
    });
}

/**
 * Build a body injection event: Valid JWT for Tenant A,
 * but body contains Tenant B's tenantId.
 */
export function makeBodyInjectionEvent(
    authToken: string,
    targetTenantId: string,
    additionalBody?: Record<string, unknown>,
): APIGatewayProxyEventV2 {
    return makeEvent({
        method: 'POST',
        path: '/api/data',
        authToken,
        body: {
            tenantId: targetTenantId,
            name: 'Injected Product',
            ...additionalBody,
        },
    });
}

/**
 * Build a nested body injection event: tenantId buried inside
 * a nested object to test recursive detection.
 */
export function makeNestedBodyInjectionEvent(
    authToken: string,
    targetTenantId: string,
): APIGatewayProxyEventV2 {
    return makeEvent({
        method: 'POST',
        path: '/api/data',
        authToken,
        body: {
            name: 'Product',
            metadata: {
                tags: ['test'],
                config: {
                    tenantId: targetTenantId, // Depth 2 nesting
                },
            },
        },
    });
}

/**
 * Build a query param injection event.
 */
export function makeQueryInjectionEvent(
    authToken: string,
    targetTenantId: string,
    paramName: string = 'tenantId',
): APIGatewayProxyEventV2 {
    return makeEvent({
        method: 'GET',
        path: '/api/products',
        authToken,
        queryStringParameters: {
            [paramName]: targetTenantId,
        },
    });
}

/**
 * Build a path param injection event.
 */
export function makePathInjectionEvent(
    authToken: string,
    targetTenantId: string,
): APIGatewayProxyEventV2 {
    return makeEvent({
        method: 'GET',
        path: `/tenants/${targetTenantId}`,
        authToken,
        pathParameters: {
            tenantId: targetTenantId,
        },
    });
}

// ── Response Helpers ─────────────────────────────────────────────────────────

/**
 * Parse a Lambda response body safely.
 */
export function parseResponseBody(result: any): any {
    if (!result) return null;
    const body = typeof result === 'object' ? result.body : result;
    if (!body) return null;
    try {
        return JSON.parse(body);
    } catch {
        return body;
    }
}

/**
 * Assert that a response indicates a blocked cross-tenant attempt.
 */
export function expectBlocked(result: any): void {
    const statusCode = result?.statusCode;
    if (statusCode !== 401 && statusCode !== 403 && statusCode !== 404) {
        const body = parseResponseBody(result);
        throw new Error(
            `Expected blocked (401/403/404) but got ${statusCode}: ${JSON.stringify(body)}`,
        );
    }
}

/**
 * Assert a successful response.
 */
export function expectSuccess(result: any): void {
    const statusCode = result?.statusCode;
    if (statusCode < 200 || statusCode >= 300) {
        const body = parseResponseBody(result);
        throw new Error(
            `Expected success (2xx) but got ${statusCode}: ${JSON.stringify(body)}`,
        );
    }
}
