// ============================================================================
// Delivery Challan Service — Hardware Shop
// ============================================================================
// Delivery challans are legally required documents for material movement.
// They track goods dispatched to a customer site (e.g., construction site).
//
// DynamoDB: PK = TENANT#{tenantId}, SK = CHALLAN#{challanId}
// Numbering: DC-{YYYYMM}-{seq} (atomic counter)
//
// FEATURE GATE: HARDWARE_DELIVERY_CHALLAN
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    Keys, TABLE_NAME,
    getItem, putItem, queryItems, updateItem,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';
import { logAudit } from '../middleware/audit';

// ── Types ──────────────────────────────────────────────────────────────────

export interface CreateChallanInput {
    sourceInvoiceId?: string;
    items: Array<{
        productId: string;
        name: string;
        quantity: number;
        unit?: string;
    }>;
    customerName: string;
    deliveryAddress: string;
    vehicleNumber?: string;
    driverName?: string;
    driverPhone?: string;
    ewayBillNumber?: string;
    notes?: string;
}

export interface ChallanResult {
    id: string;
    challanNumber: string;
    status: string;
    itemsCount: number;
    customerName: string;
    deliveryAddress: string;
    createdAt: string;
}

class ChallanError extends AppError {
    constructor(message: string, statusCode = 400) {
        super(message, statusCode, 'CHALLAN_ERROR');
        this.name = 'ChallanError';
    }
}

// ── Service Functions ──────────────────────────────────────────────────────

/**
 * Create a delivery challan.
 * Can be linked to an invoice or standalone for material transfers.
 */
export async function createChallan(
    tenantId: string,
    createdBy: string,
    input: CreateChallanInput,
): Promise<ChallanResult> {
    if (!input.items || input.items.length === 0) {
        throw new ChallanError('Delivery challan must have at least one item');
    }

    const challanId = uuidv4();
    const now = new Date().toISOString();

    // Atomic challan number generation
    const datePrefix = now.slice(0, 7).replace('-', '');
    const counterResult = await updateItem(
        Keys.tenantPK(tenantId),
        `COUNTER#CHALLAN#${datePrefix}`,
        {
            updateExpression: 'ADD counterValue :inc',
            expressionAttributeValues: { ':inc': 1 },
        },
    );
    const seq = (counterResult as any).counterValue || 1;
    const challanNumber = `DC-${datePrefix}-${String(seq).padStart(5, '0')}`;

    // If linked to an invoice, verify it exists
    if (input.sourceInvoiceId) {
        const invoice = await getItem<Record<string, any>>(
            Keys.tenantPK(tenantId),
            Keys.invoiceSK(input.sourceInvoiceId),
        );
        if (!invoice || invoice.isDeleted) {
            throw new ChallanError(`Source invoice not found: ${input.sourceInvoiceId}`, 404);
        }
    }

    const challanItem: Record<string, any> = {
        PK: Keys.tenantPK(tenantId),
        SK: Keys.challanSK(challanId),
        GSI1PK: Keys.tenantPK(tenantId),
        GSI1SK: Keys.challanNumGSI1SK(challanNumber),
        entityType: 'CHALLAN',
        id: challanId,
        tenantId,
        challanNumber,
        sourceInvoiceId: input.sourceInvoiceId || null,
        customerName: input.customerName,
        deliveryAddress: input.deliveryAddress,
        vehicleNumber: input.vehicleNumber || null,
        driverName: input.driverName || null,
        driverPhone: input.driverPhone || null,
        ewayBillNumber: input.ewayBillNumber || null,
        items: input.items.map(item => ({
            productId: item.productId,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit || 'pcs',
        })),
        itemsCount: input.items.length,
        status: 'dispatched',
        notes: input.notes || null,
        createdBy,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
    };

    await putItem(challanItem);

    logAudit({
        action: 'CHALLAN_CREATED',
        resource: 'challan',
        resourceId: challanId,
        metadata: {
            challanNumber,
            sourceInvoiceId: input.sourceInvoiceId,
            customerName: input.customerName,
            itemsCount: input.items.length,
        },
    }).catch(() => { });

    logger.info('Delivery challan created', {
        tenantId, challanNumber, items: input.items.length,
        sourceInvoiceId: input.sourceInvoiceId,
    });

    return {
        id: challanId,
        challanNumber,
        status: 'dispatched',
        itemsCount: input.items.length,
        customerName: input.customerName,
        deliveryAddress: input.deliveryAddress,
        createdAt: now,
    };
}

/**
 * Get a single delivery challan by ID.
 */
export async function getChallan(
    tenantId: string,
    challanId: string,
): Promise<Record<string, any> | null> {
    const challan = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId), Keys.challanSK(challanId),
    );
    if (!challan || challan.isDeleted) return null;
    return challan;
}

/**
 * List delivery challans.
 */
export async function listChallans(
    tenantId: string,
    options?: { limit?: number },
): Promise<{ items: Record<string, any>[]; lastKey?: Record<string, unknown> }> {
    const limit = options?.limit || 20;
    const result = await queryItems<Record<string, any>>(
        Keys.tenantPK(tenantId), 'CHALLAN#',
        {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            limit,
        },
    );
    return { items: result.items, lastKey: result.lastKey as Record<string, unknown> };
}

/**
 * Mark a challan as delivered (goods received at site).
 */
export async function markDelivered(
    tenantId: string,
    challanId: string,
    receivedBy?: string,
): Promise<{ id: string; status: string }> {
    const challan = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId), Keys.challanSK(challanId),
    );
    if (!challan || challan.isDeleted) {
        throw new ChallanError(`Challan not found: ${challanId}`, 404);
    }

    await updateItem(Keys.tenantPK(tenantId), Keys.challanSK(challanId), {
        updateExpression: 'SET #s = :delivered, deliveredAt = :now, receivedBy = :by, updatedAt = :now',
        expressionAttributeNames: { '#s': 'status' },
        expressionAttributeValues: {
            ':delivered': 'delivered',
            ':now': new Date().toISOString(),
            ':by': receivedBy || null,
        },
    });

    logAudit({
        action: 'CHALLAN_DELIVERED',
        resource: 'challan',
        resourceId: challanId,
        metadata: { challanNumber: challan.challanNumber, receivedBy },
    }).catch(() => { });

    return { id: challanId, status: 'delivered' };
}
