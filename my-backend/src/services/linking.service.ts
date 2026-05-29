// ============================================================================
// Linking Service — Vendor-Customer QR Handshake (DynamoDB)
// ============================================================================
// Migrated from PostgreSQL to DynamoDB single-table design.
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    Keys,
    getItem, putItem, queryItems, updateItem,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import * as crypto from 'crypto';

// ---- Types ----

export interface LinkToken { token: string; expiresAt: string; maxUses: number | null; }
export interface LinkResult { linkId: string; businessId: string; businessName: string; businessType: string; linkedAt: string; alreadyLinked: boolean; }
export interface LinkedVendor { linkId: string; businessId: string; businessName: string; businessType: string; logoUrl: string | null; linkedAt: string; }
export interface LinkedCustomer { linkId: string; customerUserId: string; customerName: string; customerEmail: string | null; customerPhone: string | null; linkedAt: string; }

// ---- Service Functions ----

export async function generateToken(
    tenantId: string, createdBy: string, maxUses?: number, expiryHours = 168
): Promise<LinkToken> {
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + expiryHours * 60 * 60 * 1000);

    await putItem({
        PK: `LINKTOKEN#${token}`,
        SK: 'META',
        entityType: 'LINK_TOKEN',
        token,
        tenantId,
        createdBy,
        expiresAt: expiresAt.toISOString(),
        maxUses: maxUses ?? null,
        usedCount: 0,
        createdAt: new Date().toISOString(),
    });

    logger.info('Link token generated', { tenantId, expiryHours, maxUses });
    return { token, expiresAt: expiresAt.toISOString(), maxUses: maxUses ?? null };
}

export async function linkToVendor(token: string, customerId: string, customerEmail: string | null): Promise<LinkResult> {
    const stored = await getItem<Record<string, any>>(`LINKTOKEN#${token}`, 'META');
    if (!stored) throw new LinkingError('Invalid or expired token', 404);
    if (new Date(stored.expiresAt) < new Date()) throw new LinkingError('Token has expired', 410);
    if (stored.maxUses !== null && stored.usedCount >= stored.maxUses) throw new LinkingError('Token has reached maximum uses', 410);

    const tenant = await getItem<Record<string, any>>(Keys.tenantPK(stored.tenantId), Keys.tenantProfileSK());
    if (!tenant || !tenant.isActive) throw new LinkingError('Business not found or inactive', 404);

    const linkId = `${customerId}_${stored.tenantId}`;
    const linkSK = `CUSTOMERLINK#${linkId}`;

    const existingLink = await getItem<Record<string, any>>('SHOPLINKS', linkSK);
    if (existingLink && existingLink.status === 'ACTIVE') {
        return { linkId, businessId: stored.tenantId, businessName: tenant.name, businessType: tenant.businessType, linkedAt: new Date().toISOString(), alreadyLinked: true };
    }

    const now = new Date().toISOString();
    await putItem({
        PK: 'SHOPLINKS',
        SK: linkSK,
        entityType: 'CUSTOMER_SHOP_LINK',
        id: linkId,
        customerId,
        tenantId: stored.tenantId,
        shopName: tenant.name,
        businessType: tenant.businessType,
        status: 'ACTIVE',
        linkedAt: now,
        createdAt: now,
        updatedAt: now,
        // GSI for customer lookup
        GSI1PK: `CUSTOMER#${customerId}`,
        GSI1SK: `LINK#${stored.tenantId}`,
        // GSI for vendor lookup
        GSI2PK: Keys.tenantPK(stored.tenantId),
        GSI2SK: `CUSTOMERLINK#${customerId}`,
    });

    await updateItem(`LINKTOKEN#${token}`, 'META', {
        updateExpression: 'SET usedCount = usedCount + :one',
        expressionAttributeValues: { ':one': 1 },
    });

    logger.info('Customer linked to vendor', { customerId, tenantId: stored.tenantId });
    return { linkId, businessId: stored.tenantId, businessName: tenant.name, businessType: tenant.businessType, linkedAt: now, alreadyLinked: false };
}

export async function getMyVendors(customerId: string): Promise<LinkedVendor[]> {
    const result = await queryItems<Record<string, any>>(
        `CUSTOMER#${customerId}`, 'LINK#', { indexName: 'GSI1' },
    );
    return result.items.filter(r => r.status === 'ACTIVE').map(r => ({
        linkId: r.id, businessId: r.tenantId, businessName: r.shopName, businessType: r.businessType, logoUrl: null, linkedAt: r.linkedAt,
    }));
}

export async function getMyCustomers(tenantId: string): Promise<LinkedCustomer[]> {
    const result = await queryItems<Record<string, any>>(
        Keys.tenantPK(tenantId), 'CUSTOMERLINK#', { indexName: 'GSI2' },
    );
    return result.items.filter(r => r.status === 'ACTIVE').map(r => ({
        linkId: r.id, customerUserId: r.customerId, customerName: r.customerId, customerEmail: null, customerPhone: null, linkedAt: r.linkedAt,
    }));
}

export async function revokeCustomerLink(tenantId: string, customerUserId: string): Promise<boolean> {
    const linkId = `${customerUserId}_${tenantId}`;
    try {
        await updateItem('SHOPLINKS', `CUSTOMERLINK#${linkId}`, {
            updateExpression: 'SET #s = :unlinked, unlinkedAt = :now, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':unlinked': 'UNLINKED', ':now': new Date().toISOString() },
            conditionExpression: '#s = :active',
        });
        return true;
    } catch { return false; }
}

export class LinkingError extends Error {
    public statusCode: number;
    constructor(message: string, statusCode = 400) { super(message); this.name = 'LinkingError'; this.statusCode = statusCode; }
}
