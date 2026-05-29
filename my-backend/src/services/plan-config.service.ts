// ============================================================================
// Plan Config Service — Hybrid: Code Defaults + DB Overrides
// ============================================================================
// Design principle:
//   1. The code registry (plan-feature-registry.ts) is the authoritative DEFAULT.
//   2. DynamoDB stores only DELTAS (overrides) on top of the code defaults.
//   3. At runtime, effective config = code_defaults ∪ db_overrides.added \ db_overrides.removed.
//
// This gives Super Admin the ability to edit plan defaults live without a deploy,
// while keeping the "no hardcoded permissions" rule practically enforceable:
// the code registry is a seed, not a runtime authority.
//
// DynamoDB schema (single table, PK=PLANCONFIG#<plan>, SK=META):
//   {
//     PK: "PLANCONFIG#basic",
//     SK: "META",
//     entityType: "PLAN_CONFIG",
//     plan: "basic",
//     defaultFeatures: ["dashboard", "basic_inventory", ...],  // optional override
//     limits: { maxUsers: 5, ... },                           // optional override
//     overrides: {
//       added: ["barcode_tag_printing"],   // extra features beyond code default
//       removed: ["basic_reorder_alerts"] // features stripped from code default
//     },
//     updatedAt: "2025-06-01T10:00:00Z",
//     updatedBy: "superadmin"
//   }
// ============================================================================

import { Keys, getItem, putItem, updateItem, queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import {
    PlanTier,
    FeatureKey,
    PLAN_CORE_FEATURES,
    PLAN_BUSINESS_FEATURES,
    PLAN_LIMITS,
    PlanLimits,
    getAllowedFeatures,
    mapToPlanTier,
} from '../config/plan-feature-registry';

// Re-export PlanTier for consumers of this service
export { PlanTier };

const PLANCONFIG_PK_PREFIX = 'PLANCONFIG#';

export interface PlanConfigRecord {
    plan: PlanTier;
    defaultFeatures?: FeatureKey[];     // full override list (rare)
    limits?: Partial<PlanLimits>;        // per-limit overrides
    overrides: {
        added: FeatureKey[];
        removed: FeatureKey[];
    };
    updatedAt: string;
    updatedBy: string;
}

export interface EffectivePlanConfig {
    plan: PlanTier;
    source: 'code' | 'db_override' | 'db_full';
    defaultFeatures: FeatureKey[];
    limits: PlanLimits;
    overrides: {
        added: FeatureKey[];
        removed: FeatureKey[];
    };
}

/**
 * Get the raw PlanConfig record from DynamoDB (if any).
 * Returns null if no DB row exists — caller should fall back to code defaults.
 */
export async function getPlanConfigFromDB(plan: PlanTier): Promise<PlanConfigRecord | null> {
    const pk = `${PLANCONFIG_PK_PREFIX}${plan}`;
    const item = await getItem<Record<string, any>>(pk, 'META');
    if (!item) return null;

    return {
        plan: item.plan as PlanTier,
        defaultFeatures: item.defaultFeatures,
        limits: item.limits,
        overrides: {
            added: Array.isArray(item.overrides?.added) ? item.overrides.added : [],
            removed: Array.isArray(item.overrides?.removed) ? item.overrides.removed : [],
        },
        updatedAt: item.updatedAt || item.updatedAt || new Date().toISOString(),
        updatedBy: item.updatedBy || 'system',
    };
}

/**
 * Compute effective plan configuration by merging code defaults with DB overrides.
 *
 * Algorithm:
 *   baseFeatures = code registry for this plan (core + optional business filter)
 *   if DB record exists with defaultFeatures → replace baseFeatures entirely (source='db_full')
 *   else apply DB overrides.added / overrides.removed on top of baseFeatures (source='db_override')
 *   limits = code registry limits, overridden by any DB.limits fields present
 */
export async function getEffectivePlanConfig(
    plan: PlanTier,
    businessType?: string,
): Promise<EffectivePlanConfig> {
    const db = await getPlanConfigFromDB(plan);

    // Base features from code registry
    let defaultFeatures: FeatureKey[] = businessType
        ? getAllowedFeatures(plan, businessType as any)
        : [...PLAN_CORE_FEATURES[plan]];

    let source: EffectivePlanConfig['source'] = 'code';
    let overrides = { added: [] as FeatureKey[], removed: [] as FeatureKey[] };

    if (db) {
        overrides = db.overrides;
        if (db.defaultFeatures && db.defaultFeatures.length > 0) {
            // Full replacement mode — DB owns the entire feature list
            defaultFeatures = db.defaultFeatures;
            source = 'db_full';
        } else {
            // Delta mode — apply added/removed on top of code defaults
            defaultFeatures = applyOverrides(defaultFeatures, overrides);
            source = db.overrides.added.length || db.overrides.removed.length ? 'db_override' : 'code';
        }
    }

    // Limits: start with code, overlay any DB overrides
    const codeLimits = PLAN_LIMITS[plan];
    const effectiveLimits: PlanLimits = {
        maxUsers: db?.limits?.maxUsers ?? codeLimits.maxUsers,
        maxProducts: db?.limits?.maxProducts ?? codeLimits.maxProducts,
        maxBranches: db?.limits?.maxBranches ?? codeLimits.maxBranches,
        maxDevices: db?.limits?.maxDevices ?? codeLimits.maxDevices,
        maxBusinessTypes: db?.limits?.maxBusinessTypes ?? codeLimits.maxBusinessTypes,
    };

    return {
        plan,
        source,
        defaultFeatures,
        limits: effectiveLimits,
        overrides,
    };
}

/**
 * Apply added/removed overrides to a base feature list.
 */
function applyOverrides(base: FeatureKey[], overrides: { added: FeatureKey[]; removed: FeatureKey[] }): FeatureKey[] {
    const set = new Set<FeatureKey>(base);
    for (const f of overrides.added) set.add(f);
    for (const f of overrides.removed) set.delete(f);
    return Array.from(set);
}

/**
 * List all plan configs (code + DB overlay). Used by Super Admin panel.
 */
export async function listPlanConfigs(): Promise<EffectivePlanConfig[]> {
    const tiers = [PlanTier.BASIC, PlanTier.PRO, PlanTier.PREMIUM, PlanTier.ENTERPRISE];
    const results = await Promise.all(tiers.map((t) => getEffectivePlanConfig(t)));
    return results;
}

/**
 * Update (or create) a PlanConfig record in DynamoDB with delta overrides.
 * This is the "manual edit" path for Super Admin — it never deletes the code registry,
 * only writes a DB row that layers on top.
 *
 * @param plan             which plan tier to edit
 * @param delta            features to add/remove, or limits to patch
 * @param adminId          who made the change (for audit)
 * @param replaceDefaults  if true, write full defaultFeatures (DB becomes authority)
 */
export async function updatePlanConfig(
    plan: PlanTier,
    delta: {
        addFeatures?: FeatureKey[];
        removeFeatures?: FeatureKey[];
        limits?: Partial<PlanLimits>;
        replaceDefaults?: FeatureKey[]; // optional full replacement
    },
    adminId: string,
): Promise<PlanConfigRecord> {
    const pk = `${PLANCONFIG_PK_PREFIX}${plan}`;
    const now = new Date().toISOString();

    // Read existing to merge (set-style merge for add/remove)
    const existing = await getPlanConfigFromDB(plan);
    const baseAdded = existing?.overrides?.added ?? [];
    const baseRemoved = existing?.overrides?.removed ?? [];

    const addedSet = new Set<FeatureKey>(baseAdded);
    const removedSet = new Set<FeatureKey>(baseRemoved);

    // Apply delta
    for (const f of delta.addFeatures ?? []) {
        addedSet.add(f);
        removedSet.delete(f); // adding cancels a prior removal
    }
    for (const f of delta.removeFeatures ?? []) {
        removedSet.add(f);
        addedSet.delete(f); // removing cancels a prior addition
    }

    const overrides = {
        added: Array.from(addedSet),
        removed: Array.from(removedSet),
    };

    // Build the item to persist
    const item: Record<string, any> = {
        PK: pk,
        SK: 'META',
        entityType: 'PLAN_CONFIG',
        plan,
        overrides,
        limits: {
            ...(existing?.limits ?? {}),
            ...(delta.limits ?? {}),
        },
        updatedAt: now,
        updatedBy: adminId,
    };

    if (delta.replaceDefaults && delta.replaceDefaults.length > 0) {
        item.defaultFeatures = delta.replaceDefaults;
    } else if (existing?.defaultFeatures) {
        // Preserve any previous full-replacement list unless explicitly cleared
        item.defaultFeatures = existing.defaultFeatures;
    }

    // TTL: keep DB rows for 2 years (maintenance-friendly)
    item.TTL = Math.floor(Date.now() / 1000) + (2 * 365 * 24 * 60 * 60);

    await putItem(item);

    logger.info('PlanConfig updated', {
        plan,
        added: overrides.added.length,
        removed: overrides.removed.length,
        by: adminId,
    });

    // ENHANCED: Write audit log
    const { auditPlanConfigUpdate } = await import('./audit-log.service');
    await auditPlanConfigUpdate(adminId, plan, {
        added: delta.addFeatures,
        removed: delta.removeFeatures,
        limits: delta.limits,
        replaceDefaults: delta.replaceDefaults,
    }).catch((err: Error) => logger.warn('Audit log failed (non-critical)', { error: err.message }));

    return {
        plan,
        defaultFeatures: item.defaultFeatures,
        limits: item.limits,
        overrides,
        updatedAt: now,
        updatedBy: adminId,
    };
}

/**
 * Reset a plan config to code defaults (delete the DB row).
 * Super Admin can use this to "restore factory defaults".
 */
export async function resetPlanConfigToDefaults(plan: PlanTier, adminId: string): Promise<void> {
    const pk = `${PLANCONFIG_PK_PREFIX}${plan}`;
    // We delete the DB row — next read will fall back to code registry
    const { deleteItem } = await import('../config/dynamodb.config');
    await deleteItem(pk, 'META');
    logger.info('PlanConfig reset to code defaults', { plan, by: adminId });

    // ENHANCED: Write audit log
    const { writeAuditLog } = await import('./audit-log.service');
    await writeAuditLog({
        actor: { id: adminId, type: 'admin', role: 'super_admin' },
        action: 'plan_config_reset',
        category: 'plan_change',
        target: { type: 'plan_config', id: plan },
        metadata: { resetTo: 'code_defaults' },
    }).catch((err: Error) => logger.warn('Audit log failed (non-critical)', { error: err.message }));
}

/**
 * Admin utility: list all PlanConfig DB rows (raw, for audit/troubleshooting).
 */
export async function listRawPlanConfigRows(): Promise<PlanConfigRecord[]> {
    // Query GSI or scan limited to PK prefix PLANCONFIG#
    const { queryItems } = await import('../config/dynamodb.config');
    // Since we use single table, use begins_with style query if GSI exists,
    // otherwise scan with filter (small table, admin-only, acceptable).
    const result = await queryItems<Record<string, any>>(PLANCONFIG_PK_PREFIX, undefined, {
        limit: 100,
    });
    return result.items
        .filter((i) => i.PK && i.PK.startsWith(PLANCONFIG_PK_PREFIX))
        .map((i) => ({
            plan: i.plan as PlanTier,
            defaultFeatures: i.defaultFeatures,
            limits: i.limits,
            overrides: {
                added: i.overrides?.added ?? [],
                removed: i.overrides?.removed ?? [],
            },
            updatedAt: i.updatedAt,
            updatedBy: i.updatedBy,
        }));
}

/**
 * Initialize DB with seed rows for every tier (idempotent).
 * Run once per environment or on registry version bump.
 */
export async function seedPlanConfigsIfMissing(adminId: string): Promise<void> {
    const tiers = [PlanTier.BASIC, PlanTier.PRO, PlanTier.PREMIUM, PlanTier.ENTERPRISE];
    for (const tier of tiers) {
        const existing = await getPlanConfigFromDB(tier);
        if (!existing) {
            // Create a marker row with empty overrides so DB "owns" the row
            await updatePlanConfig(tier, {}, adminId);
            logger.info('PlanConfig seeded', { tier, by: adminId });
        }
    }
}
