// ============================================
// Redis Client Configuration
// ============================================

import { createClient, RedisClientType } from 'redis';
import { logger } from '../utils/logger';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const REDIS_PREFIX = process.env.REDIS_PREFIX || 'sls:';
const REDIS_ENABLED = process.env.REDIS_ENABLED === 'true';

let redisClient: RedisClientType | null = null;

export async function getRedisClient(): Promise<RedisClientType | null> {
    if (!REDIS_ENABLED) return null;
    if (!redisClient) {
        redisClient = createClient({ url: REDIS_URL });

        redisClient.on('error', (err) => {
            logger.error('Redis Client Error', { error: err.message });
        });

        redisClient.on('connect', () => {
            logger.info('Redis connected');
        });

        await redisClient.connect();
    }
    return redisClient;
}

/**
 * Prefixed key helper — all SLS keys use `sls:` prefix
 * to avoid collisions if sharing a Redis instance.
 */
export function slsKey(key: string): string {
    return `${REDIS_PREFIX}${key}`;
}

/**
 * Cache a license validation result.
 */
export async function cacheLicenseValidation(keyHash: string, data: object, ttlSeconds = 300): Promise<void> {
    const client = await getRedisClient();
    if (!client) return;
    await client.setEx(slsKey(`license:${keyHash}`), ttlSeconds, JSON.stringify(data));
}

/**
 * Get cached license validation result.
 */
export async function getCachedValidation(keyHash: string): Promise<object | null> {
    const client = await getRedisClient();
    if (!client) return null;
    const cached = await client.get(slsKey(`license:${keyHash}`));
    return cached ? JSON.parse(cached) : null;
}

/**
 * Invalidate cached license data (call on any license update).
 */
export async function invalidateLicenseCache(keyHash: string): Promise<void> {
    const client = await getRedisClient();
    if (!client) return;
    await client.del(slsKey(`license:${keyHash}`));
}

/**
 * Rate limiter check using Redis sliding window counter.
 * Returns { allowed: boolean, remaining: number, resetIn: number }
 */
export async function checkRateLimit(
    identifier: string,
    maxRequests: number,
    windowMs: number
): Promise<{ allowed: boolean; remaining: number; resetIn: number }> {
    const client = await getRedisClient();
    if (!client) return { allowed: true, remaining: maxRequests, resetIn: windowMs };
    const key = slsKey(`rate:${identifier}`);
    const now = Date.now();
    const windowStart = now - windowMs;

    // Use Redis sorted set for sliding window
    const multi = client.multi();
    multi.zRemRangeByScore(key, 0, windowStart);     // remove expired entries
    multi.zAdd(key, { score: now, value: `${now}` }); // add current request
    multi.zCard(key);                                  // count requests in window
    multi.pExpire(key, windowMs);                      // set TTL on the key

    const results = await multi.exec();
    const requestCount = results[2] as number;
    const allowed = requestCount <= maxRequests;
    const remaining = Math.max(0, maxRequests - requestCount);

    return { allowed, remaining, resetIn: windowMs };
}

/**
 * Store a nonce for replay attack prevention.
 */
export async function storeNonce(nonce: string, ttlSeconds = 60): Promise<boolean> {
    const client = await getRedisClient();
    if (!client) return true;
    const key = slsKey(`nonce:${nonce}`);
    // SET NX = only set if not exists. Returns true if set (nonce is fresh)
    const result = await client.set(key, '1', { NX: true, EX: ttlSeconds });
    return result === 'OK';
}

/**
 * Track active sessions count for analytics.
 */
export async function updateActiveUserCount(count: number): Promise<void> {
    const client = await getRedisClient();
    if (!client) return;
    await client.setEx(slsKey('analytics:active_users'), 60, count.toString());
}

export async function getActiveUserCount(): Promise<number> {
    const client = await getRedisClient();
    if (!client) return 0;
    const count = await client.get(slsKey('analytics:active_users'));
    return count ? parseInt(count, 10) : 0;
}
