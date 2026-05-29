// ============================================================================
// MODULE TEMPLATE — Copy this entire directory to add a new business module
// ============================================================================
// Steps:
//   1. cp -r src/modules/_template src/modules/your-module
//   2. Fill in every field in this manifest
//   3. Add handlers under handlers/
//   4. Add services under services/
//   5. Create serverless.module.yml
//   6. Register in src/core/registry/module-registry.ts (one import + one line)
//   7. Add DynamoDB SK prefixes to dynamodb.config.ts Keys object
//   8. Add Flutter module in Dukan_x/lib/modules/your_module/
// ============================================================================

import { ModuleManifest } from '../../core/types/module.types';
import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

export const templateManifest: ModuleManifest = {
    id: 'your-module',            // CHANGE: unique lowercase-kebab-case ID
    version: '1.0.0',
    displayName: 'Your Module',   // CHANGE: human-readable name
    status: 'beta',               // Use 'active' when ready for production

    businessTypes: [BusinessType.OTHER],  // CHANGE: which business types activate this
    requiredPlan: PlanTier.BASIC,         // CHANGE: minimum plan
    minRole: UserRole.STAFF,              // CHANGE: minimum role

    featureKeys: [
        // CHANGE: list all FeatureKeys this module provides
        // Add new entries to plan-feature-registry.ts FeatureKey enum first
    ],

    lambdaFunctions: [
        // CHANGE: list function names that will be in serverless.module.yml
        // e.g. 'yourModuleMain', 'yourModuleReports'
    ],

    wsChannelPrefix: 'your-module:',   // CHANGE: unique prefix (no collisions)
    apiPrefix: '/your-module',          // CHANGE: all routes must start with this

    db: {
        skPrefixes: [
            // CHANGE: SK prefixes this module EXCLUSIVELY owns
            // e.g. 'YOUR_ENTITY#', 'YOUR_OTHER#'
            // Must not overlap with any other module's skPrefixes
        ],
        gsiIndexes: ['GSI1'],           // CHANGE: GSIs this module queries
        requiresWriteSharding: false,   // Set true for high-frequency POS writes
    },

    queues: [
        // OPTIONAL: uncomment if you need async SQS processing
        // {
        //     logicalName: 'YourModuleQueue',
        //     fifo: false,
        //     maxReceiveCount: 3,
        //     visibilityTimeoutSeconds: 60,
        // },
    ],

    eventPatterns: [
        // CHANGE: EventBridge events this module listens to
        { source: 'dukanx.your-module', detailTypes: ['entity.created', 'entity.updated'] },
    ],

    rateLimits: {
        [PlanTier.BASIC]: 100,
        [PlanTier.PRO]: 400,
        [PlanTier.PREMIUM]: 1200,
        [PlanTier.ENTERPRISE]: 5000,
    },

    dependsOn: ['billing'],    // CHANGE: module IDs this depends on

    aiToolsEnabled: false,
    marketplaceEligible: false,
};
