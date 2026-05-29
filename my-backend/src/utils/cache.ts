// ============================================================================
// In-Memory Cache — Lambda-Local LRU Cache (replaces dead Redis)
// ============================================================================
// Provides a simple in-memory cache that persists across warm Lambda
// invocations. Since Redis was removed from the architecture, this provides
// a lightweight alternative for caching expensive DynamoDB queries.
//
// PERF-14 FIX: Upgraded from FIFO to proper LRU eviction.
// - Accessed entries are moved to end (Map insertion order = LRU order)
// - Increased max entries from 200 to 500 for better multi-tenant hit rate
//
// Constraints:
//   - Cache is per-Lambda-instance (not shared across instances)
//   - Cache is lost on cold start (by design — not a durability layer)
//   - Max 500 entries with TTL-based expiry and LRU eviction
// ============================================================================

import { logger } from './logger';

interface CacheEntry<T> {
    data: T;
    expiresAt: number; // Unix timestamp in ms
}

const MAX_ENTRIES = 500; // PERF-14: Increased from 200 for better multi-tenant hit rate
const cache = new Map<string, CacheEntry<unknown>>();

/**
 * Get a value from cache, or compute and store it.
 *
 * @param key Cache key (e.g. `dashboard:${tenantId}`)
 * @param ttlSeconds Time-to-live in seconds
 * @param fetcher Async function that computes the value on cache miss
 * @returns The cached or freshly computed value
 */
export async function getCached<T>(
    key: string,
    ttlSeconds: number,
    fetcher: () => Promise<T>
): Promise<T> {
    const cacheKey = `cache:${key}`;

    // Check for cached entry
    const entry = cache.get(cacheKey) as CacheEntry<T> | undefined;
    if (entry && entry.expiresAt > Date.now()) {
        // PERF-14 FIX: LRU promotion — move accessed entry to end of Map
        // Map maintains insertion order; delete+set moves entry to newest position.
        cache.delete(cacheKey);
        cache.set(cacheKey, entry);
        logger.debug('Cache HIT', { key });
        return entry.data;
    }

    // Cache miss — remove stale entry
    if (entry) {
        cache.delete(cacheKey);
    }

    // Compute value
    logger.debug('Cache MISS', { key });
    const value = await fetcher();

    // Evict LRU entries if at capacity
    // PERF-14 FIX: Evict oldest (least recently used) entries — they are
    // at the front of the Map since LRU promotion pushes accessed entries to end.
    while (cache.size >= MAX_ENTRIES) {
        const firstKey = cache.keys().next().value;
        if (firstKey) {
            cache.delete(firstKey);
        } else {
            break;
        }
    }

    cache.set(cacheKey, {
        data: value,
        expiresAt: Date.now() + (ttlSeconds * 1000),
    });

    return value;
}

/**
 * Invalidate a cache entry.
 */
export function invalidateCache(key: string): void {
    const cacheKey = `cache:${key}`;
    cache.delete(cacheKey);
    logger.debug('Cache invalidated', { key });
}

/**
 * Invalidate all cache entries matching a prefix.
 */
export function invalidateCacheByPrefix(prefix: string): void {
    const targetPrefix = `cache:${prefix}`;
    let count = 0;
    for (const key of Array.from(cache.keys())) {
        if (key.startsWith(targetPrefix)) {
            cache.delete(key);
            count++;
        }
    }
    if (count > 0) {
        logger.debug('Cache prefix invalidated', { prefix, count });
    }
}

/**
 * Get cache stats for monitoring/debugging.
 */
export function getCacheStats(): { size: number; maxEntries: number } {
    return { size: cache.size, maxEntries: MAX_ENTRIES };
}
