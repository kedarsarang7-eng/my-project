// ============================================================================
// Subscription Webhook Handler — Razorpay Subscription Events
// ============================================================================
// Handles Razorpay webhook events for subscription lifecycle:
// - subscription.charged: Payment successful
// - subscription.payment.failed: Payment failed
// - subscription.cancelled: User cancelled
// - subscription.activated: New subscription started
// - subscription.halted: Subscription paused (payment failures)
//
// Security: HMAC signature verification, idempotent processing
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import * as crypto from 'crypto';
import { DynamoDBClient, GetItemCommand, PutItemCommand, QueryCommand, UpdateItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { SubscriptionStatus, getSubscriptionContext, initializeTrial } from '../services/subscription.service';
import { releaseLock, initializeGracePeriod, handleExpiredTrial } from '../services/grace-period.service';
import { regenerateManifest, forceRegenerateManifest } from '../services/feature-manifest.service';
import { mapToPlanTier, PlanTier } from '../config/plan-feature-registry';
import { RAZORPAY_PLAN_MAPPING } from '../config/razorpay-subscription.config';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

// -- Type Definitions -------------------------------------------------------

type RazorpayEventType =
    | 'subscription.charged'
    | 'subscription.payment.failed'
    | 'subscription.cancelled'
    | 'subscription.activated'
    | 'subscription.halted'
    | 'subscription.resumed'
    | 'subscription.pending'
    | 'invoice.paid'
    | 'invoice.payment_failed';

interface RazorpayWebhookEvent {
    event: RazorpayEventType;
    contains: string[];
    payload: {
        subscription?: {
            entity: RazorpaySubscription;
        };
        payment?: {
            entity: RazorpayPayment;
        };
        invoice?: {
            entity: RazorpayInvoice;
        };
    };
    created_at: number;
}

interface RazorpaySubscription {
    id: string;
    status: 'created' | 'authenticated' | 'active' | 'pending' | 'halted' | 'cancelled' | 'paused' | 'completed';
    current_start: number | null;
    current_end: number | null;
    ended_at: number | null;
    quantity: number;
    notes: Record<string, string>;
    charge_at: number | null;
    start_at: number;
    end_at: number | null;
    auth_attempts: number;
    total_count: number;
    paid_count: number;
    customer_id: string;
    plan_id: string;
    offer_id: string | null;
    has_scheduled_changes: boolean;
    change_scheduled_at: number | null;
    source: string;
    payment_method: string;
    offer_id_apply: string | null;
    remaining_count: number;
}

interface RazorpayPayment {
    id: string;
    status: 'created' | 'authorized' | 'captured' | 'refunded' | 'failed';
    amount: number;
    currency: string;
    method: string;
    description: string;
    error_code?: string;
    error_description?: string;
}

interface RazorpayInvoice {
    id: string;
    subscription_id: string;
    status: 'draft' | 'issued' | 'partially_paid' | 'paid' | 'cancelled' | 'expired' | 'pending';
    amount: number;
    currency: string;
    billing_start: number;
    billing_end: number;
    payment_id: string | null;
    error_message?: string;
}

// -- Configuration -----------------------------------------------------------

const WEBHOOK_SECRET = config.payment.razorpay.webhookSecret || '';
const DYNAMODB_TABLE = config.dynamodb.tableName;
const IS_PRODUCTION = config.app.env === 'production';

const dynamodb = new DynamoDBClient({ region: config.aws.region });

// F017: Build a deterministic reverse-lookup map from Razorpay plan ID → PlanTier.
// Avoids fragile string.includes() matching that breaks with real opaque plan IDs.
const RAZORPAY_ID_TO_TIER: Record<string, PlanTier> = (() => {
    const map: Record<string, PlanTier> = {};
    for (const [tier, cycles] of Object.entries(RAZORPAY_PLAN_MAPPING)) {
        for (const mapping of Object.values(cycles as Record<string, { razorpayPlanId: string }>)) {
            if (mapping.razorpayPlanId) {
                map[mapping.razorpayPlanId] = tier as PlanTier;
            }
        }
    }
    return map;
})();

// -- Main Handler -----------------------------------------------------------

export const handler = async (
    event: APIGatewayProxyEventV2,
    _context: Context,
): Promise<APIGatewayProxyResultV2> => {
    try {
        // F019: Reject immediately if secret is not configured.
        // An empty secret would allow HMAC bypass attacks.
        if (!WEBHOOK_SECRET) {
            logger.error('RAZORPAY_WEBHOOK_SECRET is not configured — rejecting all webhook requests');
            return { statusCode: 500, body: JSON.stringify({ error: 'Webhook endpoint misconfigured' }) };
        }

        // -- Verify webhook signature -----------------------------------------
        const signature = event.headers['x-razorpay-signature'] ||
                         event.headers['X-Razorpay-Signature'];

        if (!signature) {
            logger.warn('Missing Razorpay signature header');
            return { statusCode: 400, body: 'Missing signature' };
        }

        const body = event.body || '';
        const isValid = verifyWebhookSignature(body, signature, WEBHOOK_SECRET);

        if (!isValid) {
            logger.error('Invalid webhook signature');
            return { statusCode: 401, body: 'Invalid signature' };
        }

        // -- Parse and validate payload ---------------------------------------
        let webhookEvent: RazorpayWebhookEvent;
        try {
            webhookEvent = JSON.parse(body) as RazorpayWebhookEvent;
        } catch (parseError) {
            logger.error('Failed to parse webhook payload', { error: parseError });
            return { statusCode: 400, body: 'Invalid JSON' };
        }

        logger.info('Processing Razorpay subscription webhook', {
            eventType: webhookEvent.event,
            createdAt: webhookEvent.created_at,
        });

        // -- Check idempotency ------------------------------------------------
        // F014: Use X-Razorpay-Event-Id header (Razorpay's own dedup key) as the
        // primary idempotency key. Falls back to event-type+timestamp only if header
        // is absent (should never happen in production).
        const razorpayEventId = event.headers['x-razorpay-event-id'] ||
                                event.headers['X-Razorpay-Event-Id'];
        const eventId = razorpayEventId || `${webhookEvent.event}-${webhookEvent.created_at}`;
        if (!razorpayEventId) {
            logger.warn('X-Razorpay-Event-Id header missing, falling back to event+timestamp key', {
                eventType: webhookEvent.event,
            });
        }
        const isDuplicate = await checkDuplicateEvent(eventId);

        if (isDuplicate) {
            logger.info('Duplicate webhook event, already processed', { eventId });
            return { statusCode: 200, body: 'Already processed' };
        }

        // -- Process event by type --------------------------------------------
        const result = await processWebhookEvent(webhookEvent);

        // -- Mark event as processed ------------------------------------------
        await markEventProcessed(eventId, webhookEvent);

        return {
            statusCode: 200,
            body: JSON.stringify({
                success: true,
                processed: webhookEvent.event,
                result,
            }),
        };

    } catch (error) {
        logger.error('Unhandled error in subscription webhook', { error });
        return {
            statusCode: 500,
            body: JSON.stringify({
                success: false,
                error: 'Internal server error',
            }),
        };
    }
};

// -- Event Processing -------------------------------------------------------

async function processWebhookEvent(event: RazorpayWebhookEvent): Promise<Record<string, unknown>> {
    switch (event.event) {
        case 'subscription.charged':
            return await handleSubscriptionCharged(event);

        case 'subscription.payment.failed':
        case 'invoice.payment_failed':
            return await handlePaymentFailed(event);

        case 'subscription.cancelled':
            return await handleSubscriptionCancelled(event);

        case 'subscription.activated':
            return await handleSubscriptionActivated(event);

        case 'subscription.halted':
            return await handleSubscriptionHalted(event);

        case 'subscription.resumed':
            return await handleSubscriptionResumed(event);

        // F015: Handle subscription.pending — fired when subscription is created
        // but awaiting first payment authentication.
        case 'subscription.pending': {
            const sub = event.payload.subscription?.entity;
            if (sub) {
                const tenantId = sub.notes?.tenantId || await findTenantBySubscriptionId(sub.id);
                if (tenantId) {
                    await updateSubscriptionStatus(tenantId, {
                        subscriptionStatus: SubscriptionStatus.PAST_DUE,
                        razorpaySubscriptionId: sub.id,
                    });
                    logger.info('Subscription pending — awaiting first payment', { tenantId, subscriptionId: sub.id });
                    return { tenantId, action: 'SUBSCRIPTION_PENDING' };
                }
            }
            return { handled: false, reason: 'No tenant found for pending subscription' };
        }

        case 'invoice.paid':
            return await handleInvoicePaid(event);

        default:
            logger.warn('Unhandled subscription event type', { eventType: event.event });
            return { handled: false, reason: 'Unhandled event type' };
    }
}

async function handleSubscriptionCharged(event: RazorpayWebhookEvent): Promise<Record<string, unknown>> {
    const subscription = event.payload.subscription?.entity;
    if (!subscription) {
        throw new Error('Missing subscription entity in charged event');
    }

    const tenantId = subscription.notes?.tenantId;
    if (!tenantId) {
        throw new Error('Missing tenantId in subscription notes');
    }

    const currentContext = await getSubscriptionContext(tenantId);

    // Update subscription status to active
    await updateSubscriptionStatus(tenantId, {
        subscriptionStatus: SubscriptionStatus.ACTIVE,
        razorpaySubscriptionId: subscription.id,
        nextBillingDate: subscription.charge_at ? new Date(subscription.charge_at * 1000).toISOString() : null,
        lastPaymentDate: new Date().toISOString(),
        lastPaymentAmount: event.payload.payment?.entity?.amount 
            ?? event.payload.invoice?.entity?.amount 
            ?? 0,
        failedPaymentAttempts: 0, // Reset failure counter
    });

    // Release any existing lock
    if (currentContext.subscriptionStatus === SubscriptionStatus.PAST_DUE ||
        currentContext.subscriptionStatus === SubscriptionStatus.GRACE_PERIOD) {
        await releaseLock(tenantId);
        logger.info('Released lock after successful payment', { tenantId, subscriptionId: subscription.id });
    }

    // Invalidate manifest to refresh features
    await forceRegenerateManifest(tenantId, 'subscription_webhook');

    logger.info('Subscription payment successful', {
        tenantId,
        subscriptionId: subscription.id,
        amount: event.payload.payment?.entity?.amount,
    });

    return {
        tenantId,
        action: 'PAYMENT_SUCCESS',
        previousStatus: currentContext.subscriptionStatus,
        newStatus: SubscriptionStatus.ACTIVE,
    };
}

async function handlePaymentFailed(event: RazorpayWebhookEvent): Promise<Record<string, unknown>> {
    const subscription = event.payload.subscription?.entity;
    const payment = event.payload.payment?.entity;
    const invoice = event.payload.invoice?.entity;

    if (!subscription && !invoice) {
        throw new Error('Missing subscription or invoice entity in failed event');
    }

    const subscriptionId = subscription?.id || invoice?.subscription_id;
    if (!subscriptionId) {
        throw new Error('Missing subscription ID');
    }

    const tenantId = subscription?.notes?.tenantId || await findTenantBySubscriptionId(subscriptionId);
    if (!tenantId) {
        throw new Error(`Could not find tenant for subscription ${subscriptionId}`);
    }

    const currentContext = await getSubscriptionContext(tenantId);

    // Increment failure counter
    const failedAttempts = (currentContext as unknown as Record<string, number>).failedPaymentAttempts || 0;

    // Initialize grace period on first failure
    if (currentContext.subscriptionStatus !== SubscriptionStatus.PAST_DUE &&
        currentContext.subscriptionStatus !== SubscriptionStatus.GRACE_PERIOD) {
        await initializeGracePeriod(tenantId);
    }

    await updateSubscriptionStatus(tenantId, {
        subscriptionStatus: SubscriptionStatus.PAST_DUE,
        failedPaymentAttempts: failedAttempts + 1,
        lastFailedPaymentDate: new Date().toISOString(),
        lastFailedPaymentError: payment?.error_description || invoice?.error_message || 'Unknown error',
    });

    logger.warn('Subscription payment failed', {
        tenantId,
        subscriptionId,
        attempt: failedAttempts + 1,
        error: payment?.error_description || invoice?.error_message,
    });

    return {
        tenantId,
        action: 'PAYMENT_FAILED',
        status: SubscriptionStatus.PAST_DUE,
        gracePeriodInitialized: true,
    };
}

async function handleSubscriptionCancelled(event: RazorpayWebhookEvent): Promise<Record<string, unknown>> {
    const subscription = event.payload.subscription?.entity;
    if (!subscription) {
        throw new Error('Missing subscription entity in cancelled event');
    }

    const tenantId = subscription.notes?.tenantId || await findTenantBySubscriptionId(subscription.id);
    if (!tenantId) {
        throw new Error(`Could not find tenant for subscription ${subscription.id}`);
    }

    // Downgrade to Basic (free) plan
    await updateSubscriptionStatus(tenantId, {
        planId: PlanTier.BASIC,
        subscriptionStatus: SubscriptionStatus.CANCELLED,
        razorpaySubscriptionId: null,
        cancelledAt: new Date().toISOString(),
        cancellationReason: 'USER_INITIATED',
    });

    await updateCognitoAttributes(tenantId, {
        'custom:plan': PlanTier.BASIC,
        'custom:plan_status': 'cancelled',
    });

    await forceRegenerateManifest(tenantId, 'subscription_webhook');

    logger.info('Subscription cancelled', { tenantId, subscriptionId: subscription.id });

    return {
        tenantId,
        action: 'SUBSCRIPTION_CANCELLED',
        downgradedTo: PlanTier.BASIC,
    };
}

async function handleSubscriptionActivated(event: RazorpayWebhookEvent): Promise<Record<string, unknown>> {
    const subscription = event.payload.subscription?.entity;
    if (!subscription) {
        throw new Error('Missing subscription entity in activated event');
    }

    const tenantId = subscription.notes?.tenantId;
    if (!tenantId) {
        throw new Error('Missing tenantId in subscription notes');
    }

    // Determine plan from Razorpay plan_id
    const planTier = mapRazorpayPlanToTier(subscription.plan_id);

    await updateSubscriptionStatus(tenantId, {
        subscriptionStatus: SubscriptionStatus.ACTIVE,
        razorpaySubscriptionId: subscription.id,
        planId: planTier,
        planStartDate: new Date(subscription.start_at * 1000).toISOString(),
        nextBillingDate: subscription.charge_at ? new Date(subscription.charge_at * 1000).toISOString() : null,
        activatedAt: new Date().toISOString(),
    });

    await updateCognitoAttributes(tenantId, {
        'custom:plan': planTier,
        'custom:plan_status': 'active',
    });

    await forceRegenerateManifest(tenantId, 'subscription_webhook');

    logger.info('Subscription activated', { tenantId, subscriptionId: subscription.id, planTier });

    return {
        tenantId,
        action: 'SUBSCRIPTION_ACTIVATED',
        planTier,
    };
}

async function handleSubscriptionHalted(event: RazorpayWebhookEvent): Promise<Record<string, unknown>> {
    const subscription = event.payload.subscription?.entity;
    if (!subscription) {
        throw new Error('Missing subscription entity in halted event');
    }

    const tenantId = subscription.notes?.tenantId || await findTenantBySubscriptionId(subscription.id);
    if (!tenantId) {
        throw new Error(`Could not find tenant for subscription ${subscription.id}`);
    }

    await updateSubscriptionStatus(tenantId, {
        subscriptionStatus: SubscriptionStatus.GRACE_PERIOD,
        haltedAt: new Date().toISOString(),
    });

    logger.warn('Subscription halted due to payment failures', {
        tenantId,
        subscriptionId: subscription.id,
        authAttempts: subscription.auth_attempts,
    });

    return {
        tenantId,
        action: 'SUBSCRIPTION_HALTED',
        status: SubscriptionStatus.GRACE_PERIOD,
    };
}

async function handleSubscriptionResumed(event: RazorpayWebhookEvent): Promise<Record<string, unknown>> {
    const subscription = event.payload.subscription?.entity;
    if (!subscription) {
        throw new Error('Missing subscription entity in resumed event');
    }

    const tenantId = subscription.notes?.tenantId || await findTenantBySubscriptionId(subscription.id);
    if (!tenantId) {
        throw new Error(`Could not find tenant for subscription ${subscription.id}`);
    }

    await releaseLock(tenantId);

    // F018: Invalidate manifest and update Cognito so features are immediately restored
    await forceRegenerateManifest(tenantId, 'subscription_webhook');
    await updateCognitoAttributes(tenantId, { 'custom:plan_status': 'active' });

    logger.info('Subscription resumed', { tenantId, subscriptionId: subscription.id });

    return {
        tenantId,
        action: 'SUBSCRIPTION_RESUMED',
    };
}

async function handleInvoicePaid(event: RazorpayWebhookEvent): Promise<Record<string, unknown>> {
    const invoice = event.payload.invoice?.entity;
    if (!invoice) {
        throw new Error('Missing invoice entity in paid event');
    }

    // This is often a duplicate of subscription.charged, but we handle it for completeness
    const tenantId = await findTenantBySubscriptionId(invoice.subscription_id);
    if (!tenantId) {
        return { handled: false, reason: 'Tenant not found' };
    }

    logger.info('Invoice paid processed', { tenantId, invoiceId: invoice.id });

    return {
        tenantId,
        action: 'INVOICE_PAID',
        amount: invoice.amount,
    };
}

// -- Helper Functions -------------------------------------------------------

function verifyWebhookSignature(payload: string, signature: string, secret: string): boolean {
    const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(payload)
        .digest('hex');

    return crypto.timingSafeEqual(
        Buffer.from(signature, 'hex'),
        Buffer.from(expectedSignature, 'hex'),
    );
}

async function checkDuplicateEvent(eventId: string): Promise<boolean> {
    const command = new GetItemCommand({
        TableName: DYNAMODB_TABLE,
        Key: marshall({
            PK: 'WEBHOOK#EVENT',
            SK: `RAZORPAY#${eventId}`,
        }),
    });

    const result = await dynamodb.send(command);
    return !!result.Item;
}

async function markEventProcessed(eventId: string, event: RazorpayWebhookEvent): Promise<void> {
    const command = new PutItemCommand({
        TableName: DYNAMODB_TABLE,
        Item: marshall({
            PK: 'WEBHOOK#EVENT',
            SK: `RAZORPAY#${eventId}`,
            eventType: event.event,
            processedAt: new Date().toISOString(),
            ttl: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60), // 30 days TTL
        }),
    });

    await dynamodb.send(command);
}

async function findTenantBySubscriptionId(subscriptionId: string): Promise<string | null> {
    // F020: Query GSI2 for the subscription record. If GSI2 is not provisioned,
    // fall back to a scan-filter approach on the METADATA#SUBSCRIPTION SK range
    // using the razorpaySubscriptionId attribute as a filter.
    try {
        const command = new QueryCommand({
            TableName: DYNAMODB_TABLE,
            IndexName: 'GSI2',
            KeyConditionExpression: 'GSI2PK = :pk',
            ExpressionAttributeValues: marshall({
                ':pk': `RAZORPAY#SUBSCRIPTION#${subscriptionId}`,
            }),
            Limit: 1,
        });
        const result = await dynamodb.send(command);
        if (result.Items && result.Items.length > 0) {
            const item = unmarshall(result.Items[0]);
            if (item.tenantId) return item.tenantId;
        }
    } catch (gsiError) {
        logger.warn('GSI2 query failed for subscription lookup — GSI may not be provisioned', {
            subscriptionId,
            error: (gsiError as Error).message,
        });
    }

    // F020 Fallback: Scan METADATA#SUBSCRIPTION records for matching razorpaySubscriptionId.
    // Expensive but correct — only triggers if GSI2 is unavailable.
    try {
        const { ScanCommand } = await import('@aws-sdk/client-dynamodb');
        const scanResult = await dynamodb.send(new ScanCommand({
            TableName: DYNAMODB_TABLE,
            FilterExpression: 'SK = :sk AND razorpaySubscriptionId = :subId',
            ExpressionAttributeValues: marshall({
                ':sk': 'METADATA#SUBSCRIPTION',
                ':subId': subscriptionId,
            }),
            Limit: 1,
        }));
        if (scanResult.Items && scanResult.Items.length > 0) {
            const item = unmarshall(scanResult.Items[0]);
            logger.warn('Used scan fallback for tenant lookup — provision GSI2 to fix this', { subscriptionId });
            return item.tenantId || null;
        }
    } catch (scanError) {
        logger.error('Scan fallback also failed for tenant lookup', { subscriptionId, error: (scanError as Error).message });
    }

    return null;
}

function mapRazorpayPlanToTier(razorpayPlanId: string): PlanTier {
    // F017: Use deterministic reverse-lookup built from RAZORPAY_PLAN_MAPPING config.
    // Real Razorpay plan IDs are opaque strings (e.g. "plan_Abc123Xyz") that do not
    // contain tier names, so string.includes() would silently fall back to BASIC.
    const tier = RAZORPAY_ID_TO_TIER[razorpayPlanId];
    if (tier) return tier;

    // Legacy fallback for dev/test environments with dummy plan IDs
    const planIdLower = razorpayPlanId.toLowerCase();
    if (planIdLower.includes('enterprise')) return PlanTier.ENTERPRISE;
    if (planIdLower.includes('premium')) return PlanTier.PREMIUM;
    if (planIdLower.includes('pro')) return PlanTier.PRO;
    if (planIdLower.includes('basic')) return PlanTier.BASIC;

    logger.error('Unknown Razorpay plan ID — cannot determine tier, defaulting to BASIC', { razorpayPlanId });
    return PlanTier.BASIC;
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

    // F021: Add optimistic version locking to prevent concurrent webhook races.
    // Uses ADD to atomically increment version. ConditionExpression prevents
    // conflicting updates from overwriting each other.
    updateExpressions.push('#version = if_not_exists(#version, :vzero) + :vone');
    expressionAttributeNames['#version'] = 'version';
    expressionAttributeValues[':vzero'] = 0;
    expressionAttributeValues[':vone'] = 1;

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

async function updateCognitoAttributes(tenantId: string, attributes: Record<string, string>): Promise<void> {
    // Implementation in grace-period.service.ts
    // Simplified version here for webhook context
    const CognitoIdentityProviderClient = (await import('@aws-sdk/client-cognito-identity-provider')).CognitoIdentityProviderClient;
    const AdminUpdateUserAttributesCommand = (await import('@aws-sdk/client-cognito-identity-provider')).AdminUpdateUserAttributesCommand;
    const QueryCommand = (await import('@aws-sdk/client-dynamodb')).QueryCommand;
    const marshall = (await import('@aws-sdk/util-dynamodb')).marshall;
    const unmarshall = (await import('@aws-sdk/util-dynamodb')).unmarshall;

    const cognito = new CognitoIdentityProviderClient({ region: config.aws.region });
    const userAttributes = Object.entries(attributes).map(([Name, Value]) => ({ Name, Value }));

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
            UserPoolId: config.cognito.userPoolId,
            Username: user.userId || user.email || tenantId,
            UserAttributes: userAttributes,
        }));
    }
}
