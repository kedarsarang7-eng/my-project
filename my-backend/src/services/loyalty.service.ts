// ============================================================================
// Loyalty Points Service (DynamoDB)
// ============================================================================
// AUDIT FEATURE: Grocery loyalty points system.
//
// DynamoDB Entities:
//   PK: TENANT#{tenantId}, SK: LOYALTY#{customerId}  — Balance record
//   PK: TENANT#{tenantId}, SK: LOYALTYTXN#{txnId}    — Transaction history
//
// Earning Rules (configurable per tenant via SETTINGS):
//   Default: 1 point per ₹100 spent
//
// Redemption:
//   100 points = ₹10 discount (configurable)
//   Applied as bill-level discount in createInvoice
//   Atomic: TransactWrite deducts points + creates invoice
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    Keys, TABLE_NAME,
    getItem, putItem, queryItems, updateItem, transactWrite,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';
import { config } from '../config/environment';

export class LoyaltyError extends AppError {
    constructor(message: string, statusCode = 400) {
        super(message, statusCode, 'LOYALTY_ERROR');
    }
}

interface LoyaltyBalance {
    tenantId: string;
    customerId: string;
    totalPoints: number;
    lifetimePoints: number;
    redeemedPoints: number;
    tier: 'bronze' | 'silver' | 'gold' | 'platinum';
    lastEarnedAt?: string;
    lastRedeemedAt?: string;
}

interface LoyaltyTransaction {
    id: string;
    tenantId: string;
    customerId: string;
    type: 'earn' | 'redeem' | 'adjust' | 'expire';
    points: number; // positive = earn, negative = redeem
    balanceAfter: number;
    invoiceId?: string;
    invoiceNumber?: string;
    reason?: string;
    createdAt: string;
    createdBy: string;
}

// Default earning rate: 1 point per ₹100 (10000 paise)
const DEFAULT_POINTS_PER_PAISE = 10000; // earn 1 point per this many paise
// Default redemption: 100 points = ₹10 (1000 paise)
const DEFAULT_PAISE_PER_POINT = 10; // each point is worth this many paise

/**
 * Get loyalty balance for a customer.
 */
export async function getBalance(
    tenantId: string,
    customerId: string,
): Promise<LoyaltyBalance | null> {
    const record = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        `LOYALTY#${customerId}`,
    );
    if (!record) return null;

    return {
        tenantId,
        customerId,
        totalPoints: Number(record.totalPoints) || 0,
        lifetimePoints: Number(record.lifetimePoints) || 0,
        redeemedPoints: Number(record.redeemedPoints) || 0,
        tier: determineTier(Number(record.lifetimePoints) || 0),
        lastEarnedAt: record.lastEarnedAt,
        lastRedeemedAt: record.lastRedeemedAt,
    };
}

/**
 * Award points after invoice finalization.
 * Called automatically from invoice.service.ts post-finalization hook.
 */
export async function earnPoints(
    tenantId: string,
    customerId: string,
    invoiceTotalCents: number,
    invoiceId: string,
    invoiceNumber: string,
    createdBy: string,
): Promise<{ pointsEarned: number; newBalance: number }> {
    if (!customerId || customerId === 'guest') {
        return { pointsEarned: 0, newBalance: 0 };
    }

    // Get tenant settings for custom earning rate
    let settings: Record<string, any> | null = null;
    try {
        settings = await getItem<Record<string, any>>(
            Keys.tenantPK(tenantId), 'SETTINGS#LOYALTY',
        );
    } catch { /* Use defaults */ }

    const pointsPerPaise = Number(settings?.pointsPerPaise) || DEFAULT_POINTS_PER_PAISE;
    const pointsEarned = Math.floor(invoiceTotalCents / pointsPerPaise);

    if (pointsEarned <= 0) {
        return { pointsEarned: 0, newBalance: 0 };
    }

    // Idempotent: one earn row per invoice (SK is deterministic)
    const earnMarkerSk = `LOYALTYTXN#EARN#${invoiceId}`;
    const existingEarn = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        earnMarkerSk,
    );
    if (existingEarn) {
        const bal = await getBalance(tenantId, customerId);
        const n = Number(existingEarn.points) || 0;
        return { pointsEarned: n, newBalance: bal?.totalPoints ?? n };
    }

    const now = new Date().toISOString();
    const tableName = config.dynamodb.tableName;

    // Atomic: update balance + create transaction
    const transactItems: any[] = [];

    // Upsert loyalty balance
    transactItems.push({
        Update: {
            TableName: tableName,
            Key: {
                PK: Keys.tenantPK(tenantId),
                SK: `LOYALTY#${customerId}`,
            },
            UpdateExpression:
                'SET totalPoints = if_not_exists(totalPoints, :zero) + :pts, ' +
                'lifetimePoints = if_not_exists(lifetimePoints, :zero) + :pts, ' +
                'lastEarnedAt = :now, updatedAt = :now, ' +
                'entityType = :entityType, tenantId = :tenantId, customerId = :customerId',
            ExpressionAttributeValues: {
                ':pts': pointsEarned,
                ':zero': 0,
                ':now': now,
                ':entityType': 'LOYALTY',
                ':tenantId': tenantId,
                ':customerId': customerId,
            },
        },
    });

    const txnId = earnMarkerSk;
    // Create transaction record (SK matches pre-check for idempotency)
    transactItems.push({
        Put: {
            TableName: tableName,
            Item: {
                PK: Keys.tenantPK(tenantId),
                SK: earnMarkerSk,
                entityType: 'LOYALTY_TXN',
                id: txnId,
                tenantId,
                customerId,
                type: 'earn',
                points: pointsEarned,
                invoiceId,
                invoiceNumber,
                createdAt: now,
                createdBy,
            },
        },
    });

    try {
        await transactWrite(transactItems);
    } catch (err: any) {
        if (err?.name === 'TransactionCanceledException') {
            const after = await getItem<Record<string, any>>(
                Keys.tenantPK(tenantId), earnMarkerSk,
            );
            if (after) {
                const bal = await getBalance(tenantId, customerId);
                const n = Number(after.points) || 0;
                return { pointsEarned: n, newBalance: bal?.totalPoints ?? n };
            }
        }
        throw err;
    }

    // Denormalized total for book_store / list UIs (best-effort; must not break earn)
    try {
        await updateItem(Keys.tenantPK(tenantId), Keys.customerSK(customerId), {
            updateExpression: 'ADD loyaltyPoints :pts SET updatedAt = :now',
            expressionAttributeValues: { ':pts': pointsEarned, ':now': now },
            conditionExpression: 'attribute_exists(PK)',
        });
    } catch (e: any) {
        if (e?.name !== 'ConditionalCheckFailedException') {
            logger.warn('CUSTOMER loyaltyPoints mirror failed', {
                tenantId, customerId, error: e?.message,
            });
        }
    }

    // Read updated balance
    const updated = await getBalance(tenantId, customerId);
    const newBalance = updated?.totalPoints || pointsEarned;

    logger.info('Loyalty points earned', {
        tenantId, customerId, pointsEarned, newBalance, invoiceId,
    });

    return { pointsEarned, newBalance };
}

/**
 * Redeem points for a discount.
 * Returns the discount amount in paise that can be applied to the invoice.
 */
export async function redeemPoints(
    tenantId: string,
    customerId: string,
    pointsToRedeem: number,
    createdBy: string,
    invoiceId?: string,
): Promise<{ discountCents: number; pointsRedeemed: number; newBalance: number }> {
    if (pointsToRedeem <= 0) {
        throw new LoyaltyError('Points to redeem must be positive');
    }

    const balance = await getBalance(tenantId, customerId);
    if (!balance) {
        throw new LoyaltyError('No loyalty account found for this customer', 404);
    }

    if (balance.totalPoints < pointsToRedeem) {
        throw new LoyaltyError(
            `Insufficient points. Available: ${balance.totalPoints}, Requested: ${pointsToRedeem}`,
        );
    }

    // Get tenant settings for custom redemption rate
    let settings: Record<string, any> | null = null;
    try {
        settings = await getItem<Record<string, any>>(
            Keys.tenantPK(tenantId), 'SETTINGS#LOYALTY',
        );
    } catch { /* Use defaults */ }

    const paisePerPoint = Number(settings?.paisePerPoint) || DEFAULT_PAISE_PER_POINT;
    const discountCents = pointsToRedeem * paisePerPoint;

    const now = new Date().toISOString();
    const txnId = uuidv4();
    const tableName = config.dynamodb.tableName;

    // Atomic: deduct balance + create transaction
    const transactItems: any[] = [
        {
            Update: {
                TableName: tableName,
                Key: {
                    PK: Keys.tenantPK(tenantId),
                    SK: `LOYALTY#${customerId}`,
                },
                UpdateExpression:
                    'SET totalPoints = totalPoints - :pts, ' +
                    'redeemedPoints = if_not_exists(redeemedPoints, :zero) + :pts, ' +
                    'lastRedeemedAt = :now, updatedAt = :now',
                ConditionExpression: 'totalPoints >= :pts',
                ExpressionAttributeValues: {
                    ':pts': pointsToRedeem,
                    ':zero': 0,
                    ':now': now,
                },
            },
        },
        {
            Put: {
                TableName: tableName,
                Item: {
                    PK: Keys.tenantPK(tenantId),
                    SK: `LOYALTYTXN#${txnId}`,
                    entityType: 'LOYALTY_TXN',
                    id: txnId,
                    tenantId,
                    customerId,
                    type: 'redeem',
                    points: -pointsToRedeem,
                    discountCents,
                    invoiceId: invoiceId || null,
                    createdAt: now,
                    createdBy,
                },
            },
        },
    ];

    try {
        await transactWrite(transactItems);
    } catch (err: any) {
        if (err.name === 'TransactionCanceledException') {
            throw new LoyaltyError('Insufficient points (concurrent redemption)');
        }
        throw err;
    }

    const newBalance = balance.totalPoints - pointsToRedeem;

    logger.info('Loyalty points redeemed', {
        tenantId, customerId, pointsRedeemed: pointsToRedeem,
        discountCents, newBalance,
    });

    return { discountCents, pointsRedeemed: pointsToRedeem, newBalance };
}

/**
 * Get transaction history for a customer.
 */
export async function getHistory(
    tenantId: string,
    customerId: string,
    limit = 50,
): Promise<LoyaltyTransaction[]> {
    const result = await queryItems<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'LOYALTYTXN#',
        {
            filterExpression: 'customerId = :cid',
            expressionAttributeValues: { ':cid': customerId },
            limit,
        },
    );

    return result.items
        .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
        .map(item => ({
            id: item.id,
            tenantId: item.tenantId,
            customerId: item.customerId,
            type: item.type,
            points: item.points,
            balanceAfter: item.balanceAfter || 0,
            invoiceId: item.invoiceId,
            invoiceNumber: item.invoiceNumber,
            reason: item.reason,
            createdAt: item.createdAt,
            createdBy: item.createdBy,
        }));
}

/**
 * Determine loyalty tier based on lifetime points.
 */
function determineTier(lifetimePoints: number): 'bronze' | 'silver' | 'gold' | 'platinum' {
    if (lifetimePoints >= 10000) return 'platinum';
    if (lifetimePoints >= 5000) return 'gold';
    if (lifetimePoints >= 1000) return 'silver';
    return 'bronze';
}
