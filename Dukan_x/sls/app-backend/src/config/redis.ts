// ============================================
// Redis Client Configuration
// ============================================

import { createClient, RedisClientType } from 'redis';
import { logger } from '../utils/logger';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const REDIS_PREFIX = process.env.REDIS_PREFIX || 'app:';
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
 * Prefixed key helper — all app-backend keys use `app:` prefix
 * to avoid collisions with sls-backend (`sls:` prefix).
 */
export function appKey(key: string): string {
    return `${REDIS_PREFIX}${key}`;
}

/**
 * Rate limiter check using Redis sliding window counter.
 */
export async function checkRateLimit(
    identifier: string,
    maxRequests: number,
    windowMs: number
): Promise<{ allowed: boolean; remaining: number; resetIn: number }> {
    const client = await getRedisClient();
    if (!client) return { allowed: true, remaining: maxRequests, resetIn: windowMs };
    const key = appKey(`rate:${identifier}`);
    const now = Date.now();
    const windowStart = now - windowMs;

    const multi = client.multi();
    multi.zRemRangeByScore(key, 0, windowStart);
    multi.zAdd(key, { score: now, value: `${now}` });
    multi.zCard(key);
    multi.pExpire(key, windowMs);

    const results = await multi.exec();
    const requestCount = results[2] as number;
    const allowed = requestCount <= maxRequests;
    const remaining = Math.max(0, maxRequests - requestCount);

    return { allowed, remaining, resetIn: windowMs };
}
