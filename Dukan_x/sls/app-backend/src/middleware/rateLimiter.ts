// ============================================
// Rate Limiter Middleware
// ============================================

import { Request, Response, NextFunction } from 'express';
import { checkRateLimit } from '../config/redis';
import { logger } from '../utils/logger';

const DEFAULT_WINDOW_MS = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10);
const DEFAULT_MAX_REQUESTS = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '10', 10);

/**
 * Creates a rate limiter middleware using Redis sliding window.
 */
export function rateLimiter(
    maxRequests: number = DEFAULT_MAX_REQUESTS,
    windowMs: number = DEFAULT_WINDOW_MS,
    keyPrefix: string = 'global'
) {
    return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        try {
            const ip = req.ip || req.socket.remoteAddress || 'unknown';
            const identifier = `${keyPrefix}:${ip}`;

            const { allowed, remaining, resetIn } = await checkRateLimit(
                identifier,
                maxRequests,
                windowMs
            );

            res.setHeader('X-RateLimit-Limit', maxRequests);
            res.setHeader('X-RateLimit-Remaining', remaining);
            res.setHeader('X-RateLimit-Reset', Math.ceil(Date.now() / 1000) + Math.ceil(resetIn / 1000));

            if (!allowed) {
                logger.warn('Rate limit exceeded', { ip, prefix: keyPrefix });
                res.status(429).json({
                    error: 'Too many requests. Please try again later.',
                    code: 'RATE_LIMIT_EXCEEDED',
                    retry_after_ms: resetIn,
                });
                return;
            }

            next();
        } catch (error: any) {
            // If Redis is down, allow the request but log the error
            logger.error('Rate limiter error (allowing request)', { error: error.message });
            next();
        }
    };
}

/**
 * General API rate limiter.
 * 200 requests per minute per IP (higher than admin backend since this serves mobile traffic).
 */
export const generalRateLimiter = rateLimiter(200, 60000, 'app-api');
