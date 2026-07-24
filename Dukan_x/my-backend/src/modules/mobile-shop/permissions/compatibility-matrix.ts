/**
 * MobileShop Compatibility Matrix — Legacy Role Migration
 *
 * Maps approved legacy roles/capabilities to new MobileShop permissions.
 * This mapping is:
 * - Additive only: never removes existing access
 * - Idempotent: applying multiple times produces the same result
 * - Explicit: each mapping is documented and reviewable
 *
 * The matrix maps legacy `UserRole` values and old capability strings to
 * the corresponding MobileShop permissions. Running migration on a user
 * who already has the target permissions produces no change.
 *
 * Requirements: 8.1–8.2, 8.5–8.7, 8.13
 */

import { MOBILE_SHOP_PERMISSIONS, type MobileShopPermission } from './mobile-shop-permissions';

// ─── Legacy Role Identifiers ─────────────────────────────────────────────────

/**
 * Legacy roles as currently stored in Cognito/membership.
 * These mirror `UserRole` from tenant.types.ts.
 */
export type LegacyRole = 'owner' | 'admin' | 'manager' | 'accountant' | 'cashier' | 'staff';

/**
 * Legacy capabilities that were previously used to gate mobile features.
 * These are the `useXxx` flags from the old system.
 */
export type LegacyCapability =
  | 'useIMEI'
  | 'useWarranty'
  | 'useBuyback'
  | 'useExchange'
  | 'useJobSheets'
  | 'useRepairStatus';

// ─── Role-to-Permission Mapping ──────────────────────────────────────────────

/**
 * Defines which MobileShop permissions each legacy role receives.
 * This is the approved migration path. Roles higher in the hierarchy
 * receive broader access as per existing business expectations.
 *
 * Note: `manageStaff` previously gated service/repair routes (AF-40).
 * The matrix assigns dedicated service permissions instead of reusing
 * a generic staff-management permission.
 */
export const ROLE_PERMISSION_MAP: Readonly<Record<LegacyRole, readonly MobileShopPermission[]>> = {
  owner: [
    MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE,
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_VIEW,
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_MANAGE,
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_VIEW,
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_MANAGE,
    MOBILE_SHOP_PERMISSIONS.FINANCE_VIEW,
    MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.REPORTS_VIEW,
    MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT,
    MOBILE_SHOP_PERMISSIONS.SETTINGS_VIEW,
    MOBILE_SHOP_PERMISSIONS.SETTINGS_MANAGE,
    MOBILE_SHOP_PERMISSIONS.AUDIT_VIEW,
  ],

  admin: [
    MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE,
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_VIEW,
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_MANAGE,
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_VIEW,
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_MANAGE,
    MOBILE_SHOP_PERMISSIONS.FINANCE_VIEW,
    MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.REPORTS_VIEW,
    MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT,
    MOBILE_SHOP_PERMISSIONS.SETTINGS_VIEW,
    MOBILE_SHOP_PERMISSIONS.SETTINGS_MANAGE,
    MOBILE_SHOP_PERMISSIONS.AUDIT_VIEW,
  ],

  manager: [
    MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE,
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_VIEW,
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_MANAGE,
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_VIEW,
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_MANAGE,
    MOBILE_SHOP_PERMISSIONS.FINANCE_VIEW,
    MOBILE_SHOP_PERMISSIONS.REPORTS_VIEW,
    MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT,
    MOBILE_SHOP_PERMISSIONS.SETTINGS_VIEW,
    MOBILE_SHOP_PERMISSIONS.AUDIT_VIEW,
  ],

  accountant: [
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    MOBILE_SHOP_PERMISSIONS.FINANCE_VIEW,
    MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE,
    MOBILE_SHOP_PERMISSIONS.REPORTS_VIEW,
    MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT,
    MOBILE_SHOP_PERMISSIONS.SETTINGS_VIEW,
  ],

  cashier: [
    MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_VIEW,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW,
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_VIEW,
    MOBILE_SHOP_PERMISSIONS.FINANCE_VIEW,
  ],

  staff: [
    MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW,
  ],
};

// ─── Capability-to-Permission Mapping ────────────────────────────────────────

/**
 * Maps legacy capabilities to the MobileShop permissions they grant.
 * This provides backward-compatibility: tenants with old `useXxx` flags
 * gain equivalent new permissions without broadening access.
 */
export const CAPABILITY_PERMISSION_MAP: Readonly<Record<LegacyCapability, readonly MobileShopPermission[]>> = {
  useIMEI: [
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE,
  ],
  useWarranty: [
    MOBILE_SHOP_PERMISSIONS.WARRANTY_VIEW,
    MOBILE_SHOP_PERMISSIONS.WARRANTY_MANAGE,
  ],
  useBuyback: [
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_VIEW,
    MOBILE_SHOP_PERMISSIONS.SECOND_HAND_MANAGE,
  ],
  useExchange: [
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_VIEW,
    MOBILE_SHOP_PERMISSIONS.EXCHANGE_MANAGE,
  ],
  useJobSheets: [
    MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE,
  ],
  useRepairStatus: [
    MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
  ],
};

// ─── Legacy Permission Mapping ───────────────────────────────────────────────

/**
 * Maps old generic permission strings to MobileShop equivalents.
 * This specifically addresses AF-40 where `manageStaff` was used
 * to gate service/repair routes.
 */
export const LEGACY_PERMISSION_MAP: Readonly<Record<string, readonly MobileShopPermission[]>> = {
  manage_staff: [
    MOBILE_SHOP_PERMISSIONS.SERVICE_VIEW,
    MOBILE_SHOP_PERMISSIONS.SERVICE_MANAGE,
  ],
  view_invoices: [
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
  ],
  create_invoices: [
    MOBILE_SHOP_PERMISSIONS.IMEI_VIEW,
    MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE,
  ],
  view_reports: [
    MOBILE_SHOP_PERMISSIONS.REPORTS_VIEW,
  ],
  export_reports: [
    MOBILE_SHOP_PERMISSIONS.REPORTS_VIEW,
    MOBILE_SHOP_PERMISSIONS.REPORTS_EXPORT,
  ],
};

// ─── Idempotent Migration Function ──────────────────────────────────────────

export interface MigrationInput {
  /** Current permissions already assigned to the user */
  readonly currentPermissions: readonly string[];
  /** User's legacy role */
  readonly role: LegacyRole;
  /** Legacy capabilities enabled for the tenant */
  readonly capabilities: readonly string[];
}

export interface MigrationResult {
  /** The final permission set (superset of current + migrated) */
  readonly permissions: readonly string[];
  /** Permissions that were added (empty if already migrated) */
  readonly added: readonly string[];
  /** Whether any changes were made */
  readonly changed: boolean;
}

/**
 * Computes the migrated permission set for a mobile-shop user.
 *
 * This function is idempotent: calling it multiple times with the same input
 * produces the same output. It never removes existing permissions — only adds
 * new ones based on the role and capability mappings.
 *
 * @param input - Current permissions, role, and capabilities
 * @returns The resulting permission set with additions tracked
 */
export function migratePermissions(input: MigrationInput): MigrationResult {
  const existing = new Set(input.currentPermissions);

  // 1. Add permissions from the role mapping
  const rolePermissions = ROLE_PERMISSION_MAP[input.role] ?? [];
  for (const perm of rolePermissions) {
    existing.add(perm);
  }

  // 2. Add permissions from active capabilities
  for (const cap of input.capabilities) {
    const capPerms = CAPABILITY_PERMISSION_MAP[cap as LegacyCapability];
    if (capPerms) {
      for (const perm of capPerms) {
        existing.add(perm);
      }
    }
  }

  // 3. Add permissions from legacy permission strings already present
  for (const legacyPerm of input.currentPermissions) {
    const mapped = LEGACY_PERMISSION_MAP[legacyPerm];
    if (mapped) {
      for (const perm of mapped) {
        existing.add(perm);
      }
    }
  }

  const finalPermissions = Array.from(existing).sort();
  const added = finalPermissions.filter(p => !input.currentPermissions.includes(p));

  return {
    permissions: finalPermissions,
    added,
    changed: added.length > 0,
  };
}
