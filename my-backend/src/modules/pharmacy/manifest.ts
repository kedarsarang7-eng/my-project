import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const pharmacyManifest: ModuleManifest = {
    id: 'pharmacy',
    version: '1.0.0',
    displayName: 'Pharmacy',
    status: 'active',
    businessTypes: [BusinessType.PHARMACY],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.STAFF,
    featureKeys: [
        FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY,
        FeatureKey.PHARMACY_PRESCRIPTION,
        FeatureKey.PHARMACY_ALTERNATIVE_MEDICINE,
        FeatureKey.PHARMACY_RETURNS,
        FeatureKey.PHARMACY_SCHEDULE_H,
        FeatureKey.PHARMACY_RACK_TRACKING,
    ],
    lambdaFunctions: [
        'pharmacyBilling',
        'pharmacyInventory',
        'pharmacyBatchExpiry',
        'pharmacyCompliance',
        'pharmacyPrescriptions',
        'pharmacyReports',
        'pharmacyReturns',
    ],
    wsChannelPrefix: 'pharmacy:',
    apiPrefix: '/pharmacy',
    db: {
        skPrefixes: ['PHARMA_BATCH#', 'PHARMA_PRESCRIPTION#', 'PHARMA_SCHEDULE#', 'PHARMA_RACK#', 'PHARMA_RETURN#'],
        gsiIndexes: ['GSI1', 'GSI3'],
        requiresWriteSharding: false,
    },
    queues: [
        {
            logicalName: 'PharmacyBatchExpiryQueue',
            fifo: false,
            maxReceiveCount: 3,
            visibilityTimeoutSeconds: 120,
        },
    ],
    eventPatterns: [
        { source: 'dukanx.pharmacy', detailTypes: ['batch.expiring', 'batch.expired', 'schedule.h.dispensed'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 150,
        [PlanTier.PRO]: 500,
        [PlanTier.PREMIUM]: 1500,
        [PlanTier.ENTERPRISE]: 8000,
    },
    dependsOn: ['inventory', 'billing'],
    aiToolsEnabled: true,
    marketplaceEligible: false,
};
