// ============================================================================
// DynamoDB Base Repository — Single-Table Pattern
// ============================================================================
// Provides generic CRUD operations for any entity in the single DynamoDB table.
// All entities use PK/SK pattern with optional GSI1/GSI2 for secondary access.
//
// Replaces the PostgreSQL BaseRepository + specific repositories.
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    TABLE_NAME,
    Keys,
    getItem,
    putItem,
    queryItems,
    updateItem,
    deleteItem,
    batchWrite,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';

export interface PaginatedResult<T> {
    items: T[];
    total: number;
    lastKey?: Record<string, unknown>;
}

/**
 * DynamoRepository — generic entity CRUD for single-table design.
 *
 * Usage:
 *   const repo = new DynamoRepository('PRODUCT');
 *   await repo.create(tenantId, 'prod-123', { name: 'Widget', price: 100 });
 *   const item = await repo.findById(tenantId, 'prod-123');
 */
export class DynamoRepository<T extends Record<string, unknown> = Record<string, unknown>> {
    constructor(
        private readonly entityType: string,
        private readonly skPrefix: string,
    ) {}

    /**
     * Build the SK for a specific entity ID.
     */
    private buildSK(id: string): string {
        return `${this.skPrefix}#${id}`;
    }

    /**
     * Find a single item by tenant + ID.
     */
    async findById(tenantId: string, id: string): Promise<T | null> {
        const result = await getItem<T>(
            Keys.tenantPK(tenantId),
            this.buildSK(id),
        );
        if (result && (result as any).isDeleted) return null;
        return result;
    }

    /**
     * List all items for a tenant with optional pagination.
     */
    async findAll(
        tenantId: string,
        opts?: {
            limit?: number;
            lastKey?: Record<string, unknown>;
            scanIndexForward?: boolean;
        },
    ): Promise<PaginatedResult<T>> {
        const result = await queryItems<T>(
            Keys.tenantPK(tenantId),
            `${this.skPrefix}#`,
            {
                limit: opts?.limit || 100,
                scanIndexForward: opts?.scanIndexForward ?? false,
                exclusiveStartKey: opts?.lastKey,
                filterExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
                expressionAttributeValues: { ':false': false },
            },
        );

        return {
            items: result.items,
            total: result.items.length,
            lastKey: result.lastKey,
        };
    }

    /**
     * Create a new item. Auto-generates ID if not provided.
     */
    async create(
        tenantId: string,
        id: string | undefined,
        data: Partial<T>,
        gsiKeys?: {
            GSI1PK?: string;
            GSI1SK?: string;
            GSI2PK?: string;
            GSI2SK?: string;
        },
    ): Promise<T> {
        const itemId = id || uuidv4();
        const now = new Date().toISOString();

        const item: Record<string, unknown> = {
            PK: Keys.tenantPK(tenantId),
            SK: this.buildSK(itemId),
            entityType: this.entityType,
            id: itemId,
            tenantId,
            ...data,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
            ...gsiKeys,
        };

        await putItem(item);
        return item as T;
    }

    /**
     * Update an existing item. Only updates provided fields.
     */
    async update(
        tenantId: string,
        id: string,
        data: Partial<T>,
    ): Promise<T | null> {
        const now = new Date().toISOString();
        const updates: Record<string, unknown> = { ...data, updatedAt: now };

        // Build UpdateExpression dynamically
        const setExpressions: string[] = [];
        const expressionValues: Record<string, unknown> = {};
        const expressionNames: Record<string, string> = {};
        let idx = 0;

        for (const [key, value] of Object.entries(updates)) {
            if (key === 'PK' || key === 'SK') continue; // Never update keys
            const attrName = `#attr${idx}`;
            const attrVal = `:val${idx}`;
            expressionNames[attrName] = key;
            expressionValues[attrVal] = value;
            setExpressions.push(`${attrName} = ${attrVal}`);
            idx++;
        }

        if (setExpressions.length === 0) return null;

        const result = await updateItem(
            Keys.tenantPK(tenantId),
            this.buildSK(id),
            {
                updateExpression: `SET ${setExpressions.join(', ')}`,
                expressionAttributeValues: expressionValues,
                expressionAttributeNames: expressionNames,
                conditionExpression: 'attribute_exists(PK)',
            },
        );

        return result as T | null;
    }

    /**
     * Soft-delete an item (set isDeleted = true).
     */
    async softDelete(tenantId: string, id: string): Promise<boolean> {
        try {
            await updateItem(
                Keys.tenantPK(tenantId),
                this.buildSK(id),
                {
                    updateExpression: 'SET isDeleted = :true, updatedAt = :now',
                    expressionAttributeValues: {
                        ':true': true,
                        ':now': new Date().toISOString(),
                    },
                    conditionExpression: 'attribute_exists(PK)',
                },
            );
            return true;
        } catch (err: unknown) {
            if ((err as any).name === 'ConditionalCheckFailedException') {
                return false;
            }
            throw err;
        }
    }

    /**
     * Hard-delete an item (removes from table).
     */
    async hardDelete(tenantId: string, id: string): Promise<void> {
        await deleteItem(Keys.tenantPK(tenantId), this.buildSK(id));
    }

    /**
     * Count items for a tenant (approximation via query).
     */
    async count(tenantId: string): Promise<number> {
        const result = await queryItems(
            Keys.tenantPK(tenantId),
            `${this.skPrefix}#`,
            {
                filterExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
                expressionAttributeValues: { ':false': false },
            },
        );
        return result.items.length;
    }
}
