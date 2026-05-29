// ============================================================================
// Caching Layer — ElastiCache Redis / In-Process Fallback
// ============================================================================
// Provides a unified caching API. In production, backed by ElastiCache Redis.
// In Lambda (no Redis configured), falls back to a process-level LRU cache.
//
// Primary use cases:
//   - Tenant config / plan tier lookups (per-request overhead if hitting DDB)
//   - Feature flag snapshots (refreshed every 60s)
//   - Rate limit counters (atomic incr/decr)
//   - Module manifest snapshots (immutable at cold-start)
//
// Usage:
//   import { cache } from '../core/db/cache';
//   const tenant = await cache.get<TenantConfig>(`tenant:${id}`);
//   await cache.set(`tenant:${id}`, config, 300); // TTL 5 min
// ============================================================================

import { logger } from '../../utils/logger';

// ── Types ────────────────────────────────────────────────────────────────────

export interface CacheOptions {
    /** TTL in seconds. Defaults to 300 (5 minutes). */
    ttl?: number;
    /** Namespace prefix added automatically to all keys */
    namespace?: string;
}

interface CacheEntry<T> {
    value: T;
    expiresAt: number;
}

// ── Process-level LRU fallback ────────────────────────────────────────────────
// Used when REDIS_URL is not configured (local dev / Lambda without Redis)

const MAX_LRU_ENTRIES = 1000;
const _lruCache = new Map<string, CacheEntry<unknown>>();

function lruGet<T>(key: string): T | null {
    const entry = _lruCache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
        _lruCache.delete(key);
        return null;
    }
    return entry.value as T;
}

function lruSet<T>(key: string, value: T, ttlSeconds: number): void {
    if (_lruCache.size >= MAX_LRU_ENTRIES) {
        // Evict oldest entry
        const firstKey = _lruCache.keys().next().value;
        if (firstKey) _lruCache.delete(firstKey);
    }
    _lruCache.set(key, { value, expiresAt: Date.now() + ttlSeconds * 1000 });
}

function lruDel(key: string): void {
    _lruCache.delete(key);
}

function lruFlushPattern(pattern: string): void {
    const prefix = pattern.replace('*', '');
    for (const key of _lruCache.keys()) {
        if (key.startsWith(prefix)) _lruCache.delete(key);
    }
}

// ── Redis client (lazy-loaded to avoid cold start penalty) ───────────────────

let _redisClient: any = null;
let _redisAvailable = false;

async function getRedisClient(): Promise<any | null> {
    if (_redisClient) return _redisAvailable ? _redisClient : null;

    const redisUrl = process.env.REDIS_URL;
    if (!redisUrl) {
        logger.debug('Cache: No REDIS_URL configured, using in-process LRU cache');
        _redisAvailable = false;
        return null;
    }

    try {
        // Dynamically import ioredis to avoid cold start penalty in non-Redis envs
        const { default: Redis } = await import('ioredis');
        _redisClient = new Redis(redisUrl, {
            enableReadyCheck: true,
            maxRetriesPerRequest: 2,
            connectTimeout: 2000,
            lazyConnect: true,
        });
        await _redisClient.connect();
        _redisAvailable = true;
        logger.info('Cache: Redis connected');
    } catch (err) {
        logger.warn('Cache: Redis connection failed, falling back to LRU', { error: (err as Error).message });
        _redisAvailable = false;
    }

    return _redisAvailable ? _redisClient : null;
}

// ── Public API ────────────────────────────────────────────────────────────────

class CacheService {
    private defaultTtl = 300; // 5 minutes

    private buildKey(key: string, ns?: string): string {
        return ns ? `dukanx:${ns}:${key}` : `dukanx:${key}`;
    }

    async get<T>(key: string, opts?: CacheOptions): Promise<T | null> {
        const fullKey = this.buildKey(key, opts?.namespace);
        const redis = await getRedisClient();
        if (redis) {
            try {
                const raw = await redis.get(fullKey);
                if (!raw) return null;
                return JSON.parse(raw) as T;
            } catch (err) {
                logger.warn('Cache: Redis GET failed', { key: fullKey, error: (err as Error).message });
            }
        }
        return lruGet<T>(fullKey);
    }

    async set<T>(key: string, value: T, opts?: CacheOptions): Promise<void> {
        const ttl = opts?.ttl ?? this.defaultTtl;
        const fullKey = this.buildKey(key, opts?.namespace);
        const redis = await getRedisClient();
        if (redis) {
            try {
                await redis.setex(fullKey, ttl, JSON.stringify(value));
                return;
            } catch (err) {
                logger.warn('Cache: Redis SET failed, writing to LRU', { key: fullKey, error: (err as Error).message });
            }
        }
        lruSet(fullKey, value, ttl);
    }

    async del(key: string, opts?: CacheOptions): Promise<void> {
        const fullKey = this.buildKey(key, opts?.namespace);
        const redis = await getRedisClient();
        if (redis) {
            try {
                await redis.del(fullKey);
                return;
            } catch (err) {
                logger.warn('Cache: Redis DEL failed', { key: fullKey });
            }
        }
        lruDel(fullKey);
    }

    /** Invalidate all keys matching a prefix pattern (e.g. 'tenant:abc*') */
    async invalidatePattern(pattern: string, opts?: CacheOptions): Promise<void> {
        const fullPattern = this.buildKey(pattern, opts?.namespace);
        const redis = await getRedisClient();
        if (redis) {
            try {
                const keys: string[] = await redis.keys(fullPattern);
                if (keys.length > 0) await redis.del(...keys);
                return;
            } catch (err) {
                logger.warn('Cache: Redis KEYS invalidation failed', { pattern: fullPattern });
            }
        }
        lruFlushPattern(fullPattern);
    }

    /**
     * Get-or-set pattern: fetch from cache, or call loader fn and cache result.
     * This is the preferred usage pattern — avoids thundering herd.
     */
    async getOrSet<T>(
        key: string,
        loader: () => Promise<T>,
        opts?: CacheOptions,
    ): Promise<T> {
        const cached = await this.get<T>(key, opts);
        if (cached !== null) return cached;

        const value = await loader();
        await this.set(key, value, opts);
        return value;
    }

    /** Atomic increment — used for rate limiting counters */
    async incr(key: string, ttlSeconds = 60): Promise<number> {
        const fullKey = this.buildKey(key);
        const redis = await getRedisClient();
        if (redis) {
            try {
                const pipeline = redis.pipeline();
                pipeline.incr(fullKey);
                pipeline.expire(fullKey, ttlSeconds);
                const results = await pipeline.exec();
                return (results?.[0]?.[1] as number) ?? 1;
            } catch (err) {
                logger.warn('Cache: Redis INCR failed', { key: fullKey });
            }
        }
        // LRU fallback for rate limiting
        const current = (lruGet<number>(fullKey) ?? 0) + 1;
        lruSet(fullKey, current, ttlSeconds);
        return current;
    }

    /** Flush entire in-process LRU (useful for testing) */
    flushLocal(): void {
        _lruCache.clear();
    }
}

export const cache = new CacheService();

// ── Common Cache Keys ─────────────────────────────────────────────────────────
// Use these builders for consistent key naming across handlers.

export const CacheKeys = {
    tenantConfig: (tenantId: string) => `tenant:config:${tenantId}`,
    tenantPlan: (tenantId: string) => `tenant:plan:${tenantId}`,
    tenantModules: (tenantId: string) => `tenant:modules:${tenantId}`,
    featureFlags: (tenantId: string) => `tenant:flags:${tenantId}`,
    rateLimit: (tenantId: string, window: string) => `ratelimit:${tenantId}:${window}`,
    goldRate: (date: string) => `goldrate:${date}`,
    productCatalog: (tenantId: string, page: number) => `catalog:${tenantId}:p${page}`,
    hsnLookup: (hsn: string) => `hsn:${hsn}`,
};

/** TTL presets in seconds */
export const CacheTtl = {
    VERY_SHORT: 30,       // rate limit windows
    SHORT: 60,            // frequently changing data
    MEDIUM: 300,          // 5 min — tenant config, feature flags
    LONG: 3600,           // 1 hour — HSN data, gold rates
    VERY_LONG: 86400,     // 24 hours — static reference data
} as const;
