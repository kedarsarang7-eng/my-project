// ============================================================================
// Secure Lambda Handler Wrapper
// ============================================================================
// A Higher-Order Function to:
// 1. Verify Authentication (Cognito JWT)
// 2. Enforce Roles
// 3. Initialize Tenant Context (RLS) — CRITICAL for security
// 4. Handle Errors uniformly
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { verifyAuth, AuthError, requireRole } from './cognito-auth';
import { AuthContext, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import * as context from '../utils/context';

// Type for the actual business logic function
type AuthorizedHandlerFn = (
    event: APIGatewayProxyEventV2,
    context: Context,
    auth: AuthContext
) => Promise<APIGatewayProxyResultV2>;

/**
 * Wraps a Lambda handler with authentication, role enforcement, and tenant context initialization.
 * 
 * Usage:
 * export const handler = authorizedHandler(
 *   [UserRole.OWNER, UserRole.ADMIN], 
 *   async (event, context, auth) => {
 *      // Tenant context is ALREADY set here. Safe to query DB.
 *      return response.success({ message: 'Hello ' + auth.email });
 *   }
 * );
 */
export function authorizedHandler(
    allowedRoles: UserRole[],
    handlerFn: AuthorizedHandlerFn
) {
    return async (
        event: APIGatewayProxyEventV2,
        lambdaContext: Context
    ): Promise<APIGatewayProxyResultV2> => {
        try {
            // 1. Verify Auth
            const auth = await verifyAuth(event);

            // 2. Enforce Role
            if (allowedRoles.length > 0) {
                requireRole(auth, ...allowedRoles);
            }

            // 3. Initialize Tenant Context (AsyncLocalStorage)
            // This allows db.query() to automatically pick up the tenant_id
            return context.runWithContext({ tenantId: auth?.tenantId }, async () => {
                // 4. Execute Business Logic
                return await handlerFn(event, lambdaContext, auth);
            });

        } catch (err: unknown) {
            // 5. Standardized Error Handling
            if (err instanceof AuthError) {
                logger.warn('Auth Error', { error: err.message, path: event.rawPath });
                return response.error(err.statusCode, 'AUTH_ERROR', err.message);
            }

            logger.error('Handler Error', {
                error: (err as Error).message,
                stack: (err as Error).stack,
                path: event.rawPath
            });
            return response.internalError();
        }
    };
}
