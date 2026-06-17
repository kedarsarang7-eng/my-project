// ============================================================================
// Grace Period Service — Progressive Locking for Payment Failures
// ============================================================================
// Manages the grace period after payment failure:
// - Day 1-3: Warning only (PAST_DUE status)
// - Day 4-7: Partial lock (read-only, no create/edit) (GRACE_PERIOD status)
// - Day 8+: Full lock (data export only) (EXPIRED status)
//
// Cron job runs daily to update tenant statuses.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { DynamoDBClient, QueryCommand, UpdateItemCommand, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { CognitoIdentityProviderClient, AdminUpdateUserAttributesCommand } from '@aws-sdk/client-cognito-identity-provider';
import { SubscriptionStatus, getSubscriptionContext } from './subscription.service';
import { GRACE_PERIOD_CONFIG } from '../config/razorpay-subscription.config';
import { logger } from '../utils/logger';
import { regenerateManifest } from './feature-manifest.service';
import { config } from '../config/environment';

// ── Type Definitions ───────────────────────────────────────────────────────

export interface GracePeriodContext {
    tenantId: string;
    currentStatus: SubscriptionStatus;
    paymentFailureDate: Date;
    gracePeriodEndDate: Date;
    daysSinceFailure: number;
    lockLevel: GracePeriodLockLevel;
}

export enum GracePeriodLockLevel {
    WARNING = 'warning',      // Day 1-3: Warning banner, full access
    PARTIAL = 'partial',      // Day 4-7: Read-only, no writes
    EXPIRED = 'expired',      // Day 8+: Full lock
}

export interface GracePeriodAction {
    tenantId: string;
    action: 'NONE' | 'WARN' | 'PARTIAL_LOCK' | 'FULL_LOCK';
    previousStatus: SubscriptionStatus;
    newStatus: SubscriptionStatus;
    notificationRequired: boolean;
}

// ── Configuration ───────────────────────────────────────────────────────────

const DYNAMODB_TABLE = config.dynamodb.tableName;
const COGNITO_USER_POOL_ID = config.cognito.userPoolId;

const dynamodb = new DynamoDBClient(configureAwsClient({ region: config.aws.region }));
const cognito = new CognitoIdentityProviderClient(configureAwsClient({ region: config.aws.region }));

// ── Core Functions ───────────────────────────────────────────────────────────

/**
 * Process all tenants in grace period daily
 * This is called by the cron job handler
 */
export async function processDailyGracePeriods(): Promise<GracePeriodAction[]> {
    const actions: GracePeriodAction[] = [];

    // Find all subscriptions in PAST_DUE or GRACE_PERIOD status
    const subscriptions = await findSubscriptionsRequiringGraceCheck();

    logger.info('Processing grace periods', { count: subscriptions.length });

    for (const subscription of subscriptions) {
        const action = await evaluateGracePeriod(subscription.tenantId);
        if (action.action !== 'NONE') {
            actions.push(action);
        }
    }

    // Also check for expired trials that need auto-downgrade
    const expiredTrials = await findExpiredTrials();
    for (const tenantId of expiredTrials) {
        await handleExpiredTrial(tenantId);
    }

    logger.info('Grace period processing complete', {
        actionsTaken: actions.length,
        expiredTrials: expiredTrials.length,
    });

    return actions;
}

/**
 * Evaluate grace period for a single tenant
 */
export async function evaluateGracePeriod(tenantId: string): Promise<GracePeriodAction> {
    const context = await getSubscriptionContext(tenantId);

    // Only process PAST_DUE and GRACE_PERIOD subscriptions
    if (context.subscriptionStatus !== SubscriptionStatus.PAST_DUE &&
        context.subscriptionStatus !== SubscriptionStatus.GRACE_PERIOD) {
        return {
            tenantId,
            action: 'NONE',
            previousStatus: context.subscriptionStatus,
            newStatus: context.subscriptionStatus,
            notificationRequired: false,
        };
    }

    // Calculate days since payment failure
    const gracePeriodEnd = context.gracePeriodEndDate;
    if (!gracePeriodEnd) {
        // Initialize grace period if not set
        await initializeGracePeriod(tenantId);
        return {
            tenantId,
            action: 'WARN',
            previousStatus: context.subscriptionStatus,
            newStatus: SubscriptionStatus.PAST_DUE,
            notificationRequired: true,
        };
    }

    const now = new Date();
    const daysSinceFailure = Math.floor(
        (now.getTime() - gracePeriodEnd.getTime()) / (1000 * 60 * 60 * 24) +
        GRACE_PERIOD_CONFIG.partialLockDays,
    );

    const daysUntilLock = Math.ceil(
        (gracePeriodEnd.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
    );

    // Determine action based on timeline
    if (daysUntilLock > GRACE_PERIOD_CONFIG.partialLockDays - 3) {
        // Day 1-3: Warning phase - already PAST_DUE
        return {
            tenantId,
            action: 'WARN',
            previousStatus: context.subscriptionStatus,
            newStatus: SubscriptionStatus.PAST_DUE,
            notificationRequired: daysUntilLock === 6 || daysUntilLock === 3, // Notify on day 1 and day 4
        };
    } else if (daysUntilLock > 0) {
        // Day 4-7: Partial lock phase
        if (context.subscriptionStatus !== SubscriptionStatus.GRACE_PERIOD) {
            await applyPartialLock(tenantId, gracePeriodEnd);
            return {
                tenantId,
                action: 'PARTIAL_LOCK',
                previousStatus: SubscriptionStatus.PAST_DUE,
                newStatus: SubscriptionStatus.GRACE_PERIOD,
                notificationRequired: true,
            };
        }

        // Already in partial lock, check if notification needed
        return {
            tenantId,
            action: 'NONE',
            previousStatus: context.subscriptionStatus,
            newStatus: context.subscriptionStatus,
            notificationRequired: daysUntilLock === 1, // Final warning
        };
    } else {
        // Day 8+: Full lock - apply if not already expired
        await applyFullLock(tenantId);
        return {
            tenantId,
            action: 'FULL_LOCK',
            previousStatus: context.subscriptionStatus,
            newStatus: SubscriptionStatus.EXPIRED,
            notificationRequired: true,
        };
    }
}

/**
 * Initialize grace period for a subscription with payment failure
 */
export async function initializeGracePeriod(tenantId: string): Promise<void> {
    const gracePeriodEnd = new Date();
    gracePeriodEnd.setDate(gracePeriodEnd.getDate() + GRACE_PERIOD_CONFIG.partialLockDays);

    await updateSubscriptionStatus(tenantId, {
        subscriptionStatus: SubscriptionStatus.PAST_DUE,
        gracePeriodEndDate: gracePeriodEnd.toISOString(),
        paymentFailureDate: new Date().toISOString(),
    });

    await updateCognitoPlanStatus(tenantId, 'past_due');

    logger.info('Initialized grace period', { tenantId, gracePeriodEnd });
}

/**
 * Apply partial lock (read-only mode)
 */
export async function applyPartialLock(tenantId: string, gracePeriodEndDate: Date): Promise<void> {
    await updateSubscriptionStatus(tenantId, {
        subscriptionStatus: SubscriptionStatus.GRACE_PERIOD,
        gracePeriodEndDate: gracePeriodEndDate.toISOString(),
        lockedAt: new Date().toISOString(),
    });

    await updateCognitoPlanStatus(tenantId, 'grace_period');
    await regenerateManifest(tenantId);

    logger.warn('Applied partial lock to tenant', { tenantId, gracePeriodEndDate });
}

/**
 * Apply full lock (data export only)
 */
export async function applyFullLock(tenantId: string): Promise<void> {
    await updateSubscriptionStatus(tenantId, {
        subscriptionStatus: SubscriptionStatus.EXPIRED,
        fullyLockedAt: new Date().toISOString(),
    });

    await updateCognitoPlanStatus(tenantId, 'expired');
    await regenerateManifest(tenantId);

    logger.error('Applied full lock to tenant', { tenantId });
}

/**
 * Handle expired trial - auto-downgrade to Basic
 */
export async function handleExpiredTrial(tenantId: string): Promise<void> {
    const context = await getSubscriptionContext(tenantId);

    if (context.subscriptionStatus !== SubscriptionStatus.TRIAL) {
        return;
    }

    if (!context.trialEndDate || context.trialEndDate > new Date()) {
        return; // Trial still active
    }

    // Downgrade to Basic (free plan)
    await updateSubscriptionStatus(tenantId, {
        planId: 'basic',
        subscriptionStatus: SubscriptionStatus.ACTIVE,
        trialEndDate: context.trialEndDate.toISOString(),
        downgradedFromTrial: true,
        downgradeTimestamp: new Date().toISOString(),
    });

    await updateCognitoAttributes(tenantId, {
        'custom:plan': 'basic',
        'custom:plan_status': 'active',
    });

    await regenerateManifest(tenantId);

    // Log the downgrade
    await logGracePeriodEvent(tenantId, 'TRIAL_EXPIRED_DOWNGRADE', 'premium', 'basic');

    logger.info('Auto-downgraded expired trial to Basic', { tenantId });
}

/**
 * Release lock after successful payment
 */
export async function releaseLock(tenantId: string): Promise<void> {
    const context = await getSubscriptionContext(tenantId);

    if (context.subscriptionStatus === SubscriptionStatus.ACTIVE) {
        return; // Already active
    }

    await updateSubscriptionStatus(tenantId, {
        subscriptionStatus: SubscriptionStatus.ACTIVE,
        gracePeriodEndDate: null,
        paymentFailureDate: null,
        lockReleasedAt: new Date().toISOString(),
    });

    await updateCognitoPlanStatus(tenantId, 'active');
    await regenerateManifest(tenantId);

    logger.info('Released lock after payment', { tenantId });
}

// ── Helper Functions ───────────────────────────────────────────────────────

async function findSubscriptionsRequiringGraceCheck(): Promise<Array<{ tenantId: string; status: SubscriptionStatus }>> {
    // This would ideally use a GSI to find all subscriptions with specific statuses
    // For now, we query with a filter on the status field

    const command = new QueryCommand({
        TableName: DYNAMODB_TABLE,
        IndexName: 'GSI1', // Assuming GSI1 exists with subscription status
        KeyConditionExpression: 'GSI1PK = :pk',
        FilterExpression: '#status IN (:past_due, :grace_period)',
        ExpressionAttributeNames: {
            '#status': 'subscriptionStatus',
        },
        ExpressionAttributeValues: marshall({
            ':pk': 'SUBSCRIPTION#STATUS',
            ':past_due': 'past_due',
            ':grace_period': 'grace_period',
        }),
    });

    try {
        const result = await dynamodb.send(command);
        return result.Items?.map(item => {
            const data = unmarshall(item);
            return {
                tenantId: data.tenantId,
                status: data.subscriptionStatus as SubscriptionStatus,
            };
        }) || [];
    } catch (error) {
        // GSI might not exist, fallback to scan or alternative approach
        logger.warn('Could not query by subscription status, using fallback', { error });
        return [];
    }
}

async function findExpiredTrials(): Promise<string[]> {
    const now = new Date().toISOString();

    const command = new QueryCommand({
        TableName: DYNAMODB_TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk',
        FilterExpression: '#status = :trial AND trialEndDate < :now',
        ExpressionAttributeNames: {
            '#status': 'subscriptionStatus',
        },
        ExpressionAttributeValues: marshall({
            ':pk': 'SUBSCRIPTION#STATUS',
            ':trial': 'trial',
            ':now': now,
        }),
    });

    try {
        const result = await dynamodb.send(command);
        return result.Items?.map(item => unmarshall(item).tenantId) || [];
    } catch (error) {
        logger.warn('Could not query expired trials', { error });
        return [];
    }
}

async function updateSubscriptionStatus(
    tenantId: string,
    updates: Record<string, unknown>,
): Promise<void> {
    const updateExpressions: string[] = [];
    const expressionAttributeNames: Record<string, string> = {};
    const expressionAttributeValues: Record<string, unknown> = {};

    Object.entries(updates).forEach(([key, value]) => {
        const attrName = `#${key}`;
        const attrValue = `:${key}`;
        updateExpressions.push(`${attrName} = ${attrValue}`);
        expressionAttributeNames[attrName] = key;
        expressionAttributeValues[attrValue] = value;
    });

    updateExpressions.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();

    const command = new UpdateItemCommand({
        TableName: DYNAMODB_TABLE,
        Key: marshall({
            PK: `TENANT#${tenantId}`,
            SK: 'METADATA#SUBSCRIPTION',
        }),
        UpdateExpression: `SET ${updateExpressions.join(', ')}`,
        ExpressionAttributeNames: expressionAttributeNames,
        ExpressionAttributeValues: marshall(expressionAttributeValues),
    });

    await dynamodb.send(command);
}

async function updateCognitoPlanStatus(tenantId: string, status: string): Promise<void> {
    await updateCognitoAttributes(tenantId, {
        'custom:plan_status': status,
    });
}

async function updateCognitoAttributes(tenantId: string, attributes: Record<string, string>): Promise<void> {
    const userAttributes = Object.entries(attributes).map(([Name, Value]) => ({ Name, Value }));

    // Query to find primary user for tenant
    const command = new QueryCommand({
        TableName: DYNAMODB_TABLE,
        KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
        ExpressionAttributeValues: marshall({
            ':pk': `TENANT#${tenantId}`,
            ':sk': 'USER#',
        }),
        Limit: 1,
    });

    const result = await dynamodb.send(command);

    if (result.Items && result.Items.length > 0) {
        const user = unmarshall(result.Items[0]);

        await cognito.send(new AdminUpdateUserAttributesCommand({
            UserPoolId: COGNITO_USER_POOL_ID,
            Username: user.userId || user.email || tenantId,
            UserAttributes: userAttributes,
        }));
    }
}

async function logGracePeriodEvent(
    tenantId: string,
    eventType: string,
    fromStatus?: string,
    toStatus?: string,
): Promise<void> {
    await dynamodb.send(new PutItemCommand({
        TableName: DYNAMODB_TABLE,
        Item: marshall({
            PK: `TENANT#${tenantId}`,
            SK: `GRACEPERIOD#${Date.now()}`,
            eventType,
            fromStatus,
            toStatus,
            timestamp: new Date().toISOString(),
            ttl: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60), // 90 days TTL
        }),
    }));
}

// ── Notification Functions ─────────────────────────────────────────────────

export interface GracePeriodNotification {
    tenantId: string;
    type: 'PAYMENT_FAILED' | 'GRACE_PERIOD_START' | 'GRACE_PERIOD_WARNING' | 'FULL_LOCK' | 'TRIAL_EXPIRY';
    daysRemaining?: number;
    paymentLink?: string;
    message: string;
}

export async function sendGracePeriodNotification(notification: GracePeriodNotification): Promise<void> {
    // Queue notification for push/email
    await dynamodb.send(new PutItemCommand({
        TableName: DYNAMODB_TABLE,
        Item: marshall({
            PK: `TENANT#${notification.tenantId}`,
            SK: `NOTIFICATION#QUEUED#${Date.now()}`,
            ...notification,
            queuedAt: new Date().toISOString(),
            status: 'PENDING',
            ttl: Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60), // 7 days TTL
        }),
    }));

    logger.info('Queued grace period notification', notification as unknown as Record<string, unknown>);
}
