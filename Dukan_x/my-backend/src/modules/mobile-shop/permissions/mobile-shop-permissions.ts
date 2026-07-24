/**
 * MobileShop Permissions — Authoritative Permission Constants
 *
 * Defines all dedicated MobileShop permissions following the
 * `{domain}:{resource}:{action}` naming convention.
 *
 * Rules:
 * - `view` grants read access
 * - `manage` grants write access and implies `view`
 * - `export` is separate from `view` (requires explicit grant)
 *
 * Requirements: 8.1–8.2, 8.5–8.7, 8.13
 */

// ─── Permission Constants ────────────────────────────────────────────────────

export const MOBILE_SHOP_PERMISSIONS = {
  // Service / Repair
  SERVICE_VIEW: 'mobile_shop:service:view',
  SERVICE_MANAGE: 'mobile_shop:service:manage',

  // IMEI / Device inventory
  IMEI_VIEW: 'mobile_shop:imei:view',
  IMEI_MANAGE: 'mobile_shop:imei:manage',

  // Exchange
  EXCHANGE_VIEW: 'mobile_shop:exchange:view',
  EXCHANGE_MANAGE: 'mobile_shop:exchange:manage',

  // Warranty
  WARRANTY_VIEW: 'mobile_shop:warranty:view',
  WARRANTY_MANAGE: 'mobile_shop:warranty:manage',

  // Second-hand intake
  SECOND_HAND_VIEW: 'mobile_shop:second_hand:view',
  SECOND_HAND_MANAGE: 'mobile_shop:second_hand:manage',

  // Finance / EMI
  FINANCE_VIEW: 'mobile_shop:finance:view',
  FINANCE_MANAGE: 'mobile_shop:finance:manage',

  // Reports
  REPORTS_VIEW: 'mobile_shop:reports:view',
  REPORTS_EXPORT: 'mobile_shop:reports:export',

  // Settings
  SETTINGS_VIEW: 'mobile_shop:settings:view',
  SETTINGS_MANAGE: 'mobile_shop:settings:manage',

  // Audit (read-only for application workloads)
  AUDIT_VIEW: 'mobile_shop:audit:view',
} as const;

export type MobileShopPermission =
  (typeof MOBILE_SHOP_PERMISSIONS)[keyof typeof MOBILE_SHOP_PERMISSIONS];

/**
 * All defined permission strings as a readonly array.
 * Useful for validation and iteration.
 */
export const ALL_MOBILE_SHOP_PERMISSIONS: readonly MobileShopPermission[] =
  Object.values(MOBILE_SHOP_PERMISSIONS);

// ─── Manage-Implies-View Relationships ───────────────────────────────────────

/**
 * Maps each `manage` permission to the `view` permission it implies.
 * `reports:export` implies `reports:view`.
 */
export const PERMISSION_IMPLICATIONS: ReadonlyMap<MobileShopPermission, MobileShopPermission> =
  new Map([
    [MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE, MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW],
    [MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE, MOBILE_SHOP_PERMISSIONS.IMEI_VIEW],
    [MOBILE_SHOP_PERMISSIONS.EXCHANGE_MANAGE, MOBILE_SHOP_PERMISSIONS.EXCHANGE_VIEW],
    [MOBILE_SHOP_PERMISSIONS.WARRANTY_MANAGE, MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW],
    [MOBILE_SHOP_PERMISSIONS.SECOND_HAND_MANAGE, MOBILE_SHOP_PERMISSIONS.SECOND_HAND_VIEW],
    [MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE, MOBILE_SHOP_PERMISSIONS.FINANCE_VIEW],
    [MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT, MOBILE_SHOP_PERMISSIONS.REPORTS_VIEW],
    [MOBILE_SHOP_PERMISSIONS.SETTINGS_MANAGE, MOBILE_SHOP_PERMISSIONS.SETTINGS_VIEW],
  ]);

/**
 * Returns the full effective permission set including implied permissions.
 * For example, if the input contains `mobile_shop:service:manage`, the output
 * will also include `mobile_shop:service:view`.
 */
export function expandPermissions(granted: ReadonlySet<string>): Set<string> {
  const expanded = new Set(granted);
  for (const [manage, view] of PERMISSION_IMPLICATIONS) {
    if (expanded.has(manage)) {
      expanded.add(view);
    }
  }
  return expanded;
}
