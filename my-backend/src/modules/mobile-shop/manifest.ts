import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const mobileShopManifest: ModuleManifest = {
    id: 'mobile-shop',
    version: '1.0.0',
    displayName: 'Mobile Shop',
    status: 'active',
    businessTypes: [BusinessType.MOBILE_SHOP],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.STAFF,
    featureKeys: [
        FeatureKey.MOBILE_IMEI_ENTRY,
        FeatureKey.MOBILE_EXCHANGE,
        FeatureKey.MOBILE_REPAIR,
        FeatureKey.MOBILE_EMI_INTEGRATION,
        FeatureKey.MOBILE_IMEI_API,
    ],
    lambdaFunctions: ['mobileShopMain', 'mobileShopRepairs', 'mobileShopImei'],
    wsChannelPrefix: 'mobile:',
    apiPrefix: '/mobile',
    db: {
        skPrefixes: ['MOBILE_IMEI#', 'MOBILE_REPAIR#', 'MOBILE_EXCHANGE#', 'MOBILE_EMI#'],
        gsiIndexes: ['GSI1', 'GSI3'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.mobile', detailTypes: ['repair.completed', 'imei.flagged', 'emi.due'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 150,
        [PlanTier.PRO]: 500,
        [PlanTier.PREMIUM]: 1500,
        [PlanTier.ENTERPRISE]: 6000,
    },
    dependsOn: ['inventory', 'billing'],
    aiToolsEnabled: false,
    marketplaceEligible: false,
};
