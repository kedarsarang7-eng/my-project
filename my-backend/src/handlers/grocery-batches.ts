import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { z } from 'zod';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody, parseQuery } from '../middleware/validation';
import { createGroceryBatchSchema } from '../schemas';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, TABLE_NAME, getItem, queryItems, transactWrite } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

const GROCERY_BATCH_OPTS = {
    requiredBusinessType: BusinessType.GROCERY,
    requiredFeature: FeatureKey.GROCERY_ADVANCED_BATCH,
};

const listSchema = createGroceryBatchSchema.pick({ productId: true }).extend({
    limit: z.coerce.number().int().min(1).max(200).default(100),
});

export const createBatch = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createGroceryBatchSchema, event);
        if (!parsed.success) return parsed.error;

        const { productId, batchNumber, expiryDate, quantityReceived, costPriceCents, supplierName, invoiceRef } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);
        const now = new Date().toISOString();
        const batchId = uuidv4();
        const batchSK = `GROCBATCH#${productId}#${batchNumber}`;
        const product = await getItem<Record<string, any>>(pk, Keys.productSK(productId));

        if (!product || product.isDeleted) {
            return response.error(404, 'PRODUCT_NOT_FOUND', `Product '${productId}' not found`);
        }

        const ops: any[] = [
            {
                Put: {
                    TableName: TABLE_NAME,
                    Item: {
                        PK: pk,
                        SK: batchSK,
                        entityType: 'GROCERY_BATCH',
                        id: batchId,
                        tenantId: auth.tenantId,
                        productId,
                        productName: product.name || '',
                        batchNumber,
                        expiryDate,
                        initialQty: quantityReceived,
                        currentQty: quantityReceived,
                        costPriceCents: costPriceCents || null,
                        supplierName: supplierName || null,
                        invoiceRef: invoiceRef || null,
                        status: 'active',
                        createdBy: auth.sub,
                        createdAt: now,
                        updatedAt: now,
                    },
                    ConditionExpression: 'attribute_not_exists(PK)',
                },
            },
            {
                Update: {
                    TableName: TABLE_NAME,
                    Key: { PK: pk, SK: Keys.productSK(productId) },
                    UpdateExpression: 'SET currentStock = currentStock + :qty, updatedAt = :now',
                    ConditionExpression: 'attribute_exists(PK)',
                    ExpressionAttributeValues: {
                        ':qty': quantityReceived,
                        ':now': now,
                    },
                },
            },
        ];

        await transactWrite(ops);

        logger.info('Grocery batch created', { tenantId: auth.tenantId, productId, batchNumber, quantityReceived });
        return response.success({ id: batchId, productId, batchNumber, quantityReceived, expiryDate }, 201);
    },
    GROCERY_BATCH_OPTS,
);

export const listBatches = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseQuery(listSchema, event);
        if (!parsed.success) return parsed.error;

        const productId = parsed.data.productId;
        const limit = Number((event.queryStringParameters || {}).limit || 100);
        const pk = Keys.tenantPK(auth.tenantId);
        const items = await queryItems<Record<string, any>>(pk, `GROCBATCH#${productId}#`, {
            scanIndexForward: true,
            limit: Math.min(Math.max(limit, 1), 200),
        });

        return response.success({
            productId,
            items: items.items
                .filter((b) => !b.isDeleted)
                .map((b) => ({
                    id: b.id,
                    batchNumber: b.batchNumber,
                    expiryDate: b.expiryDate,
                    initialQty: Number(b.initialQty || 0),
                    currentQty: Number(b.currentQty || 0),
                    status: b.status || 'active',
                    supplierName: b.supplierName || null,
                    invoiceRef: b.invoiceRef || null,
                    updatedAt: b.updatedAt,
                })),
        });
    },
    GROCERY_BATCH_OPTS,
);
