// ============================================================================
// Lambda Handler — Computer Shop (DynamoDB)
// ============================================================================
// Migrated from legacy Express+PostgreSQL (dukan-backend/controllers/computer.controller.js).
// Covers: PC build checkout with serial tracking, component serial queries, RMA.
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

const COMPUTER_OPTS = { requiredBusinessType: BusinessType.COMPUTER_SHOP, requiredFeature: FeatureKey.SERVICE_BASIC_APPOINTMENT };

// ── Zod Schemas ─────────────────────────────────────────────────────────────

const buildComponentSchema = z.object({
    productId: z.string().uuid(),
    serialNumber: z.string().min(1).max(150),
});

const checkoutBuildSchema = z.object({
    components: z.array(buildComponentSchema).min(1).max(50),
    customerId: z.string().uuid().optional(),
    invoiceId: z.string().uuid(),
});

const createJobCardSchema = z.object({
    customerId: z.string().uuid().optional(),
    deviceBrand: z.string().min(1).max(100),
    deviceModel: z.string().min(1).max(100),
    serialNumber: z.string().max(150).optional(),
    reportedIssue: z.string().min(1).max(2000),
    photoUrls: z.array(z.string().url()).max(10).default([]),
    signatureUrl: z.string().url().optional(),
});

const updateJobCardStatusSchema = z.object({
    status: z.enum(['INTAKE', 'DIAGNOSIS', 'AWAITING_PARTS', 'REPAIRING', 'QC', 'DELIVERED']),
    techNotes: z.string().max(1000).optional(),
});

const createRmaSchema = z.object({
    componentSerialId: z.string().uuid(),
    brand: z.string().min(1).max(100),
    reason: z.string().min(1).max(2000),
    oemRmaNumber: z.string().max(100).optional(),
});

const updateRmaStatusSchema = z.object({
    status: z.enum(['INITIATED', 'SHIPPED_TO_OEM', 'REPLACEMENT_RECEIVED', 'REJECTED_BY_OEM', 'RESOLVED']),
});

const addJobPartSchema = z.object({
    productId: z.string().uuid(),
    quantity: z.number().positive(),
    unitPrice: z.number().nonnegative(),
    notes: z.string().max(500).optional(),
});

const assignTechnicianSchema = z.object({
    technicianId: z.string().uuid(),
    technicianName: z.string().min(1).max(100),
});

const updateLaborCostSchema = z.object({
    estimatedLaborCost: z.number().nonnegative().optional(),
    actualLaborCost: z.number().nonnegative().optional(),
    diagnosis: z.string().max(2000).optional(),
});

const convertJobToInvoiceSchema = z.object({
    customerName: z.string().min(1).max(100),
    customerPhone: z.string().max(20).optional(),
    paymentMode: z.enum(['cash', 'upi', 'card', 'credit']).default('cash'),
    notes: z.string().max(1000).optional(),
    discountCents: z.number().nonnegative().default(0),
});

const registerWarrantySchema = z.object({
    serialNumber: z.string().min(1).max(150),
    productId: z.string().uuid(),
    warrantyPeriodMonths: z.number().positive().max(60),
    purchaseDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    invoiceId: z.string().uuid(),
    customerId: z.string().uuid().optional(),
});

const multiUnitConversionSchema = z.object({
    productId: z.string().uuid(),
    primaryUnit: z.enum(['pcs', 'box', 'set', 'bundle']),
    alternateUnit: z.enum(['pcs', 'box', 'set', 'bundle']),
    conversionRate: z.number().positive(), // e.g., 1 box = 10 pcs, rate = 10
});

// ── Handlers ────────────────────────────────────────────────────────────────

/**
 * POST /computer/checkout — Atomic PC build checkout with serial tracking.
 * Deducts stock for each component and records serial numbers.
 * Uses DynamoDB TransactWriteItems for atomicity (Document Client format).
 */
export const checkoutBuild = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(checkoutBuildSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    // Build transact items using Document Client format (auto-marshalled)
    const transactItems: any[] = [];

    for (const comp of body.components) {
        // Conditional stock deduction (currentStock >= 1)
        transactItems.push({
            Update: {
                TableName: TABLE_NAME,
                Key: { PK: pk, SK: Keys.productSK(comp.productId) },
                UpdateExpression: 'SET currentStock = currentStock - :one, updatedAt = :now',
                ConditionExpression: 'attribute_exists(PK) AND currentStock >= :one',
                ExpressionAttributeValues: { ':one': 1, ':now': now },
            },
        });

        // Record serial number
        const serialId = crypto.randomUUID();
        transactItems.push({
            Put: {
                TableName: TABLE_NAME,
                Item: {
                    PK: pk, SK: `COMPSERIAL#${serialId}`,
                    entityType: 'COMPUTER_COMPONENT_SERIAL',
                    tenantId: auth.tenantId,
                    id: serialId,
                    productId: comp.productId,
                    serialNumber: comp.serialNumber,
                    isSold: true,
                    invoiceId: body.invoiceId,
                    customerId: body.customerId || null,
                    soldAt: now, createdAt: now, updatedAt: now,
                },
                ConditionExpression: 'attribute_not_exists(PK)',
            },
        });
    }

    try {
        await transactWrite(transactItems);
        return response.success({ message: `PC build tracked: ${body.components.length} components` }, 201);
    } catch (err: any) {
        if (err.name === 'TransactionCanceledException') {
            logger.warn('PC build checkout failed — stock insufficient or duplicate serial', {
                invoiceId: body.invoiceId, error: err.message,
            });
            return response.conflict('Insufficient stock or duplicate serial number');
        }
        logger.error('PC build checkout error', { error: err.message });
        return response.internalError('Failed to process PC build checkout');
    }
}, COMPUTER_OPTS);

/**
 * POST /computer/job-cards — Create a new service job card.
 */
export const createJobCard = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(createJobCardSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = crypto.randomUUID();
    const now = new Date().toISOString();

    await putItem({
        PK: pk,
        SK: `COMPJOBCARD#${id}`,
        entityType: 'COMPUTER_JOB_CARD',
        tenantId: auth.tenantId,
        id,
        customerId: body.customerId || null,
        deviceBrand: body.deviceBrand,
        deviceModel: body.deviceModel,
        serialNumber: body.serialNumber || null,
        reportedIssue: body.reportedIssue,
        status: 'INTAKE',
        photoUrls: body.photoUrls,
        signatureUrl: body.signatureUrl || null,
        technicianId: null,
        createdAt: now,
        updatedAt: now,
    });
    await recordRevision(
        auth.tenantId,
        'computer_job_cards',
        id,
        'create',
        auth.sub,
        null,
        {
            id,
            customerId: body.customerId || null,
            deviceBrand: body.deviceBrand,
            deviceModel: body.deviceModel,
            status: 'INTAKE',
        },
        { source: 'computer.createJobCard' },
    );

    return response.success({ message: 'Job Card created', id }, 201);
}, COMPUTER_OPTS);

/**
 * PATCH /computer/job-cards/{id}/status — Update job card status.
 */
export const updateJobCardStatus = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const jobCardId = event.pathParameters?.id;
    if (!jobCardId) return response.badRequest('Missing job card ID');

    const valid = parseBody(updateJobCardStatusSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        const existing = await getItem<Record<string, any>>(pk, `COMPJOBCARD#${jobCardId}`);
        if (!existing) return response.notFound('Job card');
        await updateItem(pk, `COMPJOBCARD#${jobCardId}`, {
            updateExpression: 'SET #s = :status, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':status': body.status, ':now': now },
        });
        await recordRevision(
            auth.tenantId,
            'computer_job_cards',
            jobCardId,
            'status_change',
            auth.sub,
            { status: existing.status || null },
            { status: body.status },
            { source: 'computer.updateJobCardStatus' },
        );
        return response.success({ message: 'Job card status updated' });
    } catch (err: any) {
        logger.error('Failed to update job card status', { error: err.message });
        return response.internalError('Failed to update job card status');
    }
}, COMPUTER_OPTS);

/**
 * GET /computer/job-cards — List job cards for this tenant.
 */
export const getJobCards = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const status = event.queryStringParameters?.status;

    const filterParts: string[] = ['(attribute_not_exists(isDeleted) OR isDeleted = :false)'];
    const exprValues: Record<string, any> = { ':false': false };

    if (status) {
        filterParts.push('#s = :status');
        exprValues[':status'] = status;
    }

    const jobs = await queryItems<Record<string, any>>(pk, 'COMPJOBCARD#', {
        filterExpression: filterParts.join(' AND '),
        expressionAttributeValues: exprValues,
        ...(status ? { expressionAttributeNames: { '#s': 'status' } } : {}),
    });

    return response.success(jobs.items);
}, COMPUTER_OPTS);

/**
 * POST /computer/rma — Create RMA (Return Merchandise Authorization).
 */
export const createRma = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(createRmaSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = crypto.randomUUID();
    const now = new Date().toISOString();

    await putItem({
        PK: pk,
        SK: `COMPRMA#${id}`,
        entityType: 'COMPUTER_RMA',
        tenantId: auth.tenantId,
        id,
        componentSerialId: body.componentSerialId,
        brand: body.brand,
        reason: body.reason,
        status: 'INITIATED',
        oemRmaNumber: body.oemRmaNumber || null,
        shippedAt: null,
        resolvedAt: null,
        createdAt: now,
        updatedAt: now,
    });
    await recordRevision(
        auth.tenantId,
        'computer_rma',
        id,
        'create',
        auth.sub,
        null,
        {
            id,
            componentSerialId: body.componentSerialId,
            brand: body.brand,
            status: 'INITIATED',
        },
        { source: 'computer.createRma' },
    );

    return response.success({ message: 'RMA created', id }, 201);
}, COMPUTER_OPTS);

/**
 * PATCH /computer/rma/{id}/status — Update RMA status.
 */
export const updateRmaStatus = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const rmaId = event.pathParameters?.id;
    if (!rmaId) return response.badRequest('Missing RMA ID');

    const valid = parseBody(updateRmaStatusSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const updateParts = ['#s = :status', 'updatedAt = :now'];
    const exprValues: Record<string, any> = { ':status': body.status, ':now': now };

    if (body.status === 'SHIPPED_TO_OEM') {
        updateParts.push('shippedAt = :shipped');
        exprValues[':shipped'] = now;
    } else if (['REPLACEMENT_RECEIVED', 'REJECTED_BY_OEM', 'RESOLVED'].includes(body.status)) {
        updateParts.push('resolvedAt = :resolved');
        exprValues[':resolved'] = now;
    }

    try {
        const existing = await getItem<Record<string, any>>(pk, `COMPRMA#${rmaId}`);
        if (!existing) return response.notFound('RMA');
        await updateItem(pk, `COMPRMA#${rmaId}`, {
            updateExpression: `SET ${updateParts.join(', ')}`,
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: exprValues,
        });
        await recordRevision(
            auth.tenantId,
            'computer_rma',
            rmaId,
            'status_change',
            auth.sub,
            { status: existing.status || null },
            { status: body.status },
            { source: 'computer.updateRmaStatus' },
        );
        return response.success({ message: 'RMA status updated' });
    } catch (err: any) {
        logger.error('Failed to update RMA status', { error: err.message });
        return response.internalError('Failed to update RMA status');
    }
}, COMPUTER_OPTS);

/**
 * GET /computer/serials — List component serials (with optional invoice filter).
 */
export const getSerials = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const invoiceId = event.queryStringParameters?.invoiceId;

    const filterParts: string[] = [];
    const exprValues: Record<string, any> = {};

    if (invoiceId) {
        filterParts.push('invoiceId = :inv');
        exprValues[':inv'] = invoiceId;
    }

    const serials = await queryItems<Record<string, any>>(pk, 'COMPSERIAL#', {
        ...(filterParts.length > 0 ? {
            filterExpression: filterParts.join(' AND '),
            expressionAttributeValues: exprValues,
        } : {}),
    });

    return response.success(serials.items);
}, COMPUTER_OPTS);

// ============================================================================
// JOB CARD ENHANCEMENTS — Parts, Technician, Labor, Conversion
// ============================================================================

/**
 * POST /computer/job-cards/{id}/parts — Add parts to a job and deduct inventory.
 * CRITICAL FIX: Was missing - now implemented with atomic stock deduction.
 */
export const addJobPart = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const jobCardId = event.pathParameters?.id;
    if (!jobCardId) return response.badRequest('Missing job card ID');

    const valid = parseBody(addJobPartSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    // Verify job exists and is not delivered/cancelled
    const job = await getItem<Record<string, any>>(pk, `COMPJOBCARD#${jobCardId}`);
    if (!job) return response.notFound('Job card');
    if (job.status === 'DELIVERED' || job.isDeleted) {
        return response.conflict('Cannot add parts to delivered or deleted job');
    }

    // Get product details
    const product = await getItem<Record<string, any>>(pk, Keys.productSK(body.productId));
    if (!product) return response.notFound('Product');

    // Check stock availability
    if ((product.currentStock || 0) < body.quantity) {
        return response.conflict(`Insufficient stock: ${product.currentStock || 0} available, ${body.quantity} requested`);
    }

    const partId = crypto.randomUUID();
    const totalCost = body.quantity * body.unitPrice;

    // Atomic transaction: deduct stock + record part usage
    try {
        await transactWrite([
            {
                Update: {
                    TableName: TABLE_NAME,
                    Key: { PK: pk, SK: Keys.productSK(body.productId) },
                    UpdateExpression: 'SET currentStock = currentStock - :qty, updatedAt = :now',
                    ConditionExpression: 'currentStock >= :qty',
                    ExpressionAttributeValues: { ':qty': body.quantity, ':now': now },
                },
            },
            {
                Put: {
                    TableName: TABLE_NAME,
                    Item: {
                        PK: pk,
                        SK: `JOBPART#${partId}`,
                        entityType: 'COMPUTER_JOB_PART',
                        tenantId: auth.tenantId,
                        id: partId,
                        jobCardId,
                        productId: body.productId,
                        productName: product.name,
                        quantity: body.quantity,
                        unitPrice: body.unitPrice,
                        totalCost,
                        notes: body.notes || null,
                        createdAt: now,
                        updatedAt: now,
                    },
                },
            },
            {
                Update: {
                    TableName: TABLE_NAME,
                    Key: { PK: pk, SK: `COMPJOBCARD#${jobCardId}` },
                    UpdateExpression: 'SET actualPartsCost = if_not_exists(actualPartsCost, :zero) + :cost, updatedAt = :now',
                    ExpressionAttributeValues: { ':cost': totalCost, ':zero': 0, ':now': now },
                },
            },
        ]);

        await recordRevision(
            auth.tenantId,
            'computer_job_cards',
            jobCardId,
            'update',
            auth.sub,
            { actualPartsCost: job.actualPartsCost || 0 },
            { actualPartsCost: (job.actualPartsCost || 0) + totalCost, partId, productId: body.productId },
            { source: 'computer.addJobPart' },
        );

        return response.success({ message: 'Part added to job', partId }, 201);
    } catch (err: any) {
        if (err.name === 'TransactionCanceledException') {
            return response.conflict('Stock was modified by another transaction. Please retry.');
        }
        logger.error('Failed to add job part', { error: err.message, jobCardId });
        return response.internalError('Failed to add part to job');
    }
}, COMPUTER_OPTS);

/**
 * PATCH /computer/job-cards/{id}/assign — Assign technician to job.
 * HIGH FIX: Was missing - now implemented with revision tracking.
 * ROLE FIX: Restricted to Owner/Admin/Manager only.
 */
export const assignTechnician = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const jobCardId = event.pathParameters?.id;
    if (!jobCardId) return response.badRequest('Missing job card ID');

    const valid = parseBody(assignTechnicianSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const existing = await getItem<Record<string, any>>(pk, `COMPJOBCARD#${jobCardId}`);
    if (!existing) return response.notFound('Job card');

    await updateItem(pk, `COMPJOBCARD#${jobCardId}`, {
        updateExpression: 'SET technicianId = :techId, technicianName = :techName, updatedAt = :now',
        expressionAttributeValues: { ':techId': body.technicianId, ':techName': body.technicianName, ':now': now },
    });

    await recordRevision(
        auth.tenantId,
        'computer_job_cards',
        jobCardId,
        'update',
        auth.sub,
        { technicianId: existing.technicianId || null },
        { technicianId: body.technicianId, technicianName: body.technicianName },
        { source: 'computer.assignTechnician' },
    );

    return response.success({ message: 'Technician assigned', technicianId: body.technicianId });
}, COMPUTER_OPTS);

/**
 * PATCH /computer/job-cards/{id}/labor — Update labor costs and diagnosis.
 */
export const updateLaborCost = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const jobCardId = event.pathParameters?.id;
    if (!jobCardId) return response.badRequest('Missing job card ID');

    const valid = parseBody(updateLaborCostSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const existing = await getItem<Record<string, any>>(pk, `COMPJOBCARD#${jobCardId}`);
    if (!existing) return response.notFound('Job card');

    const updateParts: string[] = ['updatedAt = :now'];
    const exprValues: Record<string, any> = { ':now': now };
    const newValues: Record<string, any> = {};

    if (body.estimatedLaborCost !== undefined) {
        updateParts.push('estimatedLaborCost = :estLabor');
        exprValues[':estLabor'] = body.estimatedLaborCost;
        newValues.estimatedLaborCost = body.estimatedLaborCost;
    }
    if (body.actualLaborCost !== undefined) {
        updateParts.push('actualLaborCost = :actLabor');
        exprValues[':actLabor'] = body.actualLaborCost;
        newValues.actualLaborCost = body.actualLaborCost;
    }
    if (body.diagnosis !== undefined) {
        updateParts.push('diagnosis = :diag');
        exprValues[':diag'] = body.diagnosis;
        newValues.diagnosis = body.diagnosis;
    }

    await updateItem(pk, `COMPJOBCARD#${jobCardId}`, {
        updateExpression: `SET ${updateParts.join(', ')}`,
        expressionAttributeValues: exprValues,
    });

    await recordRevision(
        auth.tenantId,
        'computer_job_cards',
        jobCardId,
        'update',
        auth.sub,
        { estimatedLaborCost: existing.estimatedLaborCost, actualLaborCost: existing.actualLaborCost, diagnosis: existing.diagnosis },
        newValues,
        { source: 'computer.updateLaborCost' },
    );

    return response.success({ message: 'Labor costs updated' });
}, COMPUTER_OPTS);

/**
 * POST /computer/job-cards/{id}/convert-to-invoice — Convert completed job to invoice.
 * CRITICAL FIX: Was missing - creates invoice from job labor + parts.
 * ROLE FIX: Restricted to Owner/Admin/Manager only.
 */
export const convertJobToInvoice = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const jobCardId = event.pathParameters?.id;
    if (!jobCardId) return response.badRequest('Missing job card ID');

    const valid = parseBody(convertJobToInvoiceSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);

    // Get job with all parts
    const job = await getItem<Record<string, any>>(pk, `COMPJOBCARD#${jobCardId}`);
    if (!job) return response.notFound('Job card');
    if (job.status !== 'QC' && job.status !== 'REPAIRING' && job.status !== 'DELIVERED') {
        return response.conflict('Job must be in QC, REPAIRING, or DELIVERED status to convert');
    }
    if (job.invoiceId) {
        return response.conflict('Job already converted to invoice: ' + job.invoiceId);
    }

    // Get all parts used
    const partsResult = await queryItems<Record<string, any>>(pk, 'JOBPART#', {
        filterExpression: 'jobCardId = :jobId',
        expressionAttributeValues: { ':jobId': jobCardId },
    });
    const parts = partsResult.items;

    // Calculate totals
    const laborCost = job.actualLaborCost || job.estimatedLaborCost || 0;
    const partsCost = parts.reduce((sum: number, p: any) => sum + (p.totalCost || 0), 0);
    const subtotal = laborCost + partsCost;
    const discount = body.discountCents || 0;
    const taxableAmount = Math.max(0, subtotal - discount);
    const taxRate = 0.18; // 18% GST for computer services
    const taxAmount = Math.round(taxableAmount * taxRate);
    const totalAmount = taxableAmount + taxAmount;

    // Import invoice service to create invoice
    const { createInvoice } = await import('../services/invoice.service');

    try {
        // Build invoice items
        const invoiceItems: any[] = [];

        // Add labor as line item
        if (laborCost > 0) {
            invoiceItems.push({
                productId: 'SERVICE-LABOR',
                name: `Repair Labor - ${job.deviceBrand} ${job.deviceModel}`,
                quantity: 1,
                unitPrice: laborCost,
                hsnCode: '998712', // Repair services HSN
            });
        }

        // Add parts as line items
        for (const part of parts) {
            invoiceItems.push({
                productId: part.productId,
                name: part.productName || 'Repair Part',
                quantity: part.quantity,
                unitPrice: part.unitPrice,
            });
        }

        const invoice = await createInvoice(
            auth.tenantId,
            auth.sub,
            {
                items: invoiceItems,
                customerName: body.customerName,
                customerPhone: body.customerPhone,
                paymentMode: body.paymentMode,
                notes: body.notes || `Converted from Job Card #${job.jobNumber || jobCardId}`,
                discountCents: discount,
            },
            auth.role,
            BusinessType.COMPUTER_SHOP,
        );

        // Update job with invoice reference
        const now = new Date().toISOString();
        await updateItem(pk, `COMPJOBCARD#${jobCardId}`, {
            updateExpression: 'SET invoiceId = :invId, invoiceNumber = :invNum, status = :status, updatedAt = :now',
            expressionAttributeValues: { ':invId': invoice.id, ':invNum': invoice.invoiceNumber, ':status': 'DELIVERED', ':now': now },
        });

        await recordRevision(
            auth.tenantId,
            'computer_job_cards',
            jobCardId,
            'status_change',
            auth.sub,
            { invoiceId: null, status: job.status },
            { invoiceId: invoice.id, invoiceNumber: invoice.invoiceNumber, status: 'DELIVERED' },
            { source: 'computer.convertJobToInvoice' },
        );

        return response.success({
            message: 'Job converted to invoice',
            jobCardId,
            invoiceId: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            totalAmount,
            laborCost,
            partsCost,
            partsUsed: parts.length,
        }, 201);
    } catch (err: any) {
        logger.error('Failed to convert job to invoice', { error: err.message, jobCardId });
        return response.internalError('Failed to convert job to invoice: ' + err.message);
    }
}, COMPUTER_OPTS);

/**
 * GET /computer/job-cards/{id}/parts — List parts used on a job.
 */
export const getJobParts = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const jobCardId = event.pathParameters?.id;
    if (!jobCardId) return response.badRequest('Missing job card ID');

    const pk = Keys.tenantPK(auth.tenantId);

    const parts = await queryItems<Record<string, any>>(pk, 'JOBPART#', {
        filterExpression: 'jobCardId = :jobId',
        expressionAttributeValues: { ':jobId': jobCardId },
    });

    return response.success(parts.items);
}, COMPUTER_OPTS);

// ============================================================================
// WARRANTY MANAGEMENT
// ============================================================================

/**
 * POST /computer/warranty — Register warranty for a serial number.
 * HIGH FIX: Warranty registration endpoint was missing.
 */
export const registerWarranty = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(registerWarrantySchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    // Calculate warranty expiry
    const purchaseDate = new Date(body.purchaseDate);
    const expiryDate = new Date(purchaseDate);
    expiryDate.setMonth(expiryDate.getMonth() + body.warrantyPeriodMonths);

    const warrantyId = crypto.randomUUID();

    await putItem({
        PK: pk,
        SK: `COMPWARRANTY#${warrantyId}`,
        entityType: 'COMPUTER_WARRANTY',
        tenantId: auth.tenantId,
        id: warrantyId,
        serialNumber: body.serialNumber,
        productId: body.productId,
        invoiceId: body.invoiceId,
        customerId: body.customerId || null,
        warrantyPeriodMonths: body.warrantyPeriodMonths,
        purchaseDate: body.purchaseDate,
        warrantyExpiryDate: expiryDate.toISOString().slice(0, 10),
        status: 'ACTIVE',
        claimCount: 0,
        createdAt: now,
        updatedAt: now,
    });

    // Also update the serial record with warranty info
    try {
        const serialResult = await queryItems<Record<string, any>>(pk, 'COMPSERIAL#', {
            filterExpression: 'serialNumber = :serial',
            expressionAttributeValues: { ':serial': body.serialNumber },
            limit: 1,
        });
        if (serialResult.items.length > 0) {
            const serial = serialResult.items[0];
            await updateItem(pk, serial.SK, {
                updateExpression: 'SET warrantyExpiryDate = :expiry, warrantyId = :warrantyId, updatedAt = :now',
                expressionAttributeValues: { ':expiry': expiryDate.toISOString().slice(0, 10), ':warrantyId': warrantyId, ':now': now },
            });
        }
    } catch (e) {
        logger.warn('Failed to link warranty to serial record', { error: e, serialNumber: body.serialNumber });
    }

    return response.success({
        message: 'Warranty registered',
        warrantyId,
        warrantyExpiryDate: expiryDate.toISOString().slice(0, 10),
    }, 201);
}, COMPUTER_OPTS);

/**
 * GET /computer/warranty — Query warranty by serial number.
 * HIGH FIX: Warranty lookup was missing.
 */
export const getWarranty = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const serialNumber = event.queryStringParameters?.serial;
    const warrantyId = event.queryStringParameters?.warrantyId;

    if (!serialNumber && !warrantyId) {
        return response.badRequest('Either serial number or warrantyId is required');
    }

    const pk = Keys.tenantPK(auth.tenantId);

    let warranty: Record<string, any> | null = null;

    if (warrantyId) {
        warranty = await getItem<Record<string, any>>(pk, `COMPWARRANTY#${warrantyId}`);
    } else if (serialNumber) {
        // Query by serial number (GSI would be better, but filter for now)
        const result = await queryItems<Record<string, any>>(pk, 'COMPWARRANTY#', {
            filterExpression: 'serialNumber = :serial',
            expressionAttributeValues: { ':serial': serialNumber },
            limit: 1,
        });
        warranty = result.items[0] || null;

        // Also check the serial record
        if (!warranty) {
            const serialResult = await queryItems<Record<string, any>>(pk, 'COMPSERIAL#', {
                filterExpression: 'serialNumber = :serial AND attribute_exists(warrantyExpiryDate)',
                expressionAttributeValues: { ':serial': serialNumber },
                limit: 1,
            });
            if (serialResult.items.length > 0) {
                const serial = serialResult.items[0];
                warranty = {
                    serialNumber: serial.serialNumber,
                    productId: serial.productId,
                    productName: serial.productName,
                    invoiceId: serial.invoiceId,
                    warrantyExpiryDate: serial.warrantyExpiryDate,
                    status: new Date(serial.warrantyExpiryDate) > new Date() ? 'ACTIVE' : 'EXPIRED',
                };
            }
        }
    }

    if (!warranty) {
        return response.notFound('Warranty');
    }

    // Calculate status if not set
    const now = new Date();
    const expiry = new Date(warranty.warrantyExpiryDate || warranty.soldAt || now);
    const daysRemaining = Math.ceil((expiry.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

    return response.success({
        ...warranty,
        status: warranty.status || (daysRemaining > 0 ? 'ACTIVE' : 'EXPIRED'),
        daysRemaining: daysRemaining > 0 ? daysRemaining : 0,
        isExpired: daysRemaining <= 0,
    });
}, COMPUTER_OPTS);

/**
 * GET /computer/serials/{serial}/history — Get service history for a serial.
 * MEDIUM FIX: Service history lookup was missing.
 */
export const getSerialHistory = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const serialNumber = event.pathParameters?.serial;
    if (!serialNumber) return response.badRequest('Missing serial number');

    const pk = Keys.tenantPK(auth.tenantId);

    // Get serial record
    const serialResult = await queryItems<Record<string, any>>(pk, 'COMPSERIAL#', {
        filterExpression: 'serialNumber = :serial',
        expressionAttributeValues: { ':serial': serialNumber },
        limit: 1,
    });

    if (serialResult.items.length === 0) {
        return response.notFound('Serial number');
    }

    const serial = serialResult.items[0];

    // Get related job cards (by serial number)
    const jobsResult = await queryItems<Record<string, any>>(pk, 'COMPJOBCARD#', {
        filterExpression: 'serialNumber = :serial',
        expressionAttributeValues: { ':serial': serialNumber },
    });

    // Get related RMAs (by component serial ID)
    const rmaResult = await queryItems<Record<string, any>>(pk, 'COMPRMA#', {
        filterExpression: 'componentSerialId = :serialId',
        expressionAttributeValues: { ':serialId': serial.id },
    });

    // Get warranty info
    const warrantyResult = await queryItems<Record<string, any>>(pk, 'COMPWARRANTY#', {
        filterExpression: 'serialNumber = :serial',
        expressionAttributeValues: { ':serial': serialNumber },
        limit: 1,
    });

    return response.success({
        serial: {
            serialNumber: serial.serialNumber,
            productId: serial.productId,
            productName: serial.productName,
            invoiceId: serial.invoiceId,
            invoiceNumber: serial.invoiceNumber,
            customerId: serial.customerId,
            soldAt: serial.soldAt,
        },
        serviceHistory: {
            jobCards: jobsResult.items.map((j: any) => ({
                id: j.id,
                status: j.status,
                reportedIssue: j.reportedIssue,
                diagnosis: j.diagnosis,
                technicianName: j.technicianName,
                actualLaborCost: j.actualLaborCost,
                actualPartsCost: j.actualPartsCost,
                createdAt: j.createdAt,
                updatedAt: j.updatedAt,
            })),
            rmas: rmaResult.items.map((r: any) => ({
                id: r.id,
                status: r.status,
                reason: r.reason,
                brand: r.brand,
                oemRmaNumber: r.oemRmaNumber,
                createdAt: r.createdAt,
            })),
        },
        warranty: warrantyResult.items[0] || null,
    });
}, COMPUTER_OPTS);

// ============================================================================
// MULTI-UNIT (BOX/PCS) SUPPORT
// ============================================================================

/**
 * POST /computer/products/multi-unit — Configure multi-unit conversion.
 * CRITICAL FIX: Multi-unit support was missing for Computer Shop.
 * ROLE FIX: Restricted to Owner/Admin/Manager only.
 */
export const setMultiUnitConversion = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const valid = parseBody(multiUnitConversionSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    // Verify product exists
    const product = await getItem<Record<string, any>>(pk, Keys.productSK(body.productId));
    if (!product) return response.notFound('Product');

    await updateItem(pk, Keys.productSK(body.productId), {
        updateExpression: 'SET primaryUnit = :primaryUnit, alternateUnit = :altUnit, conversionRate = :rate, updatedAt = :now',
        expressionAttributeValues: {
            ':primaryUnit': body.primaryUnit,
            ':altUnit': body.alternateUnit,
            ':rate': body.conversionRate,
            ':now': now,
        },
    });

    await recordRevision(
        auth.tenantId,
        'products',
        body.productId,
        'update',
        auth.sub,
        { primaryUnit: product.primaryUnit, alternateUnit: product.alternateUnit },
        { primaryUnit: body.primaryUnit, alternateUnit: body.alternateUnit, conversionRate: body.conversionRate },
        { source: 'computer.setMultiUnitConversion' },
    );

    return response.success({
        message: 'Multi-unit configuration saved',
        productId: body.productId,
        primaryUnit: body.primaryUnit,
        alternateUnit: body.alternateUnit,
        conversionRate: body.conversionRate,
    });
}, COMPUTER_OPTS);

/**
 * POST /computer/stock/convert-unit — Convert between units (e.g., box to pcs).
 */
export const convertStockUnit = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
    event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
    const schema = z.object({
        productId: z.string().uuid(),
        fromUnit: z.enum(['pcs', 'box', 'set', 'bundle']),
        toUnit: z.enum(['pcs', 'box', 'set', 'bundle']),
        quantity: z.number().positive(),
    });

    const valid = parseBody(schema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;

    const pk = Keys.tenantPK(auth.tenantId);

    const product = await getItem<Record<string, any>>(pk, Keys.productSK(body.productId));
    if (!product) return response.notFound('Product');

    if (!product.conversionRate) {
        return response.conflict('Product does not have multi-unit configuration');
    }

    // Calculate conversion
    let convertedQty: number;
    if (body.fromUnit === product.primaryUnit && body.toUnit === product.alternateUnit) {
        // Primary to alternate (e.g., pcs to box) - divide
        convertedQty = body.quantity / product.conversionRate;
    } else if (body.fromUnit === product.alternateUnit && body.toUnit === product.primaryUnit) {
        // Alternate to primary (e.g., box to pcs) - multiply
        convertedQty = body.quantity * product.conversionRate;
    } else {
        return response.badRequest('Invalid unit conversion');
    }

    return response.success({
        productId: body.productId,
        productName: product.name,
        from: { unit: body.fromUnit, quantity: body.quantity },
        to: { unit: body.toUnit, quantity: convertedQty },
        conversionRate: product.conversionRate,
    });
}, COMPUTER_OPTS);
