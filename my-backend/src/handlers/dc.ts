// ============================================================================
// Lambda Handler — Decoration & Catering Module (DynamoDB)
// ============================================================================
// Entities: Events, Decoration Themes, Catering Menu Items, Packages,
//           Staff, Vendors, Inventory, Expenses, Invoices, Dashboard
// All routes: /dc/*   (require JWT + BusinessType.DECORATION_CATERING)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import {
    Keys,
    queryAllItems,
    putItem,
    getItem,
    updateItem,
    deleteItem,
} from '../config/dynamodb.config';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import * as wsService from '../services/websocket.service';
import { WSEventName, ClientType } from '../types/websocket.types';
// UNS event_bus — task 14.9 migration of T-DC-1..T-DC-8 producers
import { emitUnsEvent } from '../notifications/event-bus';

// ── Handler Options ────────────────────────────────────────────────────────
const DC_OPTS = {
    requiredBusinessType: BusinessType.DECORATION_CATERING,
    requiredFeature: FeatureKey.DC_EVENT_BOOKING,
};
const DC_STAFF_OPTS = {
    requiredBusinessType: BusinessType.DECORATION_CATERING,
    requiredFeature: FeatureKey.DC_STAFF_MANAGEMENT,
};
const DC_MENU_OPTS = {
    requiredBusinessType: BusinessType.DECORATION_CATERING,
    requiredFeature: FeatureKey.DC_CATERING_MENU,
};
const DC_BILLING_OPTS = {
    requiredBusinessType: BusinessType.DECORATION_CATERING,
    requiredFeature: FeatureKey.DC_BILLING,
};
const DC_REPORTS_OPTS = {
    requiredBusinessType: BusinessType.DECORATION_CATERING,
    requiredFeature: FeatureKey.DC_REPORTS,
};
const DC_INV_OPTS = {
    requiredBusinessType: BusinessType.DECORATION_CATERING,
    requiredFeature: FeatureKey.DC_INVENTORY,
};

// ── Helpers ────────────────────────────────────────────────────────────────
function uid(): string {
    return crypto.randomUUID().replace(/-/g, '').substring(0, 16).toUpperCase();
}

function now(): string {
    return new Date().toISOString();
}

function parseBody<T>(event: any): T {
    if (!event.body) throw new Error('Request body is required');
    return typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
}

// ============================================================================
// EVENT BOOKINGS
// ============================================================================

/**
 * GET /dc/events?status=&search=&page=&limit=
 */
export const listEvents = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);

    const allEvents = await queryAllItems<Record<string, any>>(pk, 'DC_EVENT#');

    let filtered = allEvents;
    if (p.status) filtered = filtered.filter((e: Record<string, any>) => e.status === p.status);
    if (p.search) {
        const s = p.search.toLowerCase();
        filtered = filtered.filter((e: Record<string, any>) =>
            (e.customerName || '').toLowerCase().includes(s) ||
            (e.eventType || '').toLowerCase().includes(s) ||
            (e.venueName || '').toLowerCase().includes(s)
        );
    }

    filtered.sort((a: Record<string, any>, b: Record<string, any>) => (b.eventDate || '').localeCompare(a.eventDate || ''));
    const total = filtered.length;
    const paged = filtered.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
}, DC_OPTS);

/**
 * GET /dc/events/{id}
 */
export const getEvent = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Event ID required');
    const pk = Keys.tenantPK(auth.tenantId);
    const item = await getItem(pk, Keys.dcEventSK(id));
    if (!item) return response.notFound('Event not found');
    return response.success(item);
}, DC_OPTS);

/**
 * POST /dc/events
 */
export const createEvent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            customerName, customerPhone, customerEmail,
            eventType, eventTitle = '', eventDate, venueName, venueAddress,
            guestCount, decorationThemeId, cateringPackageId,
            includesDecoration = false, includesCatering = false,
            advanceAmountPaisa = 0, notes,
            setupTime, serviceStartTime, serviceEndTime, cleanupTime,
        } = body;

        if (!customerName || !customerPhone || !eventType || !eventDate || !guestCount) {
            return response.badRequest('customerName, customerPhone, eventType, eventDate, guestCount are required');
        }

        const pk = Keys.tenantPK(auth.tenantId);

        // Venue conflict check — prevent double-booking the same venue on the same date
        if (venueName) {
            const existingEvents = await queryAllItems<Record<string, any>>(pk, 'DC_EVENT#');
            const conflict = existingEvents.find(
                (e: Record<string, any>) =>
                    e.venueName &&
                    e.venueName.trim().toLowerCase() === (venueName as string).trim().toLowerCase() &&
                    e.eventDate === eventDate &&
                    e.status !== 'cancelled',
            );
            if (conflict) {
                return response.badRequest(
                    `Venue "${venueName}" is already booked on ${eventDate} (Event: ${conflict.customerName}, ID: ${conflict.id}). Please choose a different venue or date.`,
                );
            }
        }

        const id = uid();
        const ts = now();

        const item = {
            PK: pk, SK: Keys.dcEventSK(id),
            GSI1PK: Keys.dcEventGSI1PK(auth.tenantId),
            GSI1SK: Keys.dcEventGSI1SK(eventDate, id),
            id, customerName, customerPhone, customerEmail,
            eventType, eventTitle, eventDate, venueName, venueAddress,
            guestCount: Number(guestCount),
            decorationThemeId, cateringPackageId,
            includesDecoration, includesCatering,
            advanceAmountPaisa: Number(advanceAmountPaisa),
            totalAmountPaisa: 0,
            balancePaisa: 0,
            status: 'enquiry',
            notes,
            setupTime, serviceStartTime, serviceEndTime, cleanupTime,
            createdAt: ts, updatedAt: ts,
            createdBy: auth.sub,
        };

        await putItem(item);
        logger.info('DC event created', { tenantId: auth.tenantId, eventId: id });

        // Broadcast to desktop app
        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.DC_EVENT_CREATED,
            { eventId: id, customerName, eventType, eventDate, guestCount, status: 'enquiry' },
        ).catch(() => { /* non-critical */ });

        // UNS canonical emit (T-DC-1: orders.dc_quote.converted on quote→booking
        // OR new event creation). For pure new-event flow we emit a generic
        // dc_event creation envelope under the same registry slot.
        emitUnsEvent({
            eventName: 'orders.dc_quote.converted',
            category: 'orders',
            subCategory: 'dc_event',
            priority: 'normal',
            actorId: auth.sub,
            targetId: id,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                eventId: id,
                customerName,
                eventType,
                eventDate,
                guestCount,
                status: 'enquiry',
            },
            sourceModule: 'my-backend/src/handlers/dc.ts',
            dedupScopeFields: ['eventId'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success(item, 201);
    },
    DC_OPTS,
);

/**
 * PUT /dc/events/{id}
 */
export const updateEvent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Event ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);

        const existing = await getItem<Record<string, any>>(pk, Keys.dcEventSK(id));
        if (!existing) return response.notFound('Event not found');

        // Venue conflict check on update if venueName or eventDate is changing
        const newVenue = body.venueName ?? existing.venueName;
        const newDate = body.eventDate ?? existing.eventDate;
        if ((body.venueName !== undefined || body.eventDate !== undefined) && newVenue) {
            const existingEvents = await queryAllItems<Record<string, any>>(pk, 'DC_EVENT#');
            const conflict = existingEvents.find(
                (e: Record<string, any>) =>
                    e.id !== id &&
                    e.venueName &&
                    e.venueName.trim().toLowerCase() === (newVenue as string).trim().toLowerCase() &&
                    e.eventDate === newDate &&
                    e.status !== 'cancelled',
            );
            if (conflict) {
                return response.badRequest(
                    `Venue "${newVenue}" is already booked on ${newDate} (Event: ${conflict.customerName}, ID: ${conflict.id}).`,
                );
            }
        }

        const allowed = [
            'customerName', 'customerPhone', 'customerEmail', 'eventType', 'eventTitle',
            'eventDate', 'venueName', 'venueAddress', 'guestCount',
            'decorationThemeId', 'cateringPackageId', 'includesDecoration',
            'includesCatering', 'advanceAmountPaisa', 'totalAmountPaisa',
            'balancePaisa', 'status', 'notes', 'assignedStaffIds',
            'setupTime', 'serviceStartTime', 'serviceEndTime', 'cleanupTime',
        ];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) {
            if (body[k] !== undefined) updates[k] = body[k];
        }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }

        await updateItem(pk, Keys.dcEventSK(id), {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeNames: names,
            expressionAttributeValues: values,
        });

        // Broadcast update
        const statusChanged = body.status && body.status !== existing.status;
        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            statusChanged ? WSEventName.DC_EVENT_STATUS_CHANGED : WSEventName.DC_EVENT_UPDATED,
            { eventId: id, status: body.status || existing.status, statusChanged, previousStatus: existing.status },
        ).catch(() => { /* non-critical */ });

        // UNS canonical emit (T-DC-2: orders.dc_event.status_changed)
        if (statusChanged) {
            emitUnsEvent({
                eventName: 'orders.dc_event.status_changed',
                category: 'orders',
                subCategory: 'dc_event',
                priority: 'normal',
                actorId: auth.sub,
                targetId: id,
                recipients: [
                    { user_id: auth.tenantId, role: 'admin' },
                ],
                payload: {
                    tenantId: auth.tenantId,
                    eventId: id,
                    status: body.status,
                    previousStatus: existing.status,
                },
                sourceModule: 'my-backend/src/handlers/dc.ts',
                dedupScopeFields: ['eventId', 'status'],
            }).catch(() => { /* non-fatal during migration window */ });
        }

        return response.success({ ...existing, ...updates });
    },
    DC_OPTS,
);

/**
 * POST /dc/events/{id}/payments  — record an advance payment against an event (pre- or post-invoice)
 */
export const recordEventPayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _ctx, auth) => {
        const eventId = event.pathParameters?.id;
        if (!eventId) return response.badRequest('Event ID required');
        const body = parseBody<Record<string, any>>(event);
        const { amountPaisa, paymentMode = 'cash', reference, invoiceId } = body;
        if (!amountPaisa || Number(amountPaisa) <= 0) return response.badRequest('amountPaisa > 0 required');

        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcEventSK(eventId));
        if (!existing) return response.notFound('Event not found');

        const newAdvance = (existing.advanceAmountPaisa || 0) + Number(amountPaisa);
        const newBalance = Math.max(0, (existing.totalAmountPaisa || 0) - newAdvance);

        await updateItem(pk, Keys.dcEventSK(eventId), {
            updateExpression: 'SET #adv = :adv, #bal = :bal, #updatedAt = :ts',
            expressionAttributeNames: { '#adv': 'advanceAmountPaisa', '#bal': 'balancePaisa', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':adv': newAdvance, ':bal': newBalance, ':ts': now() },
        });

        // If linked invoice provided, sync its balance too
        if (invoiceId) {
            const inv = await getItem<Record<string, any>>(pk, Keys.dcInvoiceSK(invoiceId));
            if (inv) {
                const invNewAdvance = (inv.advancePaidPaisa || 0) + Number(amountPaisa);
                const invNewBalance = (inv.totalPaisa || 0) - invNewAdvance;
                const invNewStatus = invNewBalance <= 0 ? 'paid' : 'partial';
                await updateItem(pk, Keys.dcInvoiceSK(invoiceId), {
                    updateExpression: 'SET #adv = :adv, #bal = :bal, #st = :st, #updatedAt = :ts',
                    expressionAttributeNames: { '#adv': 'advancePaidPaisa', '#bal': 'balancePaisa', '#st': 'status', '#updatedAt': 'updatedAt' },
                    expressionAttributeValues: { ':adv': invNewAdvance, ':bal': invNewBalance, ':st': invNewStatus, ':ts': now() },
                });
            }
        }

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.DC_PAYMENT_RECEIVED,
            { eventId, amountPaisa: Number(amountPaisa), paymentMode, reference, invoiceId, newAdvance, newBalance },
        ).catch(() => { /* non-critical */ });

        // UNS canonical emit (T-DC-4: payment.dc.received — event-level payment)
        emitUnsEvent({
            eventName: 'payment.dc.received',
            category: 'payments',
            subCategory: 'dc',
            priority: 'normal',
            actorId: auth.sub,
            targetId: eventId,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                eventId,
                invoiceId: invoiceId ?? null,
                amountPaisa: Number(amountPaisa),
                paymentMode,
                reference: reference ?? null,
                newAdvance,
                newBalance,
            },
            sourceModule: 'my-backend/src/handlers/dc.ts',
            dedupScopeFields: ['eventId', 'invoiceId', 'amountPaisa'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success({ eventId, advanceAmountPaisa: newAdvance, balancePaisa: newBalance, paymentMode, reference, invoiceId });
    },
    DC_OPTS,
);

/**
 * DELETE /dc/events/{id}
 */
export const deleteEvent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Event ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, Keys.dcEventSK(id));
        if (!existing) return response.notFound('Event not found');
        await deleteItem(pk, Keys.dcEventSK(id));
        return response.success({ deleted: true, id });
    },
    DC_OPTS,
);

// ============================================================================
// DECORATION THEMES
// ============================================================================

/**
 * GET /dc/themes
 */
export const listThemes = authorizedHandler([], async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_THEME#');
    allItems.sort((a: Record<string, any>, b: Record<string, any>) => (a.name || '').localeCompare(b.name || ''));
    return response.success(allItems);
}, DC_OPTS);

/**
 * POST /dc/themes
 */
export const createTheme = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { name, category, description, baseRatePaisa = 0, colorPalette = [], tags = [] } = body;
        if (!name || !category) return response.badRequest('name, category required');

        const id = uid();
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk, SK: Keys.dcThemeSK(id),
            id, name, category, description,
            baseRatePaisa: Number(baseRatePaisa),
            colorPalette, tags,
            imageUrls: [],
            createdAt: ts, updatedAt: ts,
        };
        await putItem(item);
        return response.success(item, 201);
    },
    DC_OPTS,
);

/**
 * PUT /dc/themes/{id}
 */
export const updateTheme = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Theme ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcThemeSK(id));
        if (!existing) return response.notFound('Theme not found');

        const allowed = ['name', 'category', 'description', 'baseRatePaisa', 'colorPalette', 'tags', 'imageUrls'];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }
        await updateItem(pk, Keys.dcThemeSK(id), { updateExpression: `SET ${exprParts.join(', ')}`, expressionAttributeNames: names, expressionAttributeValues: values });
        return response.success({ ...existing, ...updates });
    },
    DC_OPTS,
);

/**
 * DELETE /dc/themes/{id}
 */
export const deleteTheme = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Theme ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, Keys.dcThemeSK(id));
        if (!existing) return response.notFound('Theme not found');
        await deleteItem(pk, Keys.dcThemeSK(id));
        return response.success({ deleted: true, id });
    },
    DC_OPTS,
);

// ============================================================================
// CATERING MENU ITEMS
// ============================================================================

/**
 * GET /dc/menu?category=
 */
export const listMenuItems = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_MENU#');
    let filtered = allItems;
    if (p.category) filtered = filtered.filter(i => i.category === p.category);
    filtered.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
    return response.success(filtered);
}, DC_MENU_OPTS);

/**
 * POST /dc/menu
 */
export const createMenuItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { name, category, description, ratePaisaPerPlate = 0, isVeg = true, allergens = [] } = body;
        if (!name || !category) return response.badRequest('name, category required');

        const id = uid();
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk, SK: Keys.dcMenuItemSK(id),
            id, name, category, description,
            ratePaisaPerPlate: Number(ratePaisaPerPlate),
            isVeg, allergens,
            createdAt: ts, updatedAt: ts,
        };
        await putItem(item);
        return response.success(item, 201);
    },
    DC_MENU_OPTS,
);

/**
 * PUT /dc/menu/{id}
 */
export const updateMenuItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Menu item ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcMenuItemSK(id));
        if (!existing) return response.notFound('Menu item not found');

        const allowed = ['name', 'category', 'description', 'ratePaisaPerPlate', 'isVeg', 'allergens'];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }
        await updateItem(pk, Keys.dcMenuItemSK(id), { updateExpression: `SET ${exprParts.join(', ')}`, expressionAttributeNames: names, expressionAttributeValues: values });
        return response.success({ ...existing, ...updates });
    },
    DC_MENU_OPTS,
);

/**
 * DELETE /dc/menu/{id}
 */
export const deleteMenuItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Menu item ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, Keys.dcMenuItemSK(id));
        if (!existing) return response.notFound('Menu item not found');
        await deleteItem(pk, Keys.dcMenuItemSK(id));
        return response.success({ deleted: true, id });
    },
    DC_MENU_OPTS,
);

// ============================================================================
// CATERING PACKAGES
// ============================================================================

/**
 * GET /dc/packages
 */
export const listPackages = authorizedHandler([], async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_PKG#');
    allItems.sort((a: Record<string, any>, b: Record<string, any>) => (a.name || '').localeCompare(b.name || ''));
    return response.success(allItems);
}, DC_MENU_OPTS);

/**
 * POST /dc/packages
 */
export const createPackage = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { name, description, pricePerPlatePaisa = 0, menuItemIds = [], minGuests = 1, maxGuests } = body;
        if (!name) return response.badRequest('name required');

        const id = uid();
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk, SK: Keys.dcPackageSK(id),
            id, name, description,
            pricePerPlatePaisa: Number(pricePerPlatePaisa),
            menuItemIds, minGuests, maxGuests,
            createdAt: ts, updatedAt: ts,
        };
        await putItem(item);
        return response.success(item, 201);
    },
    DC_MENU_OPTS,
);

/**
 * PUT /dc/packages/{id}
 */
export const updatePackage = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Package ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcPackageSK(id));
        if (!existing) return response.notFound('Package not found');

        const allowed = ['name', 'description', 'pricePerPlatePaisa', 'menuItemIds', 'minGuests', 'maxGuests'];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }
        await updateItem(pk, Keys.dcPackageSK(id), { updateExpression: `SET ${exprParts.join(', ')}`, expressionAttributeNames: names, expressionAttributeValues: values });
        return response.success({ ...existing, ...updates });
    },
    DC_MENU_OPTS,
);

/**
 * DELETE /dc/packages/{id}
 */
export const deletePackage = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Package ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, Keys.dcPackageSK(id));
        if (!existing) return response.notFound('Package not found');
        await deleteItem(pk, Keys.dcPackageSK(id));
        return response.success({ deleted: true, id });
    },
    DC_MENU_OPTS,
);

// ============================================================================
// STAFF
// ============================================================================

/**
 * GET /dc/staff?role=&search=
 */
export const listStaff = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_STAFF#');

    let filtered = allItems.filter((s: Record<string, any>) => !s.isDeleted);
    if (p.role) filtered = filtered.filter((s: Record<string, any>) => s.role === p.role);
    if (p.search) {
        const q = p.search.toLowerCase();
        filtered = filtered.filter((s: Record<string, any>) =>
            (s.name || '').toLowerCase().includes(q) ||
            (s.phone || '').includes(q)
        );
    }
    filtered.sort((a: Record<string, any>, b: Record<string, any>) => (a.name || '').localeCompare(b.name || ''));
    return response.success(filtered);
}, DC_STAFF_OPTS);

/**
 * POST /dc/staff
 */
export const createStaff = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { name, phone, email, role, dailyRatePaisa = 0, skills = [], address } = body;
        if (!name || !phone || !role) return response.badRequest('name, phone, role required');

        const id = uid();
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk, SK: Keys.dcStaffSK(id),
            id, name, phone, email, role,
            dailyRatePaisa: Number(dailyRatePaisa),
            skills, address, isActive: true, isDeleted: false,
            totalEventsHandled: 0,
            createdAt: ts, updatedAt: ts,
        };
        await putItem(item);
        return response.success(item, 201);
    },
    DC_STAFF_OPTS,
);

/**
 * PUT /dc/staff/{id}
 */
export const updateStaff = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Staff ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcStaffSK(id));
        if (!existing || existing.isDeleted) return response.notFound('Staff not found');

        const allowed = ['name', 'phone', 'email', 'role', 'dailyRatePaisa', 'skills', 'address', 'isActive'];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }
        await updateItem(pk, Keys.dcStaffSK(id), { updateExpression: `SET ${exprParts.join(', ')}`, expressionAttributeNames: names, expressionAttributeValues: values });
        return response.success({ ...existing, ...updates });
    },
    DC_STAFF_OPTS,
);

/**
 * DELETE /dc/staff/{id}  (soft delete)
 */
export const deleteStaff = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Staff ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, Keys.dcStaffSK(id));
        if (!existing) return response.notFound('Staff not found');
        await updateItem(pk, Keys.dcStaffSK(id), { updateExpression: 'SET #isDeleted = :v, #updatedAt = :ts', expressionAttributeNames: { '#isDeleted': 'isDeleted', '#updatedAt': 'updatedAt' }, expressionAttributeValues: { ':v': true, ':ts': now() } });
        return response.success({ deleted: true, id });
    },
    DC_STAFF_OPTS,
);

// ============================================================================
// STAFF ATTENDANCE
// ============================================================================

/**
 * POST /dc/staff/attendance  — mark attendance for multiple staff on a date
 * Body: { date: 'YYYY-MM-DD', records: [{ staffId, status: 'present'|'absent'|'halfDay' }] }
 */
export const markAttendance = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { date, records } = body;
        if (!date || !Array.isArray(records) || records.length === 0) {
            return response.badRequest('date and records[] required');
        }
        const validStatuses = ['present', 'absent', 'halfDay'];
        for (const r of records as any[]) {
            if (!r.staffId) return response.badRequest('each record must have staffId');
            if (!validStatuses.includes(r.status)) return response.badRequest(`status must be one of: ${validStatuses.join(', ')}`);
        }

        const pk = Keys.tenantPK(auth.tenantId);
        const ts = now();
        const id = `ATT#${date}`;

        const item = {
            PK: pk, SK: `DC_ATTENDANCE#${date}`,
            id, date, records,
            createdAt: ts, updatedAt: ts, createdBy: auth.sub,
        };
        await putItem(item);

        logger.info('DC attendance marked', { tenantId: auth.tenantId, date, count: records.length });
        return response.success(item, 201);
    },
    DC_STAFF_OPTS,
);

/**
 * GET /dc/staff/attendance?date=YYYY-MM-DD
 */
export const getAttendance = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    if (!p.date) return response.badRequest('date query parameter required (YYYY-MM-DD)');
    const pk = Keys.tenantPK(auth.tenantId);
    const item = await getItem<Record<string, any>>(pk, `DC_ATTENDANCE#${p.date}`);
    if (!item) return response.success({ date: p.date, records: [] });
    return response.success(item);
}, DC_STAFF_OPTS);

// ============================================================================
// VENDORS
// ============================================================================

/**
 * GET /dc/vendors?type=&search=
 */
export const listVendors = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const [allVendors, allExpenses, allPayments] = await Promise.all([
        queryAllItems<Record<string, any>>(pk, 'DC_VENDOR#'),
        queryAllItems<Record<string, any>>(pk, 'DC_EXPENSE#'),
        queryAllItems<Record<string, any>>(pk, 'DC_VPAY#'),
    ]);

    let filtered = allVendors.filter((v: Record<string, any>) => !v.isDeleted);
    if (p.type) filtered = filtered.filter((v: Record<string, any>) => v.vendorType === p.type);
    if (p.search) {
        const q = p.search.toLowerCase();
        filtered = filtered.filter((v: Record<string, any>) =>
            (v.name || '').toLowerCase().includes(q) ||
            (v.phone || '').includes(q)
        );
    }

    // Calculate totals for each vendor
    const vendorsWithTotals = filtered.map((v: Record<string, any>) => {
        const vendorExpenses = allExpenses.filter((e: Record<string, any>) => e.paidTo === v.name && !e.isDeleted);
        const vendorPayments = allPayments.filter((p: Record<string, any>) => p.vendorId === v.id);
        const totalExpensePaisa = vendorExpenses.reduce((s: number, e: Record<string, any>) => s + (e.amountPaisa || 0), 0);
        const totalPaidPaisa = vendorPayments.reduce((s: number, p: Record<string, any>) => s + (p.amountPaisa || 0), 0);
        const totalDuePaisa = Math.max(0, totalExpensePaisa - totalPaidPaisa);
        return {
            ...v,
            totalPaidPaisa,
            totalDuePaisa,
            totalExpensePaisa,
        };
    });

    vendorsWithTotals.sort((a: Record<string, any>, b: Record<string, any>) => (a.name || '').localeCompare(b.name || ''));
    return response.success(vendorsWithTotals);
}, DC_OPTS);

/**
 * POST /dc/vendors
 */
export const createVendor = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { name, phone, email, vendorType, address, gstin, notes, rating = 0 } = body;
        if (!name || !phone || !vendorType) return response.badRequest('name, phone, vendorType required');

        const id = uid();
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk, SK: Keys.dcVendorSK(id),
            id, name, phone, email, vendorType, address, gstin, notes,
            isDeleted: false, totalEventsServed: 0,
            totalPaidPaisa: 0, totalDuePaisa: 0,
            rating: Number(rating),
            ratingCount: 0,
            createdAt: ts, updatedAt: ts,
        };
        await putItem(item);
        return response.success(item, 201);
    },
    DC_OPTS,
);

/**
 * PUT /dc/vendors/{id}
 */
export const updateVendor = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Vendor ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcVendorSK(id));
        if (!existing || existing.isDeleted) return response.notFound('Vendor not found');

        const allowed = ['name', 'phone', 'email', 'vendorType', 'address', 'gstin', 'notes', 'rating'];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }
        await updateItem(pk, Keys.dcVendorSK(id), { updateExpression: `SET ${exprParts.join(', ')}`, expressionAttributeNames: names, expressionAttributeValues: values });
        return response.success({ ...existing, ...updates });
    },
    DC_OPTS,
);

/**
 * DELETE /dc/vendors/{id}  (soft delete)
 */
export const deleteVendor = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Vendor ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, Keys.dcVendorSK(id));
        if (!existing) return response.notFound('Vendor not found');
        await updateItem(pk, Keys.dcVendorSK(id), { updateExpression: 'SET #isDeleted = :v, #updatedAt = :ts', expressionAttributeNames: { '#isDeleted': 'isDeleted', '#updatedAt': 'updatedAt' }, expressionAttributeValues: { ':v': true, ':ts': now() } });
        return response.success({ deleted: true, id });
    },
    DC_OPTS,
);

// ============================================================================
// INVENTORY
// ============================================================================

/**
 * GET /dc/inventory?category=&lowStock=true
 */
export const listInventory = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_INV#');

    let filtered = allItems.filter((i: Record<string, any>) => !i.isDeleted);
    if (p.category) filtered = filtered.filter((i: Record<string, any>) => i.category === p.category);
    if (p.lowStock === 'true') {
        filtered = filtered.filter((i: Record<string, any>) => (i.currentStock || 0) <= (i.reorderPoint || 0));
    }
    filtered.sort((a: Record<string, any>, b: Record<string, any>) => (a.name || '').localeCompare(b.name || ''));
    return response.success(filtered);
}, DC_INV_OPTS);

/**
 * POST /dc/inventory
 */
export const createInventoryItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { name, category, unit, currentStock = 0, reorderPoint = 5, costPaisaPerUnit = 0, description } = body;
        if (!name || !category || !unit) return response.badRequest('name, category, unit required');

        const id = uid();
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk, SK: Keys.dcInventorySK(id),
            id, name, category, unit, description,
            currentStock: Number(currentStock),
            reorderPoint: Number(reorderPoint),
            costPaisaPerUnit: Number(costPaisaPerUnit),
            isDeleted: false,
            createdAt: ts, updatedAt: ts,
        };
        await putItem(item);
        return response.success(item, 201);
    },
    DC_INV_OPTS,
);

/**
 * PUT /dc/inventory/{id}
 */
export const updateInventoryItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Item ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcInventorySK(id));
        if (!existing || existing.isDeleted) return response.notFound('Inventory item not found');

        const allowed = ['name', 'category', 'unit', 'description', 'currentStock', 'reorderPoint', 'costPaisaPerUnit'];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }
        await updateItem(pk, Keys.dcInventorySK(id), { updateExpression: `SET ${exprParts.join(', ')}`, expressionAttributeNames: names, expressionAttributeValues: values });
        return response.success({ ...existing, ...updates });
    },
    DC_INV_OPTS,
);

/**
 * DELETE /dc/inventory/{id}  (soft delete)
 */
export const deleteInventoryItem = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Item ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, Keys.dcInventorySK(id));
        if (!existing) return response.notFound('Inventory item not found');
        await updateItem(pk, Keys.dcInventorySK(id), { updateExpression: 'SET #isDeleted = :v, #updatedAt = :ts', expressionAttributeNames: { '#isDeleted': 'isDeleted', '#updatedAt': 'updatedAt' }, expressionAttributeValues: { ':v': true, ':ts': now() } });
        return response.success({ deleted: true, id });
    },
    DC_INV_OPTS,
);

// ============================================================================
// INVOICES / BILLING
// ============================================================================

/**
 * GET /dc/invoices?eventId=&status=&search=&invoiceNumber=&page=&limit=
 */
export const listInvoices = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_INVOICE#');

    let filtered = allItems;
    if (p.eventId) filtered = filtered.filter((i: Record<string, any>) => i.eventId === p.eventId);
    if (p.status) filtered = filtered.filter((i: Record<string, any>) => i.status === p.status);
    if (p.invoiceNumber) {
        const inv = p.invoiceNumber.trim().toLowerCase();
        filtered = filtered.filter((i: Record<string, any>) =>
            (i.invoiceNumber || '').toLowerCase().includes(inv),
        );
    }
    if (p.search) {
        const q = p.search.trim().toLowerCase();
        filtered = filtered.filter((i: Record<string, any>) =>
            (i.customerName || '').toLowerCase().includes(q) ||
            (i.customerPhone || '').toLowerCase().includes(q) ||
            (i.invoiceNumber || '').toLowerCase().includes(q),
        );
    }
    filtered.sort((a: Record<string, any>, b: Record<string, any>) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    const total = filtered.length;
    const paged = filtered.slice((page - 1) * limit, page * limit);
    return response.paginated(paged, total, page, limit);
}, DC_BILLING_OPTS);

/**
 * POST /dc/invoices
 */
export const createInvoice = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const {
            eventId, customerName, customerPhone, lineItems = [],
            advancePaidPaisa = 0, discountPaisa = 0, gstPercent = 18, notes,
        } = body;

        if (!eventId || !customerName || lineItems.length === 0) {
            return response.badRequest('eventId, customerName, lineItems required');
        }

        const subtotalPaisa: number = (lineItems as any[]).reduce(
            (sum: number, li: any) => sum + (Number(li.unitPricePaisa) * Number(li.quantity || 1)), 0
        );
        const taxableAmountPaisa = subtotalPaisa - Number(discountPaisa);
        const gstAmountPaisa = Math.round(taxableAmountPaisa * Number(gstPercent) / 100);
        const totalPaisa = taxableAmountPaisa + gstAmountPaisa;
        const balancePaisa = totalPaisa - Number(advancePaidPaisa);

        const id = uid();
        const invoiceNumber = `DC-${new Date().getFullYear()}-${id.substring(0, 6)}`;
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);

        const item = {
            PK: pk, SK: Keys.dcInvoiceSK(id),
            id, invoiceNumber, eventId, customerName, customerPhone,
            lineItems, subtotalPaisa, taxableAmountPaisa,
            gstPercent: Number(gstPercent),
            gstAmountPaisa, discountPaisa: Number(discountPaisa),
            totalPaisa, advancePaidPaisa: Number(advancePaidPaisa),
            balancePaisa, notes,
            status: balancePaisa <= 0 ? 'paid' : 'partial',
            createdAt: ts, updatedAt: ts,
            createdBy: auth.sub,
        };

        await putItem(item);
        logger.info('DC invoice created', { tenantId: auth.tenantId, invoiceId: id, totalPaisa });

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.DC_INVOICE_CREATED,
            { invoiceId: id, invoiceNumber, eventId, customerName, totalPaisa, status: item.status },
        ).catch(() => { /* non-critical */ });

        // UNS canonical emit (T-DC-3: billing.dc.invoice.created)
        emitUnsEvent({
            eventName: 'billing.dc.invoice.created',
            category: 'billing',
            subCategory: 'dc_invoice',
            priority: 'normal',
            actorId: auth.sub,
            targetId: id,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                invoiceId: id,
                invoiceNumber,
                eventId,
                customerName,
                totalPaisa,
                status: item.status,
            },
            sourceModule: 'my-backend/src/handlers/dc.ts',
            dedupScopeFields: ['invoiceId'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success(item, 201);
    },
    DC_BILLING_OPTS,
);

/**
 * PUT /dc/invoices/{id}/payment  — record a payment against the invoice
 */
export const recordPayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Invoice ID required');
        const body = parseBody<Record<string, any>>(event);
        const { amountPaisa, paymentMode = 'cash', reference } = body;
        if (!amountPaisa || Number(amountPaisa) <= 0) return response.badRequest('amountPaisa > 0 required');

        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcInvoiceSK(id));
        if (!existing) return response.notFound('Invoice not found');

        const newAdvance = (existing.advancePaidPaisa || 0) + Number(amountPaisa);
        const newBalance = (existing.totalPaisa || 0) - newAdvance;
        const newStatus = newBalance <= 0 ? 'paid' : 'partial';

        await updateItem(pk, Keys.dcInvoiceSK(id), {
            updateExpression: 'SET #adv = :adv, #bal = :bal, #st = :st, #updatedAt = :ts',
            expressionAttributeNames: { '#adv': 'advancePaidPaisa', '#bal': 'balancePaisa', '#st': 'status', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':adv': newAdvance, ':bal': newBalance, ':st': newStatus, ':ts': now() },
        });

        // Broadcast payment received
        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.DC_PAYMENT_RECEIVED,
            { invoiceId: id, eventId: existing.eventId, amountPaisa, paymentMode, newStatus, newBalance },
        ).catch(() => { /* non-critical */ });

        // UNS canonical emit (T-DC-4: payment.dc.received — invoice-level payment)
        emitUnsEvent({
            eventName: 'payment.dc.received',
            category: 'payments',
            subCategory: 'dc',
            priority: 'normal',
            actorId: auth.sub,
            targetId: id,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                invoiceId: id,
                eventId: existing.eventId,
                amountPaisa: Number(amountPaisa),
                paymentMode,
                newStatus,
                newBalance,
            },
            sourceModule: 'my-backend/src/handlers/dc.ts',
            dedupScopeFields: ['invoiceId', 'amountPaisa'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success({
            id, advancePaidPaisa: newAdvance, balancePaisa: newBalance,
            status: newStatus, paymentMode, reference,
        });
    },
    DC_BILLING_OPTS,
);

// ============================================================================
// EXPENSES
// ============================================================================

/**
 * GET /dc/expenses?eventId=&from=&to=&page=&limit=
 */
export const listExpenses = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '30', 10), 100);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_EXPENSE#');

    let filtered = allItems;
    if (p.eventId) filtered = filtered.filter((e: Record<string, any>) => e.eventId === p.eventId);
    if (p.from) { const from = p.from; filtered = filtered.filter((e: Record<string, any>) => (e.date || '') >= from); }
    if (p.to) { const to = p.to; filtered = filtered.filter((e: Record<string, any>) => (e.date || '') <= to); }
    filtered.sort((a: Record<string, any>, b: Record<string, any>) => (b.date || '').localeCompare(a.date || ''));
    const total = filtered.length;
    const paged = filtered.slice((page - 1) * limit, page * limit);
    return response.paginated(paged, total, page, limit);
}, DC_REPORTS_OPTS);

/**
 * POST /dc/expenses
 */
export const createExpense = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { eventId, category, description, amountPaisa, date, paidTo, paymentMode = 'cash' } = body;
        if (!category || !amountPaisa || !date) return response.badRequest('category, amountPaisa, date required');

        const id = uid();
        const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const item = {
            PK: pk, SK: Keys.dcExpenseSK(id),
            id, eventId, category, description,
            amountPaisa: Number(amountPaisa),
            date, paidTo, paymentMode,
            createdAt: ts, updatedAt: ts, createdBy: auth.sub,
        };
        await putItem(item);

        // Broadcast expense added
        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.DC_EXPENSE_ADDED,
            { expenseId: id, eventId, category, amountPaisa, date, paidTo },
        ).catch(() => { /* non-critical */ });

        // UNS canonical emit (T-DC-5: payment.dc.expense.added)
        emitUnsEvent({
            eventName: 'payment.dc.expense.added',
            category: 'payments',
            subCategory: 'dc_expense',
            priority: 'low',
            actorId: auth.sub,
            targetId: id,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                expenseId: id,
                eventId: eventId ?? null,
                category,
                amountPaisa: Number(amountPaisa),
                date,
                paidTo: paidTo ?? null,
            },
            sourceModule: 'my-backend/src/handlers/dc.ts',
            dedupScopeFields: ['expenseId'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success(item, 201);
    },
    DC_REPORTS_OPTS,
);

/**
 * GET /dc/expenses/{id}
 */
export const getExpense = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Expense ID required');
    const pk = Keys.tenantPK(auth.tenantId);
    const item = await getItem(pk, Keys.dcExpenseSK(id));
    if (!item) return response.notFound('Expense not found');
    return response.success(item);
}, DC_REPORTS_OPTS);

/**
 * PUT /dc/expenses/{id}
 */
export const updateExpense = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Expense ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcExpenseSK(id));
        if (!existing) return response.notFound('Expense not found');

        const allowed = ['eventId', 'category', 'description', 'amountPaisa', 'date', 'paidTo', 'paymentMode'];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

        const exprParts: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) {
            exprParts.push(`#${k} = :${k}`);
            names[`#${k}`] = k;
            values[`:${k}`] = v;
        }
        await updateItem(pk, Keys.dcExpenseSK(id), { updateExpression: `SET ${exprParts.join(', ')}`, expressionAttributeNames: names, expressionAttributeValues: values });
        return response.success({ ...existing, ...updates });
    },
    DC_REPORTS_OPTS,
);

/**
 * DELETE /dc/expenses/{id}
 */
export const deleteExpense = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Expense ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, Keys.dcExpenseSK(id));
        if (!existing) return response.notFound('Expense not found');
        await deleteItem(pk, Keys.dcExpenseSK(id));
        return response.success({ deleted: true, id });
    },
    DC_REPORTS_OPTS,
);

// ============================================================================
// DASHBOARD / REPORTS
// ============================================================================

/**
 * GET /dc/dashboard?from=YYYY-MM-DD&to=YYYY-MM-DD
 * Returns KPIs: upcoming events, revenue this month, collections, top event types,
 * activeStaff, lowStockAlerts, todayEvents, revenueByMonth (last 6 months)
 */
export const getDashboard = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    // Date range filtering
    const today = new Date().toISOString().substring(0, 10);
    const from = p.from || today.substring(0, 7) + '-01'; // Default to month start
    const to = p.to || today;

    const [events, invoices, expenses, staff, inventory] = await Promise.all([
        queryAllItems<Record<string, any>>(pk, 'DC_EVENT#'),
        queryAllItems<Record<string, any>>(pk, 'DC_INVOICE#'),
        queryAllItems<Record<string, any>>(pk, 'DC_EXPENSE#'),
        queryAllItems<Record<string, any>>(pk, 'DC_STAFF#'),
        queryAllItems<Record<string, any>>(pk, 'DC_INV#'),
    ]);

    // Filter by date range
    const filteredEvents = events.filter((e: Record<string, any>) => e.eventDate >= from && e.eventDate <= to);
    const filteredInvoices = invoices.filter((i: Record<string, any>) => (i.createdAt || '').substring(0, 10) >= from && (i.createdAt || '').substring(0, 10) <= to);
    const filteredExpenses = expenses.filter((e: Record<string, any>) => (e.date || '') >= from && (e.date || '') <= to);

    const upcomingEvents = events
        .filter((e: Record<string, any>) => e.eventDate >= today && e.status !== 'cancelled')
        .sort((a: Record<string, any>, b: Record<string, any>) => a.eventDate.localeCompare(b.eventDate))
        .slice(0, 10);

    const todayEvents = events.filter((e: Record<string, any>) => e.eventDate === today && e.status !== 'cancelled').length;

    const revenueThisMonthPaisa = filteredInvoices.reduce((s: number, i: Record<string, any>) => s + (i.totalPaisa || 0), 0);
    const collectedThisMonthPaisa = filteredInvoices.reduce((s: number, i: Record<string, any>) => s + (i.advancePaidPaisa || 0), 0);
    const pendingBalancePaisa = invoices
        .filter((i: Record<string, any>) => i.status !== 'paid')
        .reduce((s: number, i: Record<string, any>) => s + (i.balancePaisa || 0), 0);

    const thisMonthExpensesPaisa = filteredExpenses.reduce((s: number, e: Record<string, any>) => s + (e.amountPaisa || 0), 0);

    // Revenue by month — last 6 months
    const revenueByMonth: Record<string, number> = {};
    for (let m = 5; m >= 0; m--) {
        const d = new Date(); d.setMonth(d.getMonth() - m);
        const key = d.toISOString().substring(0, 7); // YYYY-MM
        revenueByMonth[key] = 0;
    }
    for (const inv of invoices) {
        const month = (inv.createdAt || '').substring(0, 7);
        if (month in revenueByMonth) {
            revenueByMonth[month] = (revenueByMonth[month] || 0) + (inv.totalPaisa || 0);
        }
    }

    // Revenue by day — over the requested date range (max 90 days to avoid bloat)
    const revenueByDay: Record<string, number> = {};
    const startDate = new Date(from);
    const endDate = new Date(to);
    const rangeDays = Math.min(90, Math.ceil((endDate.getTime() - startDate.getTime()) / 86400000) + 1);
    for (let d = 0; d < rangeDays; d++) {
        const day = new Date(startDate); day.setDate(startDate.getDate() + d);
        revenueByDay[day.toISOString().substring(0, 10)] = 0;
    }
    for (const inv of filteredInvoices) {
        const day = (inv.createdAt || '').substring(0, 10);
        if (day in revenueByDay) {
            revenueByDay[day] = (revenueByDay[day] || 0) + (inv.totalPaisa || 0);
        }
    }

    const activeStaff = staff.filter((s: Record<string, any>) => !s.isDeleted && s.isActive).length;
    const lowStockAlerts = inventory.filter((i: Record<string, any>) => !i.isDeleted && (i.currentStock || 0) <= (i.reorderPoint || 0)).length;

    const eventTypeCounts: Record<string, number> = {};
    for (const e of filteredEvents) {
        eventTypeCounts[(e as Record<string, any>).eventType] = (eventTypeCounts[(e as Record<string, any>).eventType] || 0) + 1;
    }

    const statusCounts: Record<string, number> = {};
    for (const e of filteredEvents) {
        statusCounts[(e as Record<string, any>).status] = (statusCounts[(e as Record<string, any>).status] || 0) + 1;
    }

    return response.success({
        kpis: {
            totalEvents: filteredEvents.length,
            upcomingCount: upcomingEvents.length,
            todayEvents,
            revenueThisMonthPaisa,
            collectedThisMonthPaisa,
            pendingBalancePaisa,
            thisMonthExpensesPaisa,
            netProfitThisMonthPaisa: collectedThisMonthPaisa - thisMonthExpensesPaisa,
            activeStaff,
            lowStockAlerts,
        },
        dateRange: { from, to },
        upcomingEvents,
        revenueByMonth,
        revenueByDay,
        eventTypeCounts,
        statusCounts,
    });
}, DC_OPTS);

// ============================================================================
// QUOTATIONS
// ============================================================================

/**
 * GET /dc/quotes?status=draft|sent|accepted|rejected
 */
export const listQuotes = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_QUOTE#');
    let filtered = allItems.filter((q: Record<string, any>) => !q.isDeleted);
    if (p.status) filtered = filtered.filter((q: Record<string, any>) => q.status === p.status);
    filtered.sort((a: Record<string, any>, b: Record<string, any>) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    return response.success(filtered);
}, DC_BILLING_OPTS);

/**
 * GET /dc/quotes/{id}
 */
export const getQuote = authorizedHandler([], async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Quote ID required');
    const pk = Keys.tenantPK(auth.tenantId);
    const item = await getItem(pk, `DC_QUOTE#${id}`);
    if (!item || item.isDeleted) return response.notFound('Quote not found');
    return response.success(item);
}, DC_BILLING_OPTS);

/**
 * POST /dc/quotes
 */
export const createQuote = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const body = parseBody<Record<string, any>>(event);
        const { customerName, customerPhone, eventType, eventDate, venue, guestCount,
            lineItems = [], discountPaisa = 0, gstPercent = 18, notes, validUntil } = body;
        if (!customerName || !eventType) return response.badRequest('customerName, eventType required');

        const subtotalPaisa: number = (lineItems as any[]).reduce(
            (s: number, li: any) => s + (Number(li.unitPricePaisa || 0) * Number(li.quantity || 1)), 0
        );
        const taxableAmountPaisa = subtotalPaisa - Number(discountPaisa);
        const gstAmountPaisa = Math.round(taxableAmountPaisa * Number(gstPercent) / 100);
        const totalPaisa = taxableAmountPaisa + gstAmountPaisa;

        const id = uid(); const ts = now();
        const pk = Keys.tenantPK(auth.tenantId);
        const quoteNumber = `QT-${new Date().getFullYear()}-${id.substring(0, 6)}`;
        const item = {
            PK: pk, SK: `DC_QUOTE#${id}`,
            id, quoteNumber, customerName, customerPhone, eventType, eventDate,
            venue, guestCount: Number(guestCount || 0), lineItems,
            subtotalPaisa, taxableAmountPaisa,
            gstPercent: Number(gstPercent), gstAmountPaisa,
            discountPaisa: Number(discountPaisa), totalPaisa, notes,
            validUntil: validUntil || null,
            status: 'draft', isDeleted: false,
            createdAt: ts, updatedAt: ts, createdBy: auth.sub,
        };
        await putItem(item);
        return response.success(item, 201);
    }, DC_BILLING_OPTS,
);

/**
 * PUT /dc/quotes/{id}  — update status or convert to booking
 */
export const updateQuote = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Quote ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, `DC_QUOTE#${id}`);
        if (!existing || existing.isDeleted) return response.notFound('Quote not found');

        const allowed = ['status', 'notes', 'validUntil', 'lineItems', 'discountPaisa', 'gstPercent'];
        const updates: Record<string, any> = { updatedAt: now() };
        for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

        const exprParts: string[] = []; const names: Record<string, string> = {}; const values: Record<string, any> = {};
        for (const [k, v] of Object.entries(updates)) { exprParts.push(`#${k} = :${k}`); names[`#${k}`] = k; values[`:${k}`] = v; }
        await updateItem(pk, `DC_QUOTE#${id}`, { updateExpression: `SET ${exprParts.join(', ')}`, expressionAttributeNames: names, expressionAttributeValues: values });
        return response.success({ ...existing, ...updates });
    }, DC_BILLING_OPTS,
);

/**
 * DELETE /dc/quotes/{id}
 */
export const deleteQuote = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('Quote ID required');
        const pk = Keys.tenantPK(auth.tenantId);
        await updateItem(pk, `DC_QUOTE#${id}`, { updateExpression: 'SET #d = :v, #u = :ts', expressionAttributeNames: { '#d': 'isDeleted', '#u': 'updatedAt' }, expressionAttributeValues: { ':v': true, ':ts': now() } });
        return response.success({ deleted: true, id });
    }, DC_BILLING_OPTS,
);

// ============================================================================
// EVENT NOTES (append-only timeline)
// ============================================================================

/**
 * POST /dc/events/{id}/notes  — append a note to the event timeline
 */
export const appendEventNote = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const eventId = event.pathParameters?.id;
        if (!eventId) return response.badRequest('Event ID required');
        const body = parseBody<Record<string, any>>(event);
        const { text } = body;
        if (!text) return response.badRequest('text required');

        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, Keys.dcEventSK(eventId));
        if (!existing) return response.notFound('Event not found');

        const note = { id: uid(), text, createdAt: now(), createdBy: auth.sub };
        const existingNotes: any[] = existing.notesList || [];
        const updatedNotes = [...existingNotes, note];

        await updateItem(pk, Keys.dcEventSK(eventId), {
            updateExpression: 'SET #nl = :nl, #ua = :ts',
            expressionAttributeNames: { '#nl': 'notesList', '#ua': 'updatedAt' },
            expressionAttributeValues: { ':nl': updatedNotes, ':ts': now() },
        });
        return response.success({ note, notesList: updatedNotes });
    }, DC_OPTS,
);

// ============================================================================
// SHOPPING LIST
// ============================================================================

/**
 * GET /dc/events/{id}/shopping-list
 * Auto-generates raw material list based on guest count × catering package
 */
export const getShoppingList = authorizedHandler([], async (event, _ctx, auth) => {
    const eventId = event.pathParameters?.id;
    if (!eventId) return response.badRequest('Event ID required');
    const pk = Keys.tenantPK(auth.tenantId);
    const evt = await getItem<Record<string, any>>(pk, Keys.dcEventSK(eventId));
    if (!evt) return response.notFound('Event not found');

    const guests = evt.guestCount || 0;
    const items: Array<{ item: string; qty: number; unit: string; estimatedCostPaisa: number }> = [];

    if (evt.includesCatering && guests > 0) {
        items.push(
            { item: 'Rice', qty: Math.ceil(guests * 0.15), unit: 'kg', estimatedCostPaisa: Math.ceil(guests * 0.15) * 6000 },
            { item: 'Cooking Oil', qty: Math.ceil(guests * 0.05), unit: 'L', estimatedCostPaisa: Math.ceil(guests * 0.05) * 15000 },
            { item: 'Vegetables (Mixed)', qty: Math.ceil(guests * 0.20), unit: 'kg', estimatedCostPaisa: Math.ceil(guests * 0.20) * 4000 },
            { item: 'Dal (Lentils)', qty: Math.ceil(guests * 0.08), unit: 'kg', estimatedCostPaisa: Math.ceil(guests * 0.08) * 10000 },
            { item: 'Flour (Atta)', qty: Math.ceil(guests * 0.10), unit: 'kg', estimatedCostPaisa: Math.ceil(guests * 0.10) * 5000 },
            { item: 'Gas Cylinders', qty: Math.ceil(guests / 50) + 1, unit: 'pcs', estimatedCostPaisa: (Math.ceil(guests / 50) + 1) * 90000 },
            { item: 'Mineral Water Bottles', qty: Math.ceil(guests * 2), unit: 'bottles', estimatedCostPaisa: Math.ceil(guests * 2) * 2000 },
            { item: 'Sugar', qty: Math.ceil(guests * 0.04), unit: 'kg', estimatedCostPaisa: Math.ceil(guests * 0.04) * 4500 },
            { item: 'Spices (Mixed Pack)', qty: Math.ceil(guests / 100) + 1, unit: 'packs', estimatedCostPaisa: (Math.ceil(guests / 100) + 1) * 25000 },
            { item: 'Paper Plates & Cups', qty: Math.ceil(guests * 1.2), unit: 'sets', estimatedCostPaisa: Math.ceil(guests * 1.2) * 500 },
        );
    }
    if (evt.includesDecoration) {
        items.push(
            { item: 'Flowers (Marigold garlands)', qty: Math.ceil(guests / 20), unit: 'kg', estimatedCostPaisa: Math.ceil(guests / 20) * 20000 },
            { item: 'Balloons', qty: Math.ceil(guests * 2), unit: 'pcs', estimatedCostPaisa: Math.ceil(guests * 2) * 150 },
            { item: 'LED Candles / Diyas', qty: Math.ceil(guests / 5), unit: 'pcs', estimatedCostPaisa: Math.ceil(guests / 5) * 3000 },
        );
    }

    const totalEstimatedCostPaisa = items.reduce((s, i) => s + i.estimatedCostPaisa, 0);
    return response.success({ eventId, guestCount: guests, items, totalEstimatedCostPaisa });
}, DC_OPTS);

// ============================================================================
// EVENT PROFITABILITY
// ============================================================================

/**
 * GET /dc/events/{id}/profitability
 */
export const getEventProfitability = authorizedHandler([], async (event, _ctx, auth) => {
    const eventId = event.pathParameters?.id;
    if (!eventId) return response.badRequest('Event ID required');
    const pk = Keys.tenantPK(auth.tenantId);

    const [evt, allInvoices, allExpenses] = await Promise.all([
        getItem<Record<string, any>>(pk, Keys.dcEventSK(eventId)),
        queryAllItems<Record<string, any>>(pk, 'DC_INVOICE#'),
        queryAllItems<Record<string, any>>(pk, 'DC_EXPENSE#'),
    ]);
    if (!evt) return response.notFound('Event not found');

    const invoices = allInvoices.filter(i => i.eventId === eventId);
    const expenses = allExpenses.filter(e => e.eventId === eventId);

    const totalRevenuePaisa = invoices.reduce((s, i) => s + (i.totalPaisa || 0), 0);
    const totalCollectedPaisa = invoices.reduce((s, i) => s + (i.advancePaidPaisa || 0), 0);
    const totalExpensesPaisa = expenses.reduce((s, e) => s + (e.amountPaisa || 0), 0);
    const netProfitPaisa = totalCollectedPaisa - totalExpensesPaisa;
    const marginPct = totalRevenuePaisa > 0 ? Math.round(netProfitPaisa * 100 / totalRevenuePaisa) : 0;

    const expenseByCategory: Record<string, number> = {};
    for (const exp of expenses) {
        expenseByCategory[exp.category] = (expenseByCategory[exp.category] || 0) + (exp.amountPaisa || 0);
    }

    return response.success({
        eventId, eventTitle: evt.eventType, customerName: evt.customerName,
        guestCount: evt.guestCount, eventDate: evt.eventDate,
        totalRevenuePaisa, totalCollectedPaisa, totalExpensesPaisa, netProfitPaisa, marginPct,
        expenseByCategory, invoiceCount: invoices.length, expenseCount: expenses.length,
    });
}, DC_OPTS);

// ============================================================================
// VENDOR PAYMENTS
// ============================================================================

/**
 * POST /dc/vendors/{id}/payments  — record a payment made to a vendor
 */
export const recordVendorPayment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _ctx, auth) => {
        const vendorId = event.pathParameters?.id;
        if (!vendorId) return response.badRequest('Vendor ID required');
        const body = parseBody<Record<string, any>>(event);
        const { amountPaisa, paymentMode = 'cash', reference, eventId, notes } = body;
        if (!amountPaisa || Number(amountPaisa) <= 0) return response.badRequest('amountPaisa > 0 required');

        const pk = Keys.tenantPK(auth.tenantId);
        const vendor = await getItem<Record<string, any>>(pk, Keys.dcVendorSK(vendorId));
        if (!vendor || vendor.isDeleted) return response.notFound('Vendor not found');

        const payId = uid(); const ts = now();
        const payRecord = {
            PK: pk, SK: `DC_VPAY#${payId}`,
            id: payId, vendorId, vendorName: vendor.name,
            amountPaisa: Number(amountPaisa), paymentMode, reference, eventId, notes,
            date: ts.substring(0, 10), createdAt: ts, createdBy: auth.sub,
        };
        await putItem(payRecord);

        // update vendor totals
        const newTotalPaid = (vendor.totalPaidPaisa || 0) + Number(amountPaisa);
        await updateItem(pk, Keys.dcVendorSK(vendorId), {
            updateExpression: 'SET #tp = :tp, #updatedAt = :ts',
            expressionAttributeNames: { '#tp': 'totalPaidPaisa', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':tp': newTotalPaid, ':ts': ts },
        });
        return response.success(payRecord, 201);
    }, DC_OPTS,
);

/**
 * GET /dc/vendors/{id}/payments
 */
export const listVendorPayments = authorizedHandler([], async (event, _ctx, auth) => {
    const vendorId = event.pathParameters?.id;
    if (!vendorId) return response.badRequest('Vendor ID required');
    const pk = Keys.tenantPK(auth.tenantId);
    const allItems = await queryAllItems<Record<string, any>>(pk, 'DC_VPAY#');
    const filtered = allItems.filter((p: Record<string, any>) => p.vendorId === vendorId);
    filtered.sort((a: Record<string, any>, b: Record<string, any>) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    return response.success(filtered);
}, DC_OPTS);

/**
 * GET /dc/reports/summary?from=YYYY-MM-DD&to=YYYY-MM-DD
 */
export const getReportsSummary = authorizedHandler([], async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const from = p.from || new Date(Date.now() - 30 * 86400000).toISOString().substring(0, 10);
    const to = p.to || new Date().toISOString().substring(0, 10);
    const pk = Keys.tenantPK(auth.tenantId);

    const [allEvts, allInvs, allExps] = await Promise.all([
        queryAllItems<Record<string, any>>(pk, 'DC_EVENT#'),
        queryAllItems<Record<string, any>>(pk, 'DC_INVOICE#'),
        queryAllItems<Record<string, any>>(pk, 'DC_EXPENSE#'),
    ]);

    const events = allEvts.filter((e: Record<string, any>) => e.eventDate >= from && e.eventDate <= to);
    const invoices = allInvs.filter((i: Record<string, any>) => (i.createdAt || '').substring(0, 10) >= from && (i.createdAt || '').substring(0, 10) <= to);
    const expenses = allExps.filter((e: Record<string, any>) => e.date >= from && e.date <= to);

    const totalRevenuePaisa = invoices.reduce((s: number, i: Record<string, any>) => s + (i.totalPaisa || 0), 0);
    const totalCollectedPaisa = invoices.reduce((s: number, i: Record<string, any>) => s + (i.advancePaidPaisa || 0), 0);
    const totalExpensesPaisa = expenses.reduce((s: number, e: Record<string, any>) => s + (e.amountPaisa || 0), 0);

    const revenueByType: Record<string, number> = {};
    for (const e of events) {
        if (!revenueByType[e.eventType]) revenueByType[e.eventType] = 0;
    }
    for (const inv of invoices) {
        const evt = events.find(e => e.id === inv.eventId);
        if (evt) revenueByType[evt.eventType] = (revenueByType[evt.eventType] || 0) + (inv.totalPaisa || 0);
    }

    const expenseByCategory: Record<string, number> = {};
    for (const exp of expenses) {
        expenseByCategory[exp.category] = (expenseByCategory[exp.category] || 0) + (exp.amountPaisa || 0);
    }

    return response.success({
        from, to,
        totalEvents: events.length,
        completedEvents: events.filter(e => e.status === 'completed').length,
        totalRevenuePaisa,
        totalCollectedPaisa,
        totalExpensesPaisa,
        netProfitPaisa: totalCollectedPaisa - totalExpensesPaisa,
        revenueByType,
        expenseByCategory,
        invoiceCount: invoices.length,
        paidInvoices: invoices.filter(i => i.status === 'paid').length,
        pendingInvoices: invoices.filter(i => i.status !== 'paid').length,
    });
}, DC_REPORTS_OPTS);

// ============================================================================
// KITCHEN ORDER TICKETS (KOT)
// ============================================================================

/**
 * POST /dc/events/{id}/kot  — raise a kitchen order ticket for an event
 * Body: { items: [{ name, qty, unit?, notes? }], mealType: 'breakfast'|'lunch'|'dinner'|'snacks' }
 */
export const createKot = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const eventId = event.pathParameters?.id;
        if (!eventId) return response.badRequest('Event ID required');
        const body = parseBody<Record<string, any>>(event);
        const { items, mealType = 'lunch' } = body;
        if (!Array.isArray(items) || items.length === 0) return response.badRequest('items[] required');

        const pk = Keys.tenantPK(auth.tenantId);
        const evt = await getItem<Record<string, any>>(pk, Keys.dcEventSK(eventId));
        if (!evt) return response.notFound('Event not found');

        const id = uid();
        const ts = now();
        const kotNumber = `KOT-${new Date().toISOString().substring(0, 10).replace(/-/g, '')}-${id.substring(0, 4).toUpperCase()}`;

        const kotItems = (items as any[]).map((i: any) => ({
            id: uid(),
            name: i.name,
            qty: Number(i.qty || 1),
            unit: i.unit || 'portion',
            notes: i.notes || '',
            status: 'pending',
        }));

        const item = {
            PK: pk, SK: `DC_KOT#${id}`,
            id, kotNumber, eventId,
            customerName: evt.customerName, eventDate: evt.eventDate,
            guestCount: evt.guestCount,
            mealType, items: kotItems,
            status: 'pending',
            createdAt: ts, updatedAt: ts, createdBy: auth.sub,
        };
        await putItem(item);
        logger.info('DC KOT created', { tenantId: auth.tenantId, kotId: id, eventId });

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.DC_KOT_CREATED,
            { kotId: id, kotNumber, eventId, mealType, itemCount: kotItems.length },
        ).catch(() => { /* non-critical */ });

        // UNS canonical emit (T-DC-8a: orders.dc_kot.created)
        emitUnsEvent({
            eventName: 'orders.dc_kot.created',
            category: 'orders',
            subCategory: 'dc_kot',
            priority: 'normal',
            actorId: auth.sub,
            targetId: id,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                kotId: id,
                kotNumber,
                eventId,
                mealType,
                itemCount: kotItems.length,
            },
            sourceModule: 'my-backend/src/handlers/dc.ts',
            dedupScopeFields: ['kotId'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success(item, 201);
    },
    DC_OPTS,
);

/**
 * GET /dc/events/{id}/kot  — list all KOTs for an event
 */
export const listKots = authorizedHandler([], async (event, _ctx, auth) => {
    const eventId = event.pathParameters?.id;
    if (!eventId) return response.badRequest('Event ID required');
    const pk = Keys.tenantPK(auth.tenantId);
    const allKots = await queryAllItems<Record<string, any>>(pk, 'DC_KOT#');
    const filtered = allKots
        .filter((k: Record<string, any>) => k.eventId === eventId)
        .sort((a: Record<string, any>, b: Record<string, any>) => (b.createdAt || '').localeCompare(a.createdAt || ''));
    return response.success(filtered);
}, DC_OPTS);

/**
 * PUT /dc/kot/{id}  — update KOT or individual item status
 * Body: { status?: 'pending'|'preparing'|'ready'|'served'|'cancelled', itemId?, itemStatus? }
 */
export const updateKot = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event, _ctx, auth) => {
        const id = event.pathParameters?.id;
        if (!id) return response.badRequest('KOT ID required');
        const body = parseBody<Record<string, any>>(event);
        const pk = Keys.tenantPK(auth.tenantId);

        const existing = await getItem<Record<string, any>>(pk, `DC_KOT#${id}`);
        if (!existing) return response.notFound('KOT not found');

        const validKotStatuses = ['pending', 'preparing', 'ready', 'served', 'cancelled'];
        const validItemStatuses = ['pending', 'preparing', 'ready', 'served'];

        let updatedItems = existing.items as any[];

        // Update a single item status
        if (body.itemId && body.itemStatus) {
            if (!validItemStatuses.includes(body.itemStatus)) return response.badRequest(`itemStatus must be one of: ${validItemStatuses.join(', ')}`);
            updatedItems = updatedItems.map((i: any) =>
                i.id === body.itemId ? { ...i, status: body.itemStatus } : i,
            );
        }

        // Derive KOT-level status from items if not explicitly set
        let kotStatus = body.status || existing.status;
        if (!body.status) {
            const allServed = updatedItems.every((i: any) => i.status === 'served');
            const anyPreparing = updatedItems.some((i: any) => i.status === 'preparing');
            const anyReady = updatedItems.some((i: any) => i.status === 'ready');
            if (allServed) kotStatus = 'served';
            else if (anyReady) kotStatus = 'ready';
            else if (anyPreparing) kotStatus = 'preparing';
        } else {
            if (!validKotStatuses.includes(kotStatus)) return response.badRequest(`status must be one of: ${validKotStatuses.join(', ')}`);
        }

        await updateItem(pk, `DC_KOT#${id}`, {
            updateExpression: 'SET #items = :items, #status = :status, #updatedAt = :ts',
            expressionAttributeNames: { '#items': 'items', '#status': 'status', '#updatedAt': 'updatedAt' },
            expressionAttributeValues: { ':items': updatedItems, ':status': kotStatus, ':ts': now() },
        });

        wsService.broadcastToClientType(
            auth.tenantId,
            ClientType.DESKTOP_APP,
            WSEventName.DC_KOT_UPDATED,
            { kotId: id, eventId: existing.eventId, kotStatus, itemId: body.itemId, itemStatus: body.itemStatus },
        ).catch(() => { /* non-critical */ });

        // UNS canonical emit (T-DC-8b: orders.dc_kot.updated)
        emitUnsEvent({
            eventName: 'orders.dc_kot.updated',
            category: 'orders',
            subCategory: 'dc_kot',
            priority: 'normal',
            actorId: auth.sub,
            targetId: id,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                kotId: id,
                eventId: existing.eventId,
                kotStatus,
                itemId: body.itemId ?? null,
                itemStatus: body.itemStatus ?? null,
            },
            sourceModule: 'my-backend/src/handlers/dc.ts',
            dedupScopeFields: ['kotId', 'kotStatus', 'itemId', 'itemStatus'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success({ ...existing, items: updatedItems, status: kotStatus, updatedAt: now() });
    },
    DC_OPTS,
);


