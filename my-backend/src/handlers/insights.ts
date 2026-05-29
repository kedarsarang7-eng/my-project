// ============================================================================
// Lambda Handler — AI Insights (DynamoDB)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, queryItems, putItem } from '../config/dynamodb.config';
import { FeatureKey } from '../config/plan-feature-registry';
import { parseBody } from '../middleware/validation';
import { aiFeedbackSchema } from '../schemas';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /insights/ai-insight
 */
export const aiInsight = authorizedHandler([], async (_event, _context, auth) => {
    try {
        const pk = Keys.tenantPK(auth.tenantId);
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const todayISO = todayStart.toISOString();

        const yesterdayStart = new Date(todayStart);
        yesterdayStart.setDate(yesterdayStart.getDate() - 1);
        const yesterdayISO = yesterdayStart.toISOString();

        // Fetch today's invoices
        const invoices = await queryItems<Record<string, any>>(pk, 'INVOICE#', {
            filterExpression: 'createdAt >= :today AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#s) OR #s <> :voided)',
            expressionAttributeValues: { ':today': todayISO, ':false': false, ':voided': 'voided' },
            expressionAttributeNames: { '#s': 'status' },
        });

        const todaySales = invoices.items;
        const billCount = todaySales.length;
        const totalCents = todaySales.reduce((s, inv) => s + (Number(inv.totalCents) || 0), 0);
        const avgBillCents = billCount > 0 ? Math.round(totalCents / billCount) : 0;
        const totalRupees = totalCents / 100;
        const avgBillRupees = avgBillCents / 100;

        // Yesterday's invoices
        const yesterdayInvoices = await queryItems<Record<string, any>>(pk, 'INVOICE#', {
            filterExpression: 'createdAt >= :yStart AND createdAt < :yEnd AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#s) OR #s <> :voided)',
            expressionAttributeValues: { ':yStart': yesterdayISO, ':yEnd': todayISO, ':false': false, ':voided': 'voided' },
            expressionAttributeNames: { '#s': 'status' },
        });
        const yesterdayRupees = yesterdayInvoices.items.reduce((s, inv) => s + (Number(inv.totalCents) || 0), 0) / 100;

        // Low stock count
        const products = await queryItems<Record<string, any>>(pk, 'PRODUCT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND isActive = :true AND (attribute_not_exists(isService) OR isService = :false)',
            expressionAttributeValues: { ':false': false, ':true': true },
        });
        const lowStockCount = products.items.filter(p => (Number(p.currentStock) || 0) <= (Number(p.lowStockThreshold) || 0)).length;

        // Generate insight
        let insight: string;
        if (billCount === 0) {
            insight = 'No sales recorded yet today. Consider running a promotion or checking if your shop is visible online.';
        } else if (totalRupees > yesterdayRupees * 1.2 && yesterdayRupees > 0) {
            const pctUp = Math.round(((totalRupees - yesterdayRupees) / yesterdayRupees) * 100);
            insight = `Sales are up ${pctUp}% compared to yesterday (₹${totalRupees.toLocaleString()} vs ₹${yesterdayRupees.toLocaleString()}). Great momentum! `;
            if (lowStockCount > 0) insight += `Watch out: ${lowStockCount} items are running low on stock.`;
        } else if (totalRupees < yesterdayRupees * 0.8 && yesterdayRupees > 0) {
            const pctDown = Math.round(((yesterdayRupees - totalRupees) / yesterdayRupees) * 100);
            insight = `Sales are down ${pctDown}% vs yesterday. Average bill is ₹${avgBillRupees.toFixed(0)}. Consider upselling or bundling products.`;
        } else if (lowStockCount > 5) {
            insight = `${lowStockCount} items are below reorder level. Prioritize restocking to avoid lost sales. Today's revenue: ₹${totalRupees.toLocaleString()}.`;
        } else {
            insight = `Steady day so far — ${billCount} bills totaling ₹${totalRupees.toLocaleString()} (avg ₹${avgBillRupees.toFixed(0)}/bill). Keep it up!`;
        }

        return response.success({
            ai_insight: insight,
            stats: { todaySalesRupees: totalRupees, billCount, avgBillRupees, yesterdaySalesRupees: yesterdayRupees, lowStockCount },
        });
    } catch (err) {
        logger.error('Insights generation failed', { error: (err as Error).message });
        return response.success({ ai_insight: 'Unable to generate insights right now. Please try again later.' });
    }
}, { requiredFeature: FeatureKey.ADVANCED_ANALYTICS });

/**
 * POST /insights/ai-feedback
 */
export const aiFeedback = authorizedHandler([], async (event, _context, auth) => {
    try {
        // SECURITY FIX S-7: Validate input with Zod schema
        const parsed = parseBody(aiFeedbackSchema, event);
        if (!parsed.success) return parsed.error;
        const { memoryId, predictionContext, feedbackScore, agentName } = parsed.data;

        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `AIFEEDBACK#${now}#${Math.random().toString(36).slice(2, 8)}`,
            entityType: 'AI_FEEDBACK',
            tenantId: auth.tenantId,
            memoryId: memoryId || null,
            agentName: agentName || null,
            predictionContext,
            feedbackScore,
            userId: auth.sub,
            createdAt: now,
        });

        if (memoryId) {
            const { AiMemoryService } = await import('../services/ai-memory.service');
            await AiMemoryService.adjustConfidence(auth.tenantId, memoryId, feedbackScore);
        }

        return response.success({ message: 'Feedback recorded successfully' });
    } catch (err: any) {
        logger.error('AI Feedback failed', { error: err.message });
        return response.internalError('Failed to record feedback');
    }
}, { requiredFeature: FeatureKey.ADVANCED_ANALYTICS });
