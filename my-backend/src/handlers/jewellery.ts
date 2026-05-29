// ============================================================================
// Lambda Handler — Jewellery / Jewelry Store (DynamoDB)
// ============================================================================
// Purpose: Gold rate tracking, custom orders, old gold exchange (PML Act compliance)
// Business Type: JEWELLERY
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, putItem, updateItem, getItem, TABLE_NAME } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import { z } from 'zod';
import { recordRevision } from '../services/revision-history.service';

const JEWELLERY_OPTS = { requiredBusinessType: BusinessType.JEWELLERY, requiredFeature: FeatureKey.JEWELLERY_PURITY_TRACKING };

// ── Zod Schemas ─────────────────────────────────────────────────────────────

const goldRateSchema = z.object({
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    rates: z.object({
        gold24KPer10gPaisa: z.number().int().min(0),
        gold22KPer10gPaisa: z.number().int().min(0),
        gold18KPer10gPaisa: z.number().int().min(0),
        silverPerKgPaisa: z.number().int().min(0),
    }),
    source: z.enum(['MANUAL', 'API', 'BANK']).default('MANUAL'),
});

const customOrderSchema = z.object({
    customerId: z.string().uuid(),
    customerName: z.string().min(1).max(200),
    customerPhone: z.string().max(20),
    
    // Order details
    itemDescription: z.string().min(1).max(1000),
    designReference: z.string().max(200).optional(),
    
    // Metal specifications
    metalType: z.enum(['GOLD_24K', 'GOLD_22K', 'GOLD_18K', 'SILVER', 'PLATINUM']),
    estimatedWeightGrams: z.number().min(0.1).max(10000),
    
    // Charges (in paise)
    metalRatePerGramPaisa: z.number().int().min(0),
    makingChargesPerGramPaisa: z.number().int().min(0),
    wastagePercent: z.number().min(0).max(100).default(0),
    stoneChargesPaisa: z.number().int().min(0).default(0),
    otherChargesPaisa: z.number().int().min(0).default(0),
    
    // Totals
    estimatedTotalPaisa: z.number().int().min(0),
    advanceReceivedPaisa: z.number().int().min(0).default(0),
    
    // Timeline
    promisedDeliveryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    
    // Status
    status: z.enum(['PENDING', 'DESIGN_APPROVAL', 'IN_PROGRESS', 'READY', 'DELIVERED', 'CANCELLED']).default('PENDING'),
});

const oldGoldExchangeSchema = z.object({
    customerId: z.string().uuid(),
    customerName: z.string().min(1).max(200),
    
    // Old gold details (being taken in)
    oldGoldPurity: z.enum(['GOLD_24K', 'GOLD_22K', 'GOLD_18K', 'GOLD_14K', 'GOLD_9K']),
    oldGoldWeightGrams: z.number().min(0.1),
    oldGoldValuePaisa: z.number().int().min(0),
    
    // New item details (if exchanging)
    newItemDescription: z.string().max(1000).optional(),
    newItemMetalType: z.enum(['GOLD_24K', 'GOLD_22K', 'GOLD_18K', 'SILVER']).optional(),
    newItemWeightGrams: z.number().min(0).optional(),
    newItemTotalPaisa: z.number().int().min(0).optional(),
    
    // Exchange calculation
    exchangeValuePaisa: z.number().int().min(0),
    cashAdjustmentPaisa: z.number().int().default(0), // Positive = customer pays, Negative = store pays
    
    // PML Act compliance
    customerIdType: z.enum(['AADHAAR', 'PAN', 'PASSPORT', 'VOTER_ID']),
    customerIdNumber: z.string().min(1).max(50),
    customerPhotoUrl: z.string().url().optional(),
});

const hallmarkInventorySchema = z.object({
    itemName: z.string().min(1).max(200),
    huid: z.string().length(6), // Hallmark Unique ID
    purity: z.enum(['999', '916', '750', '585']),
    weightGrams: z.number().min(0.01),
    makingChargesPerGramPaisa: z.number().int().min(0),
    
    // Pricing
    metalRatePerGramPaisa: z.number().int().min(0),
    totalMrpPaisa: z.number().int().min(0),
    
    // Stock
    currentStock: z.number().int().min(0).default(0),
    
    // Images
    imageUrls: z.array(z.string().url()).max(5).default([]),
});

// ── Handlers ────────────────────────────────────────────────────────────────

/**
 * POST /jewellery/gold-rate
 * Set daily gold rate
 */
export const setGoldRate = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(goldRateSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const sk = Keys.jewelleryRateCardSK(body.date);
    const now = new Date().toISOString();

    const rateCard = {
        PK: pk,
        SK: sk,
        entityType: 'GOLD_RATE_CARD',
        tenantId: auth.tenantId,
        businessId: auth.businessId || auth.tenantId,
        ...body,
        createdAt: now,
        createdBy: auth.sub,
    };

    await putItem(rateCard);
    await recordRevision(auth.tenantId, 'GOLD_RATE_CARD', body.date, 'create', auth.sub, null, rateCard);

    logger.info('Gold rate set', { date: body.date, tenantId: auth.tenantId, handler: 'jewellery' });
    return response.success({ data: rateCard }, 201);
}, JEWELLERY_OPTS);

/**
 * GET /jewellery/gold-rate
 * Get gold rate for a date (defaults to today)
 */
export const getGoldRate = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.VIEWER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const date = event.queryStringParameters?.date || new Date().toISOString().split('T')[0];
    const pk = Keys.tenantPK(auth.tenantId);
    const sk = Keys.jewelleryRateCardSK(date);

    const result = await getItem(pk, sk);

    if (!result) {
        return response.notFound('Gold rate not found for date');
    }

    return response.success({ data: result });
}, JEWELLERY_OPTS);

/**
 * POST /jewellery/custom-orders
 * Create a custom jewellery order
 */
export const createCustomOrder = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(customOrderSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const orderId = crypto.randomUUID();
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const order = {
        PK: pk,
        SK: Keys.jewelleryCustomOrderSK(orderId),
        entityType: 'JEWELLERY_CUSTOM_ORDER',
        tenantId: auth.tenantId,
        businessId: auth.businessId || auth.tenantId,
        orderId,
        ...body,
        createdAt: now,
        updatedAt: now,
        createdBy: auth.sub,
    };

    await putItem(order);
    await recordRevision(auth.tenantId, 'JEWELLERY_CUSTOM_ORDER', orderId, 'create', auth.sub, null, order);

    logger.info('Custom order created', { orderId, tenantId: auth.tenantId, handler: 'jewellery' });
    return response.success({ data: order }, 201);
}, JEWELLERY_OPTS);

/**
 * GET /jewellery/custom-orders
 * List custom orders with optional status filter
 */
export const listCustomOrders = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.VIEWER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const status = event.queryStringParameters?.status;
    const pk = Keys.tenantPK(auth.tenantId);

    const result = await queryItems(
        pk,
        'JEWELLERY_ORDER#',
        {
            filterExpression: status ? '#status = :status' : undefined,
            expressionAttributeNames: status ? { '#status': 'status' } : undefined,
            expressionAttributeValues: status ? { ':status': status } : undefined,
        }
    );

    const orders = result.items || [];
    return response.success({ data: orders, count: orders.length });
}, JEWELLERY_OPTS);

/**
 * POST /jewellery/old-gold-exchange
 * Record old gold exchange (PML Act compliance)
 */
export const recordOldGoldExchange = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(oldGoldExchangeSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const exchangeId = crypto.randomUUID();
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const exchange = {
        PK: pk,
        SK: Keys.jewelleryExchangeSK(exchangeId),
        entityType: 'JEWELLERY_OLD_GOLD_EXCHANGE',
        tenantId: auth.tenantId,
        businessId: auth.businessId || auth.tenantId,
        exchangeId,
        ...body,
        createdAt: now,
        createdBy: auth.sub,
    };

    await putItem(exchange);
    await recordRevision(auth.tenantId, 'JEWELLERY_OLD_GOLD_EXCHANGE', exchangeId, 'create', auth.sub, null, exchange);

    logger.info('Old gold exchange recorded', { 
        exchangeId, 
        customerIdType: body.customerIdType,
        exchangeValuePaisa: body.exchangeValuePaisa,
        handler: 'jewellery' 
    });

    return response.success({ data: exchange }, 201);
}, JEWELLERY_OPTS);

/**
 * GET /jewellery/old-gold-exchange
 * List old gold exchanges (PML Act register)
 */
export const listOldGoldExchanges = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CHARTERED_ACCOUNTANT], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const result = await queryItems(
        pk,
        'JEWELLERY_EXCHANGE#'
    );

    const exchanges = result.items || [];
    return response.success({ data: exchanges, count: exchanges.length });
}, JEWELLERY_OPTS);

/**
 * POST /jewellery/hallmark-inventory
 * Add hallmark inventory item
 */
export const createHallmarkItem = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(hallmarkInventorySchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const itemId = crypto.randomUUID();
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const item = {
        PK: pk,
        SK: Keys.productSK(itemId), // Use standard product SK for unified inventory
        entityType: 'HALLMARK_JEWELLERY',
        tenantId: auth.tenantId,
        businessId: auth.businessId || auth.tenantId,
        itemId,
        ...body,
        createdAt: now,
        updatedAt: now,
        createdBy: auth.sub,
    };

    await putItem(item);

    logger.info('Hallmark item created', { itemId, huid: body.huid, handler: 'jewellery' });
    return response.success({ data: item }, 201);
}, JEWELLERY_OPTS);

/**
 * GET /jewellery/hallmark-register
 * Get HUID hallmark register for compliance
 */
export const getHallmarkRegister = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CHARTERED_ACCOUNTANT], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const result = await queryItems(
        pk,
        'PRODUCT#'
    );

    // Filter only hallmark items
    const items = (result.items || []).filter((item: any) => item.entityType === 'HALLMARK_JEWELLERY');
    
    return response.success({ 
        data: items, 
        count: items.length,
        generatedAt: new Date().toISOString(),
    });
}, JEWELLERY_OPTS);

// Default export
export default {
    setGoldRate,
    getGoldRate,
    createCustomOrder,
    listCustomOrders,
    recordOldGoldExchange,
    listOldGoldExchanges,
    createHallmarkItem,
    getHallmarkRegister,
};
