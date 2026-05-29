import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const wholesaleManifest: ModuleManifest = {
    id: 'wholesale',
    version: '1.0.0',
    displayName: 'Wholesale Distribution',
    status: 'active',
    businessTypes: [BusinessType.WHOLESALE],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.CASHIER,
    featureKeys: [
        FeatureKey.WHOLESALE_BASIC_BULK_ENTRY,
        FeatureKey.WHOLESALE_TIERED_PRICING,
        FeatureKey.WHOLESALE_LOGISTICS,
        FeatureKey.WHOLESALE_EWAY_BILL,
        FeatureKey.WHOLESALE_ADVANCED_AR,
    ],
    lambdaFunctions: ['wholesaleMain', 'wholesaleLogistics', 'wholesaleReports'],
    wsChannelPrefix: 'wholesale:',
    apiPrefix: '/wholesale',
    db: {
        skPrefixes: ['WHOLESALE_DISPATCH#', 'WHOLESALE_LR#', 'WHOLESALE_TIER#', 'WHOLESALE_EWAY#'],
        gsiIndexes: ['GSI1', 'GSI4'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.wholesale', detailTypes: ['dispatch.created', 'lr.generated', 'payment.overdue'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 150,
        [PlanTier.PRO]: 500,
        [PlanTier.PREMIUM]: 1500,
        [PlanTier.ENTERPRISE]: 8000,
    },
    dependsOn: ['inventory', 'billing'],
    aiToolsEnabled: false,
    marketplaceEligible: false,
};
