// ============================================================================
// Lambda Handler — In-Store Self Scan Session Management
// ============================================================================
// POST /in-store/session/start        — start a new scan session
// GET  /in-store/session/{sessionId}  — get session + cart
// PATCH /in-store/session/{sessionId}/cart — sync cart server-side
// POST /in-store/session/{sessionId}/abandon — abandon session
// GET  /in-store/sessions/active      — admin: list active sessions (monitor)
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import {
    Keys, putItem, getItem, updateItem, queryItems,
} from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { UserRole, AuthContext } from '../types/tenant.types';
import {
    InStoreSession, InStoreSessionStatus, CartItem, CartSummary,
    GstBreakup, SELF_SCAN_ELIGIBLE_BUSINESS_TYPES,
} from '../types/in-store.types';
import crypto from 'crypto';

const SESSION_TTL_HOURS = 4;

// ── Key builders ─────────────────────────────────────────────────────────────

function sessionPK(sessionId: string) { return `SESSION#${sessionId}`; }
function sessionSK(sessionId: string) { return `SESSION#${sessionId}`; }
function sessionByCustomerGSI1PK(customerId: string) { return `CUSTOMER_SESSION#${customerId}`; }
function sessionByStoreGSI2PK(storeId: string) { return `STORE_SESSION#${storeId}`; }

// ── Cart calculation helper ───────────────────────────────────────────────────

export function calcCartSummary(cartItems: CartItem[]): CartSummary {
    const gstSlabMap: Record<number, { taxable: number; gst: number }> = {};

    let subtotalCents = 0;
    let discountCents = 0;

    for (const item of cartItems) {
        const mrpTotal = item.mrp * item.quantity;
        const sellingTotal = item.sellingPrice * item.quantity;
        subtotalCents += sellingTotal;
        discountCents += mrpTotal - sellingTotal;

        const taxableAmount = Math.round(sellingTotal / (1 + item.gstSlab / 100));
        const gstAmount = sellingTotal - taxableAmount;

        if (!gstSlabMap[item.gstSlab]) {
            gstSlabMap[item.gstSlab] = { taxable: 0, gst: 0 };
        }
        gstSlabMap[item.gstSlab].taxable += taxableAmount;
        gstSlabMap[item.gstSlab].gst += gstAmount;
    }

    const gstBreakup: GstBreakup[] = Object.entries(gstSlabMap).map(([slab, v]) => ({
        slab: Number(slab),
        taxableAmount: v.taxable,
        cgst: Math.round(v.gst / 2),
        sgst: Math.round(v.gst / 2),
        total: v.gst,
    }));

    const totalGstCents = gstBreakup.reduce((sum, g) => sum + g.total, 0);
    const itemCount = cartItems.reduce((sum, i) => sum + i.quantity, 0);

    return {
        subtotalCents,
        discountCents,
        gstBreakup,
        totalGstCents,
        totalCents: subtotalCents,
        itemCount,
    };
}

// ── POST /in-store/session/start ─────────────────────────────────────────────

export const startSession = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        let body: { storeId: string; tenantId: string };
        try {
            body = JSON.parse(event.body || '{}');
        } catch {
            return response.badRequest('Invalid JSON body');
        }

        const { storeId, tenantId } = body;
        if (!storeId || !tenantId) {
            return response.badRequest('storeId and tenantId are required');
        }

        // Tenant isolation — tenantId in body must match JWT
        if (tenantId !== auth.tenantId) {
            return response.forbidden('Tenant mismatch');
        }

        // Verify business type supports self-scan
        const businessType = auth.businessType as string;
        if (!(SELF_SCAN_ELIGIBLE_BUSINESS_TYPES as readonly string[]).includes(businessType)) {
            return response.forbidden(
                `Self Scan & Checkout is not available for business type: ${businessType}. ` +
                `Supported: ${SELF_SCAN_ELIGIBLE_BUSINESS_TYPES.join(', ')}`
            );
        }

        // Check for existing ACTIVE session for this customer at this store
        const existingSession = await queryItems<InStoreSession>(
            sessionByCustomerGSI1PK(auth.sub),
            `STORE#${storeId}`,
            { indexName: 'GSI1', limit: 1 }
        );

        if (existingSession.items.length > 0) {
            const existing = existingSession.items[0];
            if (existing.status === InStoreSessionStatus.ACTIVE) {
                return response.success({
                    sessionId: existing.sessionId,
                    storeId: existing.storeId,
                    status: existing.status,
                    cartItems: existing.cartItems,
                    summary: calcCartSummary(existing.cartItems),
                    resumedAt: new Date().toISOString(),
                });
            }
        }

        // Fetch store info
        const tenantPK = Keys.tenantPK(auth.tenantId);
        const store = await getItem<Record<string, any>>(tenantPK, `BUSINESS#${storeId}`);
        if (!store) {
            return response.notFound('Store');
        }

        const sessionId = crypto.randomUUID();
        const now = new Date();
        const ttlEpoch = Math.floor(now.getTime() / 1000) + (SESSION_TTL_HOURS * 3600);

        const session: InStoreSession = {
            PK: sessionPK(sessionId),
            SK: sessionSK(sessionId),
            sessionId,
            customerId: auth.sub,
            storeId,
            tenantId: auth.tenantId,
            status: InStoreSessionStatus.ACTIVE,
            cartItems: [],
            startedAt: now.toISOString(),
            TTL: ttlEpoch,
            GSI1PK: sessionByCustomerGSI1PK(auth.sub),
            GSI1SK: `STORE#${storeId}`,
            GSI2PK: sessionByStoreGSI2PK(storeId),
            GSI2SK: `STATUS#${InStoreSessionStatus.ACTIVE}#${now.toISOString()}`,
        };

        await putItem(session as unknown as Record<string, unknown>);

        logger.info('InStoreSession started', { sessionId, customerId: auth.sub, storeId, tenantId: auth.tenantId });

        return response.success({
            sessionId,
            storeId,
            storeName: store.name || store.displayName || '',
            storeAddress: store.address || '',
            status: InStoreSessionStatus.ACTIVE,
        }, 201);
    }
);

// ── GET /in-store/session/{sessionId} ────────────────────────────────────────

export const getSession = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const sessionId = event.pathParameters?.sessionId;
        if (!sessionId) return response.badRequest('sessionId required');

        const session = await getItem<InStoreSession>(sessionPK(sessionId), sessionSK(sessionId));
        if (!session) return response.notFound('Session');

        // Tenant isolation
        if (session.tenantId !== auth.tenantId) return response.forbidden('Access denied');
        // Customers can only see their own session
        if (session.customerId !== auth.sub &&
            ![UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER].includes(auth.role)) {
            return response.forbidden('Access denied');
        }

        return response.success({
            session: {
                sessionId: session.sessionId,
                storeId: session.storeId,
                status: session.status,
                cartItems: session.cartItems,
                startedAt: session.startedAt,
                completedAt: session.completedAt,
            },
            summary: calcCartSummary(session.cartItems),
        });
    }
);

// ── PATCH /in-store/session/{sessionId}/cart ─────────────────────────────────

export const updateCart = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const sessionId = event.pathParameters?.sessionId;
        if (!sessionId) return response.badRequest('sessionId required');

        let body: { cartItems: CartItem[] };
        try {
            body = JSON.parse(event.body || '{}');
        } catch {
            return response.badRequest('Invalid JSON body');
        }

        if (!Array.isArray(body.cartItems)) {
            return response.badRequest('cartItems array required');
        }

        const session = await getItem<InStoreSession>(sessionPK(sessionId), sessionSK(sessionId));
        if (!session) return response.notFound('Session');
        if (session.tenantId !== auth.tenantId) return response.forbidden('Access denied');
        if (session.customerId !== auth.sub) return response.forbidden('Access denied');
        if (session.status !== InStoreSessionStatus.ACTIVE) {
            return response.badRequest(`Session is ${session.status} — cannot update cart`);
        }

        // Validate quantities
        const cartItems = body.cartItems.filter(i => i.quantity > 0);

        await updateItem(sessionPK(sessionId), sessionSK(sessionId), {
            updateExpression: 'SET cartItems = :items, updatedAt = :now',
            expressionAttributeValues: {
                ':items': cartItems,
                ':now': new Date().toISOString(),
            },
        });

        const summary = calcCartSummary(cartItems);

        return response.success({ sessionId, cartItems, ...summary });
    }
);

// ── POST /in-store/session/{sessionId}/abandon ────────────────────────────────

export const abandonSession = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const sessionId = event.pathParameters?.sessionId;
        if (!sessionId) return response.badRequest('sessionId required');

        const session = await getItem<InStoreSession>(sessionPK(sessionId), sessionSK(sessionId));
        if (!session) return response.notFound('Session');
        if (session.tenantId !== auth.tenantId) return response.forbidden('Access denied');
        if (session.customerId !== auth.sub &&
            ![UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER].includes(auth.role)) {
            return response.forbidden('Access denied');
        }

        if (session.status !== InStoreSessionStatus.ACTIVE) {
            return response.badRequest(`Session already ${session.status}`);
        }

        await updateItem(sessionPK(sessionId), sessionSK(sessionId), {
            updateExpression: 'SET #status = :status, completedAt = :now, GSI2SK = :gsi2sk',
            expressionAttributeNames: { '#status': 'status' },
            expressionAttributeValues: {
                ':status': InStoreSessionStatus.ABANDONED,
                ':now': new Date().toISOString(),
                ':gsi2sk': `STATUS#${InStoreSessionStatus.ABANDONED}#${new Date().toISOString()}`,
            },
        });

        return response.success({ message: 'Session abandoned' });
    }
);

// ── GET /in-store/sessions/active — Admin session monitor ────────────────────

export const listActiveSessions = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const storeId = event.queryStringParameters?.storeId;
        if (!storeId) return response.badRequest('storeId query param required');

        const sessions = await queryItems<InStoreSession>(
            sessionByStoreGSI2PK(storeId),
            `STATUS#${InStoreSessionStatus.ACTIVE}`,
            { indexName: 'GSI2', limit: 100 }
        );

        // Filter to this tenant only
        const filtered = sessions.items.filter(s => s.tenantId === auth.tenantId);

        return response.success({
            activeSessions: filtered.length,
            sessions: filtered.map(s => ({
                sessionId: s.sessionId,
                customerId: s.customerId,
                startedAt: s.startedAt,
                itemCount: calcCartSummary(s.cartItems).itemCount,
                totalCents: calcCartSummary(s.cartItems).totalCents,
            })),
        });
    }
);
