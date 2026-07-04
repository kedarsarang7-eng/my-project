// ============================================================================
// Staff Module — BaseRepository<T> (Task 3.2)
// ============================================================================
// A small generic base class that wraps the existing DynamoDB single-table
// helpers (putItem/getItem/queryItems) from config/dynamodb.config.ts. Staff
// repositories extend this to inherit common CRUD + soft-delete patterns.
//
// TENANT/BUSINESS ISOLATION INVARIANT
// -----------------------------------
// Every operation is scoped to the business partition:
//     PK = TENANT#{tenantId}#BIZ#{businessId}
// The key construction is delegated to each subclass via abstract methods.
// BusinessID is always the leading partition scope (Req 1.5, 11.1).
//
// Soft-delete: records are never hard-deleted. Deactivation sets `isDeleted=true`
// and `status='inactive'`; all list/get operations filter out deleted records.
// ============================================================================

import { randomUUID } from 'crypto';
import {
    getItem,
    putItem,
    queryItems,
    updateItem,
} from '../../../config/dynamodb.config';
import type { StaffEntityKeys, StaffEntityType } from '../keys';

// ── Base item shape stored in DynamoDB ──────────────────────────────────────

export interface BaseItem {
    PK: string;
    SK: string;
    GSI1PK?: string;
    GSI1SK?: string;
    entityType: string;
    tenantId: string;
    businessId: string;
    id: string;
    isDeleted: boolean;
    createdAt: string;
    updatedAt: string;
}

// Filter expression for excluding soft-deleted items.
export const NOT_DELETED_FILTER = {
    filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
    expressionAttributeValues: { ':false': false },
};

/**
 * Generic base repository for staff entities. Subclasses provide entity-specific
 * key building, entity type, SK prefix, and domain → item / item → domain
 * mapping.
 *
 * @template TDomain  The clean domain type returned to callers.
 * @template TCreate  The validated input shape for creating a new entity.
 */
export abstract class BaseRepository<TDomain, TCreate = Record<string, unknown>> {
    /** The STAFF_ENTITY_TYPE value persisted in the `entityType` attribute. */
    protected abstract readonly entityType: StaffEntityType;

    /** The SK prefix (e.g. 'EMP#') for listing queries. */
    protected abstract readonly skPrefix: string;

    /**
     * Build the DynamoDB keys for a given entity instance.
     * Subclasses call the appropriate `buildXxxKeys` helper from `../keys.ts`.
     */
    protected abstract buildKeys(
        tenantId: string,
        businessId: string,
        id: string,
        extras?: Record<string, string>,
    ): StaffEntityKeys;

    /** Map a stored DynamoDB item to the clean domain type. */
    protected abstract toDomain(item: BaseItem & Record<string, unknown>): TDomain;

    /**
     * Build the full DynamoDB item from create input + scope. Called from create().
     * Subclasses mix in entity-specific fields (e.g. fullName for Employee).
     */
    protected abstract buildCreateItem(
        tenantId: string,
        businessId: string,
        id: string,
        keys: StaffEntityKeys,
        data: TCreate,
        now: string,
    ): BaseItem & Record<string, unknown>;

    // ── CRUD operations ─────────────────────────────────────────────────────

    /**
     * Create a new entity. Returns the clean domain representation.
     */
    async create(
        tenantId: string,
        businessId: string,
        data: TCreate,
    ): Promise<TDomain> {
        const id = randomUUID();
        const now = new Date().toISOString();
        const keys = this.buildKeys(tenantId, businessId, id, { isoDate: now });
        const item = this.buildCreateItem(tenantId, businessId, id, keys, data, now);
        await putItem(item as unknown as Record<string, unknown>);
        return this.toDomain(item);
    }

    /**
     * Fetch a single entity by ID. Returns null when absent or soft-deleted.
     */
    async get(
        tenantId: string,
        businessId: string,
        id: string,
    ): Promise<TDomain | null> {
        const keys = this.buildKeys(tenantId, businessId, id);
        const item = await getItem<BaseItem & Record<string, unknown>>(keys.PK, keys.SK);
        if (!item || item.isDeleted) return null;
        return this.toDomain(item);
    }

    /**
     * List all non-deleted entities in a business.
     */
    async list(
        tenantId: string,
        businessId: string,
        opts?: { limit?: number; scanIndexForward?: boolean },
    ): Promise<TDomain[]> {
        const keys = this.buildKeys(tenantId, businessId, 'x');
        const result = await queryItems<BaseItem & Record<string, unknown>>(
            keys.PK,
            this.skPrefix,
            {
                ...NOT_DELETED_FILTER,
                limit: opts?.limit,
                scanIndexForward: opts?.scanIndexForward,
            },
        );
        return result.items.map((item) => this.toDomain(item));
    }

    /**
     * Update specific fields on an entity. Returns the updated domain object.
     * Callers provide a flat Record of fields to set (already validated by Zod).
     */
    async update(
        tenantId: string,
        businessId: string,
        id: string,
        fields: Record<string, unknown>,
    ): Promise<TDomain | null> {
        const keys = this.buildKeys(tenantId, businessId, id);
        const now = new Date().toISOString();

        // Build SET expression dynamically from the fields map.
        const entries = Object.entries(fields).filter(
            ([, v]) => v !== undefined,
        );
        if (entries.length === 0) return this.get(tenantId, businessId, id);

        const exprParts: string[] = ['#updatedAt = :updatedAt'];
        const exprValues: Record<string, unknown> = { ':updatedAt': now };
        const exprNames: Record<string, string> = { '#updatedAt': 'updatedAt' };

        for (const [key, value] of entries) {
            const placeholder = `:f_${key}`;
            const alias = `#f_${key}`;
            exprParts.push(`${alias} = ${placeholder}`);
            exprValues[placeholder] = value;
            exprNames[alias] = key;
        }

        const updated = await updateItem(keys.PK, keys.SK, {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeValues: exprValues,
            expressionAttributeNames: exprNames,
            conditionExpression: 'attribute_exists(SK)',
        });
        if (!updated) return null;
        return this.toDomain(updated as BaseItem & Record<string, unknown>);
    }

    /**
     * Soft-delete (deactivate) an entity. Sets `isDeleted = true` and
     * `status = 'inactive'`. Returns true on success, false if not found.
     */
    async deactivate(
        tenantId: string,
        businessId: string,
        id: string,
    ): Promise<boolean> {
        const keys = this.buildKeys(tenantId, businessId, id);
        const now = new Date().toISOString();
        try {
            await updateItem(keys.PK, keys.SK, {
                updateExpression:
                    'SET isDeleted = :true, #status = :inactive, updatedAt = :now',
                expressionAttributeValues: {
                    ':true': true,
                    ':inactive': 'inactive',
                    ':now': now,
                },
                expressionAttributeNames: { '#status': 'status' },
                conditionExpression: 'attribute_exists(SK)',
            });
            return true;
        } catch (err) {
            if ((err as { name?: string }).name === 'ConditionalCheckFailedException') {
                return false;
            }
            throw err;
        }
    }
}
