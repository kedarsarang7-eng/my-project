/**
 * MobileShop Middleware — Barrel Export
 *
 * Requirements: 6.4–6.6, 6.19, 8.3–8.10, 12.3
 */

// Correlation ID
export {
  extractCorrelationId,
  generateCorrelationId,
  CORRELATION_HEADER,
} from './correlation';

// TenantContext
export {
  type TenantContext,
  TenantContextError,
  resolveTenantContext,
} from './tenant-context';

// Authorization middleware
export {
  mobileShopHandler,
  parseSanitizedBody,
  type MobileShopHandlerFn,
  type MobileShopMiddlewareOptions,
} from './auth-middleware';

// Route guards
export {
  routeGuard,
  routeGuardAny,
  type RouteGuard,
  type GuardResult,
} from './route-guard';
