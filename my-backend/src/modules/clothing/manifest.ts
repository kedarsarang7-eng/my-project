import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const clothingManifest: ModuleManifest = {
    id: 'clothing',
    version: '1.0.0',
    displayName: 'Clothing & Fashion',
    status: 'active',
    businessTypes: [BusinessType.CLOTHING],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.CASHIER,
    featureKeys: [
        FeatureKey.CLOTHING_BASIC_MATRIX,
        FeatureKey.CLOTHING_FULL_MATRIX,
        FeatureKey.CLOTHING_SEASONAL_OFFERS,
    ],
    lambdaFunctions: ['clothingMain'],
    wsChannelPrefix: 'clothing:',
    apiPrefix: '/clothing',
    db: {
        skPrefixes: ['CLOTHING_VARIANT#', 'CLOTHING_SEASON#', 'CLOTHING_MATRIX#'],
        gsiIndexes: ['GSI1', 'GSI3'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.clothing', detailTypes: ['variant.low_stock', 'season.activated'] },
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
