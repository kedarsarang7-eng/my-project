import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, queryItems, transactWrite, getItem, putItem, updateItem } from '../config/dynamodb.config';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import { TransactWriteCommand } from '@aws-sdk/lib-dynamodb';
import { recordRevision } from '../services/revision-history.service';
import { config } from '../config/environment';
import { v4 as uuidv4 } from 'uuid';
import { 
    createTailoringNoteSchema, 
    updateTailoringStatusSchema, 
    updateTailoringMeasurementsSchema, 
    assignBarcodeToVariantSchema 
} from '../schemas';

const CLOTHING_OPTS = { requiredBusinessType: BusinessType.CLOTHING, requiredFeature: FeatureKey.CLOTHING_FULL_MATRIX };

/**
 * GET /clothing/variants/{productId}
 */
export const getVariants = authorizedHandler([], async (event, _context, auth) => {
    const productId = event.pathParameters?.productId;
    if (!productId) return response.badRequest('Missing productId');

    const pk = Keys.tenantPK(auth.tenantId);

    const variants = await queryItems<Record<string, any>>(pk, `VARIANT#${productId}#`, {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':false': false },
    });

    const items = variants.items.map(v => ({
        id: v.id,
        productId: v.productId,
        size: v.size,
        color: v.color,
        sku: v.sku,
        priceCents: v.priceCents,
        stock: v.stock,
    }));

    return response.success(items);
}, CLOTHING_OPTS);

/**
 * PUT /clothing/variants/bulk
 */
export const bulkUpdateVariants = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const body = JSON.parse(event.body || '{}');
        const validated = (await import('../schemas')).bulkVariantUpdateSchema.parse(body);

        const pk = Keys.tenantPK(auth.tenantId);
        const now = new Date().toISOString();

        // Prepare TransactWrite items
        const transactItems = validated.variants.map((v: any) => {
            const variantId = crypto.randomUUID();
            return {
                Put: {
                    TableName: config.dynamodb.tableName,
                    Item: {
                        PK: pk,
                        SK: `VARIANT#${validated.productId}#${variantId}`,
                        entityType: 'VARIANT',
                        id: variantId,
                        tenantId: auth.tenantId,
                        productId: validated.productId,
                        size: v.size || null,
                        color: v.color || null,
                        sku: v.sku || null,
                        priceCents: v.priceCents,
                        stock: v.stock,
                        createdAt: now,
                        updatedAt: now,
                    },
                },
            };
        });

        // Split into chunks of 25 (DynamoDB limit for TransactWriteItems)
        const chunks = [];
        for (let i = 0; i < transactItems.length; i += 25) {
            chunks.push(transactItems.slice(i, i + 25));
        }

        for (const chunk of chunks) {
            await transactWrite(chunk);
        }
        await recordRevision(
            auth.tenantId,
            'clothing_variants',
            validated.productId,
            'update',
            auth.sub,
            null,
            {
                productId: validated.productId,
                variantCount: validated.variants.length,
                updatedAt: now,
            },
            { source: 'clothing.bulkUpdateVariants' },
        );

        logger.info('Bulk updated variants', { tenantId: auth.tenantId, productId: validated.productId, count: validated.variants.length });
        return response.success({ message: 'Variants updated successfully', count: validated.variants.length });
    },
    CLOTHING_OPTS
);

// ============================================================================
// TAILORING NOTES API ENDPOINTS
// ============================================================================

/**
 * POST /clothing/tailoring-notes
 * Create a new tailoring note for an invoice
 */
export const createTailoringNote = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const body = JSON.parse(event.body || '{}');
        const validated = createTailoringNoteSchema.parse(body);

        const pk = Keys.tenantPK(auth.tenantId);
        const tailoringId = uuidv4();
        const now = new Date().toISOString();

        // Verify invoice exists and belongs to tenant
        const invoice = await getItem(pk, `INVOICE#${validated.invoiceId}`);
        if (!invoice || (invoice as any).tenantId !== auth.tenantId) {
            return response.notFound('Invoice not found');
        }

        const tailoringNote = {
            PK: pk,
            SK: `TAILORING#${tailoringId}`,
            entityType: 'TAILORING_NOTE',
            id: tailoringId,
            tenantId: auth.tenantId,
            invoiceId: validated.invoiceId,
            customerId: validated.customerId,
            measurements: validated.measurements,
            deliveryDate: validated.deliveryDate,
            priority: validated.priority,
            status: 'measurement_taken',
            notes: validated.notes,
            createdAt: now,
            updatedAt: now,
            createdBy: auth.sub,
        };

        await putItem(tailoringNote);

        // Update invoice with tailoring reference
        await updateItem(pk, `INVOICE#${validated.invoiceId}`, {
            updateExpression: 'SET tailoringNoteId = :tailoringId, updatedAt = :now',
            expressionAttributeValues: {
                ':tailoringId': tailoringId,
                ':now': now,
            },
        });

        await recordRevision(
            auth.tenantId,
            'tailoring_note',
            tailoringId,
            'create',
            auth.sub,
            null,
            {
                invoiceId: validated.invoiceId,
                deliveryDate: validated.deliveryDate,
                priority: validated.priority,
            },
            { source: 'clothing.createTailoringNote' },
        );

        logger.info('Tailoring note created', { tenantId: auth.tenantId, tailoringId, invoiceId: validated.invoiceId });
        return response.success({ id: tailoringId, message: 'Tailoring note created successfully' }, 201);
    },
    CLOTHING_OPTS
);

/**
 * GET /clothing/tailoring-notes/{tailoringId}
 * Get a specific tailoring note
 */
export const getTailoringNote = authorizedHandler([], async (event, _context, auth) => {
    const tailoringId = event.pathParameters?.tailoringId;
    if (!tailoringId) return response.badRequest('Missing tailoringId');

    const pk = Keys.tenantPK(auth.tenantId);
    const result = await getItem(pk, `TAILORING#${tailoringId}`);

    if (!result || (result as any).tenantId !== auth.tenantId) {
        return response.notFound('Tailoring note not found');
    }

    return response.success(result);
}, CLOTHING_OPTS);

/**
 * PUT /clothing/tailoring-notes/{tailoringId}/status
 * Update tailoring status
 */
export const updateTailoringStatus = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const tailoringId = event.pathParameters?.tailoringId;
        if (!tailoringId) return response.badRequest('Missing tailoringId');

        const body = JSON.parse(event.body || '{}');
        const validated = updateTailoringStatusSchema.parse(body);

        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, `TAILORING#${tailoringId}`);

        if (!existing || (existing as any).tenantId !== auth.tenantId) {
            return response.notFound('Tailoring note not found');
        }

        const now = new Date().toISOString();
        
        let updateExpression = 'SET #status = :status, updatedAt = :now, updatedBy = :updatedBy';
        let expressionAttributeNames: any = { '#status': 'status' };
        let expressionAttributeValues: any = {
            ':status': validated.status,
            ':now': now,
            ':updatedBy': auth.sub,
        };

        if (validated.notes) {
            updateExpression += ', notes = :notes';
            expressionAttributeValues[':notes'] = validated.notes;
        }
        if (validated.estimatedCompletion) {
            updateExpression += ', estimatedCompletion = :estimatedCompletion';
            expressionAttributeValues[':estimatedCompletion'] = validated.estimatedCompletion;
        }

        await updateItem(pk, `TAILORING#${tailoringId}`, {
            updateExpression,
            expressionAttributeNames,
            expressionAttributeValues,
        });

        await recordRevision(
            auth.tenantId,
            'tailoring_note',
            tailoringId,
            'update' as any, // Fix RevisionAction type
            auth.sub,
            (existing as any).status,
            {
                newStatus: validated.status,
                notes: validated.notes,
                estimatedCompletion: validated.estimatedCompletion,
            },
            { source: 'clothing.updateTailoringStatus' },
        );

        logger.info('Tailoring status updated', { tenantId: auth.tenantId, tailoringId, newStatus: validated.status });
        return response.success({ message: 'Tailoring status updated successfully' });
    },
    CLOTHING_OPTS
);

/**
 * PUT /clothing/tailoring-notes/{tailoringId}/measurements
 * Update tailoring measurements
 */
export const updateTailoringMeasurements = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const tailoringId = event.pathParameters?.tailoringId;
        if (!tailoringId) return response.badRequest('Missing tailoringId');

        const body = JSON.parse(event.body || '{}');
        const validated = updateTailoringMeasurementsSchema.parse(body);

        const pk = Keys.tenantPK(auth.tenantId);
        const existing = await getItem(pk, `TAILORING#${tailoringId}`);

        if (!existing || (existing as any).tenantId !== auth.tenantId) {
            return response.notFound('Tailoring note not found');
        }

        const now = new Date().toISOString();
        await updateItem(pk, `TAILORING#${tailoringId}`, {
            updateExpression: 'SET measurements = :measurements, updatedAt = :now, updatedBy = :updatedBy',
            expressionAttributeValues: {
                ':measurements': validated.measurements,
                ':now': now,
                ':updatedBy': auth.sub,
            },
        });

        await recordRevision(
            auth.tenantId,
            'tailoring_note',
            tailoringId,
            'update' as any, // Fix RevisionAction type
            auth.sub,
            (existing as any).measurements,
            { newMeasurements: validated.measurements },
            { source: 'clothing.updateTailoringMeasurements' },
        );

        logger.info('Tailoring measurements updated', { tenantId: auth.tenantId, tailoringId });
        return response.success({ message: 'Tailoring measurements updated successfully' });
    },
    CLOTHING_OPTS
);

/**
 * GET /clothing/tailoring-notes
 * List all tailoring notes with optional filters
 */
export const listTailoringNotes = authorizedHandler([], async (event, _context, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const status = event.queryStringParameters?.status;
    const priority = event.queryStringParameters?.priority;

    let filterExpression = '(attribute_not_exists(isDeleted) OR isDeleted = :false)';
    let expressionAttributeValues: any = { ':false': false };
    let expressionAttributeNames: any = {};

    if (status) {
        filterExpression += ' AND #status = :status';
        expressionAttributeValues[':status'] = status;
        expressionAttributeNames['#status'] = 'status';
    }

    if (priority) {
        filterExpression += ' AND priority = :priority';
        expressionAttributeValues[':priority'] = priority;
    }

    const result = await queryItems<Record<string, any>>(pk, 'TAILORING#', {
        filterExpression,
        expressionAttributeValues,
        expressionAttributeNames: Object.keys(expressionAttributeNames).length > 0 ? expressionAttributeNames : undefined,
    });

    const items = result.items.map(item => ({
        id: item.id,
        invoiceId: item.invoiceId,
        customerId: item.customerId,
        status: item.status,
        priority: item.priority,
        deliveryDate: item.deliveryDate,
        estimatedCompletion: item.estimatedCompletion,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
    }));

    return response.success(items);
}, CLOTHING_OPTS);

// ============================================================================
// BARCODE ASSIGNMENT API ENDPOINTS
// ============================================================================

/**
 * PUT /clothing/variants/{variantId}/barcode
 * Assign or update barcode for a specific variant
 */
export const assignBarcodeToVariant = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const variantId = event.pathParameters?.variantId;
        if (!variantId) return response.badRequest('Missing variantId');

        const body = JSON.parse(event.body || '{}');
        const validated = assignBarcodeToVariantSchema.parse({ ...body, variantId });

        const pk = Keys.tenantPK(auth.tenantId);
        const now = new Date().toISOString();

        // Check if variant exists and belongs to tenant
        const existingVariant = await getItem(pk, `VARIANT#${validated.productId}#${variantId}`);
        if (!existingVariant || (existingVariant as any).tenantId !== auth.tenantId) {
            return response.notFound('Variant not found');
        }

        // Check if barcode is already assigned to another variant
        const existingBarcode = await queryItems<Record<string, any>>(pk, 'VARIANT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND barcode = :barcode AND id <> :variantId',
            expressionAttributeValues: { ':false': false, ':barcode': validated.barcode, ':variantId': variantId },
            limit: 1,
        });

        if (existingBarcode.items.length > 0) {
            return response.badRequest('Barcode already assigned to another variant');
        }

        // Update variant with barcode
        await updateItem(pk, `VARIANT#${validated.productId}#${variantId}`, {
            updateExpression: 'SET barcode = :barcode, updatedAt = :now, updatedBy = :updatedBy',
            expressionAttributeValues: {
                ':barcode': validated.barcode,
                ':now': now,
                ':updatedBy': auth.sub,
            },
        });

        await recordRevision(
            auth.tenantId,
            'variant',
            variantId,
            'update' as any, // Fix RevisionAction type
            auth.sub,
            (existingVariant as any).barcode,
            { newBarcode: validated.barcode },
            { source: 'clothing.assignBarcodeToVariant' },
        );

        logger.info('Barcode assigned to variant', { 
            tenantId: auth.tenantId, 
            variantId, 
            barcode: validated.barcode,
            productId: validated.productId 
        });

        return response.success({ message: 'Barcode assigned successfully' });
    },
    CLOTHING_OPTS
);

/**
 * GET /clothing/barcode/{barcode}
 * Find variant by barcode
 */
export const getVariantByBarcode = authorizedHandler([], async (event, _context, auth) => {
    const barcode = event.pathParameters?.barcode;
    if (!barcode) return response.badRequest('Missing barcode');

    const pk = Keys.tenantPK(auth.tenantId);

    const result = await queryItems<Record<string, any>>(pk, 'VARIANT#', {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND barcode = :barcode',
        expressionAttributeValues: { ':false': false, ':barcode': barcode },
        limit: 1,
    });

    if (result.items.length === 0) {
        return response.notFound('No variant found with this barcode');
    }

    const variant = result.items[0];
    return response.success({
        id: variant.id,
        productId: variant.productId,
        size: variant.size,
        color: variant.color,
        sku: variant.sku,
        barcode: variant.barcode,
        priceCents: variant.priceCents,
        stock: variant.stock,
    });
}, CLOTHING_OPTS);
