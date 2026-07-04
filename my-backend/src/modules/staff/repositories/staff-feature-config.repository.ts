// ============================================================================
// Staff Module — StaffFeatureConfig Repository (Task 2.4)
// ============================================================================
// Persistence for Staff_Feature_Config items on the DynamoDB single table.
//
// TENANT/BUSINESS ISOLATION INVARIANT
// -----------------------------------
// Every read/write is scoped to the business partition
//     PK = TENANT#{tenantId}#BIZ#{businessId}
// built ONLY via ../keys.ts::buildStaffFeatureConfigKeys (which uses the shared
// businessPK builder that rejects '#' injection). BusinessID is always the
// leading partition scope (Req 1.5, 11.1). This repository does NOT extend the
// tenant-partition BaseRepository because staff entities use the finer-grained
// business partition — it composes the same low-level item helpers instead.
//
// SK: STAFFCFG#{businessType}#{tier}
// ============================================================================

import { getItem, putItem, queryItems } from '../../../config/dynamodb.config';
import {
    buildStaffFeatureConfigKeys,
    staffFeatureConfigSK,
    STAFFCFG_SK_PREFIX,
    STAFF_ENTITY_TYPE,
} from '../keys';
import {
    StaffFeatureConfig,
    StaffConfigTier,
    staffFeatureConfigSchema,
} from '../schemas/staff-feature-config.schema';

/** Stored shape: the config plus table keys + audit/scope attributes. */
type StaffFeatureConfigItem = StaffFeatureConfig & {
    PK: string;
    SK: string;
    GSI1PK?: string;
    GSI1SK?: string;
    entityType: string;
    tenantId: string;
    businessId: string;
    isDeleted: boolean;
    createdAt: string;
    updatedAt: string;
};

function toConfig(item: StaffFeatureConfigItem): StaffFeatureConfig {
    return {
        businessType: item.businessType,
        tier: item.tier,
        enabledModules: item.enabledModules,
        enabledFields: item.enabledFields,
    };
}

export class StaffFeatureConfigRepository {
    /**
     * Fetch the config for a specific BusinessType × tier. Returns null when
     * absent or soft-deleted.
     */
    async get(
        tenantId: string,
        businessId: string,
        businessType: string,
        tier: StaffConfigTier,
    ): Promise<StaffFeatureConfig | null> {
        const keys = buildStaffFeatureConfigKeys(tenantId, businessId, businessType, tier);
        const item = await getItem<StaffFeatureConfigItem>(keys.PK, keys.SK);
        if (!item || item.isDeleted) return null;
        return toConfig(item);
    }

    /**
     * List every staff feature config stored for a business.
     */
    async list(tenantId: string, businessId: string): Promise<StaffFeatureConfig[]> {
        const keys = buildStaffFeatureConfigKeys(tenantId, businessId, 'x', 'basic');
        const result = await queryItems<StaffFeatureConfigItem>(keys.PK, STAFFCFG_SK_PREFIX, {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        });
        return result.items.map(toConfig);
    }

    /**
     * Create or overwrite a config. Validates against the schema fail-closed
     * before writing so a malformed config can never be persisted (Req 1.9).
     */
    async upsert(
        tenantId: string,
        businessId: string,
        config: StaffFeatureConfig,
    ): Promise<StaffFeatureConfig> {
        const parsed = staffFeatureConfigSchema.parse(config);
        const keys = buildStaffFeatureConfigKeys(
            tenantId,
            businessId,
            parsed.businessType,
            parsed.tier,
        );
        const now = new Date().toISOString();

        // Preserve original createdAt if the item already exists.
        const existing = await getItem<StaffFeatureConfigItem>(keys.PK, keys.SK);

        const item: StaffFeatureConfigItem = {
            PK: keys.PK,
            SK: keys.SK,
            GSI1PK: keys.GSI1PK,
            GSI1SK: keys.GSI1SK,
            entityType: STAFF_ENTITY_TYPE.FEATURE_CONFIG,
            tenantId,
            businessId,
            businessType: parsed.businessType,
            tier: parsed.tier,
            enabledModules: parsed.enabledModules,
            enabledFields: parsed.enabledFields,
            isDeleted: false,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
        };

        await putItem(item as unknown as Record<string, unknown>);
        return toConfig(item);
    }
}

// Keep a re-export so callers can build the SK without importing keys directly.
export { staffFeatureConfigSK };
