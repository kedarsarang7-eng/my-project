import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const petrolPumpManifest: ModuleManifest = {
    id: 'petrol-pump',
    version: '1.0.0',
    displayName: 'Petrol Pump',
    status: 'active',
    businessTypes: [BusinessType.PETROL_PUMP],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.PUMPBOY,
    featureKeys: [
        FeatureKey.PETROL_BASIC_SHIFT_ENTRY,
        FeatureKey.PETROL_DIP_READING,
        FeatureKey.PETROL_NOZZLE_SETTLEMENT,
        FeatureKey.PETROL_DENSITY_LOSS,
    ],
    lambdaFunctions: [
        'pumpMain',
        'pumpPricing',
        'pumpReports',
        'pumpIntegrations',
        'pumpAtgScheduler',
    ],
    wsChannelPrefix: 'pump:',
    apiPrefix: '/pump',
    db: {
        skPrefixes: ['PUMP_SHIFT#', 'PUMP_NOZZLE#', 'PUMP_DIP#', 'PUMP_TANK#', 'PUMP_FLEET#'],
        gsiIndexes: ['GSI1', 'GSI4'],
        requiresWriteSharding: false,
    },
    queues: [
        {
            logicalName: 'PumpAtgQueue',
            fifo: false,
            maxReceiveCount: 3,
            visibilityTimeoutSeconds: 30,
        },
    ],
    eventPatterns: [
        { source: 'dukanx.pump', detailTypes: ['shift.opened', 'shift.closed', 'dip.reading', 'atg.sync'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 200,
        [PlanTier.PRO]: 600,
        [PlanTier.PREMIUM]: 2000,
        [PlanTier.ENTERPRISE]: 8000,
    },
    dependsOn: ['billing'],
    aiToolsEnabled: false,
    marketplaceEligible: false,
};
