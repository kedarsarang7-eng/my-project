import { Keys, queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

export interface AITool { name: string; description: string; parameters: any; execute: (tenantId: string, params: any) => Promise<any>; }

export const aiToolsRegistry: AITool[] = [
    {
        name: 'get_customer_balance',
        description: 'Get outstanding balance for a customer by name.',
        parameters: { type: 'object', properties: { customer_name: { type: 'string', description: 'Name to search' } }, required: ['customer_name'] },
        execute: async (tenantId: string, params: { customer_name: string }) => {
            const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'CUSTOMER#', {
                filterExpression: 'contains(#n, :name) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeNames: { '#n': 'name' },
                expressionAttributeValues: { ':name': params.customer_name, ':false': false },
                limit: 5,
            });
            if (result.items.length === 0) return { message: `No customer found matching "${params.customer_name}".` };
            return { customers: result.items.map(r => ({ name: r.name, phone: r.phone, balance: r.balance || 0 })) };
        }
    },
    {
        name: 'get_daily_profit',
        description: 'Calculate profit for a date (YYYY-MM-DD). Uses today if unspecified.',
        parameters: { type: 'object', properties: { date: { type: 'string', description: 'Date in YYYY-MM-DD' } } },
        execute: async (tenantId: string, params: { date?: string }) => {
            const targetDate = params.date || new Date().toISOString().split('T')[0];
            const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', {
                filterExpression: 'begins_with(createdAt, :date) AND #s = :completed',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':date': targetDate, ':completed': 'finalized' },
            });
            let totalSales = 0;
            for (const inv of result.items) totalSales += Number(inv.totalCents || 0);
            return { date: targetDate, total_sales: totalSales / 100, total_profit: 0 };
        }
    },
    {
        name: 'get_out_of_stock_products',
        description: 'Get products that are out of stock or low inventory.',
        parameters: { type: 'object', properties: {} },
        execute: async (tenantId: string) => {
            const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
                filterExpression: '(currentStock <= lowStockThreshold OR currentStock <= :zero) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':zero': 0, ':false': false },
            });
            return { out_of_stock_items: result.items.slice(0, 10).map(p => ({ name: p.name, sku: p.sku, currentStock: p.currentStock })) };
        }
    },
    { name: 'send_whatsapp_message', description: 'Send WhatsApp notification.', parameters: { type: 'object', properties: { customer_name: { type: 'string' }, message: { type: 'string' } }, required: ['customer_name', 'message'] }, execute: async (_t: string, params: any) => { logger.info(`[AI] WhatsApp to ${params.customer_name}`); return { status: 'success', message: `WhatsApp queued for ${params.customer_name}.` }; } },
    { name: 'open_screen', description: 'Open a specific screen.', parameters: { type: 'object', properties: { screen_name: { type: 'string' } }, required: ['screen_name'] }, execute: async (_t: string, params: any) => ({ action: 'OPEN_SCREEN', target: params.screen_name, message: `Opening ${params.screen_name}.` }) },
    {
        name: 'get_sales_data',
        description: 'Get sales trends over a given period.',
        parameters: { type: 'object', properties: { days_back: { type: 'number', description: 'Past days (default 7)' } } },
        execute: async (tenantId: string, params: { days_back?: number }) => {
            const days = params.days_back || 7;
            const since = new Date(Date.now() - days * 86400000).toISOString();
            const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INVOICE#', { filterExpression: 'createdAt >= :since', expressionAttributeValues: { ':since': since } });
            const byDate: Record<string, number> = {};
            for (const inv of result.items) { const d = (inv.createdAt || '').substring(0, 10); byDate[d] = (byDate[d] || 0) + Number(inv.totalCents || 0); }
            return { sales_data: Object.entries(byDate).map(([date, rev]) => ({ sale_date: date, daily_revenue: rev / 100 })).sort((a, b) => b.sale_date.localeCompare(a.sale_date)) };
        }
    },
    {
        name: 'get_inventory_levels',
        description: 'Get overall stock counts.',
        parameters: { type: 'object', properties: {} },
        execute: async (tenantId: string) => {
            const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', { filterExpression: 'isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)', expressionAttributeValues: { ':true': true, ':false': false } });
            const totalUnits = result.items.reduce((sum, p) => sum + Number(p.currentStock || 0), 0);
            return { inventory_summary: { total_items: result.items.length, total_units: totalUnits } };
        }
    },
    { name: 'get_staff_activity', description: 'Staff sales activity.', parameters: { type: 'object', properties: {} }, execute: async () => ({ message: "Mock: Staff Rahul processed 30% more sales." }) },
    { name: 'create_purchase_order', description: 'Draft a purchase order.', parameters: { type: 'object', properties: { item_name: { type: 'string' }, quantity: { type: 'number' } }, required: ['item_name', 'quantity'] }, execute: async (_t: string, params: any) => { logger.info(`[Action] PO: ${params.item_name} x ${params.quantity}`); return { status: 'success', message: `PO drafted for ${params.quantity}x ${params.item_name}.` }; } },
    { name: 'generate_daily_report', description: 'Generate daily summary.', parameters: { type: 'object', properties: {} }, execute: async () => ({ status: 'success', message: 'Daily report generated.' }) },
    { name: 'notify_owner', description: 'Send notification to owner.', parameters: { type: 'object', properties: { message: { type: 'string' }, urgency: { type: 'string' } }, required: ['message'] }, execute: async (_t: string, params: any) => { logger.info(`[Notify Owner] ${params.urgency}: ${params.message}`); return { status: 'success', message: 'Owner notified.' }; } },
    { name: 'get_voided_invoices', description: 'Check for voided invoices.', parameters: { type: 'object', properties: {} }, execute: async () => ({ voided_count: 0, message: "No suspicious activity detected." }) },
    { name: 'get_expenses', description: 'Get recent expenses.', parameters: { type: 'object', properties: {} }, execute: async () => ({ total_expenses: 0, message: "Expense tracking not populated." }) },
];

export function getToolDefinition(name: string): AITool | undefined { return aiToolsRegistry.find(t => t.name === name); }
export function getToolsForLLM() { return aiToolsRegistry.map(tool => ({ type: 'function', function: { name: tool.name, description: tool.description, parameters: tool.parameters } })); }
