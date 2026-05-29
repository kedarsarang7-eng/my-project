// ============================================================================
// Internal Service-to-Service Authentication Middleware
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import * as context from '../utils/context';
import { randomUUID, timingSafeEqual } from 'crypto';
import { config } from '../config/environment';

// FATAL: Missing INTERNAL_API_SECRET causes boot validation failure in environment.ts Zod schema (min 32 chars)
const INTERNAL_API_SECRET: string = config.secrets.internalApiSecret;

export interface InternalAuthContext {
    tenantId: string;
    customerId?: string;
    requestSource: string;
}

export type InternalHandlerFn = (
    event: APIGatewayProxyEventV2,
    lambdaContext: Context,
    auth: InternalAuthContext
) => Promise<APIGatewayProxyResultV2>;

export function internalHandler(handlerFn: InternalHandlerFn) {
    return async (
        event: APIGatewayProxyEventV2,
        lambdaContext: Context
    ): Promise<APIGatewayProxyResultV2> => {
        const correlationId = event.headers?.['x-correlation-id'] || randomUUID();

        try {
            // 1. Verify Internal Secret
            // FIX (H-1): Use constant-time comparison to prevent timing attacks.
            // The old `!==` leaked timing information — an attacker could measure
            // response times to iteratively discover correct secret bytes.
            const providedSecret = event.headers?.['x-internal-secret'];
            if (!providedSecret || !isTimingSafeEqual(providedSecret, INTERNAL_API_SECRET)) {
                logger.warn('Unauthorized internal API access attempt', {
                    path: event.rawPath,
                    ip: event.requestContext?.http?.sourceIp,
                    correlationId
                });
                return response.error(401, 'UNAUTHORIZED', 'Invalid internal authorization');
            }

            // 2. Extract Tenant Context
            const tenantId = event.headers?.['x-tenant-id'];
            if (!tenantId) {
                return response.badRequest('Missing x-tenant-id header');
            }

            const customerId = event.headers?.['x-customer-id'];
            const requestSource = event.headers?.['x-source'] ?? 'unknown';

            const authContext: InternalAuthContext = {
                tenantId,
                customerId,
                requestSource
            };

            // 3. Initialize AsyncLocalStorage Context (Crucial for DB RLS)
            return await context.runWithContext(
                {
                    tenantId,
                    correlationId,
                    userId: customerId ?? 'system',
                },
                async () => {
                    const result = await handlerFn(event, lambdaContext, authContext);

                    // Add correlation header
                    if (typeof result === 'object' && result !== null) {
                        const headers = (result as any).headers || {};
                        (result as any).headers = {
                            ...headers,
                            'X-Correlation-Id': correlationId,
                            'X-Internal-Ok': 'true'
                        };
                    }

                    return result;
                }
            );
        } catch (error: any) {
            logger.error('Internal Handler Error', {
                error: error.message,
                stack: error.stack,
                path: event.rawPath,
                correlationId
            });
            return response.internalError();
        }
    };
}

// FIX (H-1): Length-safe constant-time string comparison.
// Pads the shorter string to prevent length-leak side-channel attacks.
// Without this, an attacker could determine the secret length from timing.
function isTimingSafeEqual(a: string, b: string): boolean {
    const maxLen = Math.max(a.length, b.length);
    const bufA = Buffer.alloc(maxLen, 0);
    const bufB = Buffer.alloc(maxLen, 0);
    Buffer.from(a).copy(bufA);
    Buffer.from(b).copy(bufB);
    return timingSafeEqual(bufA, bufB) && a.length === b.length;
}
