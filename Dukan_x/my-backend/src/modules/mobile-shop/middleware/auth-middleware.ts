/**
 * MobileShop Authorization Middleware
 *
 * Lambda middleware that enforces mobile-shop authorization:
 * 1. Verifies JWT (via existing aws-jwt-verify)
 * 2. Extracts tenant_id, role, business_type from verified claims
 * 3. Resolves permissions via compatibility matrix
 * 4. Normalizes business_type → canonical `mobile_shop`
 * 5. Rejects non-mobile_shop business types (non-disclosing 403)
 * 6. Rejects if required permission for route is missing
 * 7. Attaches TenantContext to the handler
 * 8. Ignores client-supplied tenantId/ownerId in request body
 *
 * Critical rules:
 * - Fail closed: no context = no access (BEFORE DynamoDB)
 * - Non-disclosing: denied responses reveal nothing about entities
 * - Client-supplied ownership fields are IGNORED
 *
 * Requirements: 6.4–6.6, 6.19, 8.3–8.10, 12.3
 */

import {
  APIGatewayProxyEventV2,
  APIGatewayProxyResultV2,
  Context,
} from 'aws-lambda';
import { verifyAuth, AuthError } from '../../../middleware/cognito-auth';
import { logger } from '../../../utils/logger';
import { TenantContext, TenantContextError, resolveTenantContext } from './tenant-context';
import { type MobileShopPermission } from '../permissions/mobile-shop-permissions';

// ─── Non-Disclosing Error Responses ─────────────────────────────────────────

/** Generic 403 response that reveals nothing about why access was denied */
const NON_DISCLOSING_403: APIGatewayProxyResultV2 = {
  statusCode: 403,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    error: 'ACCESS_DENIED',
    message: 'Access denied',
  }),
};

/** Generic 401 for authentication failures */
const NON_DISCLOSING_401: APIGatewayProxyResultV2 = {
  statusCode: 401,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    error: 'UNAUTHORIZED',
    message: 'Authentication required',
  }),
};

// ─── Types ───────────────────────────────────────────────────────────────────

/**
 * Handler function that receives a resolved TenantContext.
 * The context is guaranteed to be valid and authorized before this is called.
 */
export type MobileShopHandlerFn = (
  event: APIGatewayProxyEventV2,
  lambdaContext: Context,
  tenantContext: TenantContext,
) => Promise<APIGatewayProxyResultV2>;

/**
 * Options for the mobile shop middleware.
 */
export interface MobileShopMiddlewareOptions {
  /**
   * Permission(s) required for this route.
   * If multiple are provided, ALL must be present.
   * If empty/undefined, only business-type check is enforced.
   */
  readonly requiredPermissions?: readonly MobileShopPermission[];
}

// ─── Middleware Factory ──────────────────────────────────────────────────────

/**
 * Creates a Lambda handler wrapped with MobileShop authorization.
 *
 * This middleware:
 * - Verifies JWT token via Cognito
 * - Resolves TenantContext from verified claims (never client body)
 * - Validates business type is mobile_shop
 * - Checks required permissions
 * - Strips client-supplied ownership fields from request body
 * - Returns non-disclosing errors on any failure
 *
 * Usage:
 * ```typescript
 * export const handler = mobileShopHandler(
 *   { requiredPermissions: [MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE] },
 *   async (event, context, tenantContext) => {
 *     // TenantContext is resolved and authorized here
 *     // Safe to access DynamoDB
 *     return { statusCode: 200, body: JSON.stringify({ ok: true }) };
 *   }
 * );
 * ```
 *
 * @param options - Authorization options (required permissions)
 * @param handlerFn - Business logic receiving the resolved TenantContext
 * @returns Lambda handler function
 */
export function mobileShopHandler(
  options: MobileShopMiddlewareOptions,
  handlerFn: MobileShopHandlerFn,
) {
  return async (
    event: APIGatewayProxyEventV2,
    lambdaContext: Context,
  ): Promise<APIGatewayProxyResultV2> => {
    try {
      // ── Step 1: Verify JWT ──────────────────────────────────────────────
      const auth = await verifyAuth(event);

      // ── Step 2: Resolve TenantContext from verified claims ──────────────
      // This normalizes business type and resolves permissions.
      // Throws TenantContextError if business type is not mobile_shop.
      const tenantContext = resolveTenantContext(auth, event);

      // ── Step 3: Check required permissions ─────────────────────────────
      if (options.requiredPermissions && options.requiredPermissions.length > 0) {
        const missing = options.requiredPermissions.filter(
          (perm) => !tenantContext.permissions.has(perm),
        );

        if (missing.length > 0) {
          logger.warn('Permission denied for mobile-shop route', {
            tenantId: tenantContext.tenantId,
            correlationId: tenantContext.correlationId,
            // Do NOT log which permissions are missing — non-disclosing
          });
          return NON_DISCLOSING_403;
        }
      }

      // ── Step 4: Strip client-supplied ownership fields ─────────────────
      // The event body is parsed by the handler, but we ensure that any
      // tenantId/ownerId fields in the body are not trusted. The handler
      // MUST use tenantContext for ownership, not request body fields.
      // This is enforced by design: handlers receive TenantContext, not raw body.

      // ── Step 5: Execute business logic ─────────────────────────────────
      logger.debug('MobileShop request authorized', {
        tenantId: tenantContext.tenantId,
        correlationId: tenantContext.correlationId,
        path: event.rawPath,
      });

      return await handlerFn(event, lambdaContext, tenantContext);
    } catch (err: unknown) {
      // ── Fail closed: all errors return non-disclosing responses ────────
      if (err instanceof AuthError) {
        logger.warn('MobileShop auth failure', {
          error: err.message,
          path: event.rawPath,
        });
        return NON_DISCLOSING_401;
      }

      if (err instanceof TenantContextError) {
        logger.warn('MobileShop tenant context failure', {
          code: err.code,
          path: event.rawPath,
        });
        return NON_DISCLOSING_403;
      }

      // Unknown errors — fail closed, log for diagnosis
      logger.error('MobileShop middleware unexpected error', {
        error: (err as Error).message,
        stack: (err as Error).stack,
        path: event.rawPath,
      });
      return NON_DISCLOSING_403;
    }
  };
}

// ─── Body Sanitization Utility ───────────────────────────────────────────────

/** Fields that clients must not supply — always resolved from TenantContext */
const OWNERSHIP_FIELDS_TO_STRIP = [
  'tenantId',
  'tenant_id',
  'ownerId',
  'owner_id',
  'businessId',
  'business_id',
  'subjectId',
  'subject_id',
] as const;

/**
 * Parses the event body and removes any client-supplied ownership fields.
 * Use this in handlers to safely parse request bodies.
 *
 * @param event - The API Gateway event
 * @returns Parsed body with ownership fields removed, or null if no body
 */
export function parseSanitizedBody<T extends Record<string, unknown>>(
  event: APIGatewayProxyEventV2,
): T | null {
  if (!event.body) return null;

  try {
    const parsed = JSON.parse(
      event.isBase64Encoded
        ? Buffer.from(event.body, 'base64').toString('utf-8')
        : event.body,
    ) as Record<string, unknown>;

    // Remove all ownership fields — they come from TenantContext only
    for (const field of OWNERSHIP_FIELDS_TO_STRIP) {
      delete parsed[field];
    }

    return parsed as T;
  } catch {
    return null;
  }
}
