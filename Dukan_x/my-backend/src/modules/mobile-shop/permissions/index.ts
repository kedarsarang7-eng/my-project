/**
 * MobileShop Permissions — Barrel Export
 *
 * Requirements: 8.1–8.2, 8.5–8.7, 8.13
 */

export {
  MOBILE_SHOP_PERMISSIONS,
  ALL_MOBILE_SHOP_PERMISSIONS,
  PERMISSION_IMPLICATIONS,
  expandPermissions,
  type MobileShopPermission,
} from './mobile-shop-permissions';

export {
  ROLE_PERMISSION_MAP,
  CAPABILITY_PERMISSION_MAP,
  LEGACY_PERMISSION_MAP,
  migratePermissions,
  type LegacyRole,
  type LegacyCapability,
  type MigrationInput,
  type MigrationResult,
} from './compatibility-matrix';

export {
  checkMobileShopPermission,
  checkAllPermissions,
  checkAnyPermission,
  getEffectiveMobileShopPermissions,
  isValidMobileShopPermission,
  type PermissionContext,
  type PermissionCheckResult,
} from './permission-checker';
