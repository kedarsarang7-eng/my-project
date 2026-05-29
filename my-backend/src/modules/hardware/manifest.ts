import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const hardwareManifest: ModuleManifest = {
    id: 'hardware',
    version: '1.0.0',
    displayName: 'Hardware Store',
    status: 'active',
    businessTypes: [BusinessType.HARDWARE],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.CASHIER,
    featureKeys: [
        FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE,
        FeatureKey.HARDWARE_MULTI_UOM,
        FeatureKey.HARDWARE_DELIVERY_CHALLAN,
        FeatureKey.HARDWARE_CONTRACTOR_CREDIT,
        FeatureKey.HARDWARE_GATE_PASS,
    ],
    lambdaFunctions: [
        'hardwarePhase1',
        'hardwarePhase2',
        'hardwarePhase12',
        'hardwareProjects',
        'hardwareDeposits',
    ],
    wsChannelPrefix: 'hardware:',
    apiPrefix: '/hardware',
    db: {
        skPrefixes: ['HARDWARE_PROJECT#', 'HARDWARE_DEPOSIT#', 'HARDWARE_GATEPASS#'],
        gsiIndexes: ['GSI1'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.hardware', detailTypes: ['estimate.created', 'challan.dispatched', 'project.completed'] },
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
