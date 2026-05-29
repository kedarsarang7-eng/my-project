import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody, parsePagination } from '../middleware/validation';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, getItem, putItem, queryAllItems, queryItems, updateItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import {
    createPurchaseOrderSchema,
    updatePurchaseOrderStatusSchema,
    createGrnSchema,
    createPurchaseBillSchema,
    createPartySchema,
    partyLedgerPostSchema,
} from '../schemas';

const HW_OPTS = {
    requiredBusinessType: BusinessType.HARDWARE,
    requiredFeature: FeatureKey.HARDWARE_CONTRACTOR_CREDIT,
};

export const createPurchaseOrder = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createPurchaseOrderSchema, event);
        if (!parsed.success) return parsed.error;
        const id = uuidv4();
        const now = new Date().toISOString();
        const pk = Keys.tenantPK(auth.tenantId);
        const totalCents = parsed.data.items.reduce((sum, item) =>
            sum + Math.round(item.quantity * item.rateCents), 0);

        await putItem({
            PK: pk,
            SK: Keys.purchaseOrderSK(id),
            entityType: 'PURCHASE_ORDER',
            id,
            tenantId: auth.tenantId,
            status: 'draft',
            ...parsed.data,
            totalCents,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });

        return response.success({ id, totalCents, status: 'draft' }, 201);
    },
    HW_OPTS,
);

export const listPurchaseOrders = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const { page, limit, offset } = parsePagination(event);
        const result = await queryItems<Record<string, unknown>>(Keys.tenantPK(auth.tenantId), 'PO#', {
            scanIndexForward: false,
            limit: Math.max(limit * 3, 100),
        });
        const filtered = result.items.filter((it) => !(it as any).isDeleted);
        return response.paginated(filtered.slice(offset, offset + limit), filtered.length, page, limit);
    },
    HW_OPTS,
);

export const updatePurchaseOrderStatus = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const poId = event.pathParameters?.id;
        if (!poId) return response.badRequest('Missing purchase order id');
        const parsed = parseBody(updatePurchaseOrderStatusSchema, event);
        if (!parsed.success) return parsed.error;
        const updated = await updateItem(Keys.tenantPK(auth.tenantId), Keys.purchaseOrderSK(poId), {
            updateExpression: 'SET #status = :status, #notes = :notes, updatedAt = :now',
            expressionAttributeNames: { '#status': 'status', '#notes': 'notes' },
            expressionAttributeValues: {
                ':status': parsed.data.status,
                ':notes': parsed.data.notes || null,
                ':now': new Date().toISOString(),
            },
            conditionExpression: 'attribute_exists(PK)',
        });
        return response.success({ id: poId, status: updated?.status || parsed.data.status });
    },
    HW_OPTS,
);

export const createGrn = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createGrnSchema, event);
        if (!parsed.success) return parsed.error;
        const id = uuidv4();
        const now = new Date().toISOString();
        const pk = Keys.tenantPK(auth.tenantId);
        await putItem({
            PK: pk,
            SK: Keys.grnSK(id),
            entityType: 'GRN',
            id,
            tenantId: auth.tenantId,
            ...parsed.data,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });

        return response.success({ id }, 201);
    },
    HW_OPTS,
);

export const createPurchaseBill = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createPurchaseBillSchema, event);
        if (!parsed.success) return parsed.error;
        const id = uuidv4();
        const now = new Date().toISOString();
        const totalTaxable = parsed.data.items.reduce((sum, item) => sum + item.taxableValueCents, 0);
        const totalTax = parsed.data.items.reduce((sum, item) =>
            sum + item.cgstCents + item.sgstCents + item.igstCents, 0);
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: Keys.purchaseBillSK(id),
            entityType: 'PURCHASE_BILL',
            id,
            tenantId: auth.tenantId,
            ...parsed.data,
            totalTaxableCents: totalTaxable,
            totalTaxCents: totalTax,
            totalCents: totalTaxable + totalTax,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });
        return response.success({ id }, 201);
    },
    HW_OPTS,
);

export const createParty = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createPartySchema, event);
        if (!parsed.success) return parsed.error;
        const id = uuidv4();
        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: Keys.partySK(id),
            entityType: 'PARTY',
            id,
            tenantId: auth.tenantId,
            ...parsed.data,
            runningBalanceCents: 0,
            isDeleted: false,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
        });
        return response.success({ id }, 201);
    },
    HW_OPTS,
);

export const listParties = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const items = await queryAllItems<Record<string, unknown>>(Keys.tenantPK(auth.tenantId), 'PARTY#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 20,
        });
        return response.success({ items });
    },
    HW_OPTS,
);

export const postPartyLedger = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const partyId = event.pathParameters?.id;
        if (!partyId) return response.badRequest('Missing party id');
        const parsed = parseBody(partyLedgerPostSchema, event);
        if (!parsed.success) return parsed.error;

        const pk = Keys.tenantPK(auth.tenantId);
        const partySk = Keys.partySK(partyId);
        const party = await getItem<Record<string, any>>(pk, partySk);
        if (!party || party.isDeleted) return response.notFound('Party');

        const debit = parsed.data.debitCents || 0;
        const credit = parsed.data.creditCents || 0;
        const delta = debit - credit;
        const newBalance = Number(party.runningBalanceCents || 0) + delta;
        const now = new Date().toISOString();
        const entryId = uuidv4();

        await putItem({
            PK: pk,
            SK: Keys.partyLedgerSK(entryId),
            entityType: 'PARTY_LEDGER',
            id: entryId,
            tenantId: auth.tenantId,
            partyId,
            ...parsed.data,
            balanceAfterCents: newBalance,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });

        await updateItem(pk, partySk, {
            updateExpression: 'SET runningBalanceCents = :balance, updatedAt = :now',
            expressionAttributeValues: { ':balance': newBalance, ':now': now },
            conditionExpression: 'attribute_exists(PK)',
        });

        return response.success({ partyId, ledgerEntryId: entryId, runningBalanceCents: newBalance }, 201);
    },
    HW_OPTS,
);

export const getPartyLedger = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const partyId = event.pathParameters?.id;
        if (!partyId) return response.badRequest('Missing party id');
        const items = await queryAllItems<Record<string, unknown>>(Keys.tenantPK(auth.tenantId), 'PLEDGER#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND partyId = :partyId',
            expressionAttributeValues: { ':false': false, ':partyId': partyId },
            maxPages: 40,
        });
        items.sort((a, b) => String((b as any).createdAt || '').localeCompare(String((a as any).createdAt || '')));
        return response.success({ items });
    },
    HW_OPTS,
);

export const getPartyAging = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const ledgerEntries = await queryAllItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'PLEDGER#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 60,
        });
        const now = Date.now();
        const msPerDay = 86_400_000;
        const buckets = { d0to30: 0, d31to60: 0, d61to90: 0, d90plus: 0 };
        for (const entry of ledgerEntries) {
            const age = Math.floor((now - new Date(String(entry.createdAt || '')).getTime()) / msPerDay);
            const debit = Number(entry.debitCents || 0);
            const credit = Number(entry.creditCents || 0);
            const pending = Math.max(debit - credit, 0);
            if (pending <= 0) continue;
            if (age <= 30) buckets.d0to30 += pending;
            else if (age <= 60) buckets.d31to60 += pending;
            else if (age <= 90) buckets.d61to90 += pending;
            else buckets.d90plus += pending;
        }
        return response.success({ buckets, totalCents: buckets.d0to30 + buckets.d31to60 + buckets.d61to90 + buckets.d90plus });
    },
    HW_OPTS,
);
