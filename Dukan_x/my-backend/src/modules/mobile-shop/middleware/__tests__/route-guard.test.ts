/**
 * Route Guard Tests — Route-Level Permission Verification
 *
 * Verifies:
 * - Missing context → denied
 * - Empty tenantId → denied
 * - Wrong business type → denied
 * - Missing permission → denied
 * - Has permission → authorized
 * - routeGuardAny: has any one → authorized
 * - routeGuardAny: has none → denied
 * - All denied responses are non-disclosing (no entity details)
 *
 * Requirements: 6.5–6.6, 6.19, 8.3–8.10, 13.1, 13.6
 */

import { routeGuard, routeGuardAny, type GuardResult } from '../route-guard';
import { TenantContext } from '../tenant-context';
import { MOBILE_SHOP_PERMISSIONS } from '../../permissions/mobile-shop-permissions';
import { CANONICAL_BUSINESS_TYPE } from '../../schemas/common.schema';

// ─── Fixtures ───────────────────────────────────────────────────────────────

function makeContext(overrides: Partial<TenantContext> = {}): TenantContext {
  return {
    tenantId: 'tenant-001',
    businessId: 'tenant-001',
    subjectId: 'user-001',
    businessType: CANONICAL_BUSINESS_TYPE,
    permissions: new Set([
      MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
      MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE,
      MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    ]),
    correlationId: 'corr-001',
    ...overrides,
  };
}

/** Extract response body from a denied guard result */
function getDeniedBody(result: GuardResult): Record<string, unknown> {
  const response = result.response as any;
  return JSON.parse(response.body);
}

/** Extract statusCode from a denied guard result */
function getDeniedStatus(result: GuardResult): number {
  return (result.response as any).statusCode;
}

// ─── routeGuard Tests ───────────────────────────────────────────────────────

describe('routeGuard', () => {
  it('denies when context is null/undefined (missing context)', () => {
    const guard = routeGuard([MOBILE_SHOP_PERMISSIONS.IMEI_VIEW]);
    const result = guard.check(null as unknown as TenantContext);

    expect(result.authorized).toBe(false);
    expect(result.response).toBeDefined();
    expect(getDeniedStatus(result)).toBe(403);
  });

  it('denies when tenantId is empty', () => {
    const guard = routeGuard([MOBILE_SHOP_PERMISSIONS.IMEI_VIEW]);
    const ctx = makeContext({ tenantId: '' });
    const result = guard.check(ctx);

    expect(result.authorized).toBe(false);
    expect(getDeniedStatus(result)).toBe(403);
  });

  it('denies when business type is not mobile_shop', () => {
    const guard = routeGuard([MOBILE_SHOP_PERMISSIONS.IMEI_VIEW]);
    const ctx = makeContext({ businessType: 'grocery' as typeof CANONICAL_BUSINESS_TYPE });
    const result = guard.check(ctx);

    expect(result.authorized).toBe(false);
    expect(getDeniedStatus(result)).toBe(403);
  });

  it('denies when required permission is missing', () => {
    const guard = routeGuard([MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE]);
    const ctx = makeContext(); // No FINANCE_MANAGE in fixture
    const result = guard.check(ctx);

    expect(result.authorized).toBe(false);
    expect(getDeniedStatus(result)).toBe(403);
  });

  it('authorizes when all permissions are present', () => {
    const guard = routeGuard([MOBILE_SHOP_PERMISSIONS.IMEI_VIEW]);
    const ctx = makeContext();
    const result = guard.check(ctx);

    expect(result.authorized).toBe(true);
    expect(result.response).toBeUndefined();
  });

  it('authorizes when multiple required permissions are present', () => {
    const guard = routeGuard([
      MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
      MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    ]);
    const ctx = makeContext();
    const result = guard.check(ctx);

    expect(result.authorized).toBe(true);
  });

  it('all denied responses are non-disclosing (no entity details)', () => {
    const guard = routeGuard([MOBILE_SHOP_PERMISSIONS.IMEI_VIEW]);

    // Test multiple denial reasons
    const denials = [
      guard.check(null as unknown as TenantContext),
      guard.check(makeContext({ tenantId: '' })),
      guard.check(makeContext({ businessType: 'electronics' as typeof CANONICAL_BUSINESS_TYPE })),
      guard.check(makeContext({ permissions: new Set() })),
    ];

    for (const result of denials) {
      expect(result.authorized).toBe(false);
      const body = getDeniedBody(result);
      // Non-disclosing: same generic error for all denial types
      expect(body.error).toBe('ACCESS_DENIED');
      expect(body.message).toBe('Access denied');
      // No entity-specific information leaked
      expect(body).not.toHaveProperty('tenantId');
      expect(body).not.toHaveProperty('entityId');
      expect(body).not.toHaveProperty('reason');
      expect(body).not.toHaveProperty('permission');
      expect(body).not.toHaveProperty('businessType');
    }
  });
});

// ─── routeGuardAny Tests ────────────────────────────────────────────────────

describe('routeGuardAny', () => {
  it('authorizes when user has any one of the required permissions', () => {
    const guard = routeGuardAny([
      MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE,
      MOBILE_SHOP_PERMISSIONS.IMEI_VIEW, // user has this one
    ]);
    const ctx = makeContext();
    const result = guard.check(ctx);

    expect(result.authorized).toBe(true);
  });

  it('denies when user has none of the required permissions', () => {
    const guard = routeGuardAny([
      MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE,
      MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT,
      MOBILE_SHOP_PERMISSIONS.SETTINGS_MANAGE,
    ]);
    const ctx = makeContext(); // None of these in fixture
    const result = guard.check(ctx);

    expect(result.authorized).toBe(false);
    expect(getDeniedStatus(result)).toBe(403);
  });

  it('denies when context is missing', () => {
    const guard = routeGuardAny([MOBILE_SHOP_PERMISSIONS.IMEI_VIEW]);
    const result = guard.check(null as unknown as TenantContext);

    expect(result.authorized).toBe(false);
  });

  it('denies when business type is wrong', () => {
    const guard = routeGuardAny([MOBILE_SHOP_PERMISSIONS.IMEI_VIEW]);
    const ctx = makeContext({ businessType: 'pharmacy' as typeof CANONICAL_BUSINESS_TYPE });
    const result = guard.check(ctx);

    expect(result.authorized).toBe(false);
  });

  it('authorizes with empty permission list (no specific permission required)', () => {
    const guard = routeGuardAny([]);
    const ctx = makeContext();
    const result = guard.check(ctx);

    expect(result.authorized).toBe(true);
  });
});
