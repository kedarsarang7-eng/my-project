import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const bookStoreManifest: ModuleManifest = {
    id: 'book-store',
    version: '1.0.0',
    displayName: 'Book Store',
    status: 'active',
    businessTypes: [BusinessType.BOOK_STORE],
    requiredPlan: PlanTier.BASIC,
    minRole: UserRole.CASHIER,
    featureKeys: [
        FeatureKey.BOOKSTORE_ISBN_MANUAL,
        FeatureKey.BOOKSTORE_ISBN_AUTOFILL,
        FeatureKey.BOOKSTORE_PUBLISHER_FILTERS,
        FeatureKey.BOOKSTORE_INSTITUTIONAL_SALES,
        FeatureKey.BOOKSTORE_CONSIGNMENT_SETTLEMENT,
        FeatureKey.BOOKSTORE_USED_BOOK_ENGINE,
        FeatureKey.BOOKSTORE_ACADEMIC_CRM,
    ],
    lambdaFunctions: ['bookStoreMain', 'bookStoreIsbn'],
    wsChannelPrefix: 'bookstore:',
    apiPrefix: '/books',
    db: {
        skPrefixes: ['BOOK_ISBN#', 'BOOK_CONSIGNMENT#', 'BOOK_USED#', 'BOOK_INSTITUTION#'],
        gsiIndexes: ['GSI1', 'GSI3'],
        requiresWriteSharding: false,
    },
    eventPatterns: [
        { source: 'dukanx.bookstore', detailTypes: ['isbn.autofilled', 'consignment.settled', 'institution.order'] },
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
