// ============================================================================
// Base Repository — DynamoDB Abstract Data Access
// ============================================================================
// Provides type-safe CRUD operations using DynamoDB single-table design.
// All repositories should extend this class.
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import { Keys, getItem, putItem, queryItems, updateItem, deleteItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

export interface PaginationOpts {
    page: number;
    limit: number;
    offset: number;
}

export interface PaginatedResult<T> {
    items: T[];
    total: number;
}

export abstract class BaseRepository<T extends Record<string, any>> {
    constructor(
        protected readonly entityType: string,
        protected readonly skPrefix: string,
    ) {}

    /**
     * Find a single record by ID within the tenant's scope.
     */
    async findById(tenantId: string, id: string): Promise<T | null> {
        const item = await getItem<T>(
            Keys.tenantPK(tenantId),
            `${this.skPrefix}${id}`,
        );
        if (!item || (item as any).isDeleted) return null;
        return item;
    }

    /**
     * Find all records with pagination.
     */
    async findAll(
        tenantId: string,
        opts: PaginationOpts,
        filterFn?: (item: T) => boolean,
    ): Promise<PaginatedResult<T>> {
        const result = await queryItems<T>(
            Keys.tenantPK(tenantId),
            this.skPrefix,
            {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
            },
        );

        let items = result.items;
        if (filterFn) items = items.filter(filterFn);

        const total = items.length;
        const paged = items.slice(opts.offset, opts.offset + opts.limit);

        return { items: paged, total };
    }

    /**
     * Insert a new record with auto-generated UUID.
     */
    async create(tenantId: string, data: Partial<T>): Promise<T> {
        const id = uuidv4();
        const now = new Date().toISOString();

        const item = {
            PK: Keys.tenantPK(tenantId),
            SK: `${this.skPrefix}${id}`,
            entityType: this.entityType,
            id,
            tenantId,
            ...data,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
        } as unknown as T;

        await putItem(item as Record<string, unknown>);
        return item;
    }

    /**
     * Update an existing record by ID. Only provided fields are updated.
     */
    async update(tenantId: string, id: string, data: Partial<T>): Promise<T | null> {
        const now = new Date().toISOString();
        const entries = Object.entries({ ...data, updatedAt: now }).filter(([_, v]) => v !== undefined);

        if (entries.length === 0) return this.findById(tenantId, id);

        const setParts = entries.map(([k], i) => `#k${i} = :v${i}`).join(', ');
        const exprNames: Record<string, string> = {};
        const exprValues: Record<string, unknown> = {};

        entries.forEach(([k, v], i) => {
            exprNames[`#k${i}`] = k;
            exprValues[`:v${i}`] = v;
        });

        const result = await updateItem(
            Keys.tenantPK(tenantId),
            `${this.skPrefix}${id}`,
            {
                updateExpression: `SET ${setParts}`,
                expressionAttributeNames: exprNames,
                expressionAttributeValues: exprValues,
            },
        );

        return result as T | null;
    }

    /**
     * Soft delete a record (set isDeleted = true).
     */
    async softDelete(tenantId: string, id: string): Promise<boolean> {
        try {
            await updateItem(
                Keys.tenantPK(tenantId),
                `${this.skPrefix}${id}`,
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
        } catch {
            return false;
        }
    }

    /**
     * Count records.
     */
    async count(tenantId: string, filterFn?: (item: T) => boolean): Promise<number> {
        const result = await queryItems<T>(
            Keys.tenantPK(tenantId),
            this.skPrefix,
            {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
            },
        );

        let items = result.items;
        if (filterFn) items = items.filter(filterFn);
        return items.length;
    }
}
