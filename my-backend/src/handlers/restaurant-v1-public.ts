import { config } from '../config/environment';
// ============================================================================
// Restaurant API v1 — Public compat layer for dukan_restro_pwa
// Maps /api/v1/restaurant/* → DynamoDB (same tenant partition as main DukanX apps).
// Enable with RESTO_V1_PUBLIC_ENABLED=true.
//
// Auth model (P0-02 fix, 2026-05):
//   1. Customer scans table QR → opens PWA at /?v=<vendorId>&t=<tableId>
//   2. PWA calls GET /api/v1/restaurant/scan?v=&t= → receives short-lived JWT
//      (60 min, signed with RESTO_SCAN_JWT_SECRET, scoped to {vendorId, tableId}).
//   3. PWA sends `Authorization: Bearer <jwt>` on POST /orders.
//   4. Server verifies JWT and asserts body's vendorId/tableId match claim.
//
// The previous client-side X-Resto-V1-Key shared-secret model is removed —
// it was extractable from the PWA bundle and allowed forging orders.
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { randomUUID } from 'crypto';
import * as jwt from 'jsonwebtoken';
import { Keys, queryItems, getItem, putItem, batchGetItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
// UNS event_bus — task 14.9 migration of T-RES-1 server-side producer
import { emitUnsEvent } from '../notifications/event-bus';

const SCAN_JWT_ISSUER = 'dukanx-resto-scan';
const SCAN_JWT_AUDIENCE = 'pwa-customer';
const SCAN_JWT_TTL_SECONDS = 60 * 60; // 60 minutes

interface ScanClaims {
    vendorId: string;
    tableId: string;
    iss: string;
    aud: string;
    sub: string;
    iat: number;
    exp: number;
}

function json(statusCode: number, body: unknown): APIGatewayProxyResultV2 {
    return {
        statusCode,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    };
}

function isPublicEnabled(): boolean {
    return config.resto.v1PublicEnabled === 'true';
}

function getScanSecret(): string {
    return config.resto.scanJwtSecret || '';
}

function extractBearer(event: APIGatewayProxyEventV2): string | null {
    const h = event.headers || {};
    const auth = h['authorization'] || h['Authorization'] || '';
    const m = /^Bearer\s+(.+)$/i.exec(auth);
    return m ? m[1].trim() : null;
}

function verifyScanToken(token: string): ScanClaims | null {
    const secret = getScanSecret();
    if (!secret) return null;
    try {
        const decoded = jwt.verify(token, secret, {
            issuer: SCAN_JWT_ISSUER,
            audience: SCAN_JWT_AUDIENCE,
        }) as ScanClaims;
        if (!decoded.vendorId || !decoded.tableId) return null;
        return decoded;
    } catch (err) {
        logger.warn('Scan token verification failed', { error: (err as Error).message });
        return null;
    }
}

/**
 * GET /api/v1/restaurant/scan?v=<vendorId>&t=<tableId>
 * Issues a short-lived JWT scoped to a specific table.
 */
export const compatScan = async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
): Promise<APIGatewayProxyResultV2> => {
    if (!isPublicEnabled()) return json(404, { error: 'RESTO_V1_PUBLIC_DISABLED' });

    const secret = getScanSecret();
    if (!secret) {
        logger.error('RESTO_SCAN_JWT_SECRET not configured');
        return json(500, { error: 'SCAN_NOT_CONFIGURED' });
    }

    const vendorId = event.queryStringParameters?.v;
    const tableId = event.queryStringParameters?.t;
    if (!vendorId || !tableId) {
        return json(400, { error: 'v (vendorId) and t (tableId) required' });
    }

    // Validate the table actually exists for this vendor before minting a token.
    const pk = Keys.tenantPK(vendorId);
    const table = await getItem<Record<string, any>>(pk, `RESTOTABLE#${tableId}`);
    if (!table || table.isDeleted) {
        return json(404, { error: 'table_not_found' });
    }

    const token = jwt.sign({ vendorId, tableId }, secret, {
        issuer: SCAN_JWT_ISSUER,
        audience: SCAN_JWT_AUDIENCE,
        subject: `${vendorId}:${tableId}`,
        expiresIn: SCAN_JWT_TTL_SECONDS,
    });

    return json(200, {
        token,
        expiresIn: SCAN_JWT_TTL_SECONDS,
        vendorId,
        tableId,
    });
};

/** GET /api/v1/restaurant/vendor/{vendorId}/info */
export const compatVendorInfo = async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
): Promise<APIGatewayProxyResultV2> => {
    if (!isPublicEnabled()) return json(404, { error: 'RESTO_V1_PUBLIC_DISABLED' });
    const vendorId = event.pathParameters?.vendorId;
    if (!vendorId) return json(400, { error: 'vendorId required' });

    const pk = Keys.tenantPK(vendorId);
    const businesses = await queryItems<Record<string, any>>(pk, 'BUSINESS#', {});
    const first = businesses.items[0];
    const name = first?.name || first?.displayName || 'Restaurant';
    const tagline = first?.settings?.tagline || first?.tagline || null;

    return json(200, {
        vendorId,
        name,
        tagline,
        businessType: first?.businessType || 'restaurant',
    });
};

/** GET /api/v1/restaurant/menu?vendorId= */
export const compatMenu = async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
): Promise<APIGatewayProxyResultV2> => {
    if (!isPublicEnabled()) return json(404, { error: 'RESTO_V1_PUBLIC_DISABLED' });
    const vendorId = event.queryStringParameters?.vendorId;
    if (!vendorId) return json(400, { error: 'vendorId required' });

    const pk = Keys.tenantPK(vendorId);
    const [categories, menuItems] = await Promise.all([
        queryItems<Record<string, any>>(pk, 'FOODCATEGORY#', {
            filterExpression: 'isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':true': true, ':false': false },
        }),
        queryItems<Record<string, any>>(pk, 'FOODMENUITEM#', {
            filterExpression: 'isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':true': true, ':false': false },
        }),
    ]);

    const byCat = new Map<string, typeof menuItems.items>();
    for (const m of menuItems.items) {
        const cid = String(m.categoryId || 'uncategorized');
        if (!byCat.has(cid)) byCat.set(cid, []);
        byCat.get(cid)!.push(m);
    }

    const catSorted = categories.items.sort((a, b) => (a.displayOrder || 0) - (b.displayOrder || 0));
    const list: Array<Record<string, unknown>> = [];

    for (const c of catSorted) {
        const cid = c.id || String(c.SK || '').replace('FOODCATEGORY#', '');
        const items = (byCat.get(cid) || []).map((m) => mapMenuRow(m));
        list.push({
            id: cid,
            name: c.name || 'Menu',
            imageEmoji: c.emoji || c.imageEmoji || '🍽️',
            items,
        });
    }

    for (const [cid, rows] of byCat) {
        if (catSorted.some((c) => (c.id || String(c.SK || '').replace('FOODCATEGORY#', '')) === cid)) continue;
        list.push({
            id: cid,
            name: cid === 'uncategorized' ? 'Other' : 'Menu',
            imageEmoji: '🍽️',
            items: rows.map(mapMenuRow),
        });
    }

    return json(200, list);
};

function mapMenuRow(m: Record<string, any>) {
    const cents = Number(m.salePriceCents ?? m.priceCents ?? 0);
    const id = m.id || String(m.SK || '').replace('FOODMENUITEM#', '');
    const isVeg = m.isVeg !== undefined ? !!m.isVeg : m.isVegetarian !== false;
    return {
        id,
        name: m.name || '',
        description: m.description || '',
        price: cents / 100,
        isVeg,
        variations: Array.isArray(m.variations) ? m.variations : [],
    };
}

/**
 * POST /api/v1/restaurant/orders
 * Auth: Authorization: Bearer <table-scan JWT> (issued by /scan).
 * Server-side validation:
 *   - JWT vendorId/tableId must match request body.
 *   - Each menuItemId must resolve to an active, non-deleted FOODMENUITEM.
 *   - Prices, GST and totals are computed authoritatively from DynamoDB.
 */
export const compatPlaceOrder = async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
): Promise<APIGatewayProxyResultV2> => {
    if (!isPublicEnabled()) return json(404, { error: 'RESTO_V1_PUBLIC_DISABLED' });

    // P0-02: Verify table-scoped JWT instead of static shared secret.
    const token = extractBearer(event);
    if (!token) {
        return json(401, {
            error: 'TABLE_TOKEN_REQUIRED',
            message: 'Call GET /api/v1/restaurant/scan?v=&t= first to obtain a table-scoped token.',
        });
    }
    const claims = verifyScanToken(token);
    if (!claims) return json(401, { error: 'TABLE_TOKEN_INVALID' });

    let body: Record<string, any> = {};
    try {
        body = event.body ? JSON.parse(event.body) : {};
    } catch {
        return json(400, { error: 'invalid_json' });
    }

    const vendorId = body.vendorId as string;
    const tableId = body.tableId as string;
    const rawItems = body.items as unknown[];
    if (!vendorId || !tableId || !Array.isArray(rawItems) || rawItems.length === 0) {
        return json(400, { error: 'vendorId, tableId, items required' });
    }

    // Token must match the body — prevents replay across vendors/tables.
    if (claims.vendorId !== vendorId || claims.tableId !== tableId) {
        return json(403, { error: 'TOKEN_SCOPE_MISMATCH' });
    }

    // P2-02: Resolve menu items server-side. Never trust client prices.
    const pk = Keys.tenantPK(vendorId);
    const requestedIds: string[] = [];
    const requestedQty: Record<string, number> = {};
    const requestedNotes: Record<string, string> = {};
    for (const raw of rawItems) {
        const it = raw as Record<string, unknown>;
        const id = String(it.menuItemId || it.id || '').trim();
        if (!id) return json(400, { error: 'each item requires menuItemId' });
        const qty = Math.max(1, Math.min(99, Number(it.qty ?? 1)));
        requestedIds.push(id);
        requestedQty[id] = (requestedQty[id] || 0) + qty;
        if (it.note) requestedNotes[id] = String(it.note).slice(0, 200);
    }

    const uniqueIds = Array.from(new Set(requestedIds));
    const menuRows = await batchGetItems<Record<string, any>>(
        uniqueIds.map((id) => ({ PK: pk, SK: `FOODMENUITEM#${id}` })),
    );
    const menuById = new Map<string, Record<string, any>>();
    for (const row of menuRows) {
        if (row && !row.isDeleted && row.isActive !== false && !row.isOutOfStock) {
            const id = row.id || String(row.SK || '').replace('FOODMENUITEM#', '');
            menuById.set(id, row);
        }
    }

    const missing = uniqueIds.filter((id) => !menuById.has(id));
    if (missing.length > 0) {
        return json(400, { error: 'unknown_or_unavailable_items', missing });
    }

    // Resolve vendor's GST rate (basis points, e.g. 500 = 5%). Default 5%.
    let gstRateBps = 500;
    try {
        const businesses = await queryItems<Record<string, any>>(pk, 'BUSINESS#', {});
        const biz = businesses.items[0];
        const settingsBps = Number(biz?.settings?.gstRateBps ?? biz?.gstRateBps ?? NaN);
        if (Number.isFinite(settingsBps) && settingsBps >= 0 && settingsBps <= 5000) {
            gstRateBps = Math.round(settingsBps);
        }
    } catch (err) {
        logger.warn('GST rate lookup failed; using default 5%', { error: (err as Error).message });
    }

    // Build authoritative item records + cent totals.
    let subtotalCents = 0;
    const lineItems = uniqueIds.map((id) => {
        const row = menuById.get(id)!;
        const priceCents = Number(row.salePriceCents ?? row.priceCents ?? 0);
        const qty = requestedQty[id];
        const lineCents = priceCents * qty;
        subtotalCents += lineCents;
        return {
            menuItemId: id,
            name: row.name || 'Item',
            priceCents,
            qty,
            lineCents,
            note: requestedNotes[id] || null,
            isVeg: row.isVeg !== false,
        };
    });

    const gstCents = Math.round((subtotalCents * gstRateBps) / 10000);
    const totalCents = subtotalCents + gstCents;

    const orderId = randomUUID();
    const now = new Date().toISOString();

    await putItem({
        PK: pk,
        SK: `PWAV1ORDER#${orderId}`,
        entityType: 'RESTO_PWA_V1_ORDER',
        id: orderId,
        tenantId: vendorId,
        tableId,
        items: lineItems,
        subtotalCents,
        gstCents,
        totalCents,
        gstRateBps,
        customerName: body.customerName || null,
        phone: body.phone || null,
        status: 'placed',
        kots: [],
        estimatedMinutes: 15,
        createdAt: now,
        updatedAt: now,
    });

    wsService
        .broadcastToStaff(vendorId, WSEventName.ORDER_CREATED, {
            orderId,
            source: 'restaurant_v1_public',
            tableId,
            itemCount: lineItems.length,
            totalCents,
        })
        .catch((err) => logger.warn('WS broadcast failed', { error: (err as Error).message }));

    // UNS canonical emit (T-RES-1: orders.restaurant.created)
    emitUnsEvent({
        eventName: 'orders.restaurant.created',
        category: 'orders',
        subCategory: 'restaurant',
        priority: 'high',
        actorId: 'public_scan_client',
        targetId: orderId,
        recipients: [
            { user_id: vendorId, role: 'admin' },
        ],
        payload: {
            tenantId: vendorId,
            orderId,
            source: 'restaurant_v1_public',
            tableId,
            itemCount: lineItems.length,
            totalCents,
        },
        sourceModule: 'my-backend/src/handlers/restaurant-v1-public.ts',
        dedupScopeFields: ['orderId'],
    }).catch(() => { /* non-fatal during migration window */ });

    return json(201, {
        orderId,
        status: 'placed',
        estimatedMinutes: 15,
        subtotalCents,
        gstCents,
        totalCents,
        gstRateBps,
    });
};

/** GET /api/v1/restaurant/orders/{orderId} */
export const compatOrderStatus = async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
): Promise<APIGatewayProxyResultV2> => {
    if (!isPublicEnabled()) return json(404, { error: 'RESTO_V1_PUBLIC_DISABLED' });
    const orderId = event.pathParameters?.orderId;
    const vendorId = event.queryStringParameters?.vendorId;
    if (!orderId) return json(400, { error: 'orderId required' });

    if (vendorId) {
        const row = await getItem<Record<string, any>>(Keys.tenantPK(vendorId), `PWAV1ORDER#${orderId}`);
        if (!row || row.isDeleted) return json(404, { error: 'not_found' });
        return json(200, formatOrder(row));
    }

    return json(400, { error: 'vendorId query parameter required for lookup' });
};

function formatOrder(row: Record<string, any>) {
    return {
        orderId: row.id,
        status: row.status || 'placed',
        kots: row.kots || [],
        estimatedMinutes: row.estimatedMinutes ?? 15,
        items: row.items || [],
        tableId: row.tableId,
    };
}

/**
 * GET /api/v1/restaurant/bill?vendorId=&tableId=
 * Aggregates open orders' authoritative cent totals (set at /orders time).
 * P2-02 fix: previously this re-derived from `o.items[].price` which was
 * never written by the writer → always returned 0. Now reads stored cents.
 */
export const compatBill = async (
    event: APIGatewayProxyEventV2,
    _ctx: Context,
): Promise<APIGatewayProxyResultV2> => {
    if (!isPublicEnabled()) return json(404, { error: 'RESTO_V1_PUBLIC_DISABLED' });
    const vendorId = event.queryStringParameters?.vendorId;
    const tableId = event.queryStringParameters?.tableId;
    if (!vendorId || !tableId) return json(400, { error: 'vendorId and tableId required' });

    const pk = Keys.tenantPK(vendorId);
    const orders = await queryItems<Record<string, any>>(pk, 'PWAV1ORDER#', {
        filterExpression: 'tableId = :tid AND (#st = :placed OR #st = :prep)',
        expressionAttributeNames: { '#st': 'status' },
        expressionAttributeValues: {
            ':tid': tableId,
            ':placed': 'placed',
            ':prep': 'preparing',
        },
    });

    let subtotalCents = 0;
    let gstCents = 0;
    let totalCents = 0;
    let gstRateBps = 500;
    const billItems: Array<Record<string, unknown>> = [];

    for (const o of orders.items) {
        subtotalCents += Number(o.subtotalCents ?? 0);
        gstCents += Number(o.gstCents ?? 0);
        totalCents += Number(o.totalCents ?? 0);
        if (Number.isFinite(Number(o.gstRateBps))) gstRateBps = Number(o.gstRateBps);

        const lineItems = Array.isArray(o.items) ? o.items : [];
        for (const li of lineItems) {
            const x = li as Record<string, unknown>;
            billItems.push({
                name: x.name || 'Item',
                qty: Number(x.qty ?? 1),
                priceCents: Number(x.priceCents ?? 0),
                lineCents: Number(x.lineCents ?? 0),
                note: x.note ?? null,
            });
        }
    }

    return json(200, {
        items: billItems,
        subtotalCents,
        gstCents,
        totalCents,
        gstRateBps,
        discountCents: 0,
        // Legacy float fields for older PWA builds (deprecated).
        subtotal: subtotalCents / 100,
        gst: gstCents / 100,
        grandTotal: totalCents / 100,
    });
};

/**
 * POS template routes — real flows use Cognito JWT + /resto/* in my-backend.
 */
export const posV1NotImplemented = async (
    _event: APIGatewayProxyEventV2,
    _ctx: Context,
): Promise<APIGatewayProxyResultV2> => {
    return json(501, {
        error: 'USE_CORE_RESTO_API',
        message:
            'Authenticate with POST /auth/login (Cognito), then use /resto/tables, /resto/menu, /resto/kot with Authorization Bearer token. Same API base as Dukan_x (DUKANX_API_URL).',
    });
};
