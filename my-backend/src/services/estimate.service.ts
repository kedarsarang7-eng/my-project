// ============================================================================
// Estimate / Quotation Service — Hardware Shop
// ============================================================================
// Handles estimate CRUD and conversion to invoice.
// Hardware shops heavily use estimates: contractors request quotes for materials
// (cement, steel, plumbing) before issuing purchase orders.
//
// DynamoDB:
//   PK = TENANT#{tenantId}, SK = ESTIMATE#{estimateId}
//   Line items: PK = ESTIMATE#{estimateId}, SK = ESTLINE#{lineItemId}
//   Numbering: EST-{YYYYMM}-{seq} (atomic counter)
//
// FEATURE GATE: HARDWARE_ESTIMATE_TO_INVOICE
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    Keys, TABLE_NAME,
    getItem, putItem, queryItems, updateItem, transactWrite, batchWrite,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';
import { logAudit } from '../middleware/audit';
import { createInvoice, CreateInvoiceInput, InvoiceResult } from './invoice.service';
import { config } from '../config/environment';

// ── Types ──────────────────────────────────────────────────────────────────

export interface EstimateItemInput {
    productId: string;
    name: string;
    quantity: number;
    unitPriceCents: number;
    unit?: string;
    hsnCode?: string;
    cgstRateBp?: number;
    sgstRateBp?: number;
    igstRateBp?: number;
    notes?: string;
}

export interface CreateEstimateInput {
    items: EstimateItemInput[];
    customerName?: string;
    customerPhone?: string;
    customerGstin?: string;
    validityDays?: number;      // Default 15 days
    isInterState?: boolean;
    notes?: string;
    metadata?: Record<string, unknown>;
}

export interface EstimateResult {
    id: string;
    estimateNumber: string;
    status: string;
    subtotalCents: number;
    taxCents: number;
    totalCents: number;
    itemsCount: number;
    validUntil: string;
    createdAt: string;
}

class EstimateError extends AppError {
    constructor(message: string, statusCode = 400) {
        super(message, statusCode, 'ESTIMATE_ERROR');
        this.name = 'EstimateError';
    }
}

// ── Service Functions ──────────────────────────────────────────────────────

/**
 * Create an estimate/quotation.
 * No stock deduction — estimates are non-financial documents.
 */
export async function createEstimate(
    tenantId: string,
    createdBy: string,
    input: CreateEstimateInput,
): Promise<EstimateResult> {
    if (!input.items || input.items.length === 0) {
        throw new EstimateError('Estimate must have at least one item');
    }

    const estimateId = uuidv4();
    const now = new Date().toISOString();
    const tableName = config.dynamodb.tableName;

    // Atomic estimate number generation
    const datePrefix = now.slice(0, 7).replace('-', ''); // YYYYMM
    const counterResult = await updateItem(
        Keys.tenantPK(tenantId),
        `COUNTER#ESTIMATE#${datePrefix}`,
        {
            updateExpression: 'ADD counterValue :inc',
            expressionAttributeValues: { ':inc': 1 },
        },
    );
    const seq = (counterResult as any).counterValue || 1;
    const estimateNumber = `EST-${datePrefix}-${String(seq).padStart(5, '0')}`;

    // Calculate totals (no rounding — estimates are indicative)
    let subtotalCents = 0;
    let taxCents = 0;

    const resolvedItems: Array<{
        lineItemId: string;
        productId: string;
        name: string;
        quantity: number;
        unitPriceCents: number;
        unit: string;
        lineTotalCents: number;
        lineTaxCents: number;
        hsnCode: string | null;
        cgstCents: number;
        sgstCents: number;
        igstCents: number;
    }> = [];

    for (const item of input.items) {
        const lineItemId = uuidv4();
        const lineGross = Math.round(item.unitPriceCents * item.quantity);

        let lineCgstCents = 0;
        let lineSgstCents = 0;
        let lineIgstCents = 0;

        if (input.isInterState) {
            const igstBp = (item.igstRateBp || 0) || ((item.cgstRateBp || 0) + (item.sgstRateBp || 0));
            lineIgstCents = Math.round(lineGross * igstBp / 10000);
        } else {
            lineCgstCents = Math.round(lineGross * (item.cgstRateBp || 0) / 10000);
            lineSgstCents = Math.round(lineGross * (item.sgstRateBp || 0) / 10000);
        }
        const lineTaxCents = lineCgstCents + lineSgstCents + lineIgstCents;

        subtotalCents += lineGross;
        taxCents += lineTaxCents;

        resolvedItems.push({
            lineItemId,
            productId: item.productId,
            name: item.name,
            quantity: item.quantity,
            unitPriceCents: item.unitPriceCents,
            unit: item.unit || 'pcs',
            lineTotalCents: lineGross + lineTaxCents,
            lineTaxCents,
            hsnCode: item.hsnCode || null,
            cgstCents: lineCgstCents,
            sgstCents: lineSgstCents,
            igstCents: lineIgstCents,
        });
    }

    const totalCents = subtotalCents + taxCents;
    const validityDays = input.validityDays || 15;
    const validUntil = new Date(Date.now() + validityDays * 86400000).toISOString();

    // Build estimate record
    const estimateItem: Record<string, any> = {
        PK: Keys.tenantPK(tenantId),
        SK: Keys.estimateSK(estimateId),
        GSI1PK: Keys.tenantPK(tenantId),
        GSI1SK: Keys.estimateNumGSI1SK(estimateNumber),
        entityType: 'ESTIMATE',
        id: estimateId,
        tenantId,
        estimateNumber,
        customerName: input.customerName || 'Walk-in',
        customerPhone: input.customerPhone || null,
        customerGstin: input.customerGstin || null,
        isInterState: input.isInterState || false,
        subtotalCents,
        taxCents,
        totalCents,
        itemsCount: resolvedItems.length,
        status: 'active',
        validUntil,
        notes: input.notes || null,
        metadata: input.metadata || {},
        createdBy,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
    };

    // Build line item records
    const lineItemRecords = resolvedItems.map(ri => ({
        PK: Keys.estimateLineItemPK(estimateId),
        SK: Keys.estimateLineItemSK(ri.lineItemId),
        entityType: 'ESTIMATE_LINE_ITEM',
        estimateId,
        ...ri,
        createdAt: now,
    }));

    // Write header + line items
    const transactItems: any[] = [
        { Put: { TableName: tableName, Item: estimateItem } },
    ];

    if (lineItemRecords.length <= 24) {
        // All fit in one transaction
        for (const li of lineItemRecords) {
            transactItems.push({ Put: { TableName: tableName, Item: li } });
        }
        await transactWrite(transactItems);
    } else {
        // Header in transaction, line items in batch
        await transactWrite(transactItems);
        await batchWrite(lineItemRecords.map(item => ({ type: 'put' as const, item })));
    }

    logAudit({
        action: 'ESTIMATE_CREATED',
        resource: 'estimate',
        resourceId: estimateId,
        metadata: { estimateNumber, totalCents, itemsCount: resolvedItems.length },
    }).catch(() => { });

    logger.info('Estimate created', {
        tenantId, estimateNumber, totalCents, items: resolvedItems.length,
    });

    return {
        id: estimateId,
        estimateNumber,
        status: 'active',
        subtotalCents,
        taxCents,
        totalCents,
        itemsCount: resolvedItems.length,
        validUntil,
        createdAt: now,
    };
}

/**
 * Get a single estimate by ID.
 */
export async function getEstimate(
    tenantId: string,
    estimateId: string,
): Promise<Record<string, any> | null> {
    const estimate = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId), Keys.estimateSK(estimateId),
    );
    if (!estimate || estimate.isDeleted) return null;

    // Fetch line items
    const lineItems = await queryItems<Record<string, any>>(
        Keys.estimateLineItemPK(estimateId), 'ESTLINE#',
    );

    return { ...estimate, lineItems: lineItems.items };
}

/**
 * List estimates with optional status filter.
 */
export async function listEstimates(
    tenantId: string,
    options?: { status?: string; limit?: number; cursor?: Record<string, unknown> },
): Promise<{ items: Record<string, any>[]; lastKey?: Record<string, unknown> }> {
    const limit = options?.limit || 20;

    const result = await queryItems<Record<string, any>>(
        Keys.tenantPK(tenantId), 'ESTIMATE#',
        {
            filterExpression: options?.status
                ? '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND #s = :status'
                : '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':false': false,
                ...(options?.status ? { ':status': options.status } : {}),
            },
            expressionAttributeNames: options?.status ? { '#s': 'status' } : undefined,
            limit,
        },
    );

    return { items: result.items, lastKey: result.lastKey as Record<string, unknown> };
}

/**
 * Convert estimate to invoice.
 * Atomic: marks estimate as 'converted', creates invoice via createInvoice().
 */
export async function convertToInvoice(
    tenantId: string,
    estimateId: string,
    createdBy: string,
    userRole?: string,
    businessType?: string,
): Promise<InvoiceResult> {
    const estimate = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId), Keys.estimateSK(estimateId),
    );

    if (!estimate || estimate.isDeleted) {
        throw new EstimateError(`Estimate not found: ${estimateId}`, 404);
    }

    if (estimate.status === 'converted') {
        throw new EstimateError(
            `Estimate ${estimate.estimateNumber} has already been converted to invoice ${estimate.convertedInvoiceId}.`,
            409,
        );
    }

    if (estimate.status === 'voided') {
        throw new EstimateError(`Estimate ${estimate.estimateNumber} is voided and cannot be converted.`, 400);
    }

    // Fetch line items
    const lineItems = await queryItems<Record<string, any>>(
        Keys.estimateLineItemPK(estimateId), 'ESTLINE#',
    );

    // Build invoice input from estimate line items
    const invoiceInput: CreateInvoiceInput = {
        items: lineItems.items.map(li => ({
            productId: li.productId,
            quantity: li.quantity,
            unitPrice: li.unitPriceCents,
            unit: li.unit,
        })),
        customerName: estimate.customerName,
        customerPhone: estimate.customerPhone,
        customerGstin: estimate.customerGstin,
        isInterState: estimate.isInterState,
        notes: `Converted from estimate ${estimate.estimateNumber}. ${estimate.notes || ''}`.trim(),
        metadata: {
            ...(estimate.metadata || {}),
            sourceEstimateId: estimateId,
            sourceEstimateNumber: estimate.estimateNumber,
        },
    };

    // Create invoice
    const invoiceResult = await createInvoice(tenantId, createdBy, invoiceInput, userRole, businessType);

    // Mark estimate as converted
    await updateItem(Keys.tenantPK(tenantId), Keys.estimateSK(estimateId), {
        updateExpression: 'SET #s = :converted, convertedInvoiceId = :invId, convertedAt = :now, updatedAt = :now',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: {
            ':converted': 'converted',
            ':invId': invoiceResult.id,
            ':now': new Date().toISOString(),
        },
    });

    logAudit({
        action: 'ESTIMATE_CONVERTED',
        resource: 'estimate',
        resourceId: estimateId,
        metadata: {
            estimateNumber: estimate.estimateNumber,
            invoiceId: invoiceResult.id,
            invoiceNumber: invoiceResult.invoiceNumber,
        },
    }).catch(() => { });

    logger.info('Estimate converted to invoice', {
        tenantId, estimateId, estimateNumber: estimate.estimateNumber,
        invoiceId: invoiceResult.id, invoiceNumber: invoiceResult.invoiceNumber,
    });

    return invoiceResult;
}

/**
 * Void an estimate.
 */
export async function voidEstimate(
    tenantId: string,
    estimateId: string,
    reason: string,
): Promise<{ id: string; status: string }> {
    const estimate = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId), Keys.estimateSK(estimateId),
    );

    if (!estimate || estimate.isDeleted) {
        throw new EstimateError(`Estimate not found: ${estimateId}`, 404);
    }

    if (estimate.status === 'converted') {
        throw new EstimateError(
            `Cannot void converted estimate — invoice ${estimate.convertedInvoiceId} already exists.`,
            400,
        );
    }

    await updateItem(Keys.tenantPK(tenantId), Keys.estimateSK(estimateId), {
        updateExpression: 'SET #s = :voided, voidReason = :reason, updatedAt = :now',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: {
            ':voided': 'voided',
            ':reason': reason,
            ':now': new Date().toISOString(),
        },
    });

    logAudit({
        action: 'ESTIMATE_VOIDED',
        resource: 'estimate',
        resourceId: estimateId,
        metadata: { estimateNumber: estimate.estimateNumber, reason },
    }).catch(() => { });

    return { id: estimateId, status: 'voided' };
}
