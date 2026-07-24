/**
 * Feature Policy Configuration
 *
 * Defines which features are enabled per capability tier. Used for feature-gating
 * provider-neutral capabilities (OCR, finance, SIM/recharge, bundles, e-Way, etc.)
 * and for rollout control.
 *
 * Requirements: 6.20 (feature policy gates), 10.1–10.12
 */

/** A single feature flag entry */
export interface FeaturePolicyEntry {
  /** Stable feature identifier */
  readonly featureId: string;
  /** Human-readable name */
  readonly name: string;
  /** Whether enabled by default for new tenants */
  readonly enabledByDefault: boolean;
  /** Required capability (must be present in tenant capability set) */
  readonly requiredCapability?: string;
  /** Required permission for access */
  readonly requiredPermission?: string;
  /** Whether this feature requires online connectivity */
  readonly onlineRequired: boolean;
  /** Description of the feature */
  readonly description: string;
}

export interface FeaturePolicyConfig {
  /** All declared features */
  readonly features: readonly FeaturePolicyEntry[];
}

export const FEATURE_POLICY_CONFIG: FeaturePolicyConfig = {
  features: [
    {
      featureId: 'IMEI_TRACKING',
      name: 'IMEI Unit Tracking',
      enabledByDefault: true,
      requiredCapability: 'imei_tracking',
      requiredPermission: 'mobile_shop:imei:view',
      onlineRequired: false,
      description: 'Per-unit IMEI lifecycle tracking with Luhn validation',
    },
    {
      featureId: 'SERVICE_JOBS',
      name: 'Service & Repair Jobs',
      enabledByDefault: true,
      requiredCapability: 'service_jobs',
      requiredPermission: 'mobile_shop:service:view',
      onlineRequired: false,
      description: 'Device repair and service job management',
    },
    {
      featureId: 'EXCHANGES',
      name: 'Device Exchanges',
      enabledByDefault: true,
      requiredCapability: 'exchanges',
      requiredPermission: 'mobile_shop:exchange:view',
      onlineRequired: false,
      description: 'Old-to-new device exchange with valuation',
    },
    {
      featureId: 'WARRANTY_MANAGEMENT',
      name: 'Warranty Management',
      enabledByDefault: true,
      requiredCapability: 'warranty',
      requiredPermission: 'mobile_shop:warranty:view',
      onlineRequired: false,
      description: 'Warranty registration, tracking, and claims',
    },
    {
      featureId: 'SECOND_HAND_INTAKE',
      name: 'Second-Hand Intake',
      enabledByDefault: true,
      requiredCapability: 'second_hand',
      requiredPermission: 'mobile_shop:second_hand:view',
      onlineRequired: false,
      description: 'Used device procurement with inspection and valuation',
    },
    {
      featureId: 'FINANCE_PLANS',
      name: 'EMI / Finance Plans',
      enabledByDefault: false,
      requiredCapability: 'finance',
      requiredPermission: 'mobile_shop:finance:view',
      onlineRequired: true,
      description: 'Device finance and installment plan management',
    },
    {
      featureId: 'SIM_RECHARGE',
      name: 'SIM & Recharge',
      enabledByDefault: false,
      requiredCapability: 'sim_recharge',
      requiredPermission: 'mobile_shop:finance:view',
      onlineRequired: true,
      description: 'SIM activation and mobile recharge services',
    },
    {
      featureId: 'OCR_INTAKE',
      name: 'OCR Document Intake',
      enabledByDefault: false,
      requiredCapability: 'ocr',
      requiredPermission: 'mobile_shop:imei:manage',
      onlineRequired: true,
      description: 'Optical character recognition for device intake documents',
    },
    {
      featureId: 'BUNDLES',
      name: 'Handset Bundles & Accessories',
      enabledByDefault: true,
      requiredCapability: 'bundles',
      requiredPermission: 'mobile_shop:imei:view',
      onlineRequired: false,
      description: 'Bundled sales with separate accessory lines and tax',
    },
    {
      featureId: 'PRICE_PROTECTION',
      name: 'Price Protection',
      enabledByDefault: false,
      requiredCapability: 'price_protection',
      requiredPermission: 'mobile_shop:settings:manage',
      onlineRequired: false,
      description: 'Margin and price protection policies for device sales',
    },
    {
      featureId: 'E_WAY_BILL',
      name: 'e-Way Bill Integration',
      enabledByDefault: false,
      requiredCapability: 'e_way',
      requiredPermission: 'mobile_shop:settings:manage',
      onlineRequired: true,
      description: 'Electronic waybill generation for transport compliance',
    },
    {
      featureId: 'LOYALTY',
      name: 'Loyalty & Rewards',
      enabledByDefault: false,
      requiredCapability: 'loyalty',
      requiredPermission: 'mobile_shop:settings:manage',
      onlineRequired: false,
      description: 'Customer loyalty and reward point programs',
    },
    {
      featureId: 'MOBILE_REPORTS',
      name: 'Mobile-Specific Reports',
      enabledByDefault: true,
      requiredCapability: 'reports',
      requiredPermission: 'mobile_shop:reports:view',
      onlineRequired: false,
      description: 'IMEI history, brand sales, repair revenue, exchange margin reports',
    },
  ],
} as const;
