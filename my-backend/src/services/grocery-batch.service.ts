import { Keys, TABLE_NAME, queryItems } from '../config/dynamodb.config';
import { config } from '../config/environment';

export interface GroceryBatch {
    PK: string;
    SK: string;
    batchNumber: string;
    productId: string;
    expiryDate: string;
    currentQty: number;
    status: 'active' | 'depleted' | 'expired';
}

export interface GroceryBatchDeductionOp {
    transactItem: {
        Update: {
            TableName: string;
            Key: { PK: string; SK: string };
            UpdateExpression: string;
            ConditionExpression: string;
            ExpressionAttributeNames: Record<string, string>;
            ExpressionAttributeValues: Record<string, unknown>;
        };
    };
    batchNumber: string;
    expiryDate: string;
    deductedQty: number;
    remainingQty: number;
    wasDepleted: boolean;
}

export interface GroceryFEFOResult {
    operations: GroceryBatchDeductionOp[];
    totalDeducted: number;
    batchesDepleted: number;
}

export class InsufficientGroceryBatchStockError extends Error {
    public readonly statusCode = 400;
    public readonly code = 'INSUFFICIENT_GROCERY_BATCH_STOCK';
    constructor(productName: string, requestedQty: number, availableQty: number) {
        super(
            `Insufficient unexpired batch stock for '${productName}': requested=${requestedQty}, available=${availableQty}.`,
        );
        this.name = 'InsufficientGroceryBatchStockError';
    }
}

export async function deductGroceryBatchesFEFO(
    tenantId: string,
    productId: string,
    productName: string,
    quantity: number,
    now: string,
): Promise<GroceryFEFOResult> {
    const todayUTC = new Date();
    const todayStr = new Date(
        Date.UTC(todayUTC.getUTCFullYear(), todayUTC.getUTCMonth(), todayUTC.getUTCDate()),
    ).toISOString();

    const batchResult = await queryItems<GroceryBatch>(
        Keys.tenantPK(tenantId),
        `GROCBATCH#${productId}#`,
        {
            filterExpression: '#s = :active AND currentQty > :zero AND expiryDate >= :today',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: {
                ':active': 'active',
                ':zero': 0,
                ':today': todayStr,
            },
        },
    );

    const batches = batchResult.items
        .map((b) => ({ ...b, currentQty: Number((b as any).currentQty ?? 0) }))
        .sort((a, b) => (a.expiryDate || '').localeCompare(b.expiryDate || ''));

    const totalAvailable = batches.reduce((sum, b) => sum + b.currentQty, 0);
    if (totalAvailable < quantity) {
        throw new InsufficientGroceryBatchStockError(productName, quantity, totalAvailable);
    }

    let remaining = quantity;
    const operations: GroceryBatchDeductionOp[] = [];
    let batchesDepleted = 0;
    const tableName = config.dynamodb.tableName;

    for (const batch of batches) {
        if (remaining <= 0) break;
        const deductQty = Math.min(remaining, batch.currentQty);
        const newQty = batch.currentQty - deductQty;
        const isDepleted = newQty === 0;
        if (isDepleted) batchesDepleted++;

        operations.push({
            transactItem: {
                Update: {
                    TableName: tableName,
                    Key: { PK: Keys.tenantPK(tenantId), SK: batch.SK },
                    UpdateExpression: isDepleted
                        ? 'SET currentQty = currentQty - :qty, #s = :depleted, updatedAt = :now'
                        : 'SET currentQty = currentQty - :qty, updatedAt = :now',
                    ConditionExpression: '#s = :active AND currentQty >= :qty',
                    ExpressionAttributeNames: { '#s': 'status' },
                    ExpressionAttributeValues: {
                        ':qty': deductQty,
                        ':now': now,
                        ':active': 'active',
                        ...(isDepleted ? { ':depleted': 'depleted' } : {}),
                    },
                },
            },
            batchNumber: batch.batchNumber,
            expiryDate: batch.expiryDate,
            deductedQty: deductQty,
            remainingQty: newQty,
            wasDepleted: isDepleted,
        });

        remaining -= deductQty;
    }

    return {
        operations,
        totalDeducted: quantity,
        batchesDepleted,
    };
}
