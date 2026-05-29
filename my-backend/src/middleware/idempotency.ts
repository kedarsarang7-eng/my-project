// ============================================================================
// Idempotency Middleware — DynamoDB-Backed Request Deduplication
// ============================================================================
// Prevents duplicate processing of write operations (POST, PUT, DELETE).
// Clients send an `X-Idempotency-Key` header; the middleware checks DynamoDB
// for a cached response and returns it if found — skipping handler execution.
//
// Migrated from Redis (removed) to DynamoDB with TTL auto-expiry.
//
// Usage:
//   export const createItem = authorizedHandler([...],
//     withIdempotency(async (event, context, auth) => { ... })
//   );
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { logger } from '../utils/logger';
import { AuthContext } from '../types/tenant.types';
import { Keys, getItem, putItem } from '../config/dynamodb.config';

type HandlerFn = (
    event: APIGatewayProxyEventV2,
    context: Context,
    auth: AuthContext
) => Promise<any>;

const IDEMPOTENCY_TTL_SECONDS = 86_400; // 24 hours
const IDEMPOTENCY_HEADER = 'x-idempotency-key';

/**
 * Wrap a handler with idempotency protection.
 *
 * Flow:
 *   1. Extract `X-Idempotency-Key` from headers
 *   2. If missing → execute handler normally (no idempotency)
 *   3. If present → check DynamoDB for cached response
 *   4. If cached  → return cached response immediately
 *   5. If not     → execute handler, cache response, return
 */
export function withIdempotency(handler: HandlerFn): HandlerFn {
    return async (event, context, auth) => {
        const idempotencyKey =
            event.headers?.[IDEMPOTENCY_HEADER] ||
            event.headers?.['X-Idempotency-Key'];

        // No idempotency key → run handler normally
        if (!idempotencyKey) {
            return handler(event, context, auth);
        }

        // Namespace key by tenant to prevent cross-tenant collisions
        const pk = Keys.idempotencyPK(`${auth.tenantId}:${idempotencyKey}`);
        const sk = Keys.idempotencyMetaSK();

        // 1. Check for cached response in DynamoDB
        try {
            const cached = await getItem<Record<string, any>>(pk, sk);
            if (cached && cached.responseBody) {
                logger.info('Idempotent request — returning cached response', {
                    idempotencyKey,
                    tenantId: auth.tenantId,
                });
                return JSON.parse(cached.responseBody);
            }
        } catch (e) {
            // DynamoDB failure — proceed with handler (fail-open)
            logger.warn('Idempotency cache check failed, proceeding', {
                idempotencyKey,
                error: (e as Error).message,
            });
        }

        // 2. Execute handler
        const response = await handler(event, context, auth);

        // 3. Cache the response in DynamoDB (with TTL for auto-expiry)
        try {
            await putItem(
                {
                    PK: pk,
                    SK: sk,
                    entityType: 'IDEMPOTENCY',
                    tenantId: auth.tenantId,
                    idempotencyKey,
                    responseBody: JSON.stringify(response),
                    createdAt: new Date().toISOString(),
                    TTL: Math.floor(Date.now() / 1000) + IDEMPOTENCY_TTL_SECONDS,
                },
                'attribute_not_exists(PK)', // Only set if NOT exists (first writer wins)
            );
        } catch (e: any) {
            // ConditionalCheckFailed means another request already stored a result
            // — this is fine, we still return our computed response
            if (e.name !== 'ConditionalCheckFailedException') {
                logger.warn('Idempotency cache write failed', {
                    idempotencyKey,
                    error: (e as Error).message,
                });
            }
        }

        return response;
    };
}
