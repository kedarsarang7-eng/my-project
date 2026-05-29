// ============================================================================
// Module Types — Plugin Architecture Contract
// ============================================================================
// Every business module MUST export a ModuleManifest conforming to this
// interface. The MODULE_REGISTRY assembles them at cold-start.
// NO business logic allowed in this file — pure types only.
// ============================================================================

import { BusinessType, UserRole } from '../../types/tenant.types';
import { PlanTier, FeatureKey } from '../../config/plan-feature-registry';

// ── Module Lifecycle Status ──────────────────────────────────────────────────
export type ModuleStatus = 'active' | 'deprecated' | 'beta' | 'disabled';

// ── WebSocket channel key builder for a module ───────────────────────────────
export type ChannelKeyBuilder = (tenantId: string) => string;

// ── SQS queue descriptor ─────────────────────────────────────────────────────
export interface ModuleQueue {
    /** Logical name used in serverless.yml */
    logicalName: string;
    /** Whether it is a FIFO queue */
    fifo: boolean;
    /** Max receive count before DLQ */
    maxReceiveCount: number;
    /** Visibility timeout seconds */
    visibilityTimeoutSeconds: number;
}

// ── EventBridge rule descriptor ──────────────────────────────────────────────
export interface ModuleEventPattern {
    /** Source pattern e.g. 'dukanx.grocery' */
    source: string;
    /** Detail-type patterns e.g. ['stock.low', 'batch.expiring'] */
    detailTypes: string[];
}

// ── DynamoDB partition ownership ─────────────────────────────────────────────
export interface ModuleDbConfig {
    /**
     * SK prefixes this module owns exclusively.
     * Used to document and validate no cross-module SK collisions.
     * e.g. ['GROCERY_BATCH#', 'GROCERY_EXPIRY#']
     */
    skPrefixes: string[];
    /**
     * GSI index names this module primarily queries.
     * e.g. ['GSI1', 'GSI4']
     */
    gsiIndexes: string[];
    /**
     * Whether this module requires write sharding for high-frequency
     * PK writes (e.g. grocery POS, restaurant KOT).
     */
    requiresWriteSharding?: boolean;
    /** Shard count when requiresWriteSharding = true */
    shardCount?: number;
}

// ── Rate limiting config per module ─────────────────────────────────────────
export interface ModuleRateLimits {
    [PlanTier.BASIC]: number;     // req/min
    [PlanTier.PRO]: number;
    [PlanTier.PREMIUM]: number;
    [PlanTier.ENTERPRISE]: number;
}

// ── Core ModuleManifest interface ────────────────────────────────────────────
export interface ModuleManifest {
    // ── Identity ──────────────────────────────────────────────────────────────
    /** Unique module ID — must match directory name under src/modules/ */
    id: string;
    /** Semver e.g. '1.0.0' */
    version: string;
    /** Human-readable label */
    displayName: string;
    /** Current lifecycle status */
    status: ModuleStatus;

    // ── Activation ────────────────────────────────────────────────────────────
    /** Which business types activate this module */
    businessTypes: BusinessType[];
    /** Minimum plan required to access this module */
    requiredPlan: PlanTier;
    /** All FeatureKeys this module provides */
    featureKeys: FeatureKey[];
    /** Minimum role to access any endpoint in this module */
    minRole: UserRole;

    // ── Infrastructure ────────────────────────────────────────────────────────
    /**
     * Lambda function names this module registers.
     * Must match keys in serverless.module.yml functions: block.
     */
    lambdaFunctions: string[];
    /** WebSocket channel prefix — e.g. 'grocery:' → channel = 'grocery:{tenantId}' */
    wsChannelPrefix: string;
    /** DynamoDB partitioning config */
    db: ModuleDbConfig;
    /** SQS queues this module owns */
    queues?: ModuleQueue[];
    /** EventBridge patterns this module listens to */
    eventPatterns?: ModuleEventPattern[];

    // ── Rate Limiting ─────────────────────────────────────────────────────────
    rateLimits?: ModuleRateLimits;

    // ── Routing ───────────────────────────────────────────────────────────────
    /** API path prefix e.g. '/grocery' — all module routes must start with this */
    apiPrefix: string;

    // ── Dependencies ─────────────────────────────────────────────────────────
    /**
     * Other module IDs this module depends on (shared services).
     * e.g. pharmacy depends on 'inventory'
     */
    dependsOn?: string[];

    // ── Future: AI / Marketplace ──────────────────────────────────────────────
    /** Whether this module exposes AI-friendly tool definitions */
    aiToolsEnabled?: boolean;
    /** Whether this module can be published to the plugin marketplace */
    marketplaceEligible?: boolean;
}
