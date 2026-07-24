/**
 * Permissions Tests — MobileShop Permission System
 *
 * Verifies:
 * - expandPermissions: manage implies view
 * - migratePermissions: owner role gets all permissions
 * - migratePermissions: staff role gets limited permissions
 * - migratePermissions is idempotent (running twice = same result)
 * - checkMobileShopPermission: wrong business type → denied
 * - checkMobileShopPermission: missing permission → denied with reason
 *
 * Requirements: 6.5–6.6, 6.19, 8.3–8.10, 13.1, 13.6
 */

import {
  MOBILE_SHOP_PERMISSIONS,
  expandPermissions,
} from '../mobile-shop-permissions';
import {
  migratePermissions,
  ROLE_PERMISSION_MAP,
} from '../compatibility-matrix';
import {
  checkMobileShopPermission,
  type PermissionContext,
} from '../permission-checker';

// ─── expandPermissions Tests ────────────────────────────────────────────────

describe('expandPermissions', () => {
  it('manage implies view for SERVICE', () => {
    const granted = new Set([MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE]);
    const expanded = expandPermissions(granted);

    expect(expanded.has(MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE)).toBe(true);
    expect(expanded.has(MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW)).toBe(true);
  });

  it('manage implies view for IMEI', () => {
    const granted = new Set([MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE]);
    const expanded = expandPermissions(granted);

    expect(expanded.has(MOBILE_SHOP_PERMISSIONS.IMEI_VIEW)).toBe(true);
  });

  it('manage implies view for EXCHANGE', () => {
    const granted = new Set([MOBILE_SHOP_PERMISSIONS.EXCHANGE_MANAGE]);
    const expanded = expandPermissions(granted);

    expect(expanded.has(MOBILE_SHOP_PERMISSIONS.EXCHANGE_VIEW)).toBe(true);
  });

  it('manage implies view for WARRANTY', () => {
    const granted = new Set([MOBILE_SHOP_PERMISSIONS.WARRANTY_MANAGE]);
    const expanded = expandPermissions(granted);

    expect(expanded.has(MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW)).toBe(true);
  });

  it('manage implies view for SETTINGS', () => {
    const granted = new Set([MOBILE_SHOP_PERMISSIONS.SETTINGS_MANAGE]);
    const expanded = expandPermissions(granted);

    expect(expanded.has(MOBILE_SHOP_PERMISSIONS.SETTINGS_VIEW)).toBe(true);
  });

  it('REPORTS_EXPORT implies REPORTS_VIEW', () => {
    const granted = new Set([MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT]);
    const expanded = expandPermissions(granted);

    expect(expanded.has(MOBILE_SHOP_PERMISSIONS.REPORTS_VIEW)).toBe(true);
  });

  it('view-only does not gain manage', () => {
    const granted = new Set([MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW]);
    const expanded = expandPermissions(granted);

    expect(expanded.has(MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE)).toBe(false);
  });

  it('empty set stays empty', () => {
    const expanded = expandPermissions(new Set());
    expect(expanded.size).toBe(0);
  });
});

// ─── migratePermissions Tests ───────────────────────────────────────────────

describe('migratePermissions', () => {
  it('owner role gets all defined permissions', () => {
    const result = migratePermissions({
      currentPermissions: [],
      role: 'owner',
      capabilities: [],
    });

    // Owner should get every permission in the ROLE_PERMISSION_MAP
    const expected = ROLE_PERMISSION_MAP['owner'];
    for (const perm of expected) {
      expect(result.permissions).toContain(perm);
    }
    expect(result.changed).toBe(true);
  });

  it('staff role gets limited permissions', () => {
    const result = migratePermissions({
      currentPermissions: [],
      role: 'staff',
      capabilities: [],
    });

    // Staff gets SERVICE_VIEW, IMEI_VIEW, WARRANTY_VIEW only
    expect(result.permissions).toContain(MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW);
    expect(result.permissions).toContain(MOBILE_SHOP_PERMISSIONS.IMEI_VIEW);
    expect(result.permissions).toContain(MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW);

    // Staff should NOT have manage/export permissions
    expect(result.permissions).not.toContain(MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE);
    expect(result.permissions).not.toContain(MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE);
    expect(result.permissions).not.toContain(MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT);
    expect(result.permissions).not.toContain(MOBILE_SHOP_PERMISSIONS.SETTINGS_MANAGE);
    expect(result.permissions).not.toContain(MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE);
  });

  it('is idempotent: running twice produces the same result', () => {
    const firstPass = migratePermissions({
      currentPermissions: [],
      role: 'manager',
      capabilities: ['useIMEI'],
    });

    const secondPass = migratePermissions({
      currentPermissions: firstPass.permissions,
      role: 'manager',
      capabilities: ['useIMEI'],
    });

    // Same permission set
    expect(secondPass.permissions).toEqual(firstPass.permissions);
    // No changes on second pass
    expect(secondPass.changed).toBe(false);
    expect(secondPass.added).toHaveLength(0);
  });

  it('adds capability-based permissions additively', () => {
    const result = migratePermissions({
      currentPermissions: [],
      role: 'staff',
      capabilities: ['useWarranty'],
    });

    // Staff + useWarranty → also gets WARRANTY_MANAGE
    expect(result.permissions).toContain(MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW);
    expect(result.permissions).toContain(MOBILE_SHOP_PERMISSIONS.WARRANTY_MANAGE);
  });
});

// ─── checkMobileShopPermission Tests ────────────────────────────────────────

describe('checkMobileShopPermission', () => {
  it('denies when business type is not mobile_shop', () => {
    const context: PermissionContext = {
      tenantId: 'tenant-001',
      businessType: 'grocery',
      permissions: [MOBILE_SHOP_PERMISSIONS.IMEI_VIEW],
    };

    const result = checkMobileShopPermission(
      context,
      MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    );

    expect(result.granted).toBe(false);
    expect(result.reason).toContain('Business type is not mobile_shop');
  });

  it('denies with reason when permission is missing', () => {
    const context: PermissionContext = {
      tenantId: 'tenant-001',
      businessType: 'mobile_shop',
      permissions: [MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW],
    };

    const result = checkMobileShopPermission(
      context,
      MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE,
    );

    expect(result.granted).toBe(false);
    expect(result.reason).toBeDefined();
    expect(result.reason).toContain('Missing required permission');
  });

  it('grants when permission is directly present', () => {
    const context: PermissionContext = {
      tenantId: 'tenant-001',
      businessType: 'mobile_shop',
      permissions: [MOBILE_SHOP_PERMISSIONS.IMEI_VIEW],
    };

    const result = checkMobileShopPermission(
      context,
      MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    );

    expect(result.granted).toBe(true);
    expect(result.reason).toBeUndefined();
  });

  it('grants view permission when manage is present (implication)', () => {
    const context: PermissionContext = {
      tenantId: 'tenant-001',
      businessType: 'mobile_shop',
      permissions: [MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE],
    };

    const result = checkMobileShopPermission(
      context,
      MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    );

    expect(result.granted).toBe(true);
  });
});
