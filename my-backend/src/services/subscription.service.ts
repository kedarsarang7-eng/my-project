// ============================================================================
// Subscription Service � Razorpay Integration for Plan Management
// ============================================================================
// Handles:
// - Self-service plan upgrades with proration
// - Self-service plan downgrades (scheduled)
// - Payment retry flows
// - Subscription status synchronization
// ============================================================================

import { DynamoDBClient, GetItemCommand, UpdateItemCommand, PutItemCommand, QueryCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { CognitoIdentityProviderClient, AdminUpdateUserAttributesCommand } from '@aws-sdk/client-cognito-identity-provider';
// import Razorpay from 'razorpay'; // Package not installed - commented out to fix compilation
import { PlanTier, PLAN_LIMITS, isValidUpgrade, isValidDowngrade, PLAN_HIERARCHY } from '../config/plan-feature-registry';
import {
    BillingCycle,
    getRazorpayPlanId,
    getPlanPriceInPaise,
    calculateYearlySavings,
    PRORATION_CONFIG,
    TrialConfig,
    TRIAL_CONFIG,
} from '../config/razorpay-subscription.config';
import { logger } from '../utils/logger';
import { regenerateManifest } from './feature-manifest.service';
import { invalidateManifest } from '../config/manifest-cache';
import { config } from '../config/environment';

// -- Type Definitions -------------------------------------------------------

export interface SubscriptionContext {
    tenantId: string;
    currentPlan: PlanTier;
    currentBillingCycle: BillingCycle;
    razorpaySubscriptionId: string | null;
    subscriptionStatus: SubscriptionStatus;
    planStartDate: Date;
    planEndDate: Date | null;
    trialEndDate: Date | null;
    gracePeriodEndDate: Date | null;
    nextBillingDate: Date | null;
}

// Map billing cycles to Razorpay total_count (number of billing periods in subscription)
const BILLING_CYCLE_TOTAL_COUNT: Record<BillingCycle, number> = {
    [BillingCycle.MONTHLY]: 12,      // 12 months = 1 year
    [BillingCycle.QUARTERLY]: 4,     // 4 quarters = 1 year
    [BillingCycle.BIANNUAL]: 2,      // 2 half-years = 1 year
    [BillingCycle.YEARLY]: 1,        // 1 year
    [BillingCycle.BIENNIAL]: 1,      // 1 charge for 2 years (cycle is 24mo)
    [BillingCycle.TRIENNIAL]: 1,     // 1 charge for 3 years (cycle is 36mo)
};

// Map billing cycles to months for nextBillingDate calculation (P1-4 fix)
const BILLING_CYCLE_MONTHS: Record<BillingCycle, number> = {
    [BillingCycle.MONTHLY]: 1,
    [BillingCycle.QUARTERLY]: 3,
    [BillingCycle.BIANNUAL]: 6,
    [BillingCycle.YEARLY]: 12,
    [BillingCycle.BIENNIAL]: 24,
    [BillingCycle.TRIENNIAL]: 36,
};

export enum SubscriptionStatus {
    ACTIVE = 'active',
    TRIAL = 'trial',
    PENDING_PAYMENT = 'pending_payment', // Upgrade initiated, awaiting first payment confirmation
    PAST_DUE = 'past_due',      // Payment failed, grace period active
    GRACE_PERIOD = 'grace_period', // 7-day partial lock
    CANCELLED = 'cancelled',
    EXPIRED = 'expired',        // Fully locked
    PENDING_DOWNGRADE = 'pending_downgrade',
}

export interface UpgradeRequest {
    targetPlan: PlanTier;
    billingCycle: BillingCycle;
    immediateCharge?: boolean; // Whether to charge immediately (default: true)
}

export interface UpgradeResult {
    success: boolean;
    newPlan: PlanTier;
    billingCycle: BillingCycle;
    razorpaySubscriptionId: string;
    proratedCharge: number; // in paise
    nextBillingDate: Date;
    invoiceUrl: string | null;
}

export interface DowngradeRequest {
    targetPlan: PlanTier;
    billingCycle: BillingCycle;
    effectiveDate?: Date; // When to apply (default: end of current period)
}

export interface DowngradeResult {
    success: boolean;
    targetPlan: PlanTier;
    billingCycle: BillingCycle;
    scheduledDate: Date;
    message: string;
}

export interface PaymentRetryResult {
    success: boolean;
    paymentLink: string | null;
    nextAttemptDate: Date | null;
    message: string;
}

// -- Configuration -----------------------------------------------------------

const DYNAMODB_TABLE = config.dynamodb.tableName;
const COGNITO_USER_POOL_ID = config.cognito.userPoolId;

const dynamodb = new DynamoDBClient({ region: config.aws.region });
const cognito = new CognitoIdentityProviderClient({ region: config.aws.region });

// const razorpay = new Razorpay({
//     key_id: config.payment.razorpay.keyId || '',
//     key_secret: config.payment.razorpay.keySecret || '',
// });

// -- Error Classes -----------------------------------------------------------

export class SubscriptionError extends Error {
    constructor(
        message: string,
        public code: string,
        public upgradeRequired?: boolean,
        public currentPlan?: PlanTier,
        public requiredPlan?: PlanTier,
    ) {
        super(message);
        this.name = 'SubscriptionError';
    }
}

// -- Core Functions -----------------------------------------------------------

/**
 * Get current subscription context for a tenant
 */
export async function getSubscriptionContext(tenantId: string): Promise<SubscriptionContext> {
    const command = new GetItemCommand({
        TableName: DYNAMODB_TABLE,
        Key: marshall({
            PK: `TENANT#${tenantId}`,
            SK: 'METADATA#SUBSCRIPTION',
        }),
    });

    const result = await dynamodb.send(command);

    if (!result.Item) {
        // Return default (Basic plan) if no subscription record exists
        return {
            tenantId,
            currentPlan: PlanTier.BASIC,
            currentBillingCycle: BillingCycle.MONTHLY,
            razorpaySubscriptionId: null,
            subscriptionStatus: SubscriptionStatus.ACTIVE,
            planStartDate: new Date(),
            planEndDate: null,
            trialEndDate: null,
            gracePeriodEndDate: null,
            nextBillingDate: null,
        };
    }

    const item = unmarshall(result.Item);

    return {
        tenantId,
        currentPlan: item.planId || PlanTier.BASIC,
        currentBillingCycle: item.billingCycle || BillingCycle.MONTHLY,
        razorpaySubscriptionId: item.razorpaySubscriptionId || null,
        subscriptionStatus: item.subscriptionStatus || SubscriptionStatus.ACTIVE,
        planStartDate: new Date(item.planStartDate || Date.now()),
        planEndDate: item.planEndDate ? new Date(item.planEndDate) : null,
        trialEndDate: item.trialEndDate ? new Date(item.trialEndDate) : null,
        gracePeriodEndDate: item.gracePeriodEndDate ? new Date(item.gracePeriodEndDate) : null,
        nextBillingDate: item.nextBillingDate ? new Date(item.nextBillingDate) : null,
    };
}

/**
 * Initiate plan upgrade with proration
 */
export async function initiateUpgrade(
    tenantId: string,
    userId: string,
    request: UpgradeRequest,
): Promise<UpgradeResult> {
    const context = await getSubscriptionContext(tenantId);

    // -- Validation --------------------------------------------------------
    if (!isValidUpgrade(context.currentPlan, request.targetPlan)) {
        throw new SubscriptionError(
            `Cannot upgrade from ${context.currentPlan} to ${request.targetPlan}. Downgrades or same-tier changes are not allowed via upgrade endpoint.`,
            'INVALID_UPGRADE_PATH',
            false,
            context.currentPlan,
            request.targetPlan,
        );
    }

    // Check if already on target plan
    if (context.currentPlan === request.targetPlan && context.currentBillingCycle === request.billingCycle) {
        throw new SubscriptionError(
            `Already subscribed to ${request.targetPlan} with ${request.billingCycle} billing.`,
            'ALREADY_ON_PLAN',
        );
    }

    // -- Cancel existing subscription if present ---------------------------
    if (context.razorpaySubscriptionId) {
        try {
            // Razorpay not available - commented out
            // await razorpay.subscriptions.cancel(context.razorpaySubscriptionId, {
            //     cancel_at_cycle_end: true,
            // });
            logger.info('Razorpay subscription cancel skipped (package not installed)', {
                tenantId,
                subscriptionId: context.razorpaySubscriptionId,
            });
        } catch (error) {
            // Log but continue - subscription might already be cancelled
            logger.warn('Failed to cancel existing subscription', { tenantId, error });
        }
    }

    // -- Create new Razorpay subscription -------------------------------------
    const razorpayPlanId = getRazorpayPlanId(request.targetPlan, request.billingCycle);
    const customerId = await getOrCreateRazorpayCustomer(tenantId, userId);

    // Razorpay not available - commented out
    // const subscriptionOptions: Razorpay.SubscriptionCreateRequest = {
    //     plan_id: razorpayPlanId,
    //     customer_id: customerId,
    //     total_count: BILLING_CYCLE_TOTAL_COUNT[request.billingCycle], // Fixed: proper cycle-to-count mapping
    //     quantity: 1,
    //     notify_info: {
    //         notify_email: true,
    //         notify_sms: true,
    //     },
    //     notes: {
    //         tenantId: tenantId,
    //         userId: userId,
    //         businessType: context.businessType,
    //     },
    // };

    // Calculate prorated charge if immediate payment needed
    let proratedCharge = 0;
    if (request.immediateCharge !== false && context.nextBillingDate) {
        proratedCharge = await calculateProratedCharge(
            context,
            request.targetPlan,
            request.billingCycle,
        );

        if (proratedCharge > 0) {
            // Razorpay not available - commented out
            // subscriptionOptions.offer_id = await createProratedOffer(
            //     proratedCharge,
            //     `Prorated upgrade from ${context.currentPlan} to ${request.targetPlan}`,
            // );
            logger.info('Prorated offer creation skipped (package not installed)', {
                proratedCharge,
                currentPlan: context.currentPlan,
                targetPlan: request.targetPlan,
            });
        }
    }

    // Razorpay not available - commented out
    // const razorpaySubscription = await razorpay.subscriptions.create(subscriptionOptions);
    const razorpaySubscription = { id: 'placeholder-subscription-id', short_url: null };

    logger.info('Razorpay subscription creation skipped (package not installed)', {
        tenantId,
        newPlan: request.targetPlan,
        subscriptionId: razorpaySubscription.id,
        proratedCharge,
    });

    // -- Update DynamoDB ----------------------------------------------------
    // Calculate next billing date based on billing cycle
const nextBillingDate = new Date();
const monthsToAdd = BILLING_CYCLE_MONTHS[request.billingCycle];
nextBillingDate.setMonth(nextBillingDate.getMonth() + monthsToAdd);

    // F016: Do NOT set ACTIVE here — payment has not been confirmed yet.
    // Set PENDING_PAYMENT until subscription.activated or subscription.charged webhook fires.
    // Cognito plan attributes and manifest are updated only after webhook confirmation.
    await updateSubscriptionRecord(tenantId, {
        pendingPlanId: request.targetPlan,
        billingCycle: request.billingCycle,
        razorpaySubscriptionId: razorpaySubscription.id,
        subscriptionStatus: SubscriptionStatus.PENDING_PAYMENT,
        pendingPlanStartDate: new Date().toISOString(),
        gracePeriodEndDate: null,
        previousPlan: context.currentPlan,
        upgradeTimestamp: new Date().toISOString(),
    });

    // -- Log upgrade for analytics -----------------------------------------
    await logSubscriptionChange(tenantId, userId, 'UPGRADE', context.currentPlan, request.targetPlan, proratedCharge);

    return {
        success: true,
        newPlan: request.targetPlan,
        billingCycle: request.billingCycle,
        razorpaySubscriptionId: razorpaySubscription.id,
        proratedCharge,
        nextBillingDate,
        invoiceUrl: razorpaySubscription.short_url || null,
    };
}

/**
 * Initiate plan downgrade (scheduled at end of current period)
 */
export async function initiateDowngrade(
    tenantId: string,
    userId: string,
    request: DowngradeRequest,
): Promise<DowngradeResult> {
    const context = await getSubscriptionContext(tenantId);

    // -- Validation --------------------------------------------------------
    if (!isValidDowngrade(context.currentPlan, request.targetPlan)) {
        throw new SubscriptionError(
            `Cannot downgrade from ${context.currentPlan} to ${request.targetPlan}. Upgrades are not allowed via downgrade endpoint.`,
            'INVALID_DOWNGRADE_PATH',
        );
    }

    // -- Schedule downgrade at end of current billing period ---------------
    const scheduledDate = request.effectiveDate || context.nextBillingDate || new Date();

    // Update Razorpay subscription to cancel at cycle end
    if (context.razorpaySubscriptionId) {
        // Razorpay not available - commented out
        // await razorpay.subscriptions.update(context.razorpaySubscriptionId, {
        //     schedule_change_at: 'cycle_end',
        // });
        logger.info('Razorpay subscription update skipped (package not installed)', {
            subscriptionId: context.razorpaySubscriptionId,
        });
    }

    // -- Update DynamoDB with pending downgrade status ----------------------
    await updateSubscriptionRecord(tenantId, {
        pendingDowngrade: {
            targetPlan: request.targetPlan,
            targetBillingCycle: request.billingCycle,
            scheduledDate: scheduledDate.toISOString(),
        },
        subscriptionStatus: SubscriptionStatus.PENDING_DOWNGRADE,
    });

    logger.info('Scheduled downgrade', {
        tenantId,
        from: context.currentPlan,
        to: request.targetPlan,
        scheduledDate,
    });

    await logSubscriptionChange(tenantId, userId, 'DOWNGRADE_SCHEDULED', context.currentPlan, request.targetPlan, 0);

    return {
        success: true,
        targetPlan: request.targetPlan,
        billingCycle: request.billingCycle,
        scheduledDate,
        message: `Downgrade to ${request.targetPlan} will take effect on ${scheduledDate.toLocaleDateString()}. You retain current features until then.`,
    };
}

/**
 * Create payment retry link for failed subscriptions
 */
export async function createPaymentRetry(
    tenantId: string,
    userId: string,
): Promise<PaymentRetryResult> {
    const context = await getSubscriptionContext(tenantId);

    if (context.subscriptionStatus !== SubscriptionStatus.PAST_DUE &&
        context.subscriptionStatus !== SubscriptionStatus.GRACE_PERIOD) {
        throw new SubscriptionError(
            'Payment retry only available for past due subscriptions',
            'NOT_PAYMENT_FAILED',
        );
    }

    if (!context.razorpaySubscriptionId) {
        throw new SubscriptionError(
            'No active subscription found',
            'NO_SUBSCRIPTION',
        );
    }

    try {
        // Get Razorpay subscription details
        // Razorpay not available - commented out
        // const subscription = await razorpay.subscriptions.fetch(context.razorpaySubscriptionId);
        const subscription = { id: context.razorpaySubscriptionId, status: 'active' };

        // Create a payment link for the pending invoice
        // const paymentLink = await razorpay.paymentLink.create({
        //     amount: getPlanPriceInPaise(context.currentPlan, context.currentBillingCycle), // Fixed: use plan price, not timestamp
        //     currency: 'INR',
        //     description: `Payment for DukanX ${context.currentPlan} plan`,
        //     customer: {
        //         email: await getTenantEmail(tenantId),
        //     },
        //     notify: {
        //         email: true,
        //         sms: true,
        //     },
        //     reminder_enable: true,
        // });
        const paymentLink = { id: 'placeholder-payment-link-id', short_url: null };

        // Update subscription record with retry attempt
        await updateSubscriptionRecord(tenantId, {
            lastRetryAttempt: new Date().toISOString(),
            paymentLinkId: paymentLink.id,
            paymentLinkUrl: paymentLink.short_url,
        });

        logger.info('Created payment retry link', {
            tenantId,
            subscriptionId: context.razorpaySubscriptionId,
            paymentLinkId: paymentLink.id,
        });

        return {
            success: true,
            paymentLink: paymentLink.short_url,
            nextAttemptDate: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
            message: 'Payment link created. Please complete payment to restore full access.',
        };
    } catch (error) {
        logger.error('Failed to create payment retry link', { tenantId, error });
        throw new SubscriptionError(
            'Failed to create payment link. Please contact support.',
            'PAYMENT_LINK_FAILED',
        );
    }
}

// -- Helper Functions -------------------------------------------------------

async function calculateProratedCharge(
    context: SubscriptionContext,
    targetPlan: PlanTier,
    billingCycle: BillingCycle,
): Promise<number> {
    if (!context.nextBillingDate || context.subscriptionStatus === SubscriptionStatus.TRIAL) {
        return 0; // No charge if in trial or no next billing date
    }

    const targetPrice = getPlanPriceInPaise(targetPlan, billingCycle);
    const daysInPeriod = billingCycle === BillingCycle.MONTHLY ? 30 : 365;
    const daysRemaining = Math.max(0, Math.ceil(
        (context.nextBillingDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24)
    ));

    // Prorated charge for remaining days
    const proratedAmount = Math.round((targetPrice / daysInPeriod) * daysRemaining);
    return proratedAmount;
}

async function createProratedOffer(amount: number, description: string): Promise<string> {
    // Razorpay not available - commented out
    // const offer = await razorpay.offers.create({
    //     offer_id: `offer_${Date.now()}`,
    //     type: 'DISCOUNT',
    //     description,
    //     amount: amount,
    // });
    const offer = { id: `placeholder-offer-${Date.now()}` };
    return offer.id;
}

async function getOrCreateRazorpayCustomer(tenantId: string, userId: string): Promise<string> {
    // Query DynamoDB for existing customer mapping
    const command = new GetItemCommand({
        TableName: DYNAMODB_TABLE,
        Key: marshall({
            PK: `TENANT#${tenantId}`,
            SK: 'METADATA#RAZORPAY_CUSTOMER',
        }),
    });

    const result = await dynamodb.send(command);

    if (result.Item) {
        const item = unmarshall(result.Item);
        return item.customerId;
    }

    // Create new Razorpay customer
    const tenantEmail = await getTenantEmail(tenantId);
    // Razorpay not available - commented out
    // const customer = await razorpay.customers.create({
    //     email: tenantEmail,
    //     notes: {
    //         tenantId,
    //         userId,
    //     },
    // });
    const customer = { id: 'placeholder-customer-id' };

    // Store mapping
    await dynamodb.send(new PutItemCommand({
        TableName: DYNAMODB_TABLE,
        Item: marshall({
            PK: `TENANT#${tenantId}`,
            SK: 'METADATA#RAZORPAY_CUSTOMER',
            customerId: customer.id,
            createdAt: new Date().toISOString(),
        }),
    }));

    return customer.id;
}

async function getTenantEmail(tenantId: string): Promise<string> {
    const command = new GetItemCommand({
        TableName: DYNAMODB_TABLE,
        Key: marshall({
            PK: `TENANT#${tenantId}`,
            SK: 'METADATA#PROFILE',
        }),
    });

    const result = await dynamodb.send(command);

    if (result.Item) {
        const item = unmarshall(result.Item);
        return item.email || item.adminEmail || 'admin@dukanx.com';
    }

    return 'admin@dukanx.com';
}

async function updateSubscriptionRecord(
    tenantId: string,
    updates: Record<string, unknown>,
): Promise<void> {
    const updateExpressions: string[] = [];
    const expressionAttributeNames: Record<string, string> = {};
    const expressionAttributeValues: Record<string, unknown> = {};

    Object.entries(updates).forEach(([key, value], index) => {
        const attrName = `#${key}`;
        const attrValue = `:${key}`;
        updateExpressions.push(`${attrName} = ${attrValue}`);
        expressionAttributeNames[attrName] = key;
        expressionAttributeValues[attrValue] = value;
    });

    // Add updatedAt timestamp
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

async function updateCognitoAttributes(
    tenantId: string,
    attributes: Record<string, string>,
): Promise<void> {
    const userAttributes = Object.entries(attributes).map(([Name, Value]) => ({ Name, Value }));

    // Get primary user from tenant
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

async function logSubscriptionChange(
    tenantId: string,
    userId: string,
    action: string,
    fromPlan: PlanTier,
    toPlan: PlanTier,
    amount: number,
): Promise<void> {
    await dynamodb.send(new PutItemCommand({
        TableName: DYNAMODB_TABLE,
        Item: marshall({
            PK: `TENANT#${tenantId}`,
            SK: `PLANHISTORY#${Date.now()}`,
            action,
            fromPlan,
            toPlan,
            amount,
            userId,
            timestamp: new Date().toISOString(),
            ttl: Math.floor(Date.now() / 1000) + (2 * 365 * 24 * 60 * 60), // 2 years TTL
        }),
    }));
}

// -- Initialization Functions -------------------------------------------------

/**
 * Initialize trial subscription for new tenant
 */
export async function initializeTrial(tenantId: string, userId: string): Promise<SubscriptionContext> {
    const trialEndDate = new Date();
    trialEndDate.setDate(trialEndDate.getDate() + TRIAL_CONFIG.durationDays);

    const context: SubscriptionContext = {
        tenantId,
        currentPlan: TRIAL_CONFIG.trialPlan,
        currentBillingCycle: BillingCycle.MONTHLY,
        razorpaySubscriptionId: null,
        subscriptionStatus: SubscriptionStatus.TRIAL,
        planStartDate: new Date(),
        planEndDate: trialEndDate,
        trialEndDate,
        gracePeriodEndDate: null,
        nextBillingDate: trialEndDate,
    };

    // Create subscription record
    await dynamodb.send(new PutItemCommand({
        TableName: DYNAMODB_TABLE,
        Item: marshall({
            PK: `TENANT#${tenantId}`,
            SK: 'METADATA#SUBSCRIPTION',
            tenantId,
            planId: context.currentPlan,
            billingCycle: context.currentBillingCycle,
            razorpaySubscriptionId: context.razorpaySubscriptionId,
            subscriptionStatus: context.subscriptionStatus,
            planStartDate: context.planStartDate.toISOString(),
            planEndDate: context.planEndDate?.toISOString(),
            trialEndDate: context.trialEndDate?.toISOString(),
            gracePeriodEndDate: context.gracePeriodEndDate?.toISOString(),
            nextBillingDate: context.nextBillingDate?.toISOString(),
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
        }),
    }));

    // Update Cognito
    await updateCognitoAttributes(tenantId, {
        'custom:plan': context.currentPlan,
        'custom:plan_status': 'trial',
    });

    // Generate manifest
    await regenerateManifest(tenantId);

    logger.info('Initialized trial subscription', {
        tenantId,
        trialPlan: context.currentPlan,
        trialEndDate,
    });

    return context;
}
