// ============================================================================
// Pharmacy Batch Service — FIFO Batch Consumption Engine
// ============================================================================
// Implements server-side FIFO (First-In, First-Out) batch stock deduction
// for the pharmacy vertical. Oldest batches (by expiryDate) are consumed
// first to prevent drug expiration on shelves.
//
// DynamoDB Schema:
//   PK: TENANT#{tenantId}
//   SK: MEDBATCH#{productId}#{batchNumber}
//   Fields: batchNumber, productId, productName, expiryDate (ISO),
//           batchStock (number), costPricePaise (number),
//           status: 'active'|'depleted'|'expired', createdAt, updatedAt
//
// FIFO-001: Query all active, non-expired batches for a product
// FIFO-002: Sort ascending by expiryDate (oldest first)
// FIFO-003: Walk batches deducting stock until qty is fulfilled
// FIFO-004: Mark batch as 'depleted' when batchStock reaches 0
// FIFO-005: Throw InsufficientBatchStockError if total < requested
// FIFO-006: Return DynamoDB transactWrite operations for atomicity
// ============================================================================

import {
    Keys, TABLE_NAME,
    queryItems,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

// ---- Error Class ----

/**
 * Thrown when pharmacy batch stock is insufficient for the requested quantity.
 * Includes batch-level detail for UI display.
 */
export class InsufficientBatchStockError extends Error {
    public readonly statusCode = 400;
    public readonly code = 'INSUFFICIENT_BATCH_STOCK';
    public readonly productId: string;
    public readonly productName: string;
    public readonly requestedQty: number;
    public readonly availableQty: number;
    public readonly batches: BatchAvailability[];

    constructor(
        productId: string,
        productName: string,
        requestedQty: number,
        availableQty: number,
        batches: BatchAvailability[],
    ) {
        super(
            `Insufficient batch stock for '${productName}': ` +
            `requested=${requestedQty}, available across ${batches.length} active batch(es)=${availableQty}. ` +
            `Please check batch inventory or restock.`,
        );
        this.name = 'InsufficientBatchStockError';
        this.productId = productId;
        this.productName = productName;
        this.requestedQty = requestedQty;
        this.availableQty = availableQty;
        this.batches = batches;
    }
}

// ---- Types ----

/** A single MEDBATCH# record from DynamoDB */
export interface MedBatch {
    PK: string;
    SK: string;
    batchNumber: string;
    productId: string;
    productName?: string;
    expiryDate: string;       // ISO 8601 date string (YYYY-MM-DD or full ISO)
    batchStock: number;       // Current stock in this batch
    costPricePaise: number;   // Purchase cost per unit in paise
    status: 'active' | 'depleted' | 'expired';
    createdAt: string;
    updatedAt: string;
    // Pharmacy strategy uses 'currentQty' in some places — normalize
    currentQty?: number;
}

/** Summary of batch availability for error reporting */
export interface BatchAvailability {
    batchNumber: string;
    expiryDate: string;
    available: number;
}

/** A single batch deduction operation to include in transactWrite */
export interface BatchDeductionOp {
    /** The DynamoDB Update operation for transactWrite */
    transactItem: {
        Update: {
            TableName: string;
            Key: { PK: string; SK: string };
            UpdateExpression: string;
            ConditionExpression: string;
            ExpressionAttributeValues: Record<string, unknown>;
        };
    };
    /** Metadata about this deduction for audit/logging */
    batchNumber: string;
    expiryDate: string;
    deductedQty: number;
    remainingStock: number;
    wasDepleted: boolean;
    costPricePaise: number;
}

/** Result of FIFO batch deduction planning */
export interface FIFODeductionResult {
    /** Array of DynamoDB transactWrite operations */
    operations: BatchDeductionOp[];
    /** Total quantity deducted across all batches */
    totalDeducted: number;
    /** Weighted average cost of goods sold (in paise) */
    cogsPaise: number;
    /** Number of batches that were fully depleted */
    batchesDepleted: number;
}

// ---- Helper: Build MEDBATCH SK prefix ----

/**
 * Build the SK prefix for querying all MEDBATCH records for a product.
 * Format: MEDBATCH#{productId}#
 */
function medBatchSKPrefix(productId: string): string {
    return `MEDBATCH#${productId}#`;
}

/**
 * Build the full SK for a specific batch.
 * Format: MEDBATCH#{productId}#{batchNumber}
 */
export function medBatchSK(productId: string, batchNumber: string): string {
    return `MEDBATCH#${productId}#${batchNumber}`;
}

// ---- Core Function ----

/**
 * Plan FIFO batch deduction for a pharmacy product.
 *
 * Queries all MEDBATCH# records for the given productId, filters to only
 * active and non-expired batches, sorts by expiryDate ascending (FIFO),
 * and walks the list deducting stock until the requested quantity is fulfilled.
 *
 * Returns an array of DynamoDB transactWrite Update operations that MUST
 * be included in the caller's transactWrite() call for atomicity.
 *
 * CRITICAL: Each batch update uses ConditionExpression to enforce:
 *   - batchStock >= deductedQty (no negative stock)
 *   - status = 'active' (no selling from expired/depleted batches)
 *
 * @param tenantId - Tenant ID from JWT
 * @param productId - Product to deduct batches from
 * @param productName - For error messages
 * @param quantity - Total quantity to deduct (must be positive)
 * @param now - ISO timestamp for updatedAt
 * @returns FIFODeductionResult with transactWrite operations
 * @throws InsufficientBatchStockError if insufficient batch stock
 */
export async function deductBatchesFIFO(
    tenantId: string,
    productId: string,
    productName: string,
    quantity: number,
    now: string,
): Promise<FIFODeductionResult> {
    const tableName = config.dynamodb.tableName;

    // FIFO-001: Query all MEDBATCH# records for this product
    const todayUTC = new Date();
    const todayStr = new Date(
        Date.UTC(todayUTC.getUTCFullYear(), todayUTC.getUTCMonth(), todayUTC.getUTCDate()),
    ).toISOString();

    const batchResult = await queryItems<MedBatch>(
        Keys.tenantPK(tenantId),
        medBatchSKPrefix(productId),
        {
            filterExpression:
                '#batchStatus = :active AND batchStock > :zero AND expiryDate >= :today',
            expressionAttributeNames: {
                '#batchStatus': 'status',
            },
            expressionAttributeValues: {
                ':active': 'active',
                ':zero': 0,
                ':today': todayStr,
            },
        },
    );

    // Normalize: pharmacy strategy uses `currentQty` in some places
    const batches = batchResult.items.map(b => ({
        ...b,
        batchStock: b.batchStock ?? b.currentQty ?? 0,
    }));

    // FIFO-002: Sort ascending by expiryDate (oldest first = sell first)
    batches.sort((a, b) => {
        const dateA = a.expiryDate || '';
        const dateB = b.expiryDate || '';
        return dateA.localeCompare(dateB);
    });

    // FIFO-005: Check total available stock
    const totalAvailable = batches.reduce((sum, b) => sum + b.batchStock, 0);
    if (totalAvailable < quantity) {
        throw new InsufficientBatchStockError(
            productId,
            productName,
            quantity,
            totalAvailable,
            batches.map(b => ({
                batchNumber: b.batchNumber,
                expiryDate: b.expiryDate,
                available: b.batchStock,
            })),
        );
    }

    // FIFO-003: Walk batches, deducting stock in FIFO order
    let remaining = quantity;
    const operations: BatchDeductionOp[] = [];
    let cogsPaise = 0;
    let batchesDepleted = 0;

    for (const batch of batches) {
        if (remaining <= 0) break;

        const deductFromBatch = Math.min(remaining, batch.batchStock);
        const newBatchStock = batch.batchStock - deductFromBatch;
        const isDepleted = newBatchStock === 0;

        if (isDepleted) batchesDepleted++;

        // COGS tracking: cost × quantity consumed from this batch
        cogsPaise += (batch.costPricePaise || 0) * deductFromBatch;

        // FIFO-004/006: Build conditional update operation
        // Two cases: (a) batch becomes depleted, (b) batch has remaining stock
        const updateExpression = isDepleted
            ? 'SET batchStock = batchStock - :qty, #batchStatus = :depleted, updatedAt = :now'
            : 'SET batchStock = batchStock - :qty, updatedAt = :now';

        const expressionAttributeValues: Record<string, unknown> = {
            ':qty': deductFromBatch,
            ':now': now,
            ':activeStatus': 'active',
            ':minStock': deductFromBatch,
        };

        if (isDepleted) {
            expressionAttributeValues[':depleted'] = 'depleted';
        }

        operations.push({
            transactItem: {
                Update: {
                    TableName: tableName,
                    Key: {
                        PK: Keys.tenantPK(tenantId),
                        SK: batch.SK || medBatchSK(productId, batch.batchNumber),
                    },
                    UpdateExpression: updateExpression,
                    // CRITICAL: ConditionExpression prevents negative stock AND
                    // ensures batch hasn't been concurrently expired/depleted
                    ConditionExpression:
                        '#batchStatus = :activeStatus AND batchStock >= :minStock',
                    ExpressionAttributeValues: expressionAttributeValues,
                },
            },
            batchNumber: batch.batchNumber,
            expiryDate: batch.expiryDate,
            deductedQty: deductFromBatch,
            remainingStock: newBatchStock,
            wasDepleted: isDepleted,
            costPricePaise: batch.costPricePaise || 0,
        });

        remaining -= deductFromBatch;
    }

    // Safety invariant: remaining must be 0 exactly
    if (remaining > 0) {
        // This should never happen since we checked totalAvailable >= quantity above
        logger.error('FIFO INVARIANT VIOLATION: remaining > 0 after batch walk', {
            tenantId, productId, quantity, remaining, batchCount: batches.length,
        });
        throw new InsufficientBatchStockError(
            productId,
            productName,
            quantity,
            totalAvailable - remaining,
            batches.map(b => ({
                batchNumber: b.batchNumber,
                expiryDate: b.expiryDate,
                available: b.batchStock,
            })),
        );
    }

    // Add expressionAttributeNames to all operations that reference '#batchStatus'
    for (const op of operations) {
        (op.transactItem.Update as any).ExpressionAttributeNames = {
            '#batchStatus': 'status',
        };
    }

    logger.info('FIFO batch deduction planned', {
        tenantId,
        productId,
        productName,
        requestedQty: quantity,
        batchesConsumed: operations.length,
        batchesDepleted,
        cogsPaise,
        batches: operations.map(op => ({
            batch: op.batchNumber,
            expiry: op.expiryDate,
            deducted: op.deductedQty,
            remaining: op.remainingStock,
            depleted: op.wasDepleted,
        })),
    });

    return {
        operations,
        totalDeducted: quantity,
        cogsPaise,
        batchesDepleted,
    };
}
