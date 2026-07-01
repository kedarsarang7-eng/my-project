// ============================================
// Rate Limiter Middleware
// ============================================
// Uses Redis sliding window to prevent brute-force attacks
// on the validation API and other sensitive endpoints.

import { Request, Response, NextFunction } from 'express';
import { checkRateLimit } from '../config/redis';
import { logger } from '../utils/logger';

const DEFAULT_WINDOW_MS = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10);
const DEFAULT_MAX_REQUESTS = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '10', 10);

/**
 * Creates a rate limiter middleware using Redis sliding window.
 * 
 * @param maxRequests - Maximum requests per window (default: 10)
 * @param windowMs - Window duration in milliseconds (default: 60000 = 1 minute)
 * @param keyPrefix - Custom key prefix for different endpoints
 */
export function rateLimiter(
    maxRequests: number = DEFAULT_MAX_REQUESTS,
    windowMs: number = DEFAULT_WINDOW_MS,
    keyPrefix: string = 'global'
) {
    return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        try {
            // Use IP address as the rate limit identifier
            const ip = req.ip || req.socket.remoteAddress || 'unknown';
            const identifier = `${keyPrefix}:${ip}`;

            const { allowed, remaining, resetIn } = await checkRateLimit(
                identifier,
                maxRequests,
                windowMs
            );

            // Set rate limit headers (RFC 6585)
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
            // This prevents Redis failures from blocking all API traffic
            logger.error('Rate limiter error (allowing request)', { error: error.message });
            next();
        }
    };
}

/**
 * Stricter rate limiter for the validation endpoint.
 * 10 requests per minute per IP.
 */
export const validateRateLimiter = rateLimiter(10, 60000, 'validate');

/**
 * Authentication rate limiter — prevents login brute-force.
 * 5 attempts per minute per IP.
 */
export const authRateLimiter = rateLimiter(5, 60000, 'auth');

/**
 * General API rate limiter.
 * 100 requests per minute per IP.
 */
export const generalRateLimiter = rateLimiter(100, 60000, 'api');
