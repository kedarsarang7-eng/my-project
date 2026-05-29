import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const jewelleryManifest: ModuleManifest = {
    id: 'jewellery',
    version: '1.0.0',
    displayName: 'Jewellery Store',
    status: 'active',
    businessTypes: [BusinessType.JEWELLERY],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.STAFF,
    featureKeys: [
        FeatureKey.JEWELLERY_PURITY_TRACKING,
        FeatureKey.JEWELLERY_MAKING_CHARGES,
        FeatureKey.JEWELLERY_HALLMARK,
        FeatureKey.JEWELLERY_OLD_GOLD_EXCHANGE,
        FeatureKey.JEWELLERY_DAILY_RATE_CARD,
        FeatureKey.JEWELLERY_CUSTOM_ORDERS,
        FeatureKey.JEWELLERY_GOLD_RATE_ALERTS,
        FeatureKey.JEWELLERY_REPAIR_MANAGEMENT,
        FeatureKey.JEWELLERY_GOLD_SCHEMES,
    ],
    lambdaFunctions: [
        'jewelleryMain',
        'jewelleryExtended',
        'jewelleryReports',
    ],
    wsChannelPrefix: 'jewellery:',
    apiPrefix: '/jewellery',
    db: {
        skPrefixes: [
            'GOLDRATE#', 'JEWELLERY_ORDER#', 'JEWELLERY_EXCHANGE#',
            'ALERT#', 'MAKING_CONFIG#', 'REPAIR#', 'GOLD_SCHEME#', 'SCHEME_TEMPLATE#',
        ],
        gsiIndexes: ['GSI1', 'GSI4'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.jewellery', detailTypes: ['gold.rate.updated', 'scheme.payment.due', 'repair.ready'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 100,
        [PlanTier.PRO]: 300,
        [PlanTier.PREMIUM]: 1000,
        [PlanTier.ENTERPRISE]: 5000,
    },
    dependsOn: ['inventory', 'billing'],
    aiToolsEnabled: true,
    marketplaceEligible: false,
};
