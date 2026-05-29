// ============================================================================
// Lambda Handler — Admin (Kill Switch & System Status) (DynamoDB)
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { Keys, getItem, queryItems, updateItem } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { killSwitchSchema } from '../schemas';
import { logAudit } from '../middleware/audit';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
import { recordRevision } from '../services/revision-history.service';

export const killSwitch = authorizedHandler(
    [UserRole.OWNER],
    async (event, _context, auth) => {
        const parsed = parseBody(killSwitchSchema, event);
        if (!parsed.success) return parsed.error;
        const { action, reason } = parsed.data;
        const isActive = action === 'enable';
        const now = new Date().toISOString();
        const existing = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), Keys.tenantProfileSK());

        await updateItem(Keys.tenantPK(auth.tenantId), Keys.tenantProfileSK(), {
            updateExpression: 'SET isActive = :active, updatedAt = :now',
            expressionAttributeValues: { ':active': isActive, ':now': now },
        });
        await recordRevision(
            auth.tenantId,
            'tenants',
            auth.tenantId,
            'status_change',
            auth.sub,
            {
                isActive: existing?.isActive ?? null,
            },
            {
                isActive,
                reason: reason || null,
            },
            { source: 'admin.killSwitch', action },
        );

        await logAudit({ action: `tenant.${action}`, resource: 'tenant', resourceId: auth.tenantId, metadata: { reason }, ip: event.requestContext?.http?.sourceIp });
        logger.info('Kill switch activated', { action, reason, triggeredBy: auth.sub });
        wsService.broadcastToBusiness(auth.tenantId, WSEventName.ADMIN_ACTION, { action: `tenant.${action}`, reason, isActive }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        return response.success({ tenantId: auth.tenantId, isActive, action, message: action === 'disable' ? 'Tenant disabled.' : 'Tenant re-enabled.' });
    }
);

export const systemStatus = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (_event, _context, auth) => {
        const tenant = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), Keys.tenantProfileSK());
        if (!tenant) return response.notFound('Tenant');

        const users = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'USER#');
        const products = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'PRODUCT#', { filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)', expressionAttributeValues: { ':false': false } });
        const invoices = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'INVOICE#', { filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)', expressionAttributeValues: { ':false': false } });

        const todayISO = new Date().toISOString().substring(0, 10);
        const todayInvoices = invoices.items.filter(i => (i.createdAt || '').startsWith(todayISO) && i.status !== 'voided');
        const todayRevenue = todayInvoices.reduce((sum, i) => sum + Number(i.totalCents || 0), 0);

        return response.success({
            system: { status: 'healthy', serverTime: new Date().toISOString(), version: '1.1.0' },
            tenant: { id: tenant.id, name: tenant.name, businessType: tenant.businessType, plan: tenant.subscriptionPlan, isActive: tenant.isActive, createdAt: tenant.createdAt },
            counts: { users: users.items.length, products: products.items.length, transactions: invoices.items.length },
            today: { bills_today: todayInvoices.length, revenue_today_cents: todayRevenue },
        });
    }
);

export const analytics = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (_event, _context, auth) => {
        const invoices = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'INVOICE#', { filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND #s <> :voided', expressionAttributeNames: { '#s': 'status' }, expressionAttributeValues: { ':false': false, ':voided': 'voided' } });
        const customers = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'CUSTOMER#', { filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)', expressionAttributeValues: { ':false': false } });

        const todayISO = new Date().toISOString().substring(0, 10);
        const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().substring(0, 10);
        let todaySales = 0, monthSales = 0, totalSales = 0, todayBills = 0;
        for (const inv of invoices.items) {
            const t = Number(inv.totalCents || 0);
            totalSales += t;
            if ((inv.createdAt || '').startsWith(todayISO)) { todaySales += t; todayBills++; }
            if ((inv.createdAt || '') >= monthStart) monthSales += t;
        }

        return response.success({ todaySales: todaySales / 100, todayBillCount: todayBills, monthlySales: monthSales / 100, totalSales: totalSales / 100, customerCount: customers.items.length, totalDues: 0, lowStockCount: 0 });
    }
);

export const revenue = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (_event, _context, auth) => {
        const invoices = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'INVOICE#', { filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND #s <> :voided', expressionAttributeNames: { '#s': 'status' }, expressionAttributeValues: { ':false': false, ':voided': 'voided' } });

        let totalSales = 0, totalCollections = 0, totalInv = 0, paid = 0, partial = 0, unpaid = 0;
        for (const inv of invoices.items) { totalInv++; totalSales += Number(inv.totalCents || 0); totalCollections += Number(inv.paidCents || 0); if (Number(inv.paidCents || 0) >= Number(inv.totalCents || 0)) paid++; else if (Number(inv.paidCents || 0) > 0) partial++; else unpaid++; }

        return response.success({ totalSales: totalSales / 100, totalCollections: totalCollections / 100, totalOutstanding: (totalSales - totalCollections) / 100, invoiceCount: totalInv, paidInvoices: paid, partialInvoices: partial, unpaidInvoices: unpaid, totalReturns: 0 });
    }
);
