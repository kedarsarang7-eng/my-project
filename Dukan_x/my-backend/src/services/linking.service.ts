// ============================================================================
// Linking Service — Vendor-Customer QR Handshake
// ============================================================================
// Manages vendor-customer links via signed tokens (QR codes).
// Uses customer_shop_links table (spans tenants — no RLS).
// ============================================================================

import { getPool } from '../config/db.config';
import { logger } from '../utils/logger';
import * as crypto from 'crypto';

// ---- Types ----

export interface LinkToken {
    token: string;
    expiresAt: string;
    maxUses: number | null;
}

export interface LinkResult {
    linkId: string;
    businessId: string;
    businessName: string;
    businessType: string;
    linkedAt: string;
    alreadyLinked: boolean;
}

export interface LinkedVendor {
    linkId: string;
    businessId: string;
    businessName: string;
    businessType: string;
    logoUrl: string | null;
    linkedAt: string;
}

export interface LinkedCustomer {
    linkId: string;
    customerUserId: string;
    customerName: string;
    customerEmail: string | null;
    customerPhone: string | null;
    linkedAt: string;
}

// ---- Service Functions ----

/**
 * Generate a signed linking token for the vendor's QR code.
 * Persisted to PostgreSQL (linking_tokens table) — survives Lambda cold starts.
 */
export async function generateToken(
    tenantId: string,
    createdBy: string,
    maxUses?: number,
    expiryHours = 168 // 7 days
): Promise<LinkToken> {
    const db = getPool();
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + expiryHours * 60 * 60 * 1000);

    await db.query(
        `INSERT INTO linking_tokens (token, tenant_id, created_by, expires_at, max_uses)
         VALUES ($1, $2, $3, $4, $5)`,
        [token, tenantId, createdBy, expiresAt, maxUses ?? null]
    );

    logger.info('Link token generated', { tenantId, expiryHours, maxUses });

    return {
        token,
        expiresAt: expiresAt.toISOString(),
        maxUses: maxUses ?? null,
    };
}

/**
 * Customer uses a token to link to a vendor's business.
 */
export async function linkToVendor(
    token: string,
    customerId: string,
    customerEmail: string | null
): Promise<LinkResult> {
    const db = getPool();

    // Lookup token from DB
    const tokenResult = await db.query(
        `SELECT token, tenant_id, expires_at, max_uses, used_count
         FROM linking_tokens WHERE token = $1`,
        [token]
    );

    if (tokenResult.rows.length === 0) {
        throw new LinkingError('Invalid or expired token', 404);
    }

    const stored = tokenResult.rows[0];

    if (new Date(stored.expires_at) < new Date()) {
        await db.query(`DELETE FROM linking_tokens WHERE token = $1`, [token]);
        throw new LinkingError('Token has expired', 410);
    }

    if (stored.max_uses !== null && stored.used_count >= stored.max_uses) {
        throw new LinkingError('Token has reached maximum uses', 410);
    }

    // Get tenant info
    const tenantResult = await db.query(
        `SELECT id, name, business_type, logo_url FROM tenants WHERE id = $1 AND is_active = TRUE`,
        [stored.tenant_id]
    );

    if (tenantResult.rows.length === 0) {
        throw new LinkingError('Business not found or inactive', 404);
    }

    const tenant = tenantResult.rows[0];
    const linkId = `${customerId}_${stored.tenant_id}`;

    // Check if already linked
    const existingLink = await db.query(
        `SELECT id, status FROM customer_shop_links WHERE id = $1`,
        [linkId]
    );

    if (existingLink.rows.length > 0) {
        const existing = existingLink.rows[0];
        if (existing.status === 'ACTIVE') {
            return {
                linkId,
                businessId: stored.tenant_id,
                businessName: tenant.name,
                businessType: tenant.business_type,
                linkedAt: new Date().toISOString(),
                alreadyLinked: true,
            };
        }

        // Reactivate unlinked/blocked
        await db.query(
            `UPDATE customer_shop_links SET status = 'ACTIVE', unlinked_at = NULL, updated_at = NOW() WHERE id = $1`,
            [linkId]
        );
    } else {
        // Create new link
        await db.query(
            `INSERT INTO customer_shop_links (id, customer_id, tenant_id, shop_name, business_type, status, linked_at)
             VALUES ($1, $2, $3, $4, $5, 'ACTIVE', NOW())`,
            [linkId, customerId, stored.tenant_id, tenant.name, tenant.business_type]
        );
    }

    // Increment token usage in DB
    await db.query(
        `UPDATE linking_tokens SET used_count = used_count + 1 WHERE token = $1`,
        [token]
    );

    logger.info('Customer linked to vendor', { customerId, tenantId: stored.tenant_id });

    return {
        linkId,
        businessId: stored.tenant_id,
        businessName: tenant.name,
        businessType: tenant.business_type,
        linkedAt: new Date().toISOString(),
        alreadyLinked: false,
    };
}

/**
 * Get all vendors a customer is linked to.
 */
export async function getMyVendors(customerId: string): Promise<LinkedVendor[]> {
    const db = getPool();

    const result = await db.query(
        `SELECT csl.id AS link_id, csl.tenant_id AS business_id,
                t.name AS business_name, t.business_type, t.logo_url,
                csl.linked_at
         FROM customer_shop_links csl
         JOIN tenants t ON t.id = csl.tenant_id
         WHERE csl.customer_id = $1 AND csl.status = 'ACTIVE'
         ORDER BY csl.linked_at DESC`,
        [customerId]
    );

    return result.rows.map((r: any) => ({
        linkId: r.link_id,
        businessId: r.business_id,
        businessName: r.business_name,
        businessType: r.business_type,
        logoUrl: r.logo_url || null,
        linkedAt: r.linked_at?.toISOString() || new Date().toISOString(),
    }));
}

/**
 * Get all customers linked to a vendor's business.
 */
export async function getMyCustomers(tenantId: string): Promise<LinkedCustomer[]> {
    const db = getPool();

    const result = await db.query(
        `SELECT csl.id AS link_id, csl.customer_id AS customer_user_id,
                COALESCE(u.full_name, csl.customer_id) AS customer_name,
                u.email AS customer_email, u.phone AS customer_phone,
                csl.linked_at
         FROM customer_shop_links csl
         LEFT JOIN users u ON u.cognito_sub = csl.customer_id
         WHERE csl.tenant_id = $1 AND csl.status = 'ACTIVE'
         ORDER BY csl.linked_at DESC`,
        [tenantId]
    );

    return result.rows.map((r: any) => ({
        linkId: r.link_id,
        customerUserId: r.customer_user_id,
        customerName: r.customer_name,
        customerEmail: r.customer_email || null,
        customerPhone: r.customer_phone || null,
        linkedAt: r.linked_at?.toISOString() || new Date().toISOString(),
    }));
}

/**
 * Revoke a customer's link (vendor side).
 */
export async function revokeCustomerLink(tenantId: string, customerUserId: string): Promise<boolean> {
    const db = getPool();
    const linkId = `${customerUserId}_${tenantId}`;

    const result = await db.query(
        `UPDATE customer_shop_links SET status = 'UNLINKED', unlinked_at = NOW(), updated_at = NOW()
         WHERE id = $1 AND tenant_id = $2 AND status = 'ACTIVE'
         RETURNING id`,
        [linkId, tenantId]
    );

    return (result.rowCount ?? 0) > 0;
}

// ---- Errors ----

export class LinkingError extends Error {
    public statusCode: number;
    constructor(message: string, statusCode = 400) {
        super(message);
        this.name = 'LinkingError';
        this.statusCode = statusCode;
    }
}
