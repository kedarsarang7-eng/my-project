import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const restaurantManifest: ModuleManifest = {
    id: 'restaurant',
    version: '1.0.0',
    displayName: 'Restaurant',
    status: 'active',
    businessTypes: [BusinessType.RESTAURANT],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.STAFF,
    featureKeys: [
        FeatureKey.RESTAURANT_BASIC_TABLE_MGMT,
        FeatureKey.RESTAURANT_KOT,
        FeatureKey.RESTAURANT_SPLIT_BILLING,
        FeatureKey.RESTAURANT_BOM,
        FeatureKey.RESTAURANT_WAITER_APP,
        FeatureKey.RESTAURANT_MULTI_KITCHEN,
    ],
    lambdaFunctions: [
        'restaurantMenu',
        'restaurantTables',
        'restaurantOrders',
        'restaurantKot',
        'restaurantBilling',
        'restaurantAnalytics',
        'restaurantDelivery',
        'restaurantReports',
        'restaurantV1Public',
    ],
    wsChannelPrefix: 'restaurant:',
    apiPrefix: '/restaurant',
    db: {
        skPrefixes: ['RESTO_TABLE#', 'RESTO_ORDER#', 'RESTO_KOT#', 'RESTO_MENU#', 'RESTO_DELIVERY#', 'RESTO_COMBO#'],
        gsiIndexes: ['GSI1', 'GSI4'],
        requiresWriteSharding: true,
        shardCount: 10,
    },
    queues: [
        {
            logicalName: 'RestaurantKotQueue',
            fifo: true,
            maxReceiveCount: 3,
            visibilityTimeoutSeconds: 30,
        },
    ],
    eventPatterns: [
        { source: 'dukanx.restaurant', detailTypes: ['kot.new', 'order.placed', 'table.occupied', 'table.cleared', 'payment.completed'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 300,
        [PlanTier.PRO]: 1000,
        [PlanTier.PREMIUM]: 3000,
        [PlanTier.ENTERPRISE]: 15000,
    },
    dependsOn: ['inventory', 'billing'],
    aiToolsEnabled: true,
    marketplaceEligible: false,
};
