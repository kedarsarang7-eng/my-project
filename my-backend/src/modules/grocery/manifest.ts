import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const groceryManifest: ModuleManifest = {
    id: 'grocery',
    version: '1.0.0',
    displayName: 'Grocery Store',
    status: 'active',
    businessTypes: [BusinessType.GROCERY],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.CASHIER,
    featureKeys: [
        FeatureKey.GROCERY_FAST_BILLING_POS,
        FeatureKey.GROCERY_WEIGHING_SCALE,
        FeatureKey.GROCERY_ADVANCED_BATCH,
    ],
    lambdaFunctions: [
        'groceryBatches',
        'groceryExpiry',
        'groceryBilling',
        'groceryInventory',
        'groceryReports',
    ],
    wsChannelPrefix: 'grocery:',
    apiPrefix: '/grocery',
    db: {
        skPrefixes: ['GROCERY_BATCH#', 'GROCERY_EXPIRY#', 'GROCERY_WEIGHSCALE#'],
        gsiIndexes: ['GSI1', 'GSI3'],
        requiresWriteSharding: true,
        shardCount: 5,
    },
    queues: [
        {
            logicalName: 'GroceryExpiryQueue',
            fifo: false,
            maxReceiveCount: 3,
            visibilityTimeoutSeconds: 60,
        },
    ],
    eventPatterns: [
        { source: 'dukanx.grocery', detailTypes: ['stock.low', 'batch.expiring', 'weighscale.reading'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 200,
        [PlanTier.PRO]: 600,
        [PlanTier.PREMIUM]: 2000,
        [PlanTier.ENTERPRISE]: 10000,
    },
    dependsOn: ['inventory', 'billing'],
    aiToolsEnabled: true,
    marketplaceEligible: false,
};
