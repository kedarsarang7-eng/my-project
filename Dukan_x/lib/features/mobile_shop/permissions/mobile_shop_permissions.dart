/// MobileShop Permissions — Authoritative Permission Constants (Dart)
///
/// Defines all dedicated MobileShop permissions following the
/// `{domain}:{resource}:{action}` naming convention.
///
/// Rules:
/// - `view` grants read access
/// - `manage` grants write access and implies `view`
/// - `export` is separate from `view` (requires explicit grant)
///
/// Requirements: 8.1–8.2, 8.5–8.7, 8.13
library;

/// All MobileShop-specific permission constants.
abstract final class MobileShopPermissions {
  MobileShopPermissions._();

  // Service / Repair
  static const serviceView = 'mobile_shop:service:view';
  static const serviceManage = 'mobile_shop:service:manage';

  // IMEI / Device inventory
  static const imeiView = 'mobile_shop:imei:view';
  static const imeiManage = 'mobile_shop:imei:manage';

  // Exchange
  static const exchangeView = 'mobile_shop:exchange:view';
  static const exchangeManage = 'mobile_shop:exchange:manage';

  // Warranty
  static const warrantyView = 'mobile_shop:warranty:view';
  static const warrantyManage = 'mobile_shop:warranty:manage';

  // Second-hand intake
  static const secondHandView = 'mobile_shop:second_hand:view';
  static const secondHandManage = 'mobile_shop:second_hand:manage';

  // Finance / EMI
  static const financeView = 'mobile_shop:finance:view';
  static const financeManage = 'mobile_shop:finance:manage';

  // Reports
  static const reportsView = 'mobile_shop:reports:view';
  static const reportsExport = 'mobile_shop:reports:export';

  // Settings
  static const settingsView = 'mobile_shop:settings:view';
  static const settingsManage = 'mobile_shop:settings:manage';

  // Audit (read-only for application workloads)
  static const auditView = 'mobile_shop:audit:view';

  /// All defined permission strings.
  static const List<String> all = [
    serviceView,
    serviceManage,
    imeiView,
    imeiManage,
    exchangeView,
    exchangeManage,
    warrantyView,
    warrantyManage,
    secondHandView,
    secondHandManage,
    financeView,
    financeManage,
    reportsView,
    reportsExport,
    settingsView,
    settingsManage,
    auditView,
  ];

  /// Maps each `manage` permission to the `view` it implies.
  /// `reports:export` implies `reports:view`.
  static const Map<String, String> implications = {
    serviceManage: serviceView,
    imeiManage: imeiView,
    exchangeManage: exchangeView,
    warrantyManage: warrantyView,
    secondHandManage: secondHandView,
    financeManage: financeView,
    reportsExport: reportsView,
    settingsManage: settingsView,
  };
}
