import { Keys, putItem, queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { AIService } from './ai.service';
import { AiMemoryService } from './ai-memory.service';

export class AiLearningService {

    static async runNightlyPipeline(): Promise<void> {
        logger.info('[AILearning] Starting nightly learning pipeline');
        // Query all tenants with active AI settings
        const result = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, { indexName: 'GSI1' });
        for (const tenant of result.items) {
            try {
                const settings = await import('../config/dynamodb.config').then(m => m.getItem<Record<string, any>>(Keys.tenantPK(tenant.tenantId || tenant.id), 'AISETTINGS#META'));
                if (!settings || !settings.isActive) continue;
                await this.extractFeatures(tenant.tenantId || tenant.id);
                await this.extractInsights(tenant.tenantId || tenant.id);
            } catch (err: any) { logger.error(`[AILearning] Pipeline failed for ${tenant.tenantId}: ${err.message}`); }
        }
    }

    private static async extractFeatures(tenantId: string): Promise<void> {
        logger.debug(`[AILearning] Extracting features for tenant ${tenantId}`);
        const today = new Date().toISOString().split('T')[0];
        const sevenDaysAgo = new Date(Date.now() - 7 * 86400000).toISOString();
        const fourteenDaysAgo = new Date(Date.now() - 14 * 86400000).toISOString();

        // Sales velocity: last 7 days
        const invoices = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: '#s = :completed AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':completed': 'finalized', ':false': false },
        });

        let currentSales = 0, pastSales = 0;
        for (const inv of invoices.items) {
            if (inv.createdAt >= sevenDaysAgo) currentSales += Number(inv.totalCents || 0);
            else if (inv.createdAt >= fourteenDaysAgo) pastSales += Number(inv.totalCents || 0);
        }

        await putItem({
            PK: Keys.tenantPK(tenantId), SK: `AIFEATURE#${today}#weekly_sales_velocity`,
            entityType: 'AI_FEATURE', tenantId, featureKey: 'weekly_sales_velocity',
            featureValue: { current: currentSales, past: pastSales }, computationDate: today,
            createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        });

        // Fast moving products
        const lineItems = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', { filterExpression: 'createdAt >= :since', expressionAttributeValues: { ':since': sevenDaysAgo } });
        // Approximate with invoice-level data since line items are separate
        await putItem({
            PK: Keys.tenantPK(tenantId), SK: `AIFEATURE#${today}#fast_moving_7d`,
            entityType: 'AI_FEATURE', tenantId, featureKey: 'fast_moving_products_7d',
            featureValue: { invoiceCount: lineItems.items.length }, computationDate: today,
            createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        });
    }

    private static async extractInsights(tenantId: string): Promise<void> {
        logger.debug(`[AILearning] Extracting insights for tenant ${tenantId}`);
        const today = new Date().toISOString().split('T')[0];
        const features = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), `AIFEATURE#${today}#`);
        if (features.items.length === 0) return;

        const prompt = `Analyze the following business features:\n${JSON.stringify(features.items.map(f => ({ key: f.featureKey, value: f.featureValue })))}\n\nGenerate 1-3 short business insights as JSON array: [{type, content, tags}]. Return ONLY valid JSON.`;
        try {
            const response = await AIService.processCommand(tenantId, prompt, "You are an AI data analyst. Only output valid JSON.", []);
            const jsonStr = response.text.replace(/```(json)?/g, '').trim();
            const insights = JSON.parse(jsonStr);
            for (const insight of insights) { if (insight.type && insight.content) await AiMemoryService.addMemory(tenantId, insight.type, insight.content, insight.tags || []); }
        } catch (error: any) { logger.error(`[AILearning] Insight generation failed: ${error.message}`); }
    }
}
