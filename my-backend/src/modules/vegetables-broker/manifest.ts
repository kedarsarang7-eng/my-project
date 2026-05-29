import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const vegetablesBrokerManifest: ModuleManifest = {
    id: 'vegetables-broker',
    version: '1.0.0',
    displayName: 'Vegetables Broker (Mandi)',
    status: 'active',
    businessTypes: [BusinessType.VEGETABLES_BROKER],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.CASHIER,
    featureKeys: [
        FeatureKey.VEGBROKER_BASIC_RATE_ENTRY,
        FeatureKey.VEGBROKER_COMMISSION_AUTOMATION,
        FeatureKey.VEGBROKER_FARMER_SETTLEMENT,
    ],
    lambdaFunctions: ['vegBrokerMain'],
    wsChannelPrefix: 'vegbroker:',
    apiPrefix: '/veg-broker',
    db: {
        skPrefixes: ['VEGBROKER_RATE#', 'VEGBROKER_FARMER#', 'VEGBROKER_COMMISSION#', 'VEGBROKER_APMC#'],
        gsiIndexes: ['GSI1'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.vegbroker', detailTypes: ['rate.entered', 'farmer.settled', 'apmc.levy'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 100,
        [PlanTier.PRO]: 400,
        [PlanTier.PREMIUM]: 1000,
        [PlanTier.ENTERPRISE]: 4000,
    },
    dependsOn: ['billing'],
    aiToolsEnabled: false,
    marketplaceEligible: false,
};
