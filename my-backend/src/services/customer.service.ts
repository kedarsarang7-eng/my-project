// ============================================================================
// Customer Service — Migrated from sls/backend
// ============================================================================
// Migrated from: sls/backend/src/services/customerService.ts
// Adapted for my-backend Lambda architecture

import { logger } from '../utils/logger';
import { InventoryService } from './inventory.service';
import { getMyCustomers, revokeCustomerLink } from './linking.service';

// Placeholder implementations for missing services
const cacheService = {
    get: async <T>(key: string): Promise<T | null> => null,
    set: async (key: string, value: any, ttl: number): Promise<void> => {}
};

const tenantService = {
    getTenantById: async (id: string): Promise<any> => null
};

const inventoryService = new InventoryService();

// Placeholder invoice service
const invoiceService = {
    getCustomerInvoices: async (shopId: string, customerId: string, options: any) => ({ 
        items: [
            {
                id: 'placeholder',
                invoiceNumber: 'INV-001',
                status: 'paid',
                subtotalCents: 10000,
                discountCents: 0,
                taxCents: 1800,
                totalCents: 11800,
                paidCents: 11800,
                balanceCents: 0,
                paymentMode: 'cash',
                notes: null,
                createdAt: new Date().toISOString(),
                itemsCount: 1
            }
        ], 
        total: 1 
    }),
    getInvoiceById: async (shopId: string, invoiceId: string) => ({
        id: invoiceId,
        invoiceNumber: 'INV-001',
        status: 'paid',
        subtotalCents: 10000,
        discountCents: 0,
        taxCents: 1800,
        totalCents: 11800,
        paidCents: 11800,
        balanceCents: 0,
        paymentMode: 'cash',
        notes: null,
        createdAt: new Date().toISOString(),
        itemsCount: 1,
        customerId: 'placeholder-customer'
    }),
    getInvoiceItems: async (shopId: string, invoiceId: string) => [
        {
            id: 'item1',
            name: 'Sample Product',
            quantity: 1,
            unit: 'pcs',
            unitPriceCents: 10000,
            discountCents: 0,
            taxCents: 1800,
            totalCents: 11800
        }
    ]
};

// ---- Types ----

export interface ShopPublicInfo {
    id: string;
    name: string;
    display_name: string | null;
    business_type: string;
    phone: string | null;
    email: string | null;
    logo_url: string | null;
    address: Record<string, unknown>;
    theme_color: string | null;
}

export interface ProductListItem {
    id: string;
    name: string;
    display_name: string | null;
    category: string | null;
    subcategory: string | null;
    brand: string | null;
    unit: string;
    sale_price_cents: number;
    mrp_cents: number | null;
    hsn_code: string | null;
    current_stock: number;
    is_service: boolean;
    description: string | null;
    attributes: Record<string, unknown>;
}

export interface OrderSummary {
    id: string;
    invoice_number: string;
    status: string;
    subtotal_cents: number;
    discount_cents: number;
    tax_cents: number;
    total_cents: number;
    paid_cents: number;
    balance_cents: number;
    payment_mode: string | null;
    notes: string | null;
    created_at: Date;
    items_count: number;
}

export interface OrderItem {
    id: string;
    name: string;
    quantity: number;
    unit: string;
    unit_price_cents: number;
    discount_cents: number;
    tax_cents: number;
    total_cents: number;
}

export interface OrderDetail extends OrderSummary {
    items: OrderItem[];
}

export interface CustomerDashboard {
    shop: ShopPublicInfo;
    total_billed_cents: number;
    total_paid_cents: number;
    outstanding_cents: number;
    total_orders: number;
    recent_orders: OrderSummary[];
}

// ---- Shop Verification ----

export async function verifyShop(shopCode: string): Promise<ShopPublicInfo | null> {
    // Try cache first
    const cacheKey = `shop:${shopCode}`;
    const cached = await cacheService.get<ShopPublicInfo>(cacheKey);
    if (cached) return cached;

    const tenant = await tenantService.getTenantById(shopCode);
    if (!tenant || tenant.isActive === false) return null;

    // Check subscription
    if (tenant.subscriptionValidUntil && new Date() > new Date(tenant.subscriptionValidUntil)) {
        logger.warn('Shop verification: subscription expired', { shopId: shopCode });
        return null;
    }

    const shop: ShopPublicInfo = {
        id: shopCode,
        name: tenant.name || tenant.businessName || '',
        display_name: tenant.displayName || null,
        business_type: tenant.businessType || 'general',
        phone: tenant.phone || null,
        email: tenant.email || null,
        logo_url: tenant.logoUrl || null,
        address: tenant.address || {},
        theme_color: tenant.settings?.themeColor || null,
    };

    // Cache for 5 minutes
    await cacheService.set(cacheKey, shop, 300);

    return shop;
}

// ---- Product Operations ----

export async function getProducts(
    shopId: string,
    options: { category?: string; search?: string; page?: number; limit?: number } = {}
): Promise<{ products: ProductListItem[]; total: number }> {
    const { page = 1, limit = 50, category, search } = options;

    // Get products from inventory service
    const products = await inventoryService.getItems({ tenantId: shopId, isActive: true, page: 1, limit: 50 });

    return {
        products: products.items.map(p => ({
            id: p.id,
            name: p.name,
            display_name: p.displayName || null,
            category: p.category || null,
            subcategory: p.subcategory || null,
            brand: p.brand || null,
            unit: p.unit,
            sale_price_cents: p.salePriceCents,
            mrp_cents: p.mrpCents || null,
            hsn_code: p.hsnCode || null,
            current_stock: p.currentStock,
            is_service: p.productType === 'service',
            description: p.description || null,
            attributes: p.attributes || {},
        })),
        total: products.total,
    };
}

export async function getProductDetail(
    shopId: string,
    productId: string
): Promise<ProductListItem | null> {
    const products = await inventoryService.getItems({ tenantId: shopId, isActive: true, page: 1, limit: 50 });
    const product = products.items.find(p => p.id === productId);
    if (!product) return null;

    return {
        id: product.id,
        name: product.name,
        display_name: product.displayName || null,
        category: product.category || null,
        subcategory: product.subcategory || null,
        brand: product.brand || null,
        unit: product.unit,
        sale_price_cents: product.salePriceCents,
        mrp_cents: product.mrpCents || null,
        hsn_code: product.hsnCode || null,
        current_stock: product.currentStock,
        is_service: product.productType === 'service',
        description: product.description || null,
        attributes: product.attributes || {},
    };
}

// ---- Order Operations ----

export async function getOrders(
    shopId: string,
    customerId: string,
    options: { status?: string; page?: number; limit?: number } = {}
): Promise<{ orders: OrderSummary[]; total: number }> {
    const { status, page = 1, limit = 20 } = options;

    const orders = await invoiceService.getCustomerInvoices(shopId, customerId, {
        status,
        page,
        limit,
    });

    return {
        orders: orders.items.map(o => ({
            id: o.id,
            invoice_number: o.invoiceNumber,
            status: o.status,
            subtotal_cents: o.subtotalCents,
            discount_cents: o.discountCents,
            tax_cents: o.taxCents,
            total_cents: o.totalCents,
            paid_cents: o.paidCents,
            balance_cents: o.balanceCents,
            payment_mode: o.paymentMode || null,
            notes: o.notes || null,
            created_at: new Date(o.createdAt),
            items_count: o.itemsCount || 0,
        })),
        total: orders.total,
    };
}

export async function getOrderDetail(
    shopId: string,
    customerId: string,
    orderId: string
): Promise<OrderDetail | null> {
    const order = await invoiceService.getInvoiceById(shopId, orderId);
    if (!order || order.customerId !== customerId) return null;

    const items = await invoiceService.getInvoiceItems(shopId, orderId);

    return {
        id: order.id,
        invoice_number: order.invoiceNumber,
        status: order.status,
        subtotal_cents: order.subtotalCents,
        discount_cents: order.discountCents,
        tax_cents: order.taxCents,
        total_cents: order.totalCents,
        paid_cents: order.paidCents,
        balance_cents: order.balanceCents,
        payment_mode: order.paymentMode || null,
        notes: order.notes || null,
        created_at: new Date(order.createdAt),
        items_count: items.length,
        items: items.map(i => ({
            id: i.id,
            name: i.name,
            quantity: i.quantity,
            unit: i.unit,
            unit_price_cents: i.unitPriceCents,
            discount_cents: i.discountCents,
            tax_cents: i.taxCents,
            total_cents: i.totalCents,
        })),
    };
}

// ---- Customer Dashboard ----

export async function getDashboard(
    shopId: string,
    customerId: string
): Promise<CustomerDashboard | null> {
    const shop = await verifyShop(shopId);
    if (!shop) return null;

    const { orders } = await getOrders(shopId, customerId, { limit: 5 });

    let totalBilled = 0;
    let totalPaid = 0;
    for (const o of orders) {
        totalBilled += o.total_cents || 0;
        totalPaid += o.paid_cents || 0;
    }

    return {
        shop,
        total_billed_cents: totalBilled,
        total_paid_cents: totalPaid,
        outstanding_cents: totalBilled - totalPaid,
        total_orders: orders.length,
        recent_orders: orders,
    };
}

// ---- Customer-Shop Link ----

export async function isCustomerLinkedToShop(
    shopId: string,
    customerId: string
): Promise<boolean> {
    const customers = await getMyCustomers(shopId);
    const link = customers.find(c => c.customerUserId === customerId);
    return !!(link);
}

export async function linkCustomerToShop(
    shopId: string,
    customerId: string,
    metadata?: Record<string, unknown>
): Promise<boolean> {
    try {
        // For now, return true as a placeholder - actual linking logic would need to be implemented
        logger.info('Customer link requested', { shopId, customerId, metadata });
        return true;
    } catch (error) {
        logger.error('Failed to link customer to shop', {
            shopId,
            customerId,
            error: (error as Error).message,
        });
        return false;
    }
}

export async function unlinkCustomerFromShop(
    shopId: string,
    customerId: string
): Promise<boolean> {
    try {
        await revokeCustomerLink(shopId, customerId);
        return true;
    } catch (error) {
        logger.error('Failed to unlink customer from shop', {
            shopId,
            customerId,
            error: (error as Error).message,
        });
        return false;
    }
}

// ---- Default Export ----

export default {
    verifyShop,
    getProducts,
    getProductDetail,
    getOrders,
    getOrderDetail,
    getDashboard,
    isCustomerLinkedToShop,
    linkCustomerToShop,
    unlinkCustomerFromShop,
};
