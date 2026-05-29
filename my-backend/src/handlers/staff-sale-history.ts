// ============================================================================
// Lambda Handler — Owner/Admin Staff Transaction History (DynamoDB)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, getItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

const PUMP_OWNER_OPTS = { requiredBusinessType: BusinessType.PETROL_PUMP, requiredFeature: FeatureKey.PETROL_BASIC_SHIFT_ENTRY };

/**
 * GET /staff/transactions — All staff transactions (owner view)
 */
export const getStaffTransactions = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const pathStaffId = event.pathParameters?.staffId;
        const limit = Math.min(parseInt(params.limit || '50', 10), 100);
        const offset = Math.max(parseInt(params.offset || '0', 10), 0);
        const pk = Keys.tenantPK(auth.tenantId);

        const sales = await queryItems<Record<string, any>>(pk, 'STAFFSALE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        });

        let items = sales.items;
        if (params.staffId || pathStaffId) items = items.filter(i => i.staffId === (params.staffId || pathStaffId));
        if (params.dateFrom) items = items.filter(i => (i.createdAt || '') >= params.dateFrom!);
        if (params.dateTo) items = items.filter(i => (i.createdAt || '') <= params.dateTo!);
        if (params.productType) items = items.filter(i => i.productType === params.productType);
        if (params.paymentMode) items = items.filter(i => i.paymentMode === params.paymentMode);
        if (params.paymentStatus) items = items.filter(i => i.paymentStatus === params.paymentStatus);

        items.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));
        const total = items.length;
        const paged = items.slice(offset, offset + limit).map(s => ({
            id: s.id, staffId: s.staffId, staffName: s.staffName,
            productType: s.productType, amountCents: s.amountCents,
            paymentMode: s.paymentMode, paymentStatus: s.paymentStatus,
            vehicleNumber: s.vehicleNumber, customerName: s.customerName,
            invoiceNumber: s.invoiceNumber, notes: s.notes,
            createdAt: s.createdAt, updatedAt: s.updatedAt,
        }));

        return response.paginated(paged, total, Math.floor(offset / limit) + 1, limit);
    },
    PUMP_OWNER_OPTS,
);

/**
 * GET /staff/transactions/summary — Aggregated totals per staff/day
 */
export const getTransactionSummary = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const dateFrom = params.dateFrom || new Date().toISOString().split('T')[0];
        const dateTo = params.dateTo || new Date().toISOString().split('T')[0];
        const pk = Keys.tenantPK(auth.tenantId);

        const sales = await queryItems<Record<string, any>>(pk, 'STAFFSALE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        });

        // Filter by date range
        const filtered = sales.items.filter(s => {
            const d = (s.createdAt || '').slice(0, 10);
            return d >= dateFrom && d <= dateTo && ['paid', 'pending'].includes(s.paymentStatus || '');
        });

        // Overall
        const overall = {
            totalTransactions: filtered.length,
            totalAmountCents: filtered.reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
            cashAmountCents: filtered.filter(s => s.paymentMode === 'cash').reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
            onlineAmountCents: filtered.filter(s => s.paymentMode === 'online').reduce((s, i) => s + (Number(i.amountCents) || 0), 0),
            cashCount: filtered.filter(s => s.paymentMode === 'cash').length,
            onlineCount: filtered.filter(s => s.paymentMode === 'online').length,
        };

        // Per-staff
        const staffMap = new Map<string, { staffId: string; staffName: string; totalTransactions: number; totalAmountCents: number; cashAmountCents: number; onlineAmountCents: number }>();
        for (const s of filtered) {
            const key = s.staffId;
            const existing = staffMap.get(key) || { staffId: key, staffName: s.staffName || '', totalTransactions: 0, totalAmountCents: 0, cashAmountCents: 0, onlineAmountCents: 0 };
            existing.totalTransactions++;
            existing.totalAmountCents += Number(s.amountCents) || 0;
            if (s.paymentMode === 'cash') existing.cashAmountCents += Number(s.amountCents) || 0;
            else existing.onlineAmountCents += Number(s.amountCents) || 0;
            staffMap.set(key, existing);
        }

        // Per-product
        const productMap = new Map<string, { productType: string; totalTransactions: number; totalAmountCents: number }>();
        for (const s of filtered) {
            const key = s.productType;
            const existing = productMap.get(key) || { productType: key, totalTransactions: 0, totalAmountCents: 0 };
            existing.totalTransactions++;
            existing.totalAmountCents += Number(s.amountCents) || 0;
            productMap.set(key, existing);
        }

        return response.success({
            dateFrom, dateTo, overall,
            byStaff: Array.from(staffMap.values()).sort((a, b) => b.totalAmountCents - a.totalAmountCents),
            byProduct: Array.from(productMap.values()).sort((a, b) => b.totalAmountCents - a.totalAmountCents),
        });
    },
    PUMP_OWNER_OPTS,
);

/**
 * GET /staff/transactions/{id} — Single transaction detail
 */
export const getTransactionDetail = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const txnId = event.pathParameters?.id;
        if (!txnId) return response.badRequest('Transaction ID is required');

        const pk = Keys.tenantPK(auth.tenantId);
        const sale = await getItem<Record<string, any>>(pk, `STAFFSALE#${txnId}`);

        if (!sale || sale.isDeleted) return response.notFound('Staff transaction');

        // Fetch payment info if exists
        const payments = await queryItems<Record<string, any>>(pk, 'STAFFSALEPAYMENT#', {
            filterExpression: 'staffSaleId = :saleId',
            expressionAttributeValues: { ':saleId': txnId },
            limit: 1,
        });

        const payment = payments.items[0];
        return response.success({
            ...sale,
            qrPayload: payment?.qrPayload, paymentUrl: payment?.paymentUrl,
            gatewayType: payment?.gatewayType, gatewayOrderId: payment?.gatewayOrderId,
            gatewayTransactionId: payment?.gatewayTransactionId,
            paymentGatewayStatus: payment?.status,
            webhookReceivedAt: payment?.webhookReceivedAt,
            webhookVerified: payment?.webhookVerified,
            expiresAt: payment?.expiresAt,
        });
    },
    PUMP_OWNER_OPTS,
);
