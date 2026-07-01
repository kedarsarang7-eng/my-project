// ============================================
// Customer Service — Tenant-Scoped Data Access
// ============================================
// All database queries for the Customer App.
// EVERY query uses withTenant() to enforce RLS isolation.
//
// Rules:
//   1. Products: filtered by shop_id (public within shop)
//   2. Orders/Invoices: filtered by shop_id AND customer_id
//   3. Dashboard: aggregated for shop_id + customer_id
//   4. Shop verification: public lookup by shop code
// ============================================

import { withTenant } from '../middleware/tenantMiddleware';
import { queryOne, query } from '../config/database';
import { logger } from '../utils/logger';

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

export interface OrderDetail extends OrderSummary {
    items: OrderItem[];
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

export interface CustomerDashboard {
    shop: ShopPublicInfo;
    total_billed_cents: number;
    total_paid_cents: number;
    outstanding_cents: number;
    total_orders: number;
    recent_orders: OrderSummary[];
}

// ---- Shop Verification ----

/**
 * Verify a shop exists and is active. Returns public info only.
 * This is a PUBLIC endpoint — no auth required.
 *
 * Accepts either a UUID (tenant ID) or a short shop code.
 */
export async function verifyShop(shopCode: string): Promise<ShopPublicInfo | null> {
    interface TenantRow {
        id: string;
        name: string;
        display_name: string | null;
        business_type: string;
        phone: string | null;
        email: string | null;
        logo_url: string | null;
        address: Record<string, unknown>;
        settings: Record<string, any>;
        is_active: boolean;
        subscription_valid_until: Date | null;
    }

    // Try exact UUID match first
    let tenant = await queryOne<TenantRow>(
        `SELECT id, name, display_name, business_type, phone, email,
                logo_url, address, settings, is_active, subscription_valid_until
         FROM tenants
         WHERE id = $1 AND is_active = TRUE`,
        [shopCode]
    );

    // If not found by UUID, try by phone or short code in settings
    if (!tenant) {
        tenant = await queryOne<TenantRow>(
            `SELECT id, name, display_name, business_type, phone, email,
                    logo_url, address, settings, is_active, subscription_valid_until
             FROM tenants
             WHERE (phone = $1 OR settings->>'shop_code' = $1)
               AND is_active = TRUE`,
            [shopCode]
        );
    }

    if (!tenant) return null;

    // Check subscription
    if (tenant.subscription_valid_until) {
        const expiry = new Date(tenant.subscription_valid_until);
        if (new Date() > expiry) {
            logger.warn('Shop verification: subscription expired', { shopId: tenant.id });
            return null; // Don't expose expired shops
        }
    }

    return {
        id: tenant.id,
        name: tenant.name,
        display_name: tenant.display_name,
        business_type: tenant.business_type,
        phone: tenant.phone,
        email: tenant.email,
        logo_url: tenant.logo_url,
        address: tenant.address || {},
        theme_color: tenant.settings?.theme_color || null,
    };
}

// ---- Products ----

/**
 * Get public product catalog for a shop.
 * Scoped to tenant via RLS.
 */
export async function getProducts(
    shopId: string,
    options: { category?: string; search?: string; page?: number; limit?: number } = {}
): Promise<{ products: ProductListItem[]; total: number }> {
    const { category, search, page = 1, limit = 50 } = options;
    const offset = (page - 1) * limit;

    return withTenant(shopId, async (client) => {
        // Build WHERE clause dynamically
        const conditions: string[] = ['is_active = TRUE', 'NOT is_deleted'];
        const params: any[] = [];
        let paramIndex = 1;

        if (category) {
            conditions.push(`category = $${paramIndex}`);
            params.push(category);
            paramIndex++;
        }

        if (search) {
            conditions.push(`(name ILIKE $${paramIndex} OR display_name ILIKE $${paramIndex} OR barcode = $${paramIndex + 1})`);
            params.push(`%${search}%`, search);
            paramIndex += 2;
        }

        const whereClause = conditions.join(' AND ');

        // Count total
        const countResult = await client.query(
            `SELECT COUNT(*)::int AS total FROM inventory WHERE ${whereClause}`,
            params
        );
        const total = countResult.rows[0]?.total || 0;

        // Fetch page
        const dataResult = await client.query(
            `SELECT id, name, display_name, category, subcategory, brand, unit,
                    sale_price_cents, mrp_cents, hsn_code, current_stock,
                    is_service, description, attributes
             FROM inventory
             WHERE ${whereClause}
             ORDER BY category, name
             LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
            [...params, limit, offset]
        );

        return { products: dataResult.rows, total };
    });
}

// ---- Orders ----

/**
 * Get orders for a specific customer within a shop.
 * DOUBLE FILTERED: tenant_id (RLS) + customer_id (explicit WHERE).
 */
export async function getOrders(
    shopId: string,
    customerId: string,
    options: { status?: string; page?: number; limit?: number } = {}
): Promise<{ orders: OrderSummary[]; total: number }> {
    const { status, page = 1, limit = 20 } = options;
    const offset = (page - 1) * limit;

    return withTenant(shopId, async (client) => {
        const conditions: string[] = ['NOT is_deleted'];
        const params: any[] = [];
        let paramIndex = 1;

        // CRITICAL: Always filter by customer_id
        conditions.push(`customer_id = $${paramIndex}`);
        params.push(customerId);
        paramIndex++;

        if (status) {
            conditions.push(`status = $${paramIndex}`);
            params.push(status);
            paramIndex++;
        }

        const whereClause = conditions.join(' AND ');

        // Count
        const countResult = await client.query(
            `SELECT COUNT(*)::int AS total FROM transactions WHERE ${whereClause}`,
            params
        );
        const total = countResult.rows[0]?.total || 0;

        // Fetch with items count
        const dataResult = await client.query(
            `SELECT t.id, t.invoice_number, t.status, t.subtotal_cents,
                    t.discount_cents, t.tax_cents, t.total_cents, t.paid_cents,
                    t.balance_cents, t.payment_mode, t.notes, t.created_at,
                    COALESCE(ic.items_count, 0)::int AS items_count
             FROM transactions t
             LEFT JOIN (
                 SELECT transaction_id, COUNT(*)::int AS items_count
                 FROM transaction_items
                 GROUP BY transaction_id
             ) ic ON ic.transaction_id = t.id
             WHERE ${whereClause}
             ORDER BY t.created_at DESC
             LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
            [...params, limit, offset]
        );

        return { orders: dataResult.rows, total };
    });
}

/**
 * Get a single order with line items.
 * DOUBLE FILTERED: tenant_id (RLS) + customer_id (explicit WHERE).
 */
export async function getOrderDetail(
    shopId: string,
    customerId: string,
    orderId: string
): Promise<OrderDetail | null> {
    return withTenant(shopId, async (client) => {
        // Fetch order — MUST match both tenant (RLS) and customer_id
        const orderResult = await client.query(
            `SELECT id, invoice_number, status, subtotal_cents, discount_cents,
                    tax_cents, total_cents, paid_cents, balance_cents,
                    payment_mode, notes, created_at
             FROM transactions
             WHERE id = $1 AND customer_id = $2 AND NOT is_deleted`,
            [orderId, customerId]
        );

        if (orderResult.rows.length === 0) return null;

        const order = orderResult.rows[0];

        // Fetch line items
        const itemsResult = await client.query(
            `SELECT id, name, quantity, unit, unit_price_cents,
                    discount_cents, tax_cents, total_cents
             FROM transaction_items
             WHERE transaction_id = $1
             ORDER BY id`,
            [orderId]
        );

        return {
            ...order,
            items_count: itemsResult.rows.length,
            items: itemsResult.rows,
        };
    });
}

// ---- Dashboard ----

/**
 * Get customer dashboard data for a specific shop.
 * Aggregates billing data scoped to shop_id + customer_id.
 */
export async function getDashboard(
    shopId: string,
    customerId: string
): Promise<CustomerDashboard | null> {
    // Get shop info (not tenant-scoped, public info)
    const shop = await verifyShop(shopId);
    if (!shop) return null;

    return withTenant(shopId, async (client) => {
        // Aggregate billing stats for this customer
        const statsResult = await client.query(
            `SELECT
                 COALESCE(SUM(total_cents), 0)::bigint AS total_billed_cents,
                 COALESCE(SUM(paid_cents), 0)::bigint AS total_paid_cents,
                 COALESCE(SUM(balance_cents), 0)::bigint AS outstanding_cents,
                 COUNT(*)::int AS total_orders
             FROM transactions
             WHERE customer_id = $1 AND NOT is_deleted`,
            [customerId]
        );

        const stats = statsResult.rows[0] || {
            total_billed_cents: 0,
            total_paid_cents: 0,
            outstanding_cents: 0,
            total_orders: 0,
        };

        // Recent orders (last 5)
        const recentResult = await client.query(
            `SELECT t.id, t.invoice_number, t.status, t.total_cents,
                    t.paid_cents, t.balance_cents, t.payment_mode, t.created_at,
                    COALESCE(ic.items_count, 0)::int AS items_count
             FROM transactions t
             LEFT JOIN (
                 SELECT transaction_id, COUNT(*)::int AS items_count
                 FROM transaction_items
                 GROUP BY transaction_id
             ) ic ON ic.transaction_id = t.id
             WHERE t.customer_id = $1 AND NOT t.is_deleted
             ORDER BY t.created_at DESC
             LIMIT 5`,
            [customerId]
        );

        return {
            shop,
            total_billed_cents: Number(stats.total_billed_cents),
            total_paid_cents: Number(stats.total_paid_cents),
            outstanding_cents: Number(stats.outstanding_cents),
            total_orders: stats.total_orders,
            recent_orders: recentResult.rows,
        };
    });
}

// ---- Customer-Shop Link Verification ----

/**
 * Check if a customer is linked to a shop.
 * Used to verify access before returning data.
 *
 * NOTE: This checks the `shop_links` concept. In the current schema,
 * the link is tracked in Firestore. For the RDS path, we check if
 * the customer has any transactions with this tenant.
 *
 * For a production system, add a `customer_shop_links` table to RDS.
 */
export async function isCustomerLinkedToShop(
    shopId: string,
    customerId: string
): Promise<boolean> {
    // Check if customer has any transactions with this shop
    // This is a pragmatic check — in production, use a dedicated links table
    const result = await queryOne<{ exists: boolean }>(
        `SELECT EXISTS(
             SELECT 1 FROM transactions
             WHERE tenant_id = $1 AND customer_id = $2 AND NOT is_deleted
             LIMIT 1
         ) AS exists`,
        [shopId, customerId]
    );

    return result?.exists || false;
}
