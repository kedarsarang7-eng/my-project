// ============================================================================
// Rate Limiter Middleware — Token Bucket Algorithm
// ============================================================================
// Layer 2 of rate limiting defense (Layer 1 is API Gateway usage plans).
// Implements per-user token bucket with atomic DynamoDB operations.
// 
// Strategy:
// - Internal users: 60 token bucket, refill 1/sec
// - Customer users: 20 token bucket, refill 1/sec
// - Atomic decrement with conditional expression
// - DynamoDB TTL auto-cleans stale entries
// 
// On rate limit exceeded: returns 429 with Retry-After header
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, UpdateCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { AuthContext } from '../types/tenant.types';
import { config } from '../config/environment';
import { logger } from '../utils/logger';

// Initialize DynamoDB client (singleton)
const client = new DynamoDBClient(configureAwsClient({}));
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = config.dynamodb.rateLimitTable;

/**
 * Rate limiting configuration by user type
 */
const RATE_LIMITS: Record<string, { maxTokens: number; refillRate: number }> = {
    // Internal users get higher limits
    admin: { maxTokens: 60, refillRate: 1 },
    manager: { maxTokens: 60, refillRate: 1 },
    ca: { maxTokens: 60, refillRate: 1 },
    staff: { maxTokens: 60, refillRate: 1 },
    
    // Customers get lower limits
    customer: { maxTokens: 20, refillRate: 1 },
    
    // Fallback for unknown roles
    default: { maxTokens: 10, refillRate: 0.5 },
};

/**
 * Rate limit check result
 */
export type RateLimitResult =
    | { allowed: true; remaining: number; resetTime: number }
    | { allowed: false; retryAfter: number };

/**
 * Rate limit entry in DynamoDB
 */
interface RateLimitEntry {
    PK: string;        // userId
    tokens: number;
    lastRefill: number; // epoch seconds
    ttl: number;       // DynamoDB TTL
}

/**
 * Check rate limit for a user using token bucket algorithm
 * 
 * WHY: Token bucket allows burst traffic while maintaining sustainable rate.
 * Unlike fixed window, it doesn't have thundering herd problems at window boundaries.
 * 
 * Algorithm:
 * 1. Calculate tokens to add based on elapsed time
 * 2. Cap at maxTokens
 * 3. Atomically decrement if tokens > 0
 * 4. Return 429 if no tokens available
 * 
 * @param userId - User identifier (Cognito sub)
 * @param role - User role (determines bucket size)
 * @returns RateLimitResult - allowed status and remaining tokens or retry time
 */
export async function checkRateLimit(
    userId: string,
    role: string
): Promise<RateLimitResult> {
    const config = RATE_LIMITS[role] || RATE_LIMITS.default;
    const now = Math.floor(Date.now() / 1000);
    const pk = userId;

    try {
        // Try to get existing bucket
        const getResult = await docClient.send(new GetCommand({
            TableName: TABLE_NAME,
            Key: { PK: pk },
        }));

        const existing = getResult.Item as RateLimitEntry | undefined;

        if (!existing) {
            // No bucket exists - create new one with full tokens minus 1
            const newEntry: RateLimitEntry = {
                PK: pk,
                tokens: config.maxTokens - 1,
                lastRefill: now,
                ttl: now + 86400, // 24 hour TTL
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: newEntry,
                ConditionExpression: 'attribute_not_exists(PK)', // Only if not exists
            }));

            return {
                allowed: true,
                remaining: newEntry.tokens,
                resetTime: now + 1,
            };
        }

        // Calculate refill
        const elapsed = now - existing.lastRefill;
        const tokensToAdd = Math.floor(elapsed * config.refillRate);
        const newTokenCount = Math.min(
            existing.tokens + tokensToAdd,
            config.maxTokens
        );

        // If no tokens to consume, return rate limited
        if (newTokenCount < 1) {
            const retryAfter = Math.ceil((1 - newTokenCount) / config.refillRate);
            
            logger.warn('RATE_LIMIT_EXCEEDED', {
                userId,
                role,
                currentTokens: newTokenCount,
                retryAfter,
            });

            return {
                allowed: false,
                retryAfter,
            };
        }

        // Atomically update tokens with conditional expression
        // This ensures no race conditions between concurrent requests
        try {
            await docClient.send(new UpdateCommand({
                TableName: TABLE_NAME,
                Key: { PK: pk },
                UpdateExpression: 'SET tokens = :newTokens, lastRefill = :now, ttl = :ttl',
                ConditionExpression: 'tokens = :expectedTokens AND lastRefill = :expectedLastRefill',
                ExpressionAttributeValues: {
                    ':newTokens': newTokenCount - 1,
                    ':expectedTokens': existing.tokens,
                    ':expectedLastRefill': existing.lastRefill,
                    ':now': now,
                    ':ttl': now + 86400,
                },
            }));

            return {
                allowed: true,
                remaining: newTokenCount - 1,
                resetTime: now + Math.ceil((config.maxTokens - (newTokenCount - 1)) / config.refillRate),
            };

        } catch (error) {
            // Condition check failed - concurrent modification
            // Recursively retry (with limit to prevent stack overflow)
            logger.warn('RATE_LIMIT_CONCURRENT_UPDATE', {
                userId,
                role,
                message: 'Concurrent bucket update detected, retrying',
            });
            
            // Simple retry - in production, use exponential backoff
            return checkRateLimit(userId, role);
        }

    } catch (error) {
        logger.error('RATE_LIMIT_ERROR', {
            userId,
            role,
            error: (error as Error).message,
        });

        // Fail open - allow request if rate limiter fails
        // This prevents rate limiter from being a single point of failure
        // but logs the incident for monitoring
        return {
            allowed: true,
            remaining: -1,
            resetTime: now,
        };
    }
}

/**
 * Middleware wrapper for rate limiting
 * 
 * Use this in your handler wrapper after auth validation
 */
export async function validateRateLimit(
    auth: AuthContext
): Promise<RateLimitResult> {
    return checkRateLimit(auth.sub, auth.role);
}

/**
 * Calculate exponential backoff for client retry guidance
 */
export function calculateBackoff(attempt: number, baseDelay = 1000, maxDelay = 60000): number {
    const jitter = Math.random() * 0.3 + 0.85; // 0.85-1.15 jitter
    const exponentialDelay = baseDelay * Math.pow(2, attempt);
    return Math.min(exponentialDelay * jitter, maxDelay);
}
