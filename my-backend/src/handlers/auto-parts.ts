// ============================================================================
// Lambda Handler — Auto Parts / Garage (DynamoDB)
// ============================================================================
// Purpose: Vehicle lookup, fitment guide, job cards, warranty tracking, OEM cross-reference
// Business Type: AUTO_PARTS
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, putItem, updateItem, getItem, transactWrite, TABLE_NAME } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import crypto from 'crypto';
import { z } from 'zod';
import { recordRevision } from '../services/revision-history.service';

const AUTOPARTS_OPTS = { requiredBusinessType: BusinessType.AUTO_PARTS, requiredFeature: FeatureKey.AUTOPARTS_VEHICLE_LOOKUP };

// ── Zod Schemas ─────────────────────────────────────────────────────────────

const vehicleSchema = z.object({
    make: z.string().min(1).max(100),
    model: z.string().min(1).max(100),
    year: z.number().int().min(1900).max(2100),
    variant: z.string().max(100).optional(),
    engineNumber: z.string().max(100).optional(),
    chassisNumber: z.string().max(100).optional(),
    registrationNumber: z.string().max(20).optional(),
});

const createJobCardSchema = z.object({
    vehicle: vehicleSchema,
    customerId: z.string().uuid().optional(),
    customerName: z.string().min(1).max(200).optional(),
    customerPhone: z.string().max(20).optional(),
    reportedIssue: z.string().min(1).max(2000),
    estimatedCost: z.number().int().min(0).optional(), // in paise
    photoUrls: z.array(z.string().url()).max(10).default([]),
});

const updateJobCardSchema = z.object({
    status: z.enum(['INTAKE', 'DIAGNOSIS', 'AWAITING_PARTS', 'REPAIRING', 'QC', 'READY', 'DELIVERED', 'CANCELLED']),
    partsUsed: z.array(z.object({
        partId: z.string().uuid(),
        partName: z.string(),
        quantity: z.number().int().min(1),
        unitPricePaisa: z.number().int().min(0),
        serialNumber: z.string().optional(),
    })).optional(),
    laborChargesPaisa: z.number().int().min(0).optional(),
    notes: z.string().max(2000).optional(),
});

const addPartSchema = z.object({
    name: z.string().min(1).max(200),
    sku: z.string().min(1).max(100),
    oemNumber: z.string().max(100).optional(),
    compatibleVehicles: z.array(vehicleSchema).optional(),
    category: z.enum(['engine', 'transmission', 'brakes', 'suspension', 'electrical', 'body', 'interior', 'accessories', 'oil', 'filters']),
    mrpPaisa: z.number().int().min(0),
    costPricePaisa: z.number().int().min(0).optional(),
    gstRate: z.number().min(0).max(100).default(28),
    warrantyMonths: z.number().int().min(0).default(0),
    rackLocation: z.string().max(50).optional(),
    reorderLevel: z.number().int().min(0).default(5),
});

const oemCrossRefSchema = z.object({
    oemNumber: z.string().min(1).max(100),
    aftermarketNumber: z.string().min(1).max(100),
    brand: z.string().min(1).max(100),
    quality: z.enum(['OEM', 'OES', 'Aftermarket', 'Refurbished']).default('Aftermarket'),
});

// ── Handlers ────────────────────────────────────────────────────────────────

/**
 * POST /auto-parts/job-cards
 * Create a new job card for vehicle service/repair
 */
export const createJobCard = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(createJobCardSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const jobCardId = crypto.randomUUID();
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const jobCard = {
        PK: pk,
        SK: Keys.autoPartsJobCardSK(jobCardId),
        entityType: 'AUTOPARTS_JOB_CARD',
        tenantId: auth.tenantId,
        businessId: auth.businessId || auth.tenantId,
        jobCardId,
        vehicle: body.vehicle,
        customerId: body.customerId,
        customerName: body.customerName,
        customerPhone: body.customerPhone,
        reportedIssue: body.reportedIssue,
        estimatedCostPaisa: body.estimatedCost || 0,
        status: 'INTAKE',
        photoUrls: body.photoUrls,
        createdAt: now,
        updatedAt: now,
        createdBy: auth.sub,
    };

    await putItem(jobCard);
    await recordRevision(auth.tenantId, 'AUTOPARTS_JOB_CARD', jobCardId, 'create', auth.sub, null, jobCard);

    logger.info('Job card created', { jobCardId, tenantId: auth.tenantId, handler: 'autoParts' });
    return response.success({ data: jobCard }, 201);
}, AUTOPARTS_OPTS);

/**
 * GET /auto-parts/job-cards
 * List all job cards with optional status filter
 */
export const listJobCards = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.VIEWER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const status = event.queryStringParameters?.status;
    const pk = Keys.tenantPK(auth.tenantId);

    const result = await queryItems(
        pk,
        'AUTOPARTS_JOB_CARD#',
        {
            filterExpression: status ? '#status = :status' : undefined,
            expressionAttributeNames: status ? { '#status': 'status' } : undefined,
            expressionAttributeValues: status ? { ':status': status } : undefined,
        }
    );

    const jobCards = result.items || [];
    return response.success({ data: jobCards, count: jobCards.length });
}, AUTOPARTS_OPTS);

/**
 * GET /auto-parts/job-cards/{id}
 * Get a specific job card with parts used
 */
export const getJobCard = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.VIEWER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const id = event.pathParameters?.id;
    if (!id || !z.string().uuid().safeParse(id).success) {
        return response.badRequest('Invalid ID parameter');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    const result = await getItem<Record<string, unknown>>(pk, Keys.autoPartsJobCardSK(id));

    if (!result) {
        return response.notFound('Job card not found');
    }

    return response.success({ data: result });
}, AUTOPARTS_OPTS);

/**
 * PUT /auto-parts/job-cards/{id}
 * Update job card status and add parts used
 */
export const updateJobCard = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const id = event.pathParameters?.id;
    if (!id || !z.string().uuid().safeParse(id).success) {
        return response.badRequest('Invalid ID parameter');
    }

    const valid = parseBody(updateJobCardSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const sk = Keys.autoPartsJobCardSK(id);
    const now = new Date().toISOString();

    // Build update expression
    let updateExpr = 'SET #status = :status, updatedAt = :now, updatedBy = :userId';
    const exprValues: Record<string, unknown> = {
        ':status': body.status,
        ':now': now,
        ':userId': auth.sub,
    };
    const exprNames: Record<string, string> = { '#status': 'status' };

    if (body.partsUsed) {
        updateExpr += ', partsUsed = :partsUsed';
        exprValues[':partsUsed'] = body.partsUsed;
    }
    if (body.laborChargesPaisa !== undefined) {
        updateExpr += ', laborChargesPaisa = :labor';
        exprValues[':labor'] = body.laborChargesPaisa;
    }
    if (body.notes) {
        updateExpr += ', notes = :notes';
        exprValues[':notes'] = body.notes;
    }

    const result = await updateItem(pk, sk, {
        updateExpression: updateExpr,
        expressionAttributeNames: exprNames,
        expressionAttributeValues: exprValues,
    });

    if (!result) {
        return response.notFound('Job card not found or update failed');
    }

    const attrs = result.Attributes as Record<string, unknown> | undefined;
    if (!attrs) {
        return response.notFound('Job card not found or update failed');
    }

    await recordRevision(auth.tenantId, 'AUTOPARTS_JOB_CARD', id, 'update', auth.sub, null, attrs);

    logger.info('Job card updated', { jobCardId: id, status: body.status, handler: 'autoParts' });
    return response.success({ data: attrs });
}, AUTOPARTS_OPTS);

/**
 * POST /auto-parts/parts
 * Add a new auto part with vehicle compatibility
 */
export const createPart = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(addPartSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const partId = crypto.randomUUID();
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const part = {
        PK: pk,
        SK: Keys.autoPartsPartSK(partId),
        entityType: 'AUTOPARTS_PART',
        tenantId: auth.tenantId,
        businessId: auth.businessId || auth.tenantId,
        partId,
        ...body,
        currentStock: 0,
        createdAt: now,
        updatedAt: now,
        createdBy: auth.sub,
    };

    await putItem(part);

    logger.info('Part created', { partId, name: body.name, handler: 'autoParts' });
    return response.success({ data: part }, 201);
}, AUTOPARTS_OPTS);

/**
 * GET /auto-parts/parts
 * List all parts with optional category filter
 */
export const listParts = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.VIEWER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const category = event.queryStringParameters?.category;
    const pk = Keys.tenantPK(auth.tenantId);

    const result = await queryItems(
        pk,
        'AUTOPARTS_PART#',
        {
            filterExpression: category ? '#category = :category' : undefined,
            expressionAttributeNames: category ? { '#category': 'category' } : undefined,
            expressionAttributeValues: category ? { ':category': category } : undefined,
        }
    );

    const parts = result.items || [];
    return response.success({ data: parts, count: parts.length });
}, AUTOPARTS_OPTS);

/**
 * POST /auto-parts/vehicle-lookup
 * Find parts compatible with a vehicle
 */
export const lookupPartsByVehicle = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(vehicleSchema, event);
    if (!valid.success) return valid.error;
    const vehicle = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);

    // Query all parts and filter by vehicle compatibility
    // In production, this should use a GSI for vehicle-specific queries
    const result = await queryItems(
        pk,
        'AUTOPARTS_PART#'
    );

    const allParts = result.items || [];
    
    // Filter parts compatible with the given vehicle
    const compatibleParts = allParts.filter((part: any) => {
        if (!part.compatibleVehicles || part.compatibleVehicles.length === 0) {
            // Universal fit parts
            return true;
        }
        return part.compatibleVehicles.some((v: any) => 
            v.make.toLowerCase() === vehicle.make.toLowerCase() &&
            v.model.toLowerCase() === vehicle.model.toLowerCase() &&
            (vehicle.year >= (v.year - 1) && vehicle.year <= (v.year + 1))
        );
    });

    logger.info('Vehicle lookup performed', { 
        make: vehicle.make, 
        model: vehicle.model, 
        year: vehicle.year,
        matches: compatibleParts.length,
        handler: 'autoParts' 
    });

    return response.success({ 
        data: compatibleParts, 
        count: compatibleParts.length,
        vehicle,
    });
}, AUTOPARTS_OPTS);

/**
 * POST /auto-parts/oem-cross-ref
 * Add or lookup OEM cross-reference
 */
export const createOemCrossRef = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(oemCrossRefSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    // Store both directions for easy lookup
    const entries = [
        {
            PK: pk,
            SK: `OEM#${body.oemNumber}#${body.aftermarketNumber}`,
            entityType: 'OEM_CROSS_REFERENCE',
            tenantId: auth.tenantId,
            oemNumber: body.oemNumber,
            aftermarketNumber: body.aftermarketNumber,
            brand: body.brand,
            quality: body.quality,
            direction: 'OEM_TO_AFTERMARKET',
            createdAt: now,
        },
        {
            PK: pk,
            SK: `AFTERMARKET#${body.aftermarketNumber}#${body.oemNumber}`,
            entityType: 'OEM_CROSS_REFERENCE',
            tenantId: auth.tenantId,
            oemNumber: body.oemNumber,
            aftermarketNumber: body.aftermarketNumber,
            brand: body.brand,
            quality: body.quality,
            direction: 'AFTERMARKET_TO_OEM',
            createdAt: now,
        },
    ];

    for (const entry of entries) {
        await putItem(entry);
    }

    logger.info('OEM cross-reference created', { 
        oemNumber: body.oemNumber, 
        aftermarketNumber: body.aftermarketNumber,
        handler: 'autoParts' 
    });

    return response.success({ data: entries[0] }, 201);
}, AUTOPARTS_OPTS);

/**
 * GET /auto-parts/oem-cross-ref/{number}
 * Lookup OEM or aftermarket number
 */
export const lookupOemCrossRef = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.VIEWER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const number = event.pathParameters?.number;
    const type = event.queryStringParameters?.type || 'oem'; // 'oem' or 'aftermarket'

    if (!number) {
        return response.badRequest('Number is required');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    const prefix = type === 'oem' ? `OEM#${number}` : `AFTERMARKET#${number}`;

    const result = await queryItems(
        pk,
        prefix
    );

    const refs = result.items || [];
    return response.success({ data: refs, count: refs.length });
}, AUTOPARTS_OPTS);

// Default export for handler discovery
export default {
    createJobCard,
    listJobCards,
    getJobCard,
    updateJobCard,
    createPart,
    listParts,
    lookupPartsByVehicle,
    createOemCrossRef,
    lookupOemCrossRef,
};
