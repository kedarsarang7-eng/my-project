// ============================================================================
// Lambda Handler — Perishable Batch Expiry Cron (EventBridge)
// ============================================================================
// Triggered daily by EventBridge to scan all perishable records across
// pharmacy AND grocery tenants:
//   - Pharmacy: MEDBATCH# records (batch-level tracking)
//   - Grocery:  PRODUCT# records with expiryDate (SKU-level tracking)
//
// Identifies expired entries (expiryDate < today), marks them accordingly,
// and prevents future sale from expired stock.
//
// Schedule: rate(1 day) — runs at midnight UTC
//
// This is a BACKGROUND job — no auth required. It uses scanTable (admin-only)
// since it needs to process all tenants. In production with large datasets,
// this should be replaced with a per-tenant EventBridge fan-out pattern.
// ============================================================================

import { ScheduledEvent, Context } from 'aws-lambda';
import {
    TABLE_NAME,
    scanTable,
    updateItem,
    queryItems,
    Keys,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';

/**
 * Daily cron handler to expire perishable stock.
 *
 * Strategy:
 * 1. Query all distinct tenants (pharmacy + grocery via PROFILE records)
 * 2. For pharmacy: query MEDBATCH# where expiryDate < today AND status = 'active'
 * 3. For grocery: query PRODUCT# where expiryDate < today AND isExpired <> true
 * 4. Update each to expired status
 * 5. Log summary for operational monitoring
 */
export async function handler(
    event: ScheduledEvent,
    _context: Context,
): Promise<{ statusCode: number; body: string }> {
    const startTime = Date.now();
    const now = new Date();
    const todayStr = new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
    ).toISOString();
    const todayDate = todayStr.split('T')[0]; // YYYY-MM-DD

    logger.info('Perishable batch expiry cron started', { todayDate, todayStr });

    let totalExpired = 0;
    let totalGroceryExpired = 0;
    let totalErrors = 0;
    let tenantsProcessed = 0;

    try {
        // Step 1: Get all tenant profiles for pharmacy AND grocery tenants
        // AUDIT FIX: Previously only scanned pharmacy — grocery perishables were ignored
        const tenantProfiles = await scanTable<Record<string, any>>(
            'SK = :profile AND (businessType = :pharmacy OR businessType = :grocery)',
            { ':profile': 'PROFILE', ':pharmacy': 'pharmacy', ':grocery': 'grocery' },
            undefined,
            500,
        );

        logger.info('Found pharmacy+grocery tenants', { count: tenantProfiles.length });

        // Step 2: Process each tenant (pharmacy → MEDBATCH#, grocery → PRODUCT#)
        for (const profile of tenantProfiles) {
            const tenantId = profile.tenantId || profile.PK?.replace('TENANT#', '');
            if (!tenantId) continue;

            tenantsProcessed++;

            const businessType = profile.businessType || 'grocery';

            try {
                if (businessType === 'pharmacy') {
                    // ── PHARMACY: Expire MEDBATCH# records ──────────────────────
                    const expiredBatches = await queryItems<Record<string, any>>(
                        Keys.tenantPK(tenantId),
                        'MEDBATCH#',
                        {
                            filterExpression:
                                '#batchStatus = :active AND expiryDate < :today AND batchStock > :zero',
                            expressionAttributeNames: {
                                '#batchStatus': 'status',
                            },
                            expressionAttributeValues: {
                                ':active': 'active',
                                ':today': todayStr,
                                ':zero': 0,
                            },
                        },
                    );

                    if (expiredBatches.items.length > 0) {
                        logger.info('Expiring pharmacy batches', {
                            tenantId,
                            batchCount: expiredBatches.items.length,
                        });

                        for (const batch of expiredBatches.items) {
                            try {
                                await updateItem(
                                    batch.PK || Keys.tenantPK(tenantId),
                                    batch.SK,
                                    {
                                        updateExpression:
                                            'SET #batchStatus = :expired, updatedAt = :now, expiredAt = :now',
                                        expressionAttributeNames: {
                                            '#batchStatus': 'status',
                                        },
                                        expressionAttributeValues: {
                                            ':expired': 'expired',
                                            ':now': now.toISOString(),
                                            ':active': 'active',
                                        },
                                        conditionExpression: '#batchStatus = :active',
                                    },
                                );
                                totalExpired++;
                            } catch (err: any) {
                                if (err.name === 'ConditionalCheckFailedException') {
                                    logger.debug('Batch already expired (concurrent)', {
                                        tenantId, batchSK: batch.SK,
                                    });
                                } else {
                                    totalErrors++;
                                    logger.error('Failed to expire pharmacy batch', {
                                        tenantId, batchSK: batch.SK,
                                        error: (err as Error).message,
                                    });
                                }
                            }
                        }
                    }
                } else if (businessType === 'grocery') {
                    // ── GROCERY: Expire PRODUCT# records with expiryDate ────────
                    // Grocery stores track expiry at the product/SKU level, not batch level.
                    // Products with expiryDate < today get isExpired=true flag.
                    const expiredProducts = await queryItems<Record<string, any>>(
                        Keys.tenantPK(tenantId),
                        'PRODUCT#',
                        {
                            filterExpression:
                                'attribute_exists(expiryDate) AND expiryDate < :today ' +
                                'AND (attribute_not_exists(isExpired) OR isExpired = :false) ' +
                                'AND (attribute_not_exists(isDeleted) OR isDeleted = :false) ' +
                                'AND currentStock > :zero',
                            expressionAttributeValues: {
                                ':today': todayDate,
                                ':false': false,
                                ':zero': 0,
                            },
                        },
                    );

                    if (expiredProducts.items.length > 0) {
                        logger.info('Expiring grocery products', {
                            tenantId,
                            productCount: expiredProducts.items.length,
                        });

                        for (const product of expiredProducts.items) {
                            try {
                                await updateItem(
                                    product.PK || Keys.tenantPK(tenantId),
                                    product.SK,
                                    {
                                        updateExpression:
                                            'SET isExpired = :true, expiredAt = :now, updatedAt = :now',
                                        expressionAttributeValues: {
                                            ':true': true,
                                            ':now': now.toISOString(),
                                            ':false': false,
                                        },
                                        conditionExpression:
                                            'attribute_not_exists(isExpired) OR isExpired = :false',
                                    },
                                );
                                totalGroceryExpired++;
                            } catch (err: any) {
                                if (err.name === 'ConditionalCheckFailedException') {
                                    logger.debug('Product already marked expired', {
                                        tenantId, productSK: product.SK,
                                    });
                                } else {
                                    totalErrors++;
                                    logger.error('Failed to expire grocery product', {
                                        tenantId, productSK: product.SK,
                                        error: (err as Error).message,
                                    });
                                }
                            }
                        }
                    }
                }
            } catch (err) {
                totalErrors++;
                logger.error('Failed to process tenant for expiry', {
                    tenantId, businessType,
                    error: (err as Error).message,
                });
            }
        }
    } catch (err) {
        logger.error('Perishable batch expiry cron FAILED', {
            error: (err as Error).message,
            stack: (err as Error).stack,
        });
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Batch expiry cron failed' }),
        };
    }

    const durationMs = Date.now() - startTime;
    const summary = {
        tenantsProcessed,
        totalExpired,
        totalGroceryExpired,
        totalErrors,
        durationMs,
        todayDate,
    };

    logger.info('Perishable batch expiry cron completed', summary);

    return {
        statusCode: 200,
        body: JSON.stringify(summary),
    };
}
