import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const autoPartsManifest: ModuleManifest = {
    id: 'auto-parts',
    version: '1.0.0',
    displayName: 'Auto Parts & Garage',
    status: 'active',
    businessTypes: [BusinessType.AUTO_PARTS],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.STAFF,
    featureKeys: [
        FeatureKey.AUTOPARTS_VEHICLE_LOOKUP,
        FeatureKey.AUTOPARTS_OEM_CROSS_REF,
        FeatureKey.AUTOPARTS_FITMENT_GUIDE,
        FeatureKey.AUTOPARTS_RETURN_WARRANTY,
        FeatureKey.AUTOPARTS_JOB_CARD,
    ],
    lambdaFunctions: ['autoPartsMain', 'autoPartsJobCards'],
    wsChannelPrefix: 'autoparts:',
    apiPrefix: '/auto-parts',
    db: {
        skPrefixes: ['AUTOPARTS_JOB_CARD#', 'AUTOPARTS_PART#', 'OEM#', 'AFTERMARKET#'],
        gsiIndexes: ['GSI1', 'GSI3'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.autoparts', detailTypes: ['jobcard.created', 'vehicle.lookup', 'warranty.expiring'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 100,
        [PlanTier.PRO]: 400,
        [PlanTier.PREMIUM]: 1200,
        [PlanTier.ENTERPRISE]: 5000,
    },
    dependsOn: ['inventory', 'billing'],
    aiToolsEnabled: false,
    marketplaceEligible: false,
};
