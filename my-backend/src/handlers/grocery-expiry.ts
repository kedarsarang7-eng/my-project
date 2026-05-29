// ============================================================================
// Lambda Handler — Grocery Expiry Alerts (GET /inventory/expiry-alerts)
// ============================================================================
// Returns products expiring within a configurable threshold (default 30 days).
// Groups results by urgency: expired | expiring_7d | expiring_30d
//
// FSSAI compliance: Grocery stores must not sell expired food items.
// This endpoint powers the dashboard "Expiring Soon" section and the
// Flutter notification badge on inventory.
//
// Access: All roles (grocery business type only)
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, queryItems } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { BusinessType } from '../types/tenant.types';

interface ExpiryAlertItem {
    id: string;
    name: string;
    barcode?: string;
    category?: string;
    currentStock: number;
    unit: string;
    expiryDate: string;
    daysRemaining: number;
    salePriceCents: number;
    stockValueCents: number;
}

interface ExpiryAlertResponse {
    expired: ExpiryAlertItem[];
    expiring_7d: ExpiryAlertItem[];
    expiring_30d: ExpiryAlertItem[];
    summary: {
        expiredCount: number;
        expiredValueCents: number;
        expiring7dCount: number;
        expiring7dValueCents: number;
        expiring30dCount: number;
        expiring30dValueCents: number;
        totalAtRiskValueCents: number;
    };
}

/**
 * GET /inventory/expiry-alerts?threshold=30
 *
 * Query Parameters:
 *   threshold: number — Days threshold for "expiring soon" (default 30, max 180)
 *   category:  string — Filter by category (optional)
 *   limit:     number — Max results per group (default 50)
 */
export const getExpiryAlerts = authorizedHandler(
    [], // All roles
    async (event, _context, auth) => {
        const tenantId = auth.tenantId;
        const threshold = Math.min(
            Math.max(parseInt(event.queryStringParameters?.threshold || '30', 10) || 30, 1),
            180,
        );
        const category = event.queryStringParameters?.category;
        const limit = Math.min(
            parseInt(event.queryStringParameters?.limit || '50', 10) || 50,
            200,
        );

        logger.info('Grocery expiry alerts request', {
            tenantId, threshold, category, limit,
        });

        const now = new Date();
        const todayStr = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}`;

        // Threshold date: today + N days
        const thresholdDate = new Date(
            Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + threshold),
        );
        const thresholdStr = thresholdDate.toISOString().split('T')[0];

        // 7-day urgency boundary
        const sevenDayDate = new Date(
            Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 7),
        );
        const sevenDayStr = sevenDayDate.toISOString().split('T')[0];

        // Query all products with expiryDate within threshold
        let filterExpr =
            'attribute_exists(expiryDate) AND expiryDate <= :threshold ' +
            'AND (attribute_not_exists(isDeleted) OR isDeleted = :false) ' +
            'AND currentStock > :zero';

        const exprValues: Record<string, unknown> = {
            ':threshold': thresholdStr,
            ':false': false,
            ':zero': 0,
        };

        if (category) {
            filterExpr += ' AND category = :category';
            exprValues[':category'] = category;
        }

        // Batch-level expiry for grocery lots (new model)
        const batchResult = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId),
            'GROCBATCH#',
            {
                filterExpression:
                    'expiryDate <= :threshold AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND currentQty > :zero',
                expressionAttributeValues: {
                    ':threshold': thresholdStr,
                    ':false': false,
                    ':zero': 0,
                },
                limit: limit * 3,
            },
        );

        const result = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId),
            'PRODUCT#',
            {
                filterExpression: filterExpr,
                expressionAttributeValues: exprValues,
                limit: limit * 3, // Fetch more to distribute across groups
            },
        );

        // Classify products into urgency groups
        const expired: ExpiryAlertItem[] = [];
        const expiring7d: ExpiryAlertItem[] = [];
        const expiring30d: ExpiryAlertItem[] = [];

        for (const product of result.items) {
            const expiryDate = product.expiryDate || '';
            if (!expiryDate) continue;

            const expiryMs = new Date(expiryDate + 'T00:00:00Z').getTime();
            const todayMs = new Date(todayStr + 'T00:00:00Z').getTime();
            const daysRemaining = Math.floor((expiryMs - todayMs) / 86400000);

            const item: ExpiryAlertItem = {
                id: product.id,
                name: product.name || '',
                barcode: product.barcode,
                category: product.category,
                currentStock: Number(product.currentStock) || 0,
                unit: product.unit || 'pcs',
                expiryDate,
                daysRemaining,
                salePriceCents: Number(product.salePriceCents) || 0,
                stockValueCents: (Number(product.currentStock) || 0) * (Number(product.salePriceCents) || 0),
            };

            if (daysRemaining < 0) {
                if (expired.length < limit) expired.push(item);
            } else if (daysRemaining <= 7) {
                if (expiring7d.length < limit) expiring7d.push(item);
            } else {
                if (expiring30d.length < limit) expiring30d.push(item);
            }
        }

        for (const batch of batchResult.items) {
            const expiryDate = batch.expiryDate || '';
            if (!expiryDate) continue;

            const expiryMs = new Date(expiryDate + 'T00:00:00Z').getTime();
            const todayMs = new Date(todayStr + 'T00:00:00Z').getTime();
            const daysRemaining = Math.floor((expiryMs - todayMs) / 86400000);

            const item: ExpiryAlertItem = {
                id: batch.id || batch.SK,
                name: `${batch.productName || 'Unknown'} [Batch ${batch.batchNumber || 'N/A'}]`,
                category: batch.category,
                currentStock: Number(batch.currentQty) || 0,
                unit: batch.unit || 'pcs',
                expiryDate,
                daysRemaining,
                salePriceCents: Number(batch.salePriceCents) || 0,
                stockValueCents: (Number(batch.currentQty) || 0) * (Number(batch.salePriceCents) || 0),
            };

            if (daysRemaining < 0) {
                if (expired.length < limit) expired.push(item);
            } else if (daysRemaining <= 7) {
                if (expiring7d.length < limit) expiring7d.push(item);
            } else {
                if (expiring30d.length < limit) expiring30d.push(item);
            }
        }

        // Sort each group: most urgent first
        expired.sort((a, b) => a.daysRemaining - b.daysRemaining);
        expiring7d.sort((a, b) => a.daysRemaining - b.daysRemaining);
        expiring30d.sort((a, b) => a.daysRemaining - b.daysRemaining);

        // Calculate summary
        const sumValue = (items: ExpiryAlertItem[]) =>
            items.reduce((acc, i) => acc + i.stockValueCents, 0);

        const alertResponse: ExpiryAlertResponse = {
            expired,
            expiring_7d: expiring7d,
            expiring_30d: expiring30d,
            summary: {
                expiredCount: expired.length,
                expiredValueCents: sumValue(expired),
                expiring7dCount: expiring7d.length,
                expiring7dValueCents: sumValue(expiring7d),
                expiring30dCount: expiring30d.length,
                expiring30dValueCents: sumValue(expiring30d),
                totalAtRiskValueCents: sumValue(expired) + sumValue(expiring7d) + sumValue(expiring30d),
            },
        };

        logger.info('Grocery expiry alerts response', {
            tenantId,
            expiredCount: expired.length,
            expiring7dCount: expiring7d.length,
            expiring30dCount: expiring30d.length,
        });

        return response.success(alertResponse);
    },
    { requiredBusinessType: BusinessType.GROCERY },
);
