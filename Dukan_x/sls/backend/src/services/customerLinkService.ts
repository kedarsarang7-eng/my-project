// ============================================
// Customer-Shop Link Service — Link Management
// ============================================
// Manages the customer_shop_links table.
// Links are created when:
//   1. Customer confirms linking to a shop (POST /api/customer/link-shop)
//   2. Admin/owner manually adds a customer
//   3. (Future) Auto-link on first purchase
//
// Links can be deactivated (soft-unlink) but the row is preserved
// for audit trail purposes.
// ============================================

import { query, queryOne } from '../config/database';
import { logger } from '../utils/logger';

// ---- Types ----

export interface CustomerShopLink {
    id: string;
    customer_id: string;
    tenant_id: string;
    linked_at: Date;
    linked_via: string;
    display_name: string | null;
    phone: string | null;
    is_active: boolean;
    created_at: Date;
    updated_at: Date;
}

export interface LinkedShopInfo {
    tenant_id: string;
    shop_name: string;
    display_name: string | null;
    business_type: string;
    phone: string | null;
    logo_url: string | null;
    theme_color: string | null;
    linked_at: Date;
    linked_via: string;
}

// ---- Link Operations ----

/**
 * Create or reactivate a customer-shop link.
 * Uses upsert (ON CONFLICT DO UPDATE) so it's idempotent.
 *
 * Returns the created/reactivated link.
 */
export async function linkCustomerToShop(
    customerId: string,
    tenantId: string,
    options: {
        linked_via?: string;
        display_name?: string | null;
        phone?: string | null;
    } = {}
): Promise<CustomerShopLink> {
    const { linked_via = 'manual', display_name = null, phone = null } = options;
    const linkId = `${customerId}_${tenantId}`;

    const result = await queryOne<CustomerShopLink>(
        `INSERT INTO customer_shop_links (id, customer_id, tenant_id, linked_via, display_name, phone)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (id) DO UPDATE SET
             is_active = TRUE,
             unlinked_at = NULL,
             unlinked_reason = NULL,
             updated_at = NOW()
         RETURNING *`,
        [linkId, customerId, tenantId, linked_via, display_name, phone]
    );

    logger.info('Customer linked to shop', {
        customerId,
        tenantId,
        linked_via,
        reactivated: result?.updated_at !== result?.created_at,
    });

    return result!;
}

/**
 * Soft-unlink a customer from a shop.
 * Preserves the row for audit but marks is_active = false.
 */
export async function unlinkCustomerFromShop(
    customerId: string,
    tenantId: string,
    reason: string = 'customer_request'
): Promise<boolean> {
    const linkId = `${customerId}_${tenantId}`;

    const result = await queryOne<{ id: string }>(
        `UPDATE customer_shop_links
         SET is_active = FALSE,
             unlinked_at = NOW(),
             unlinked_reason = $2,
             updated_at = NOW()
         WHERE id = $1 AND is_active = TRUE
         RETURNING id`,
        [linkId, reason]
    );

    if (result) {
        logger.info('Customer unlinked from shop', { customerId, tenantId, reason });
        return true;
    }

    return false;
}

/**
 * Check if a customer is linked to a shop.
 */
export async function isLinked(
    customerId: string,
    tenantId: string
): Promise<boolean> {
    const result = await queryOne<{ exists: boolean }>(
        `SELECT EXISTS(
             SELECT 1 FROM customer_shop_links
             WHERE customer_id = $1
               AND tenant_id = $2::uuid
               AND is_active = TRUE
         ) AS exists`,
        [customerId, tenantId]
    );

    return result?.exists || false;
}

/**
 * Get all shops linked to a customer.
 * Joins with tenants table to get shop details.
 */
export async function getLinkedShops(
    customerId: string
): Promise<LinkedShopInfo[]> {
    const rows = await query<LinkedShopInfo>(
        `SELECT
             csl.tenant_id,
             t.name AS shop_name,
             t.display_name,
             t.business_type,
             t.phone,
             t.logo_url,
             t.settings->>'theme_color' AS theme_color,
             csl.linked_at,
             csl.linked_via
         FROM customer_shop_links csl
         JOIN tenants t ON t.id = csl.tenant_id
         WHERE csl.customer_id = $1
           AND csl.is_active = TRUE
           AND t.is_active = TRUE
         ORDER BY csl.linked_at DESC`,
        [customerId]
    );

    return rows;
}

/**
 * Get the total number of active links for a customer.
 */
export async function getLinkCount(customerId: string): Promise<number> {
    const result = await queryOne<{ count: number }>(
        `SELECT COUNT(*)::int AS count
         FROM customer_shop_links
         WHERE customer_id = $1 AND is_active = TRUE`,
        [customerId]
    );

    return result?.count || 0;
}
