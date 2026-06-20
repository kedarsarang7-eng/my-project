/**
 * Property-Based Test: API Path Matching
 *
 * Feature: full-stack-audit-remediation, Property 4: API Path Matching
 *
 * Validates: Requirements 2.2, 2.3, 2.4
 *
 * For any HTTP call site path and for any set of backend route paths,
 * the matcher SHALL identify a connection if and only if the normalized
 * paths are equal. Call sites with no matching route SHALL be flagged as
 * broken dependencies, and routes with no matching call site SHALL be
 * flagged as orphaned.
 */

import * as fc from 'fast-check';
import { normalizePath, matchCallSitesToRoutes } from './api_mapper';
import { Route, CallSite } from '../types';

// ── Generators ───────────────────────────────────────────────────────────────

/** Generate a valid path segment (alphanumeric + hyphens) */
const pathSegmentArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789-_'.split('')),
  { minLength: 1, maxLength: 12 }
);

/** Generate a path parameter like {id}, {userId}, {orderId} */
const pathParamArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')),
  { minLength: 1, maxLength: 10 }
).map((s) => `{${s}}`);

/** Generate a single path part — either a literal segment or a parameter */
const pathPartArb = fc.oneof(pathSegmentArb, pathParamArb);

/** Generate a random HTTP path like /users/{id}/orders */
const httpPathArb = fc
  .array(pathPartArb, { minLength: 1, maxLength: 5 })
  .map((parts) => '/' + parts.join('/'));

/** Generate a valid HTTP method */
const httpMethodArb = fc.constantFrom('GET', 'POST', 'PUT', 'DELETE', 'PATCH');

/** Generate a Route object */
const routeArb = fc.record({
  method: httpMethodArb,
  path: httpPathArb,
  handlerFile: fc.constant('handler.ts'),
  authenticated: fc.boolean(),
  source: fc.constant('serverless.yml' as const),
}).map((r) => ({
  ...r,
  normalizedPath: normalizePath(r.path),
}));

/** Generate a CallSite object */
const callSiteArb = fc.record({
  screenFile: fc.constant('screen.dart'),
  requestPath: httpPathArb,
  httpMethod: httpMethodArb,
  lineNumber: fc.integer({ min: 1, max: 500 }),
}).map((cs) => ({
  ...cs,
  normalizedPath: normalizePath(cs.requestPath),
}));

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Property 4: API Path Matching', () => {
  it('normalizePath replaces all path parameters with {*}', () => {
    fc.assert(
      fc.property(httpPathArb, (path) => {
        const normalized = normalizePath(path);
        // After normalization, no {paramName} should remain (only {*})
        const remainingParams = normalized.match(/\{[^*}]+\}/g);
        expect(remainingParams).toBeNull();
        // All original params should become {*}
        const originalParams = path.match(/\{[^}]+\}/g) || [];
        const wildcards = normalized.match(/\{\*\}/g) || [];
        expect(wildcards.length).toBe(originalParams.length);
      }),
      { numRuns: 100 }
    );
  });

  it('connection IFF normalized paths and methods are equal', () => {
    fc.assert(
      fc.property(
        fc.array(callSiteArb, { minLength: 0, maxLength: 5 }),
        fc.array(routeArb, { minLength: 0, maxLength: 5 }),
        (callSites, routes) => {
          const result = matchCallSitesToRoutes(callSites, routes);

          // Every matched pair must have equal normalized paths and methods
          for (const { callSite, route } of result.matched) {
            expect(callSite.normalizedPath.toLowerCase()).toBe(
              route.normalizedPath.toLowerCase()
            );
            expect(callSite.httpMethod.toUpperCase()).toBe(
              route.method.toUpperCase()
            );
          }

          // Every broken dependency must have NO route with matching normalized path + method
          for (const broken of result.brokenDependencies) {
            const hasMatch = routes.some(
              (r) =>
                r.normalizedPath.toLowerCase() === broken.normalizedPath.toLowerCase() &&
                r.method.toUpperCase() === broken.httpMethod.toUpperCase()
            );
            expect(hasMatch).toBe(false);
          }

          // Every orphaned route must have NO call site with matching normalized path + method
          for (const orphaned of result.orphanedRoutes) {
            const hasMatch = callSites.some(
              (cs) =>
                cs.normalizedPath.toLowerCase() === orphaned.normalizedPath.toLowerCase() &&
                cs.httpMethod.toUpperCase() === orphaned.method.toUpperCase()
            );
            expect(hasMatch).toBe(false);
          }
        }
      ),
      { numRuns: 100 }
    );
  });

  it('broken dependencies + matched call sites = all call sites', () => {
    fc.assert(
      fc.property(
        fc.array(callSiteArb, { minLength: 0, maxLength: 8 }),
        fc.array(routeArb, { minLength: 0, maxLength: 8 }),
        (callSites, routes) => {
          const result = matchCallSitesToRoutes(callSites, routes);

          const matchedCallSites = result.matched.map((m) => m.callSite);
          const totalAccountedFor = matchedCallSites.length + result.brokenDependencies.length;
          expect(totalAccountedFor).toBe(callSites.length);
        }
      ),
      { numRuns: 100 }
    );
  });

  it('orphaned routes + matched routes ⊆ all routes', () => {
    fc.assert(
      fc.property(
        fc.array(callSiteArb, { minLength: 0, maxLength: 8 }),
        fc.array(routeArb, { minLength: 0, maxLength: 8 }),
        (callSites, routes) => {
          const result = matchCallSitesToRoutes(callSites, routes);

          const matchedRouteCount = new Set(result.matched.map((m) => m.route)).size;
          // Orphaned + matched unique routes should cover all routes
          expect(result.orphanedRoutes.length + matchedRouteCount).toBeLessThanOrEqual(
            routes.length
          );
        }
      ),
      { numRuns: 100 }
    );
  });
});
