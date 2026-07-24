/// Feature Policy Configuration (Flutter)
///
/// Defines which features are enabled per capability tier. Used for
/// feature-gating provider-neutral capabilities on the client side.
///
/// Requirements: 6.20, 10.1–10.12
library;

import 'package:flutter/foundation.dart';

/// A single feature policy entry.
@immutable
class FeaturePolicyEntry {
  /// Stable feature identifier.
  final String featureId;

  /// Human-readable name.
  final String name;

  /// Whether enabled by default for new tenants.
  final bool enabledByDefault;

  /// Required capability (must be present in tenant capability set).
  final String? requiredCapability;

  /// Required permission for access.
  final String? requiredPermission;

  /// Whether this feature requires online connectivity.
  final bool onlineRequired;

  /// Description of the feature.
  final String description;

  const FeaturePolicyEntry({
    required this.featureId,
    required this.name,
    required this.enabledByDefault,
    this.requiredCapability,
    this.requiredPermission,
    required this.onlineRequired,
    required this.description,
  });
}

/// Feature policy configuration.
@immutable
class FeaturePolicyConfig {
  /// All declared features.
  final List<FeaturePolicyEntry> features;

  const FeaturePolicyConfig({required this.features});

  /// Returns the policy entry for the given [featureId], or null.
  FeaturePolicyEntry? getFeature(String featureId) {
    return features.where((f) => f.featureId == featureId).firstOrNull;
  }

  /// Returns whether [featureId] requires online connectivity.
  bool requiresOnline(String featureId) {
    return getFeature(featureId)?.onlineRequired ?? false;
  }
}

/// Default feature policy configuration.
const kFeaturePolicyConfig = FeaturePolicyConfig(
  features: [
    FeaturePolicyEntry(
      featureId: 'IMEI_TRACKING',
      name: 'IMEI Unit Tracking',
      enabledByDefault: true,
      requiredCapability: 'imei_tracking',
      requiredPermission: 'mobile_shop:imei:view',
      onlineRequired: false,
      description: 'Per-unit IMEI lifecycle tracking with Luhn validation',
    ),
    FeaturePolicyEntry(
      featureId: 'SERVICE_JOBS',
      name: 'Service & Repair Jobs',
      enabledByDefault: true,
      requiredCapability: 'service_jobs',
      requiredPermission: 'mobile_shop:service:view',
      onlineRequired: false,
      description: 'Device repair and service job management',
    ),
    FeaturePolicyEntry(
      featureId: 'EXCHANGES',
      name: 'Device Exchanges',
      enabledByDefault: true,
      requiredCapability: 'exchanges',
      requiredPermission: 'mobile_shop:exchange:view',
      onlineRequired: false,
      description: 'Old-to-new device exchange with valuation',
    ),
    FeaturePolicyEntry(
      featureId: 'WARRANTY_MANAGEMENT',
      name: 'Warranty Management',
      enabledByDefault: true,
      requiredCapability: 'warranty',
      requiredPermission: 'mobile_shop:warranty:view',
      onlineRequired: false,
      description: 'Warranty registration, tracking, and claims',
    ),
    FeaturePolicyEntry(
      featureId: 'SECOND_HAND_INTAKE',
      name: 'Second-Hand Intake',
      enabledByDefault: true,
      requiredCapability: 'second_hand',
      requiredPermission: 'mobile_shop:second_hand:view',
      onlineRequired: false,
      description: 'Used device procurement with inspection and valuation',
    ),
    FeaturePolicyEntry(
      featureId: 'FINANCE_PLANS',
      name: 'EMI / Finance Plans',
      enabledByDefault: false,
      requiredCapability: 'finance',
      requiredPermission: 'mobile_shop:finance:view',
      onlineRequired: true,
      description: 'Device finance and installment plan management',
    ),
    FeaturePolicyEntry(
      featureId: 'SIM_RECHARGE',
      name: 'SIM & Recharge',
      enabledByDefault: false,
      requiredCapability: 'sim_recharge',
      requiredPermission: 'mobile_shop:finance:view',
      onlineRequired: true,
      description: 'SIM activation and mobile recharge services',
    ),
    FeaturePolicyEntry(
      featureId: 'OCR_INTAKE',
      name: 'OCR Document Intake',
      enabledByDefault: false,
      requiredCapability: 'ocr',
      requiredPermission: 'mobile_shop:imei:manage',
      onlineRequired: true,
      description: 'Optical character recognition for device intake documents',
    ),
    FeaturePolicyEntry(
      featureId: 'BUNDLES',
      name: 'Handset Bundles & Accessories',
      enabledByDefault: true,
      requiredCapability: 'bundles',
      requiredPermission: 'mobile_shop:imei:view',
      onlineRequired: false,
      description: 'Bundled sales with separate accessory lines and tax',
    ),
    FeaturePolicyEntry(
      featureId: 'PRICE_PROTECTION',
      name: 'Price Protection',
      enabledByDefault: false,
      requiredCapability: 'price_protection',
      requiredPermission: 'mobile_shop:settings:manage',
      onlineRequired: false,
      description: 'Margin and price protection policies for device sales',
    ),
    FeaturePolicyEntry(
      featureId: 'E_WAY_BILL',
      name: 'e-Way Bill Integration',
      enabledByDefault: false,
      requiredCapability: 'e_way',
      requiredPermission: 'mobile_shop:settings:manage',
      onlineRequired: true,
      description: 'Electronic waybill generation for transport compliance',
    ),
    FeaturePolicyEntry(
      featureId: 'LOYALTY',
      name: 'Loyalty & Rewards',
      enabledByDefault: false,
      requiredCapability: 'loyalty',
      requiredPermission: 'mobile_shop:settings:manage',
      onlineRequired: false,
      description: 'Customer loyalty and reward point programs',
    ),
    FeaturePolicyEntry(
      featureId: 'MOBILE_REPORTS',
      name: 'Mobile-Specific Reports',
      enabledByDefault: true,
      requiredCapability: 'reports',
      requiredPermission: 'mobile_shop:reports:view',
      onlineRequired: false,
      description:
          'IMEI history, brand sales, repair revenue, exchange margin reports',
    ),
    FeaturePolicyEntry(
      featureId: 'ACCOUNTING',
      name: 'Accounting Lines',
      enabledByDefault: true,
      requiredCapability: 'accounting',
      requiredPermission: 'mobile_shop:finance:view',
      onlineRequired: false,
      description: 'Separate stock, tax, and accounting lines for device sales',
    ),
    FeaturePolicyEntry(
      featureId: 'TAX_MANAGEMENT',
      name: 'GST / Tax Management',
      enabledByDefault: true,
      requiredCapability: 'tax_management',
      requiredPermission: 'mobile_shop:finance:view',
      onlineRequired: false,
      description:
          'Mobile GST, HSN codes, and tax rate management for device sales',
    ),
    FeaturePolicyEntry(
      featureId: 'AUDIT_TRAIL',
      name: 'Audit Trail',
      enabledByDefault: true,
      requiredCapability: 'audit_trail',
      requiredPermission: 'mobile_shop:audit:view',
      onlineRequired: false,
      description:
          'Immutable audit event history for all lifecycle and financial changes',
    ),
    FeaturePolicyEntry(
      featureId: 'BACKUP_EXPORT',
      name: 'Backup & Export',
      enabledByDefault: false,
      requiredCapability: 'backup_export',
      requiredPermission: 'mobile_shop:reports:export',
      onlineRequired: true,
      description: 'Encrypted backup and data export for mobile shop records',
    ),
    FeaturePolicyEntry(
      featureId: 'COMPLIANCE',
      name: 'Compliance Checks',
      enabledByDefault: false,
      requiredCapability: 'compliance',
      requiredPermission: 'mobile_shop:settings:manage',
      onlineRequired: true,
      description:
          'e-Way bill, transaction threshold, and jurisdiction compliance',
    ),
  ],
);
