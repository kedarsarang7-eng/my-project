// ============================================================================
// Lambda Handler — Book Store Module (DynamoDB)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, queryItems, putItem, getItem, updateItem } from '../config/dynamodb.config';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { createBookReturnSchema } from '../schemas';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import { recordRevision } from '../services/revision-history.service';

const BOOK_STORE_OPTS = { requiredBusinessType: BusinessType.BOOK_STORE, requiredFeature: FeatureKey.BOOKSTORE_ISBN_MANUAL };
const BOOK_STORE_ISBN_OPTS = {
    requiredBusinessType: BusinessType.BOOK_STORE,
    requiredFeature: FeatureKey.BOOKSTORE_ISBN_AUTOFILL,
};
const BOOK_STORE_INSTITUTIONAL_OPTS = {
    requiredBusinessType: BusinessType.BOOK_STORE,
    requiredFeature: FeatureKey.BOOKSTORE_INSTITUTIONAL_SALES,
};
const BOOK_STORE_CONSIGNMENT_OPTS = {
    requiredBusinessType: BusinessType.BOOK_STORE,
    requiredFeature: FeatureKey.BOOKSTORE_CONSIGNMENT_SETTLEMENT,
};

function normalizeIsbn(raw: string): string {
    return raw.replace(/[-\s]/g, '').toUpperCase();
}

function isValidIsbn(value: string): boolean {
    return /^(?:\d{13}|\d{9}[\dX])$/.test(normalizeIsbn(value));
}

/**
 * GET /book-store/books?search=&category=&lowStock=true&page=1&limit=20
 */
export const getBooks = authorizedHandler([], async (event, _context, auth) => {
    const params = event.queryStringParameters || {};
    const page = parseInt(params.page || '1', 10);
    const limit = Math.min(parseInt(params.limit || '20', 10), 100);
    const pk = Keys.tenantPK(auth.tenantId);

    const products = await queryItems<Record<string, any>>(pk, 'PRODUCT#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
    });

    let items = products.items;

    if (params.search) {
        const s = params.search.toLowerCase();
        items = items.filter(i =>
            (i.name || '').toLowerCase().includes(s) ||
            (i.isbn || '').toLowerCase().includes(s) ||
            (i.author || '').toLowerCase().includes(s) ||
            (i.publisher || '').toLowerCase().includes(s)
        );
    }
    if (params.category) {
        items = items.filter(i => i.category === params.category);
    }
    if (params.lowStock === 'true') {
        items = items.filter(i => (Number(i.currentStock) || 0) <= (Number(i.lowStockThreshold) || 0));
    }

    items.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
    const total = items.length;
    const offset = (page - 1) * limit;
    const paged = items.slice(offset, offset + limit).map(i => ({
        id: i.id, name: i.name, isbn: i.isbn, author: i.author, publisher: i.publisher,
        category: i.category, salePriceCents: i.salePriceCents, currentStock: i.currentStock,
        lowStockThreshold: i.lowStockThreshold, createdAt: i.createdAt, updatedAt: i.updatedAt,
    }));

    return response.paginated(paged, total, page, limit);
}, BOOK_STORE_OPTS);

/**
 * GET /book-store/low-stock
 */
export const getLowStockBooks = authorizedHandler([], async (_event, _context, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const products = await queryItems<Record<string, any>>(pk, 'PRODUCT#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
    });

    const lowStock = products.items
        .filter(i => (Number(i.currentStock) || 0) <= (Number(i.lowStockThreshold) || 0))
        .sort((a, b) => (Number(a.currentStock) || 0) - (Number(b.currentStock) || 0))
        .slice(0, 50)
        .map(i => ({
            id: i.id, name: i.name, isbn: i.isbn, author: i.author, publisher: i.publisher,
            currentStock: i.currentStock, lowStockThreshold: i.lowStockThreshold,
        }));

    return response.success(lowStock);
}, BOOK_STORE_OPTS);

/**
 * POST /book-store/returns — Publisher return
 */
export const createBookReturn = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        // SECURITY FIX S-7: Validate input with Zod schema
        const body = JSON.parse(event.body || '{}');
        const validated = createBookReturnSchema.parse(body);

        const totalAmount = validated.items.reduce((sum: number, item) => sum + (item.qty || 0) * (item.price || 0), 0);
        const now = new Date().toISOString();
        const returnId = crypto.randomUUID();

        const item = {
            PK: Keys.tenantPK(auth.tenantId),
            SK: `BOOKRETURN#${returnId}`,
            entityType: 'BOOK_RETURN',
            id: returnId, tenantId: auth.tenantId,
            vendorId: validated.vendorId, vendorName: validated.vendorName || null,
            returnDate: validated.returnDate || now.slice(0, 10),
            status: 'draft', items: validated.items, totalAmount,
            notes: validated.notes || null, isDeleted: false,
            createdAt: now, updatedAt: now,
        };

        await putItem(item);
        await recordRevision(
            auth.tenantId,
            'book_returns',
            returnId,
            'create',
            auth.sub,
            null,
            {
                id: returnId,
                vendorId: validated.vendorId,
                status: 'draft',
                itemCount: validated.items.length,
                totalAmount,
            },
            { source: 'book_store.createBookReturn' },
        );
        logger.info('Book return created', { tenantId: auth.tenantId, returnId, itemCount: validated.items.length });
        return response.success(item, 201);
    }, BOOK_STORE_OPTS);

/**
 * GET /book-store/returns?status=draft&page=1&limit=20
 */
export const listBookReturns = authorizedHandler([], async (event, _context, auth) => {
    const params = event.queryStringParameters || {};
    const page = parseInt(params.page || '1', 10);
    const limit = Math.min(parseInt(params.limit || '20', 10), 100);
    const pk = Keys.tenantPK(auth.tenantId);

    const returns = await queryItems<Record<string, any>>(pk, 'BOOKRETURN#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
    });

    let items = returns.items;
    if (params.status) items = items.filter(i => i.status === params.status);
    items.sort((a, b) => (b.returnDate || '').localeCompare(a.returnDate || ''));

    const total = items.length;
    const offset = (page - 1) * limit;
    const paged = items.slice(offset, offset + limit);

    return response.paginated(paged, total, page, limit);
}, BOOK_STORE_OPTS);

/**
 * GET /book-store/customer-loyalty?phone=9876543210
 */
export const customerLoyaltyLookup = authorizedHandler([], async (event, _context, auth) => {
    const phone = event.queryStringParameters?.phone;
    if (!phone) return response.badRequest('Missing required query parameter: phone');

    const pk = Keys.tenantPK(auth.tenantId);
    const customers = await queryItems<Record<string, any>>(pk, 'CUSTOMER#', {
        filterExpression: 'phone = :phone AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':phone': phone, ':false': false },
        limit: 1,
    });

    if (customers.items.length === 0) return response.notFound('Customer');

    const c = customers.items[0];
    return response.success({
        id: c.id, name: c.name, phone: c.phone,
        loyaltyPoints: c.loyaltyPoints || 0,
        totalBilled: c.totalBilled || 0, totalPaid: c.totalPaid || 0,
    });
}, BOOK_STORE_OPTS);

/**
 * GET /book-store/isbn/{isbn} — ISBN scan auto-fill lookup
 */
export const lookupBookByIsbn = authorizedHandler([], async (event, _context, auth) => {
    const rawIsbn = event.pathParameters?.isbn || '';
    if (!rawIsbn) return response.badRequest('Missing ISBN');

    const isbn = normalizeIsbn(rawIsbn);
    if (!isValidIsbn(isbn)) {
        return response.badRequest('Invalid ISBN-10/ISBN-13 format');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    const books = await queryItems<Record<string, any>>(pk, 'PRODUCT#', {
        filterExpression: 'isbn = :isbn AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':isbn': isbn, ':false': false },
        limit: 1,
    });

    if (books.items.length === 0) {
        return response.notFound('Book');
    }

    const b = books.items[0];
    return response.success({
        id: b.id,
        isbn: b.isbn,
        name: b.name,
        author: b.author,
        publisher: b.publisher,
        brand: b.brand,
        category: b.category,
        subcategory: b.subcategory,
        salePriceCents: b.salePriceCents,
        mrpCents: b.mrpCents,
        purchasePriceCents: b.purchasePriceCents,
        currentStock: b.currentStock,
        lowStockThreshold: b.lowStockThreshold,
        hsnCode: b.hsnCode,
        autoFill: {
            itemName: b.name,
            itemLabel: 'Book',
            unit: b.unit || 'pcs',
        },
    });
}, BOOK_STORE_ISBN_OPTS);

/**
 * POST /book-store/institutional-orders — Bulk institutional order cycle
 */
export const createInstitutionalOrder = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const body = JSON.parse(event.body || '{}');
        const validated = (await import('../schemas')).createInstitutionalOrderSchema.parse(body);

        const now = new Date().toISOString();
        const orderId = crypto.randomUUID();
        const totalAmount = validated.items.reduce((sum: number, item: any) => sum + (item.qty || 0) * (item.price || 0), 0);

        const item = {
            PK: Keys.tenantPK(auth.tenantId),
            SK: `INSTORDER#${orderId}`,
            entityType: 'INSTITUTIONAL_ORDER',
            id: orderId,
            tenantId: auth.tenantId,
            institutionName: validated.institutionName,
            contactPerson: validated.contactPerson || null,
            contactPhone: validated.contactPhone || null,
            dueDate: validated.dueDate || null,
            items: validated.items,
            totalAmount,
            notes: validated.notes || null,
            status: 'pending',
            createdAt: now,
            updatedAt: now,
        };

        await putItem(item);
        await recordRevision(
            auth.tenantId,
            'book_institutional_orders',
            orderId,
            'create',
            auth.sub,
            null,
            {
                id: orderId,
                institutionName: validated.institutionName,
                status: 'pending',
                itemCount: validated.items.length,
                totalAmount,
            },
            { source: 'book_store.createInstitutionalOrder' },
        );
        logger.info('Institutional order created', { tenantId: auth.tenantId, orderId, itemCount: validated.items.length });
        return response.success(item, 201);
    },
    BOOK_STORE_INSTITUTIONAL_OPTS,
);

/**
 * POST /book-store/consignments — Create a consignment intake record
 */
export const createConsignment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const body = JSON.parse(event.body || '{}');
        const validated = (await import('../schemas')).createConsignmentSchema.parse(body);

        const now = new Date().toISOString();
        const consignmentId = crypto.randomUUID();
        const totalAmount = validated.items.reduce((sum: number, item: any) => sum + (item.qty || 0) * (item.price || 0), 0);

        const item = {
            PK: Keys.tenantPK(auth.tenantId),
            SK: `CONSIGNMENT#${consignmentId}`,
            entityType: 'CONSIGNMENT',
            id: consignmentId,
            tenantId: auth.tenantId,
            vendorId: validated.vendorId,
            vendorName: validated.vendorName || null,
            receivedDate: validated.receivedDate || now.slice(0, 10),
            items: validated.items,
            totalAmount,
            notes: validated.notes || null,
            status: 'open',
            createdAt: now,
            updatedAt: now,
        };

        await putItem(item);
        await recordRevision(
            auth.tenantId,
            'book_consignments',
            consignmentId,
            'create',
            auth.sub,
            null,
            {
                id: consignmentId,
                vendorId: validated.vendorId,
                status: 'open',
                itemCount: validated.items.length,
                totalAmount,
            },
            { source: 'book_store.createConsignment' },
        );
        logger.info('Consignment created', { tenantId: auth.tenantId, consignmentId, itemCount: validated.items.length });
        return response.success(item, 201);
    },
    BOOK_STORE_CONSIGNMENT_OPTS,
);

/**
 * POST /book-store/consignments/{id}/settlement — Settle a consignment cycle
 */
export const settleConsignment = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const consignmentId = event.pathParameters?.id;
        if (!consignmentId) return response.badRequest('Missing consignment id');

        const body = JSON.parse(event.body || '{}');
        const validated = (await import('../schemas')).createConsignmentSettlementSchema.parse(body);
        const pk = Keys.tenantPK(auth.tenantId);
        const now = validated.settlementDate || new Date().toISOString().slice(0, 10);

        const consignment = await getItem<Record<string, any>>(pk, `CONSIGNMENT#${consignmentId}`);
        if (!consignment) return response.notFound('Consignment');

        const settlementId = crypto.randomUUID();
        const settlement = {
            PK: pk,
            SK: `CONSIGNMENTSETTLE#${settlementId}`,
            entityType: 'CONSIGNMENT_SETTLEMENT',
            id: settlementId,
            tenantId: auth.tenantId,
            consignmentId,
            vendorId: consignment.vendorId,
            soldQty: validated.soldQty,
            returnedQty: validated.returnedQty,
            settlementAmount: validated.settlementAmount,
            notes: validated.notes || null,
            settlementDate: now,
            createdAt: new Date().toISOString(),
        };

        await putItem(settlement);
        await updateItem(pk, `CONSIGNMENT#${consignmentId}`, {
            updateExpression: 'SET #s = :settled, settlementId = :settlementId, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: {
                ':settled': 'settled',
                ':settlementId': settlementId,
                ':now': new Date().toISOString(),
            },
        });
        await recordRevision(
            auth.tenantId,
            'book_consignments',
            consignmentId,
            'status_change',
            auth.sub,
            { status: consignment.status || null, settlementId: consignment.settlementId || null },
            { status: 'settled', settlementId },
            { source: 'book_store.settleConsignment' },
        );

        return response.success({ message: 'Consignment settled', settlementId }, 201);
    },
    BOOK_STORE_CONSIGNMENT_OPTS,
);

/**
 * GET /books/school-orders
 */
export const getSchoolOrders = authorizedHandler([], async (event, _context, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    
    const orders = await queryItems<Record<string, any>>(pk, 'INSTORDER#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
    });

    const items = orders.items.map(o => ({
        id: o.id,
        schoolName: o.institutionName,
        grade: o.grade || 'General',
        totalSets: o.totalSets || (o.items ? o.items.length : 1),
        fulfilledSets: o.fulfilledSets || 0,
        status: o.status,
    }));

    return response.success({ orders: items });
}, BOOK_STORE_INSTITUTIONAL_OPTS);

/**
 * POST /books/school-orders/{id}/fulfill
 */
export const fulfillSchoolOrder = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const orderId = event.pathParameters?.id;
        if (!orderId) return response.badRequest('Missing order id');

        const body = JSON.parse(event.body || '{}');
        const validated = (await import('../schemas/mobile.schema')).fulfillSchoolOrderSchema.parse(body);

        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem<Record<string, any>>(pk, `INSTORDER#${orderId}`);
        if (!existing) return response.notFound('Order');
        await updateItem(pk, `INSTORDER#${orderId}`, {
            updateExpression: 'ADD fulfilledSets :sets SET updatedAt = :now',
            expressionAttributeValues: {
                ':sets': validated.sets,
                ':now': new Date().toISOString(),
            },
        });
        await recordRevision(
            auth.tenantId,
            'book_institutional_orders',
            orderId,
            'update',
            auth.sub,
            { fulfilledSets: Number(existing.fulfilledSets || 0) },
            { fulfilledSets: Number(existing.fulfilledSets || 0) + Number(validated.sets || 0) },
            { source: 'book_store.fulfillSchoolOrder' },
        );

        return response.success({ message: 'Order fulfilled partially/fully' });
    }, BOOK_STORE_INSTITUTIONAL_OPTS
);

/**
 * GET /books/consignments
 */
export const getConsignments = authorizedHandler([], async (event, _context, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const consignments = await queryItems<Record<string, any>>(pk, 'CONSIGNMENT#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
    });

    const items = consignments.items.map(c => ({
        id: c.id,
        publisherId: c.vendorId,
        publisherName: c.vendorName || 'Unknown',
        totalBooksReceived: c.items?.reduce((sum: number, item: any) => sum + (item.qty || 0), 0) || 0,
        totalBooksSold: c.totalBooksSold || 0,
        settlementAmount: c.settlementAmount || 0,
        status: c.status,
    }));

    return response.success({ consignments: items });
}, BOOK_STORE_CONSIGNMENT_OPTS);
