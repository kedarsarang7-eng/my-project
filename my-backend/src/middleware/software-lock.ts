// ============================================================================
// Software Lock Middleware — Enforce Subscription Status on API Access
// ============================================================================
// Implements the software locking mechanism for payment failures:
// - ACTIVE/TRIAL: Full access
// - PAST_DUE: Warning + full access (grace period day 1-7)
// - GRACE_PERIOD: Partial lock (can view, cannot create/edit)
// - EXPIRED: Full lock (data export only)
//
// This middleware runs AFTER authentication but BEFORE feature/limit guards.
// ============================================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { getSubscriptionContext, SubscriptionStatus } from '../services/subscription.service';
import { logger } from '../utils/logger';

// ── Type Definitions ───────────────────────────────────────────────────────

export interface LockCheckResult {
    /** Can the user access this feature at all? */
    allowed: boolean;
    /** Current lock level */
    lockLevel: LockLevel;
    /** Human-readable message for user */
    userMessage: string;
    /** Additional data for UI (payment link, expiry date, etc.) */
    metadata?: {
        gracePeriodEndDate?: string;
        paymentLink?: string;
        daysRemaining?: number;
    };
}

export enum LockLevel {
    NONE = 'none',              // Full access
    WARNING = 'warning',        // Warning displayed, full access
    PARTIAL = 'partial',        // Read-only, no create/edit
    FULL = 'full',              // Complete lock (export only)
}

export interface SoftwareLockConfig {
    /** HTTP methods that require write access */
    writeMethods: string[];
    /** API paths that bypass lock (public, health, payment retry) */
    bypassPaths: string[];
}

// ── Configuration ───────────────────────────────────────────────────────────

const LOCK_CONFIG: SoftwareLockConfig = {
    writeMethods: ['POST', 'PUT', 'PATCH', 'DELETE'],
    bypassPaths: [
        '/health',
        '/payment/retry',
        '/subscription/retry',
        '/subscription/current',
        '/subscription/plans',
        '/auth',
        '/export/data',  // Always allow data export even when locked
    ],
};

// ── Error Classes ───────────────────────────────────────────────────────────

export class SoftwareLockError extends Error {
    constructor(
        message: string,
        public lockLevel: LockLevel,
        public code: string,
        public metadata?: LockCheckResult['metadata'],
    ) {
        super(message);
        this.name = 'SoftwareLockError';
    }
}

// ── Core Functions ───────────────────────────────────────────────────────

/**
 * Check if request should be allowed based on subscription lock status
 */
export async function checkSoftwareLock(
    tenantId: string,
    event: APIGatewayProxyEventV2,
): Promise<LockCheckResult> {
    // Check bypass paths
    const path = event.rawPath || event.requestContext?.http?.path || '';
    const method = event.requestContext?.http?.method || 'GET';

    if (isBypassPath(path)) {
        return {
            allowed: true,
            lockLevel: LockLevel.NONE,
            userMessage: '',
        };
    }

    // Get subscription context
    const subscription = await getSubscriptionContext(tenantId);

    // Determine lock level based on status
    const lockLevel = determineLockLevel(subscription.subscriptionStatus);

    // Check if write operation is allowed
    if (LOCK_CONFIG.writeMethods.includes(method)) {
        if (lockLevel === LockLevel.FULL) {
            logger.warn('Write operation blocked - full lock active', {
                tenantId,
                path,
                method,
                status: subscription.subscriptionStatus,
            });

            return {
                allowed: false,
                lockLevel,
                userMessage: 'Your subscription has expired. Please renew to continue using all features.',
                metadata: {
                    gracePeriodEndDate: subscription.gracePeriodEndDate?.toISOString(),
                },
            };
        }

        if (lockLevel === LockLevel.PARTIAL) {
            logger.warn('Write operation blocked - partial lock active', {
                tenantId,
                path,
                method,
                daysRemaining: subscription.gracePeriodEndDate
                    ? Math.ceil((subscription.gracePeriodEndDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
                    : 0,
            });

            const daysRemaining = subscription.gracePeriodEndDate
                ? Math.ceil((subscription.gracePeriodEndDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
                : 0;

            return {
                allowed: false,
                lockLevel,
                userMessage: `Payment failed ${daysRemaining > 0 ? `${daysRemaining} days ago` : 'recently'}. Please complete payment to restore full access.`,
                metadata: {
                    gracePeriodEndDate: subscription.gracePeriodEndDate?.toISOString(),
                    daysRemaining,
                },
            };
        }
    }

    // Read operations are allowed at WARNING and PARTIAL levels
    if (lockLevel === LockLevel.WARNING) {
        return {
            allowed: true,
            lockLevel,
            userMessage: 'Payment failed. Please update your payment method to avoid service interruption.',
            metadata: {
                gracePeriodEndDate: subscription.gracePeriodEndDate?.toISOString(),
            },
        };
    }

    // Full access
    return {
        allowed: true,
        lockLevel: LockLevel.NONE,
        userMessage: '',
    };
}

/**
 * Determine lock level from subscription status
 */
export function determineLockLevel(status: SubscriptionStatus): LockLevel {
    switch (status) {
        case SubscriptionStatus.ACTIVE:
        case SubscriptionStatus.TRIAL:
        case SubscriptionStatus.PENDING_PAYMENT: // Upgrade initiated — allow full access while payment processes
            return LockLevel.NONE;

        case SubscriptionStatus.PAST_DUE:
            return LockLevel.WARNING;

        case SubscriptionStatus.GRACE_PERIOD:
        case SubscriptionStatus.PENDING_DOWNGRADE:
            return LockLevel.PARTIAL;

        case SubscriptionStatus.CANCELLED:
        case SubscriptionStatus.EXPIRED:
            return LockLevel.FULL;

        default:
            return LockLevel.FULL; // Fail-safe: lock if unknown
    }
}

/**
 * Check if path should bypass lock checks
 */
function isBypassPath(path: string): boolean {
    return LOCK_CONFIG.bypassPaths.some(bypass =>
        path === bypass || path.startsWith(bypass + '/'),
    );
}

/**
 * Format error response for lock violations
 */
export function formatLockErrorResponse(error: SoftwareLockError): Record<string, unknown> {
    return {
        success: false,
        errorCode: 'SUBSCRIPTION_LOCK',
        lockLevel: error.lockLevel,
        message: error.message,
        metadata: error.metadata,
        actionRequired: error.lockLevel === LockLevel.PARTIAL
            ? 'PAYMENT_RETRY'
            : error.lockLevel === LockLevel.FULL
                ? 'SUBSCRIPTION_RENEW'
                : 'NONE',
    };
}

// ── Middleware Factory ───────────────────────────────────────────────────────

/**
 * Wraps a handler with software lock checks
 */
export function withSoftwareLock<T extends (event: APIGatewayProxyEventV2, ...args: unknown[]) => Promise<unknown>>(
    handler: T,
    options: { allowReadDuringPartial?: boolean } = {},
): T {
    return (async (event: APIGatewayProxyEventV2, ...args: unknown[]) => {
        const tenantId = extractTenantId(event);

        if (!tenantId) {
            // No tenant context - let downstream auth handle this
            return handler(event, ...args);
        }

        const lockCheck = await checkSoftwareLock(tenantId, event);

        if (!lockCheck.allowed) {
            const error = new SoftwareLockError(
                lockCheck.userMessage,
                lockCheck.lockLevel,
                'SUBSCRIPTION_LOCK',
                lockCheck.metadata,
            );

            logger.error('Software lock enforced', {
                tenantId,
                lockLevel: lockCheck.lockLevel,
                path: event.rawPath,
            });

            return formatLockErrorResponse(error);
        }

        // Add lock info to context for potential warning display
        (event as unknown as Record<string, unknown>).lockInfo = {
            lockLevel: lockCheck.lockLevel,
            userMessage: lockCheck.userMessage,
            metadata: lockCheck.metadata,
        };

        return handler(event, ...args);
    }) as T;
}

/**
 * Extract tenant ID from JWT claims in event
 */
function extractTenantId(event: APIGatewayProxyEventV2): string | null {
    // Extract from authorizer context
    const authorizer = (event as unknown as { requestContext?: { authorizer?: { jwt?: { claims?: Record<string, string> } } } }).requestContext?.authorizer;

    if (authorizer?.jwt?.claims) {
        return authorizer.jwt.claims['custom:tenantId'] ||
               authorizer.jwt.claims['custom:businessId'] ||
               null;
    }

    // Try to extract from Cognito groups or other claims
    const requestContext = (event as unknown as { requestContext?: { authorizer?: { claims?: Record<string, string> } } }).requestContext;
    if (requestContext?.authorizer?.claims) {
        return requestContext.authorizer.claims['custom:tenantId'] ||
               requestContext.authorizer.claims['custom:businessId'] ||
               null;
    }

    return null;
}
