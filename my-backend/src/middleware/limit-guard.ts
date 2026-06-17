// ============================================================================
// Limit Guard Middleware — Enforce Plan-Based Usage Limits
// ============================================================================
// Validates usage against plan limits:
//   - maxUsers
//   - maxProducts
//   - maxInvoicesPerMonth (via currentMonthInvoiceCount)
//
// Applied at the start of Lambda handlers that create resources.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { AuthContext } from '../types/tenant.types';
import { PlanLimits, mapToPlanTier } from '../config/plan-feature-registry';
import { Keys, getItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

export class LimitExceededError extends Error {
    constructor(
        public limitType: 'users' | 'products' | 'invoices',
        public current: number,
        public max: number,
        public upgradeRequired: boolean = true
    ) {
        super(`Limit exceeded: ${limitType} (${current}/${max})`);
        this.name = 'LimitExceededError';
    }
}

export interface LimitCheckContext {
    tenantId: string;
    limits: PlanLimits;
    currentUsers?: number;
    currentProducts?: number;
    currentInvoices?: number;
}

/**
 * Resolve limit context for a tenant
 * Fetches current usage from DynamoDB and applies plan limits
 */
export async function resolveLimitContext(auth: AuthContext): Promise<LimitCheckContext> {
    // F010: Read plan from METADATA#SUBSCRIPTION (planId field), not from PROFILE
    // (subscriptionPlan field). These are two separate DynamoDB items.
    const [subscription, profile] = await Promise.all([
        getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'METADATA#SUBSCRIPTION'),
        getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), Keys.tenantProfileSK()),
    ]);

    if (!profile) {
        throw new Error(`Tenant profile not found: ${auth.tenantId}`);
    }

    // F010: Use planId from subscription record; fall back to BASIC if not found
    const planTier = mapToPlanTier(subscription?.planId || 'basic');
    const { PLAN_LIMITS } = await import('../config/plan-feature-registry');
    const limits = PLAN_LIMITS[planTier];

    // Check if invoice count needs reset (new month)
    const currentMonth = new Date().toISOString().slice(0, 7).replace('-', '');
    const storedMonth = profile.invoiceCountMonth || '';
    let currentInvoices = profile.currentMonthInvoiceCount || 0;

    if (storedMonth !== currentMonth) {
        // Reset counter for new month
        currentInvoices = 0;
        // Note: Actual reset happens in checkInvoiceLimit or via cron
    }

    return {
        tenantId: auth.tenantId,
        limits,
        currentUsers: profile.activeUserCount || 1, // Owner counts as 1
        currentProducts: profile.currentProductCount || 0,
        currentInvoices,
    };
}

/**
 * Check if adding a new user would exceed the plan limit
 * @throws LimitExceededError if limit would be exceeded
 */
export async function checkUserLimit(
    context: LimitCheckContext,
    auth: AuthContext
): Promise<void> {
    const maxUsers = context.limits.maxUsers;

    // null/unlimited
    if (maxUsers === null || maxUsers === undefined) {
        return;
    }

    const currentUsers = context.currentUsers || 1;

    // Check if adding a new user would exceed the limit
    if (currentUsers + 1 > maxUsers) {
        logger.warn('User limit would be exceeded', {
            tenantId: context.tenantId,
            current: currentUsers,
            max: maxUsers,
        });

        throw new LimitExceededError('users', currentUsers, maxUsers);
    }
}

/**
 * Check if adding a new product would exceed the plan limit
 * @throws LimitExceededError if limit would be exceeded
 */
export async function checkProductLimit(
    context: LimitCheckContext,
    auth: AuthContext
): Promise<void> {
    const maxProducts = context.limits.maxProducts;

    // null/unlimited
    if (maxProducts === null || maxProducts === undefined) {
        return;
    }

    const currentProducts = context.currentProducts || 0;

    // Check if adding a new product would exceed the limit
    if (currentProducts + 1 > maxProducts) {
        logger.warn('Product limit would be exceeded', {
            tenantId: context.tenantId,
            current: currentProducts,
            max: maxProducts,
        });

        throw new LimitExceededError('products', currentProducts, maxProducts);
    }
}

/**
 * Check if creating a new invoice would exceed the monthly limit
 * @throws LimitExceededError if limit would be exceeded
 */
export async function checkInvoiceLimit(
    context: LimitCheckContext,
    auth: AuthContext
): Promise<void> {
    const maxInvoices = context.limits.maxInvoicesPerMonth;

    // null/unlimited (not currently in PLAN_LIMITS, but future-proofing)
    if (maxInvoices === null || maxInvoices === undefined) {
        return;
    }

    // Check if creating a new invoice would exceed the limit
    const currentInvoices = context.currentInvoices || 0;
    if (currentInvoices + 1 > maxInvoices) {
        logger.warn('Monthly invoice limit would be exceeded', {
            tenantId: context.tenantId,
            current: currentInvoices,
            max: maxInvoices,
        });
        throw new LimitExceededError('invoices', currentInvoices, maxInvoices);
    }
}

/**
 * F009: Atomically check-and-increment the invoice counter.
 * Replaces the separate checkInvoiceLimit + incrementInvoiceCounter calls with a single
 * conditional UpdateItem. Throws LimitExceededError if the limit has been reached.
 * This prevents race conditions where two concurrent requests both pass the limit check.
 */
export async function atomicIncrementInvoiceCounter(tenantId: string, maxInvoices: number | null | undefined): Promise<void> {
    const { DynamoDBClient, UpdateItemCommand } = await import('@aws-sdk/client-dynamodb');
    const { marshall, unmarshall } = await import('@aws-sdk/util-dynamodb');
    const { config } = await import('../config/environment');
    const { ConditionalCheckFailedException } = await import('@aws-sdk/client-dynamodb');

    const currentMonth = new Date().toISOString().slice(0, 7).replace('-', '');
    const dynamodb = new DynamoDBClient(configureAwsClient({ region: config.aws.region }));

    if (maxInvoices === null || maxInvoices === undefined) {
        // Unlimited — just increment without condition
        await dynamodb.send(new UpdateItemCommand({
            TableName: config.dynamodb.tableName,
            Key: marshall({ PK: Keys.tenantPK(tenantId), SK: Keys.tenantProfileSK() }),
            UpdateExpression: 'SET currentMonthInvoiceCount = if_not_exists(currentMonthInvoiceCount, :zero) + :inc, invoiceCountMonth = :month',
            ExpressionAttributeValues: marshall({ ':zero': 0, ':inc': 1, ':month': currentMonth }),
        }));
        return;
    }

    try {
        await dynamodb.send(new UpdateItemCommand({
            TableName: config.dynamodb.tableName,
            Key: marshall({ PK: Keys.tenantPK(tenantId), SK: Keys.tenantProfileSK() }),
            // Atomic: increment only if current count < max AND month matches (or reset if new month)
            UpdateExpression: 'SET currentMonthInvoiceCount = if_not_exists(currentMonthInvoiceCount, :zero) + :inc, invoiceCountMonth = :month',
            ConditionExpression:
                '(attribute_not_exists(invoiceCountMonth) OR invoiceCountMonth <> :month OR currentMonthInvoiceCount < :max)',
            ExpressionAttributeValues: marshall({
                ':zero': 0,
                ':inc': 1,
                ':max': maxInvoices,
                ':month': currentMonth,
            }),
        }));
        logger.debug('Invoice counter atomically incremented', { tenantId, month: currentMonth });
    } catch (err: unknown) {
        if (err instanceof ConditionalCheckFailedException ||
            (err as Error)?.name === 'ConditionalCheckFailedException') {
            const currentCount = (await getItem<Record<string, any>>(
                Keys.tenantPK(tenantId), Keys.tenantProfileSK()
            ))?.currentMonthInvoiceCount ?? maxInvoices;
            logger.warn('Monthly invoice limit reached (atomic check)', { tenantId, currentCount, maxInvoices });
            throw new LimitExceededError('invoices', currentCount, maxInvoices);
        }
        throw err;
    }
}

/**
 * Increment the invoice counter after successful creation.
 * @deprecated Use atomicIncrementInvoiceCounter() which combines check + increment atomically.
 */
export async function incrementInvoiceCounter(tenantId: string): Promise<void> {
    const { updateItem } = await import('../config/dynamodb.config');
    const currentMonth = new Date().toISOString().slice(0, 7).replace('-', '');

    await updateItem(
        Keys.tenantPK(tenantId),
        Keys.tenantProfileSK(),
        {
            updateExpression: 'SET currentMonthInvoiceCount = if_not_exists(currentMonthInvoiceCount, :zero) + :inc, invoiceCountMonth = :month',
            expressionAttributeValues: {
                ':zero': 0,
                ':inc': 1,
                ':month': currentMonth,
            },
        }
    );

    logger.debug('Invoice counter incremented', { tenantId, month: currentMonth });
}

/**
 * Increment the product counter after successful creation
 */
export async function incrementProductCounter(tenantId: string): Promise<void> {
    const { updateItem } = await import('../config/dynamodb.config');

    await updateItem(
        Keys.tenantPK(tenantId),
        Keys.tenantProfileSK(),
        {
            updateExpression: 'SET currentProductCount = if_not_exists(currentProductCount, :zero) + :inc',
            expressionAttributeValues: {
                ':zero': 0,
                ':inc': 1,
            },
        }
    );

    logger.debug('Product counter incremented', { tenantId });
}

/**
 * Decrement the product counter after deletion
 */
export async function decrementProductCounter(tenantId: string): Promise<void> {
    const { updateItem } = await import('../config/dynamodb.config');

    await updateItem(
        Keys.tenantPK(tenantId),
        Keys.tenantProfileSK(),
        {
            updateExpression: 'SET currentProductCount = if_not_exists(currentProductCount, :zero) - :dec',
            expressionAttributeValues: {
                ':zero': 0,
                ':dec': 1,
            },
        }
    );

    logger.debug('Product counter decremented', { tenantId });
}

/**
 * Unified error response format for limit violations
 */
export function formatLimitError(error: LimitExceededError): {
    success: false;
    errorCode: 'LIMIT_EXCEEDED';
    errorMessage: string;
    upgradeRequired: true;
    currentPlan: string;
    requiredPlan: string;
    limit: {
        type: string;
        current: number;
        max: number;
    };
} {
    return {
        success: false,
        errorCode: 'LIMIT_EXCEEDED',
        errorMessage: `You have reached the ${error.limitType} limit for your current plan (${error.current}/${error.max}). Please upgrade to continue.`,
        upgradeRequired: true,
        currentPlan: 'current', // Caller should provide actual plan
        requiredPlan: 'pro', // Or calculate based on limit
        limit: {
            type: error.limitType,
            current: error.current,
            max: error.max,
        },
    };
}
