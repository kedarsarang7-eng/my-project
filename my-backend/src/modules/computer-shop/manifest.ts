import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const computerShopManifest: ModuleManifest = {
    id: 'computer-shop',
    version: '1.0.0',
    displayName: 'Computer Store',
    status: 'active',
    businessTypes: [BusinessType.COMPUTER_SHOP],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.STAFF,
    featureKeys: [
        FeatureKey.COMPUTER_PC_BUILDER,
        FeatureKey.COMPUTER_COMPONENT_TRACKING,
        FeatureKey.COMPUTER_AMC,
        FeatureKey.COMPUTER_SERVICE_DESK,
    ],
    lambdaFunctions: ['computerMain', 'computerAmc', 'computerServiceDesk'],
    wsChannelPrefix: 'computer:',
    apiPrefix: '/computer',
    db: {
        skPrefixes: ['COMPUTER_BUILD#', 'COMPUTER_COMPONENT#', 'COMPUTER_AMC#', 'COMPUTER_TICKET#'],
        gsiIndexes: ['GSI1'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.computer', detailTypes: ['amc.expiring', 'ticket.resolved', 'build.completed'] },
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
