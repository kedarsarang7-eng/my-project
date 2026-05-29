import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const clinicManifest: ModuleManifest = {
    id: 'clinic',
    version: '1.0.0',
    displayName: 'Clinic',
    status: 'active',
    businessTypes: [BusinessType.CLINIC],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.STAFF,
    featureKeys: [
        FeatureKey.CLINIC_TOKEN_SCREEN,
        FeatureKey.CLINIC_BASIC_EMR,
        FeatureKey.CLINIC_E_PRESCRIPTION,
        FeatureKey.CLINIC_FULL_EMR,
        FeatureKey.CLINIC_AUTO_FOLLOWUP,
        FeatureKey.CLINIC_PATIENT_MGMT,
        FeatureKey.CLINIC_APPOINTMENT_MGMT,
        FeatureKey.CLINIC_DOCTOR_PROFILE,
    ],
    lambdaFunctions: [
        'clinicPatients',
        'clinicAppointments',
        'clinicDoctors',
        'clinicPrescriptions',
        'clinicBilling',
        'clinicDashboard',
        'clinicReports',
        'clinicScheduler',
        'clinicPdf',
    ],
    wsChannelPrefix: 'clinic:',
    apiPrefix: '/clinic',
    db: {
        skPrefixes: ['CLINIC_PATIENT#', 'CLINIC_APPOINTMENT#', 'CLINIC_PRESCRIPTION#', 'CLINIC_TOKEN#', 'CLINIC_EMR#'],
        gsiIndexes: ['GSI1', 'GSI2'],
        requiresWriteSharding: false,
    },
    queues: [
        {
            logicalName: 'ClinicFollowUpQueue',
            fifo: false,
            maxReceiveCount: 3,
            visibilityTimeoutSeconds: 60,
        },
    ],
    eventPatterns: [
        { source: 'dukanx.clinic', detailTypes: ['appointment.booked', 'patient.registered', 'followup.due', 'token.called'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 100,
        [PlanTier.PRO]: 400,
        [PlanTier.PREMIUM]: 1200,
        [PlanTier.ENTERPRISE]: 6000,
    },
    dependsOn: ['billing'],
    aiToolsEnabled: true,
    marketplaceEligible: false,
};
