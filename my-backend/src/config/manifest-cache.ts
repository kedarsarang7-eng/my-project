// ============================================================================
// Manifest Cache — In-Memory Cache for Feature Manifests
// ============================================================================
// Provides cached retrieval of signed feature manifests per tenant.
// Replaced Redis with in-memory cache (Lambda-warm-instance scoped).
//
// Key pattern: manifest:{tenantId}
// TTL: 3600s (1 hour)
// ============================================================================

import { getCached, invalidateCache, invalidateCacheByPrefix } from '../utils/cache';
import { logger } from '../utils/logger';

const MANIFEST_TTL_SECONDS = 3600; // 1 hour
const MANIFEST_KEY_PREFIX = 'manifest:';

// In-memory rate limiter (per Lambda instance)
const rateLimitMap = new Map<string, { count: number; expiresAt: number }>();
const RATE_LIMIT_MAX = 10;    // max validations per minute per tenant
const RATE_LIMIT_WINDOW = 60; // seconds

export interface CachedManifest {
    tenantId: string;
    planTier: string;
    businessType: string;
    allowedFeatures: string[];
    manifestHash: string;
    signedToken: string;
    expiresAt: string;
}

// In-memory manifest storage (separate from general cache for manifest-specific logic)
const manifestStore = new Map<string, { data: CachedManifest; expiresAt: number }>();

/**
 * Get cached feature manifest for a tenant.
 * Returns null if not cached or expired.
 */
export async function getCachedManifest(tenantId: string): Promise<CachedManifest | null> {
    const key = `${MANIFEST_KEY_PREFIX}${tenantId}`;
    const entry = manifestStore.get(key);
    if (entry && entry.expiresAt > Date.now()) {
        return entry.data;
    }
    if (entry) {
        manifestStore.delete(key);
    }
    return null;
}

/**
 * Store feature manifest in cache.
 */
export async function setCachedManifest(
    tenantId: string,
    manifest: CachedManifest,
): Promise<void> {
    const key = `${MANIFEST_KEY_PREFIX}${tenantId}`;
    manifestStore.set(key, {
        data: manifest,
        expiresAt: Date.now() + (MANIFEST_TTL_SECONDS * 1000),
    });
}

/**
 * Invalidate (delete) a tenant's cached manifest.
 * Called on plan upgrade/downgrade.
 */
export async function invalidateManifest(tenantId: string): Promise<void> {
    const key = `${MANIFEST_KEY_PREFIX}${tenantId}`;
    manifestStore.delete(key);
    invalidateCache(`manifest:${tenantId}`);
    logger.info('Manifest cache invalidated', { tenantId });
}

/**
 * Invalidate all cached manifests.
 * Used when feature registry is updated globally.
 */
export async function invalidateAllManifests(): Promise<void> {
    let count = 0;
    for (const key of Array.from(manifestStore.keys())) {
        if (key.startsWith(MANIFEST_KEY_PREFIX)) {
            manifestStore.delete(key);
            count++;
        }
    }
    invalidateCacheByPrefix('manifest:');
    logger.info('All manifest caches invalidated', { keyCount: count });
}

/**
 * Check license validation rate limit for a tenant.
 * Returns true if within limit, false if rate exceeded.
 * Uses in-memory Map (per Lambda instance).
 */
export async function checkLicenseValidationRate(tenantId: string): Promise<boolean> {
    const key = `ratelimit:license:${tenantId}`;
    const now = Date.now();

    const entry = rateLimitMap.get(key);
    if (entry && entry.expiresAt > now) {
        entry.count++;
        return entry.count <= RATE_LIMIT_MAX;
    }

    // New window
    rateLimitMap.set(key, {
        count: 1,
        expiresAt: now + (RATE_LIMIT_WINDOW * 1000),
    });
    return true;
}
