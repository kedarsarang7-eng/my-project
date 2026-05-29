import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody, parseQuery } from '../middleware/validation';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, getItem, putItem, queryAllItems, updateItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import * as invoiceService from '../services/invoice.service';

const HW_OPTS = {
    requiredBusinessType: BusinessType.HARDWARE,
    requiredFeature: FeatureKey.HARDWARE_CONTRACTOR_CREDIT,
};

const quickInvoiceSchema = z.object({
    customerName: z.string().max(200).optional(),
    customerPhone: z.string().max(20).optional(),
    customerGstin: z.string().max(15).optional(),
    invoiceType: z.enum(['tax_invoice', 'retail_invoice', 'proforma_invoice']).default('retail_invoice'),
    paymentMode: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'cheque', 'credit', 'wallet']).default('cash'),
    invoiceProfileId: z.string().max(100).optional(),
    discountCents: z.number().int().min(0).default(0),
    items: z.array(z.object({
        productId: z.string().uuid(),
        quantity: z.number().positive(),
        unit: z.string().max(20).optional(),
        unitPrice: z.number().int().min(0).optional(),
        unitPriceCents: z.number().int().min(0).optional(),
        discountCents: z.number().int().min(0).optional(),
    })).min(1),
});

const invoiceProfileSchema = z.object({
    defaultProfileId: z.string().max(100).optional(),
    profiles: z.array(z.object({
        id: z.string().max(100),
        name: z.string().max(100),
        showLogo: z.boolean().default(true),
        showCustomerGstin: z.boolean().default(true),
        showItemHsn: z.boolean().default(true),
        showRoundOff: z.boolean().default(true),
        showPaymentSummary: z.boolean().default(true),
        footerNote: z.string().max(500).optional(),
    })).max(20).default([]),
});

const salesOrderCreateSchema = z.object({
    customerName: z.string().min(1).max(200),
    customerPhone: z.string().max(20).optional(),
    siteAddress: z.string().max(500).optional(),
    scheduleDate: z.string().optional(),
    notes: z.string().max(1000).optional(),
    items: z.array(z.object({
        productId: z.string().uuid(),
        itemName: z.string().min(1).max(200),
        quantity: z.number().positive(),
        unit: z.string().max(20).default('pcs'),
    })).min(1),
});

const salesOrderStatusSchema = z.object({
    status: z.enum(['pending', 'partially_delivered', 'delivered', 'cancelled']),
    notes: z.string().max(500).optional(),
});

export const quickCreateInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(quickInvoiceSchema, event);
        if (!parsed.success) return parsed.error;
        const input = parsed.data;
        const result = await invoiceService.createInvoice(
            auth.tenantId,
            auth.sub,
            {
                customerName: input.customerName,
                customerPhone: input.customerPhone,
                customerGstin: input.customerGstin,
                paymentMode: input.paymentMode,
                discountCents: input.discountCents,
                invoiceType: input.invoiceType,
                invoiceProfileId: input.invoiceProfileId,
                metadata: { fastPos: true },
                items: input.items.map((it) => ({
                    productId: it.productId,
                    quantity: it.quantity,
                    unit: it.unit,
                    unitPrice: it.unitPrice ?? it.unitPriceCents ?? 0,
                    discountCents: it.discountCents ?? 0,
                })),
            },
            auth.role,
            auth.businessType,
        );
        return response.success(result, 201);
    },
    HW_OPTS,
);

export const getInvoiceProfiles = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const settings = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), Keys.tenantSettingsSK());
        const billing = settings?.hardwareBilling || {};
        return response.success({
            defaultProfileId: billing.defaultProfileId || null,
            profiles: Array.isArray(billing.invoiceProfiles) ? billing.invoiceProfiles : [],
        });
    },
    HW_OPTS,
);

export const saveInvoiceProfiles = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(invoiceProfileSchema, event);
        if (!parsed.success) return parsed.error;
        const settings = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), Keys.tenantSettingsSK());
        const merged = {
            ...(settings || {}),
            PK: Keys.tenantPK(auth.tenantId),
            SK: Keys.tenantSettingsSK(),
            entityType: (settings?.entityType || 'SETTINGS'),
            tenantId: auth.tenantId,
            hardwareBilling: {
                ...(settings?.hardwareBilling || {}),
                defaultProfileId: parsed.data.defaultProfileId || null,
                invoiceProfiles: parsed.data.profiles,
            },
            updatedAt: new Date().toISOString(),
        };
        await putItem(merged);
        return response.success({ updated: true });
    },
    HW_OPTS,
);

export const getSupplierRateComparison = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const qs = parseQuery(z.object({ itemName: z.string().max(200).optional() }), event);
        if (!qs.success) return qs.error;
        const itemName = (qs.data.itemName || '').trim().toLowerCase();
        const bills = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'PBILL#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });
        const rows: Array<Record<string, unknown>> = [];
        for (const bill of bills) {
            const supplierId = String(bill.supplierId || '');
            const supplierName = String(bill.supplierName || bill.vendorName || '');
            const createdAt = String(bill.createdAt || '');
            const items = Array.isArray(bill.items) ? bill.items : [];
            for (const line of items) {
                const lineName = String(line.itemName || line.name || '').toLowerCase();
                if (itemName && !lineName.includes(itemName)) continue;
                const qty = Number(line.quantity || 0);
                const rateCents = Number(line.rateCents || line.unitPriceCents || 0);
                if (qty <= 0 || rateCents <= 0) continue;
                rows.push({
                    supplierId,
                    supplierName,
                    itemName: String(line.itemName || line.name || ''),
                    rateCents,
                    quantity: qty,
                    observedAt: createdAt,
                });
            }
        }
        rows.sort((a, b) => Number(a.rateCents || 0) - Number(b.rateCents || 0));
        return response.success({
            itemFilter: itemName || null,
            best: rows.slice(0, 20),
            comparedRows: rows.length,
        });
    },
    HW_OPTS,
);

export const getPendingPurchaseOrders = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const poItems = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'PO#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 30,
        });
        const open = poItems.filter((po) => {
            const status = String(po.status || '').toLowerCase();
            return status !== 'closed' && status !== 'cancelled' && status !== 'received';
        });
        open.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
        return response.success({ items: open, count: open.length });
    },
    HW_OPTS,
);

export const createSalesOrder = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(salesOrderCreateSchema, event);
        if (!parsed.success) return parsed.error;
        const id = uuidv4();
        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `SALESORDER#${id}`,
            entityType: 'SALES_ORDER',
            id,
            tenantId: auth.tenantId,
            ...parsed.data,
            status: 'pending',
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });
        return response.success({ id, status: 'pending' }, 201);
    },
    HW_OPTS,
);

export const listSalesOrders = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const items = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'SALESORDER#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 20,
        });
        items.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
        return response.success({ items });
    },
    HW_OPTS,
);

export const updateSalesOrderStatus = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Missing sales order id');
        const parsed = parseBody(salesOrderStatusSchema, event);
        if (!parsed.success) return parsed.error;
        await updateItem(Keys.tenantPK(auth.tenantId), `SALESORDER#${id}`, {
            updateExpression: 'SET #status = :status, #notes = :notes, updatedAt = :now',
            expressionAttributeNames: { '#status': 'status', '#notes': 'notes' },
            expressionAttributeValues: {
                ':status': parsed.data.status,
                ':notes': parsed.data.notes || null,
                ':now': new Date().toISOString(),
            },
            conditionExpression: 'attribute_exists(PK)',
        });
        return response.success({ id, status: parsed.data.status });
    },
    HW_OPTS,
);

export const getItemVelocityReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const lineItems = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'INVOICE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 30,
        });
        const map = new Map<string, { qty: number; revenue: number }>();
        for (const inv of lineItems) {
            const items = Array.isArray(inv.items) ? inv.items : [];
            for (const it of items) {
                const name = String(it.itemName || it.name || 'Unknown');
                const prev = map.get(name) || { qty: 0, revenue: 0 };
                prev.qty += Number(it.quantity || 0);
                prev.revenue += Number(it.totalCents || 0);
                map.set(name, prev);
            }
        }
        const rows = Array.from(map.entries()).map(([itemName, v]) => ({ itemName, ...v }));
        rows.sort((a, b) => b.qty - a.qty);
        return response.success({
            fastMoving: rows.slice(0, 25),
            slowMoving: rows.slice(-25).reverse(),
        });
    },
    HW_OPTS,
);

export const getDeadStockReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const products = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'PRODUCT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 20,
        });
        const dead = products
            .filter((p) => Number(p.currentStock || 0) > 0 && Number(p.lastSoldAtTs || 0) === 0)
            .map((p) => ({
                productId: p.id,
                name: p.name,
                currentStock: Number(p.currentStock || 0),
                stockValueCents: Number(p.currentStock || 0) * Number(p.purchasePriceCents || 0),
            }));
        dead.sort((a, b) => b.stockValueCents - a.stockValueCents);
        return response.success({ items: dead, count: dead.length });
    },
    HW_OPTS,
);
