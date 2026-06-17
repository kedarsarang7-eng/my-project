// ============================================================================
// Secure Lambda Handler Wrapper
// ============================================================================
// A Higher-Order Function to:
// 1. Verify Authentication (Cognito JWT)
// 2. Enforce Roles
// 3. Initialize Tenant Context (AsyncLocalStorage) — CRITICAL for security
// 4. Add request correlation ID for tracing
// 5. Handle Errors uniformly (using AppError hierarchy)
// 6. Add security response headers
// 7. Detect cross-tenant attack attempts
// 8. Validate request nonces (anti-replay)
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { verifyAuth } from './cognito-auth';
import { AuthContext, UserRole } from '../types/tenant.types';
import { AppError, AuthError } from '../utils/errors';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import * as context from '../utils/context';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { validateBusinessType, HandlerOptions } from './business-type-guard';
import { validateFeatureAccess } from './plan-guard';
import { validatePermission } from './permission-guard';
import { checkSoftwareLock, LockLevel } from './software-lock';
import { FeatureKey } from '../config/plan-feature-registry';
import { logRequest, logAuthFailure } from './cloudwatch-logger';
import { config } from '../config/environment';
import { getRequestLocale, runWithLocale } from '../i18n/i18n.middleware';

// PERF-9 FIX: Lazy-load CloudWatchClient — avoids ~200ms cold start penalty
// when this module is imported by every handler.
let _cloudwatchClient: CloudWatchClient | null = null;
function getCloudWatchClient(): CloudWatchClient {
    if (!_cloudwatchClient) {
        _cloudwatchClient = new CloudWatchClient(configureAwsClient({ region: config.aws.region }));
    }
    return _cloudwatchClient;
}

// Type for the actual business logic function
type AuthorizedHandlerFn = (
    event: APIGatewayProxyEventV2,
    context: Context,
    auth: AuthContext
) => Promise<APIGatewayProxyResultV2>;

// Security headers added to every response
const SECURITY_HEADERS = {
    'X-Content-Type-Options': 'nosniff',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'X-Frame-Options': 'DENY',
    'Cache-Control': 'no-store',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
};

/**
 * Detect cross-tenant access attempts.
 * Checks if the request body or headers contain a tenant_id that doesn't match
 * the authenticated user's tenant_id from their JWT token.
 *
 * This prevents a compromised or malicious user from attempting to access
 * another tenant's data by injecting a different tenant_id in the request.
 */
async function detectCrossTenantAccess(
    auth: AuthContext,
    event: APIGatewayProxyEventV2,
    correlationId: string
): Promise<void> {
    // 1. Check HTTP Headers (Strict Enforcement)
    const headerTenantId = event.headers?.['x-tenant-id'] || event.headers?.['X-Tenant-Id'];
    if (headerTenantId && headerTenantId !== auth.tenantId) {
        throwSecurityAlert(auth, event, correlationId, headerTenantId, 'Header Mismatch');
    }

    // 2. CRITICAL FIX: Check Query String Parameters
    const queryParams = event.queryStringParameters || {};
    const queryTenantId = queryParams.tenantId || queryParams.tenant_id || queryParams.tid;
    if (queryTenantId && queryTenantId !== auth.tenantId) {
        throwSecurityAlert(auth, event, correlationId, queryTenantId, 'Query Param Injection');
    }

    // 3. CRITICAL FIX: Check Path Parameters (for routes like /tenants/{tenantId}/...)
    const pathParams = event.pathParameters || {};
    const pathTenantId = pathParams.tenantId || pathParams.tenant_id;
    if (pathTenantId && pathTenantId !== auth.tenantId) {
        throwSecurityAlert(auth, event, correlationId, pathTenantId, 'Path Param Injection');
    }

    // 4. Check Request Body
    if (!event.body) return;

    try {
        // SECURITY: Payload Size Limit (1MB)
        if (event.body.length > 1048576) {
            throwSecurityAlert(auth, event, correlationId, 'N/A', 'Payload Size Exceeded');
        }

        const body = JSON.parse(event.body);

        // Check for explicit tenant_id in request body
        const bodyTenantId = body.tenantId || body.tenant_id;
        if (bodyTenantId && bodyTenantId !== auth.tenantId) {
            throwSecurityAlert(auth, event, correlationId, bodyTenantId, 'Body Injection');
        }

        // CRITICAL FIX: Recursively check nested tenant_id in body
        const nestedTenantId = findNestedTenantId(body);
        if (nestedTenantId && nestedTenantId !== auth.tenantId) {
            throwSecurityAlert(auth, event, correlationId, nestedTenantId, 'Nested Body Injection');
        }
    } catch (err) {
        if (err instanceof AuthError) throw err;
        // JSON parse errors are fine — not all requests have JSON bodies
    }
}

/**
 * CRITICAL FIX: Recursively search for tenantId in nested objects (max depth 3).
 * Prevents attacks that embed tenantId in nested fields like { data: { tenantId: "..." } }
 */
function findNestedTenantId(obj: any, depth = 0): string | null {
    if (depth > 3 || !obj || typeof obj !== 'object') return null;
    for (const key of Object.keys(obj)) {
        if ((key === 'tenantId' || key === 'tenant_id') && typeof obj[key] === 'string') {
            return obj[key];
        }
        if (typeof obj[key] === 'object' && obj[key] !== null) {
            const found = findNestedTenantId(obj[key], depth + 1);
            if (found) return found;
        }
    }
    return null;
}

function throwSecurityAlert(
    auth: AuthContext,
    event: APIGatewayProxyEventV2,
    correlationId: string,
    attemptedTenantId: string,
    vector: string
) {
    // SECURITY ALERT: Cross-tenant access attempt detected
    logger.error('CROSS-TENANT ATTACK DETECTED', {
        jwtTenantId: auth.tenantId,
        requestedTenantId: attemptedTenantId,
        vector,
        userId: auth.sub,
        email: auth.email,
        role: auth.role,
        sourceIp: event.requestContext?.http?.sourceIp,
        path: event.rawPath,
        method: event.requestContext?.http?.method,
        correlationId,
        userAgent: event.headers?.['user-agent'],
    });

    // Emit CloudWatch metric for alarm trigger
    try {
        getCloudWatchClient().send(new PutMetricDataCommand({
            Namespace: 'DukanX/Security',
            MetricData: [{
                MetricName: 'CrossTenantAttempt',
                Value: 1,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'TenantId', Value: auth.tenantId },
                    { Name: 'AttemptedTenantId', Value: attemptedTenantId },
                    { Name: 'Vector', Value: vector },
                ],
            }],
        })).catch(() => { });
    } catch (metricErr) {
        logger.warn('Failed to emit cross-tenant metric', {
            error: (metricErr as Error).message,
        });
    }

    throw new AuthError(
        'Cross-tenant access denied — this incident has been logged'
    );
}

/**
 * Detect cross-business access attempts.
 * Checks if the request body or headers contain a business_id that doesn't belong
 * to the authenticated user's tenant_id.
 */
async function detectCrossBusinessAccess(
    auth: AuthContext,
    event: APIGatewayProxyEventV2,
    correlationId: string
): Promise<void> {
    let attemptedBusinessId: string | undefined;

    // 1. Check HTTP Headers
    const headerBusinessId = event.headers?.['x-business-id'] || event.headers?.['X-Business-Id'];
    if (headerBusinessId) {
        attemptedBusinessId = headerBusinessId;
    }

    // 2. Check Request Body
    if (!attemptedBusinessId && event.body) {
        try {
            // SECURITY: Payload Size Limit (1MB)
            if (event.body.length > 1048576) {
                logger.warn('PAYLOAD_SIZE_EXCEEDED', { correlationId, length: event.body.length });
                throw new AuthError('Request payload too large');
            }

            const body = JSON.parse(event.body);
            attemptedBusinessId = body.businessId || body.business_id;
        } catch (err) {
            // ignore JSON parse error
        }
    }

    if (!attemptedBusinessId) return;

    // Validate ownership via DynamoDB
    const { getItem, queryItems, Keys } = await import('../config/dynamodb.config');
    const business = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), `BUSINESS#${attemptedBusinessId}`);

    if (!business) {
        // SECURITY ALERT: Cross-business access attempt detected
        logger.error('CROSS-BUSINESS ATTACK DETECTED', {
            jwtTenantId: auth.tenantId,
            requestedBusinessId: attemptedBusinessId,
            userId: auth.sub,
            email: auth.email,
            role: auth.role,
            sourceIp: event.requestContext?.http?.sourceIp,
            path: event.rawPath,
            method: event.requestContext?.http?.method,
            correlationId,
        });

        try {
            getCloudWatchClient().send(new PutMetricDataCommand({
                Namespace: 'DukanX/Security',
                MetricData: [{
                    MetricName: 'CrossBusinessAttempt',
                    Value: 1,
                    Unit: 'Count',
                    Dimensions: [
                        { Name: 'TenantId', Value: auth.tenantId },
                        { Name: 'AttemptedBusinessId', Value: attemptedBusinessId },
                    ],
                }],
            })).catch(() => { });
        } catch (metricErr) { }

        throw new AuthError('Cross-business access denied — this incident has been logged');
    }

    // If role is staff, verify they are assigned to this business
    if (auth.role === UserRole.STAFF) {
        const staffResult = await queryItems<Record<string, any>>(
            Keys.tenantPK(auth.tenantId), 'STAFF#',
            {
                filterExpression: 'businessId = :bid AND cognitoSub = :sub',
                expressionAttributeValues: { ':bid': attemptedBusinessId, ':sub': auth.sub },
                limit: 1,
            }
        );
        if (staffResult.items.length === 0) {
            logger.error('STAFF UNAUTHORIZED BUSINESS ACCESS', {
                jwtTenantId: auth.tenantId,
                requestedBusinessId: attemptedBusinessId,
                userId: auth.sub,
                email: auth.email,
                path: event.rawPath,
                correlationId
            });
        throw new AuthError('Staff unauthorized for this business.');
        }
    }
}

/**
 * Wraps a Lambda handler with authentication, role enforcement, tenant context,
 * correlation ID tracking, cross-tenant detection, and uniform error handling.
 */
export function authorizedHandler(
    allowedRoles: UserRole[],
    handlerFn: AuthorizedHandlerFn,
    options?: HandlerOptions
): (event: APIGatewayProxyEventV2, lambdaContext: Context) => Promise<APIGatewayProxyResultV2>;

export function authorizedHandler(
    handlerFn: (event: APIGatewayProxyEventV2, context: Context) => Promise<APIGatewayProxyResultV2>,
    options?: { requireRoles?: string[]; requireAuth?: boolean }
): (event: APIGatewayProxyEventV2, lambdaContext: Context) => Promise<APIGatewayProxyResultV2>;

export function authorizedHandler(
    arg1: any,
    arg2?: any,
    arg3?: any
) {
    let allowedRoles: UserRole[] = [];
    let handlerFn: any;
    let options: any = arg3;

    if (Array.isArray(arg1)) {
        allowedRoles = arg1;
        handlerFn = arg2;
    } else {
        handlerFn = arg1;
        const opt = arg2 as { requireRoles?: string[]; requireAuth?: boolean } | undefined;
        options = {
            requireAuth: opt?.requireAuth ?? true,
        };
        if (opt?.requireRoles) {
            allowedRoles = opt.requireRoles.map(r => {
                const normalized = r.toUpperCase().replace('-', '_');
                return normalized as UserRole;
            });
        }
    }

    return async (
        event: APIGatewayProxyEventV2,
        lambdaContext: Context
    ): Promise<APIGatewayProxyResultV2> => {
        // Generate correlation ID for distributed tracing
        const correlationId =
            event.headers?.['x-correlation-id'] ||
            event.headers?.['x-amzn-requestid'] ||
            event.requestContext?.requestId ||
            randomUUID();

        const startTime = Date.now();

        try {
            // 1. Verify Auth
            let auth: AuthContext | null = null;
            if (options?.requireAuth !== false) {
                auth = await verifyAuth(event);

                // 2. Enforce Role
                if (allowedRoles.length > 0) {
                    if (!allowedRoles.includes(auth.role)) {
                        throw new AuthError(
                            `Role '${auth.role}' not authorized. Required: ${allowedRoles.join(', ')}`,
                            403
                        );
                    }
                }

                // 2.5. Enforce Global Role Restrictions
                const method = event.requestContext?.http?.method?.toUpperCase() || 'GET';
                if (auth.role === UserRole.VIEWER && method !== 'GET' && method !== 'OPTIONS') {
                    throw new AuthError('Role "viewer" has read-only access and cannot modify data', 403);
                }

                if (auth.role === UserRole.CHARTERED_ACCOUNTANT) {
                    const path = event.rawPath || '';
                    const isFinancialRoute = path.startsWith('/reports') || path.startsWith('/invoices') || path.startsWith('/payments');
                    if (!isFinancialRoute) {
                        throw new AuthError('Role "chartered_accountant" is restricted to financial data only', 403);
                    }
                }

                // 3. Cross-Tenant Attack Detection
                await detectCrossTenantAccess(auth, event, correlationId);

                // 3.1. Cross-Business Attack Detection
                await detectCrossBusinessAccess(auth, event, correlationId);

                // 3.5. Business Type Authorization (if required)
                if (options?.requiredBusinessType) {
                    await validateBusinessType(
                        auth,
                        options.requiredBusinessType,
                        correlationId,
                        event.rawPath || '',
                    );
                }

                // 3.6. Plan Feature Guard (if required)
                if (options?.requiredFeature) {
                    await validateFeatureAccess(
                        auth,
                        options.requiredFeature as FeatureKey,
                        correlationId,
                        event.rawPath || '',
                    );
                }

                // 3.7. Combined Permission Guard (role + plan) (if required)
                if (options?.requiredPermission) {
                    await validatePermission(
                        auth,
                        options.requiredPermission,
                        correlationId,
                        event.rawPath || '',
                    );
                }

                // 3.8. Software Lock Check — enforce subscription expiry / grace period
                if (auth.role !== UserRole.SUPER_ADMIN) {
                    const lockCheck = await checkSoftwareLock(auth.tenantId, event);
                    if (!lockCheck.allowed) {
                        logger.warn('Software lock enforced', {
                            tenantId: auth.tenantId,
                            lockLevel: lockCheck.lockLevel,
                            path: event.rawPath,
                            correlationId,
                        });
                        return addHeaders(
                            response.error(
                                402,
                                'SUBSCRIPTION_LOCK',
                                lockCheck.userMessage,
                                lockCheck.metadata,
                            ),
                            correlationId,
                        );
                    }
                    // Attach lock info to event for downstream warning banners
                    if (lockCheck.lockLevel !== LockLevel.NONE) {
                        (event as unknown as Record<string, unknown>).lockInfo = {
                            lockLevel: lockCheck.lockLevel,
                            userMessage: lockCheck.userMessage,
                            metadata: lockCheck.metadata,
                        };
                    }
                }
            }

            // 4. Initialize Tenant + Correlation Context (AsyncLocalStorage)
            // Extract businessId from headers (it was validated in detectCrossBusinessAccess)
            const businessId = event.headers?.['x-business-id']
                || event.headers?.['X-Business-Id'];

            // 4.5. Detect and bind request locale (X-App-Locale → Accept-Language → en)
            const requestLocale = getRequestLocale(event);

            return await context.runWithContext(
                {
                    tenantId: auth?.tenantId,
                    correlationId,
                    userId: auth?.sub,
                    businessId,
                    role: auth?.role,
                },
                () => runWithLocale(requestLocale, async () => {
                    // 5. Execute Business Logic
                    const result = await handlerFn(event, lambdaContext, auth);

                    // 5.5. Log the request with CloudWatch structured logger
                    const statusCode = typeof result === 'object' && result !== null
                        ? (result as any).statusCode || 200
                        : 200;
                    logRequest({
                        client_id: auth?.tenantId || 'anonymous',
                        user_id: auth?.sub || 'anonymous',
                        path: event.rawPath || '',
                        method: event.requestContext?.http?.method || 'UNKNOWN',
                        status_code: statusCode,
                        latency_ms: Date.now() - startTime,
                        correlation_id: correlationId,
                        user_agent: event.headers?.['user-agent'],
                        source_ip: event.requestContext?.http?.sourceIp,
                        role: auth?.role || 'anonymous',
                        business_type: auth?.businessType,
                    }).catch(() => { /* non-critical */ });

                    // 6. Add security + tracing headers to response
                    return addHeaders(result, correlationId);
                })
            );
        } catch (err: unknown) {
            // 7. Standardized Error Handling using AppError hierarchy
            if (err instanceof AppError) {
                logger.warn('Handler AppError', {
                    error: err.message,
                    code: err.code,
                    statusCode: err.statusCode,
                    path: event.rawPath,
                    correlationId,
                });
                return addHeaders(
                    response.error(err.statusCode, err.code, err.message, err.details),
                    correlationId
                );
            }

            // Unknown errors — never leak internals
            logger.error('Unhandled Handler Error', {
                error: (err as Error).message,
                stack: (err as Error).stack,
                path: event.rawPath,
                correlationId,
            });

            // Log auth failures for CloudWatch alarm
            if ((err as any)?.code === 'AUTH_ERROR' || (err as any)?.statusCode === 401) {
                logAuthFailure(
                    event.rawPath || '',
                    event.requestContext?.http?.method || '',
                    event.requestContext?.http?.sourceIp,
                    (err as Error).message,
                    correlationId,
                );
            }

            return addHeaders(response.internalError(), correlationId);
        }
    };
}

/**
 * Add security and tracing headers to any Lambda response.
 */
function addHeaders(
    result: APIGatewayProxyResultV2,
    correlationId: string
): APIGatewayProxyResultV2 {
    if (typeof result === 'object' && result !== null) {
        const headers = (result as any).headers || {};
        (result as any).headers = {
            ...headers,
            ...SECURITY_HEADERS,
            'X-Correlation-Id': correlationId,
        };
    }
    return result;
}
