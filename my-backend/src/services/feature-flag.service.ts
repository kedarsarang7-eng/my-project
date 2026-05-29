// ============================================================================
// Feature Flag Service — Migrated from sls/backend
// ============================================================================
// Migrated from: sls/backend/src/services/featureFlagService.ts
// Adapted for my-backend Lambda architecture

import { logger } from '../utils/logger';
import { docClient, TABLE_NAME } from '../config/dynamodb.config';
import {
    GetCommand,
    PutCommand,
    DeleteCommand,
    ScanCommand,
} from '@aws-sdk/lib-dynamodb';
import * as crypto from 'crypto';

// ---- DynamoDB Key Patterns ----

const FF_PK_PREFIX = 'FEATUREFLAG';
const FF_SK = 'CONFIG';

function ffPK(flagKey: string): string {
    return `${FF_PK_PREFIX}#${flagKey}`;
}

// ---- Types ----

export interface FeatureFlag {
    id: string;
    flag_key: string;
    display_name: string;
    description: string | null;
    flag_type: string;
    default_value: any;
    plan_overrides: Record<string, any>;
    min_app_version: string | null;
    rollout_percentage: number;
    is_active: boolean;
    created_by: string | null;
    updated_by: string | null;
    created_at: string;
    updated_at: string;
}

// ---- In-Memory Cache ----

let _flagCache: { data: FeatureFlag[]; expiresAt: number } | null = null;
const FLAG_CACHE_TTL_MS = 5 * 60 * 1000;

function invalidateFlagCache(): void {
    _flagCache = null;
}

// ---- CRUD Operations ----

/**
 * Get all feature flags from DynamoDB
 */
export async function listFeatureFlags(): Promise<FeatureFlag[]> {
    if (_flagCache && _flagCache.expiresAt > Date.now()) {
        return _flagCache.data;
    }

    try {
        const result = await docClient.send(new ScanCommand({
            TableName: TABLE_NAME,
            FilterExpression: 'begins_with(PK, :prefix) AND SK = :sk',
            ExpressionAttributeValues: {
                ':prefix': FF_PK_PREFIX,
                ':sk': FF_SK,
            },
        }));

        if (result.Items && result.Items.length > 0) {
            const flags = result.Items.map(item => dynamoToFeatureFlag(item));
            _flagCache = { data: flags, expiresAt: Date.now() + FLAG_CACHE_TTL_MS };
            return flags;
        }
    } catch (error: any) {
        logger.error('DynamoDB feature flag scan failed', { error: error.message });
        return [];
    }

    return [];
}

/**
 * Get a single feature flag by key
 */
export async function getFeatureFlag(flagKey: string): Promise<FeatureFlag | null> {
    try {
        const result = await docClient.send(new GetCommand({
            TableName: TABLE_NAME,
            Key: { PK: ffPK(flagKey), SK: FF_SK },
        }));

        if (result.Item) {
            return dynamoToFeatureFlag(result.Item);
        }
    } catch (error: any) {
        logger.error('DynamoDB feature flag get failed', { flagKey, error: error.message });
        return null;
    }

    return null;
}

/**
 * Create a new feature flag
 */
export async function createFeatureFlag(params: {
    flag_key: string;
    display_name: string;
    description?: string;
    flag_type?: string;
    default_value?: any;
    plan_overrides?: Record<string, any>;
    min_app_version?: string;
    rollout_percentage?: number;
    created_by: string;
}): Promise<FeatureFlag> {
    const now = new Date().toISOString();
    const id = crypto.randomUUID();

    const flag: Record<string, any> = {
        PK: ffPK(params.flag_key),
        SK: FF_SK,
        entityType: 'FEATURE_FLAG',
        id,
        flag_key: params.flag_key,
        display_name: params.display_name,
        description: params.description || null,
        flag_type: params.flag_type || 'boolean',
        default_value: params.default_value ?? false,
        plan_overrides: params.plan_overrides || {},
        min_app_version: params.min_app_version || null,
        rollout_percentage: params.rollout_percentage ?? 100,
        is_active: true,
        created_by: params.created_by,
        updated_by: params.created_by,
        created_at: now,
        updated_at: now,
    };

    await docClient.send(new PutCommand({
        TableName: TABLE_NAME,
        Item: flag,
        ConditionExpression: 'attribute_not_exists(PK)',
    }));

    invalidateFlagCache();
    logger.info('Feature flag created', { key: params.flag_key });

    return dynamoToFeatureFlag(flag);
}

/**
 * Update a feature flag
 */
export async function updateFeatureFlag(
    flagKey: string,
    updates: Partial<{
        display_name: string;
        description: string;
        default_value: any;
        plan_overrides: Record<string, any>;
        min_app_version: string;
        rollout_percentage: number;
        is_active: boolean;
    }>,
    updatedBy: string
): Promise<FeatureFlag | null> {
    const current = await getFeatureFlag(flagKey);
    if (!current) return null;

    const merged: Record<string, any> = {
        PK: ffPK(flagKey),
        SK: FF_SK,
        entityType: 'FEATURE_FLAG',
        id: current.id,
        flag_key: flagKey,
        display_name: updates.display_name ?? current.display_name,
        description: updates.description ?? current.description,
        flag_type: current.flag_type,
        default_value: updates.default_value ?? current.default_value,
        plan_overrides: updates.plan_overrides ?? current.plan_overrides,
        min_app_version: updates.min_app_version ?? current.min_app_version,
        rollout_percentage: updates.rollout_percentage ?? current.rollout_percentage,
        is_active: updates.is_active ?? current.is_active,
        created_by: current.created_by,
        updated_by: updatedBy,
        created_at: current.created_at,
        updated_at: new Date().toISOString(),
    };

    await docClient.send(new PutCommand({
        TableName: TABLE_NAME,
        Item: merged,
    }));

    invalidateFlagCache();
    logger.info('Feature flag updated', { key: flagKey, updatedBy });

    return dynamoToFeatureFlag(merged);
}

/**
 * Delete a feature flag
 */
export async function deleteFeatureFlag(flagKey: string): Promise<boolean> {
    try {
        await docClient.send(new DeleteCommand({
            TableName: TABLE_NAME,
            Key: { PK: ffPK(flagKey), SK: FF_SK },
        }));
        invalidateFlagCache();
        return true;
    } catch (error: any) {
        logger.error('Failed to delete feature flag', { flagKey, error: error.message });
        return false;
    }
}

// ---- Feature Flag Resolution ----

/**
 * Resolve feature flags for a tenant/plan
 */
export async function resolveFeatureFlags(params: {
    plan: string;
    app_version?: string;
    license_key?: string;
    license_feature_flags?: Record<string, any>;
}): Promise<{
    flags: Record<string, any>;
    config_hash: string;
}> {
    const allFlags = await listFeatureFlags();
    const resolved: Record<string, any> = {};

    for (const flag of allFlags) {
        if (!flag.is_active) continue;

        // Check version gate
        if (flag.min_app_version && params.app_version) {
            if (compareVersions(params.app_version, flag.min_app_version) < 0) {
                continue;
            }
        }

        // Check rollout percentage (deterministic based on license key)
        if (flag.rollout_percentage < 100 && params.license_key) {
            const hash = crypto.createHash('md5')
                .update(`${flag.flag_key}:${params.license_key}`)
                .digest();
            const bucket = hash[0]! % 100;
            if (bucket >= flag.rollout_percentage) {
                resolved[flag.flag_key] = flag.default_value;
                continue;
            }
        }

        // Resolve value: license override > plan override > default
        if (params.license_feature_flags && params.license_feature_flags[flag.flag_key] !== undefined) {
            resolved[flag.flag_key] = params.license_feature_flags[flag.flag_key];
        } else if (flag.plan_overrides && flag.plan_overrides[params.plan.toLowerCase()] !== undefined) {
            resolved[flag.flag_key] = flag.plan_overrides[params.plan.toLowerCase()];
        } else {
            resolved[flag.flag_key] = flag.default_value;
        }
    }

    // Generate config hash for client-side caching
    const config_hash = crypto.createHash('sha256')
        .update(JSON.stringify(resolved))
        .digest('hex')
        .substring(0, 16);

    return { flags: resolved, config_hash };
}

// ---- Helpers ----

function dynamoToFeatureFlag(item: Record<string, any>): FeatureFlag {
    return {
        id: item.id || '',
        flag_key: item.flag_key || item.PK?.replace(`${FF_PK_PREFIX}#`, ''),
        display_name: item.display_name || '',
        description: item.description || null,
        flag_type: item.flag_type || 'boolean',
        default_value: item.default_value ?? false,
        plan_overrides: item.plan_overrides || {},
        min_app_version: item.min_app_version || null,
        rollout_percentage: item.rollout_percentage ?? 100,
        is_active: item.is_active ?? true,
        created_by: item.created_by || null,
        updated_by: item.updated_by || null,
        created_at: item.created_at || '',
        updated_at: item.updated_at || '',
    };
}

function compareVersions(v1: string, v2: string): number {
    const parts1 = v1.split('.').map(Number);
    const parts2 = v2.split('.').map(Number);

    for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
        const p1 = parts1[i] || 0;
        const p2 = parts2[i] || 0;
        if (p1 > p2) return 1;
        if (p1 < p2) return -1;
    }
    return 0;
}

// ---- Default Export ----

export default {
    listFeatureFlags,
    getFeatureFlag,
    createFeatureFlag,
    updateFeatureFlag,
    deleteFeatureFlag,
    resolveFeatureFlags,
};
