import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const decorationCateringManifest: ModuleManifest = {
    id: 'decoration-catering',
    version: '1.0.0',
    displayName: 'Decoration & Catering',
    status: 'active',
    businessTypes: [BusinessType.DECORATION_CATERING],
    requiredPlan: PlanTier.PRO,
    minRole: UserRole.STAFF,
    featureKeys: [
        FeatureKey.DC_EVENT_BOOKING,
        FeatureKey.DC_DECORATION_THEMES,
        FeatureKey.DC_CATERING_MENU,
        FeatureKey.DC_STAFF_MANAGEMENT,
        FeatureKey.DC_VENDOR_MANAGEMENT,
        FeatureKey.DC_INVENTORY,
        FeatureKey.DC_BILLING,
        FeatureKey.DC_REPORTS,
        FeatureKey.DC_MEAL_PLANNER,
        FeatureKey.DC_EXPENSE_TRACKING,
    ],
    lambdaFunctions: [
        'dcEvents',
        'dcThemes',
        'dcMenu',
        'dcPackages',
        'dcStaff',
        'dcVendors',
        'dcInventory',
        'dcInvoices',
        'dcExpenses',
        'dcDashboard',
        'dcReports',
    ],
    wsChannelPrefix: 'dc:',
    apiPrefix: '/dc',
    db: {
        skPrefixes: [
            'DC_EVENT#', 'DC_THEME#', 'DC_MENU#', 'DC_PKG#',
            'DC_STAFF#', 'DC_VENDOR#', 'DC_INV#', 'DC_EXPENSE#', 'DC_INVOICE#',
        ],
        gsiIndexes: ['GSI1', 'GSI4'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.dc', detailTypes: ['event.booked', 'event.confirmed', 'payment.received', 'staff.assigned'] },
    ],
    rateLimits: {
        [PlanTier.BASIC]: 50,
        [PlanTier.PRO]: 300,
        [PlanTier.PREMIUM]: 1000,
        [PlanTier.ENTERPRISE]: 5000,
    },
    dependsOn: ['billing'],
    aiToolsEnabled: false,
    marketplaceEligible: true,
};
