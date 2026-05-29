import { Keys, queryItems } from '../config/dynamodb.config';
import { AIService } from './ai.service';
import { logger } from '../utils/logger';

export class AutonomousAgentService {

    static async runHourlyTasks(): Promise<void> {
        logger.info('[Auto Agent] Starting hourly autonomous scans');
        // Scan all tenants with active AI settings
        const result = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, { indexName: 'GSI1' });
        for (const tenant of result.items) {
            try {
                const tenantId = tenant.tenantId || tenant.id;
                const settings = await import('../config/dynamodb.config').then(m => m.getItem<Record<string, any>>(Keys.tenantPK(tenantId), 'AISETTINGS#META'));
                if (!settings || !settings.isActive || settings.autonomousMode === 'disabled') continue;
                if (settings.autoNotifyInventory) await this.analyzeInventory(tenantId, settings.autonomousMode);
            } catch (err: any) { logger.error(`[Auto Agent] Hourly failed for ${tenant.tenantId}: ${err.message}`); }
        }
    }

    static async runDailyTasks(): Promise<void> {
        logger.info('[Auto Agent] Starting daily autonomous tasks');
        const result = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, { indexName: 'GSI1' });
        for (const tenant of result.items) {
            try {
                const tenantId = tenant.tenantId || tenant.id;
                const settings = await import('../config/dynamodb.config').then(m => m.getItem<Record<string, any>>(Keys.tenantPK(tenantId), 'AISETTINGS#META'));
                if (!settings || !settings.isActive || settings.autonomousMode === 'disabled') continue;
                if (settings.autoDailyReport) await this.generateDailyReport(tenantId, settings.autonomousMode);
                if (settings.autoNotifyCredit) await this.analyzeCredit(tenantId, settings.autonomousMode);
                // AUDIT FIX FEAT-1.6: Grocery reorder prediction
                if (settings.autoReorderAlert) await this.analyzeReorderNeeds(tenantId, settings.autonomousMode);
            } catch (err: any) { logger.error(`[Auto Agent] Daily failed for ${tenant.tenantId}: ${err.message}`); }
        }
    }

    private static async analyzeInventory(tenantId: string, mode: string) {
        logger.debug(`[Auto Agent] Analyzing Inventory for ${tenantId}`);
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: '(currentStock <= lowStockThreshold OR currentStock <= :zero) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':zero': 0, ':false': false },
            limit: 10,
        });
        if (result.items.length === 0) return;

        const prompt = `The following products are low/out of stock:\n${JSON.stringify(result.items.map(p => ({ name: p.name, sku: p.sku, stock: p.currentStock })))}\n\n${mode === 'auto' ? "You may notify the owner about critical shortages." : "Suggest actions only."}`;
        await AIService.processCommand(tenantId, prompt);
    }

    private static async generateDailyReport(tenantId: string, mode: string) {
        logger.debug(`[Auto Agent] Daily Report for ${tenantId}`);
        const todayISO = new Date().toISOString().split('T')[0];
        const invoices = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: 'begins_with(createdAt, :today) AND #s = :fin',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':today': todayISO, ':fin': 'finalized' },
        });
        let totalSales = 0;
        for (const inv of invoices.items) totalSales += Number(inv.totalCents || 0);

        const prompt = `EOD Report:\nTotal Sales: ₹${(totalSales / 100).toFixed(2)}\nTotal Invoices: ${invoices.items.length}\n\nGenerate a concise daily summary.${mode === 'auto' ? " Alert if sales are unusually low." : ""}`;
        const response = await AIService.processCommand(tenantId, prompt);
        logger.info(`[Auto Agent EOD] Tenant: ${tenantId}`, { summary: response.text });
    }

    private static async analyzeCredit(tenantId: string, mode: string) {
        logger.debug(`[Auto Agent] Analyzing Credit for ${tenantId}`);
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'CUSTOMER#', {
            filterExpression: 'balance > :zero AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':zero': 0, ':false': false },
            limit: 5,
        });
        if (result.items.length === 0) return;

        const prompt = `Pending credit balances:\n${JSON.stringify(result.items.map(c => ({ name: c.name, phone: c.phone, balance: c.balance })))}\n\n${mode === 'auto' ? "Auto-send WhatsApp reminders for top 2 balances." : "Suggest who to remind."}`;
        await AIService.processCommand(tenantId, prompt);
    }

    /**
     * AUDIT FIX FEAT-1.6: Grocery Reorder Prediction
     * Calculates daily average sales rate per product (last 30 days)
     * and predicts days-until-stockout. Alerts for items with < 3 days stock.
     */
    private static async analyzeReorderNeeds(tenantId: string, mode: string) {
        logger.debug(`[Auto Agent] Analyzing reorder needs for ${tenantId}`);

        const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();

        // Get recent invoices
        const invoices = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
            filterExpression: 'createdAt >= :since AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND #s <> :voided',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':since': thirtyDaysAgo, ':false': false, ':voided': 'voided' },
            limit: 200,
        });

        if (invoices.items.length === 0) return;

        // Aggregate product sales quantities from line items
        const productSales = new Map<string, { totalQty: number; productName: string }>();
        for (const inv of invoices.items) {
            try {
                const lineItems = await queryItems<Record<string, any>>(
                    `INVOICE#${inv.id}`, 'LINEITEM#', { limit: 50 },
                );
                for (const li of lineItems.items) {
                    const key = li.productId || li.itemId;
                    if (!key) continue;
                    const existing = productSales.get(key) || { totalQty: 0, productName: li.name || key };
                    existing.totalQty += Number(li.quantity) || 0;
                    productSales.set(key, existing);
                }
            } catch { /* Skip invoice if line item fetch fails */ }
        }

        // Get current stock for these products
        const products = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND currentStock > :zero',
            expressionAttributeValues: { ':false': false, ':zero': 0 },
            limit: 200,
        });

        const productStockMap = new Map(products.items.map(p => [p.id, p]));
        const criticalItems: Array<{ name: string; stock: number; dailyAvg: number; daysRemaining: number }> = [];

        for (const [productId, sales] of productSales) {
            const product = productStockMap.get(productId);
            if (!product) continue;

            const dailyAvg = sales.totalQty / 30;
            if (dailyAvg <= 0) continue;

            const currentStock = Number(product.currentStock) || 0;
            const daysRemaining = Math.floor(currentStock / dailyAvg);

            if (daysRemaining <= 3) {
                criticalItems.push({
                    name: sales.productName,
                    stock: currentStock,
                    dailyAvg: Math.round(dailyAvg * 100) / 100,
                    daysRemaining,
                });
            }
        }

        if (criticalItems.length === 0) return;

        // Sort by urgency
        criticalItems.sort((a, b) => a.daysRemaining - b.daysRemaining);

        const prompt = `🚨 REORDER ALERT: ${criticalItems.length} products will stock out within 3 days:\n${JSON.stringify(criticalItems.slice(0, 10))}\n\n${mode === 'auto' ? "Generate a purchase order suggestion for these items." : "Alert the owner about these critical shortages."}`;
        await AIService.processCommand(tenantId, prompt);

        logger.info(`[Auto Agent] Reorder analysis: ${criticalItems.length} critical items for ${tenantId}`);
    }
}

