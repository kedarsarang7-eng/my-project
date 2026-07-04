// ============================================================================
// Staff Module — Global Search & Saved Filters Service (Task 13.2)
// ============================================================================
// Provides backend-side global search across staff entities (Employee,
// Department, Designation, Task, LeaveRequest) with a text query that matches
// against key searchable fields. Results are merged from multiple entity types
// and returned ranked by relevance.
//
// Saved Filters: simple CRUD for persisting user-defined filter configurations
// (entity type, field filters, sort order). Stored per user per business in
// DynamoDB using the SK prefix SRCHFILTER#.
//
// The truly-offline search against the Local_Database is a frontend concern
// (task 15.x/16.x Drift); this backend endpoint serves the online search +
// saved-filter persistence.
//
// Requirements: 9.7 (global search operating offline against Local_Database
// with saved filters). Backend provides the search endpoint and saved filter
// CRUD; offline search is client-side.
// ============================================================================

import { businessPK, gsi1PK } from '../../../dynamodb/keys';
import { queryItems, putItem, getItem, queryAllItems, deleteItem } from '../../../config/dynamodb.config';
import {
    EMP_SK_PREFIX,
    DEPT_SK_PREFIX,
    DESIG_SK_PREFIX,
    TASK_SK_PREFIX,
    LVREQ_SK_PREFIX,
    STAFF_ENTITY_TYPE,
} from '../keys';

// ── Types ───────────────────────────────────────────────────────────────────

export interface SearchResult {
    /** Entity type (e.g. 'STAFF_EMP', 'STAFF_DEPT'). */
    entityType: string;
    /** Record ID. */
    id: string;
    /** Primary display value (name/title). */
    label: string;
    /** Optional secondary info (department, status). */
    sublabel?: string;
    /** Relevance score (higher is better). */
    score: number;
}

export interface SearchResponse {
    query: string;
    results: SearchResult[];
    total: number;
}

export interface SavedFilter {
    id: string;
    userId: string;
    businessId: string;
    tenantId: string;
    name: string;
    /** Which entity types to include in the search. */
    entityTypes?: string[];
    /** Field-level filters (e.g. { status: 'active', departmentId: 'xyz' }). */
    filters?: Record<string, string>;
    /** Sort configuration. */
    sort?: { field: string; direction: 'asc' | 'desc' };
    createdAt: string;
    updatedAt: string;
}

// SK prefix for saved filters (per-user within the business partition)
const SAVED_FILTER_SK_PREFIX = 'SRCHFILTER#';

function savedFilterSK(userId: string, filterId: string): string {
    return `${SAVED_FILTER_SK_PREFIX}${userId}#${filterId}`;
}

// ── Search Logic ────────────────────────────────────────────────────────────

/**
 * Simple case-insensitive substring match score.
 * Returns 0 if no match, higher score for earlier/exact matches.
 */
function matchScore(text: string | undefined, query: string): number {
    if (!text) return 0;
    const lowerText = text.toLowerCase();
    const lowerQuery = query.toLowerCase();
    if (lowerText === lowerQuery) return 100;
    if (lowerText.startsWith(lowerQuery)) return 80;
    const idx = lowerText.indexOf(lowerQuery);
    if (idx >= 0) return 60 - Math.min(idx, 50);
    // Partial word match
    const words = lowerText.split(/\s+/);
    for (const word of words) {
        if (word.startsWith(lowerQuery)) return 50;
    }
    return 0;
}

/**
 * Search across multiple staff entity types within a business scope.
 * Uses DynamoDB queries with `begins_with` on known SK prefixes and applies
 * application-side text filtering.
 *
 * For large datasets, clients should rely on the offline Local_Database search
 * (Drift). This endpoint covers online search for freshest data.
 */
export async function globalStaffSearch(
    tenantId: string,
    businessId: string,
    query: string,
    options?: {
        entityTypes?: string[];
        limit?: number;
        filters?: Record<string, string>;
    },
): Promise<SearchResponse> {
    const limit = options?.limit ?? 50;
    const lowerQuery = query.toLowerCase().trim();

    if (!lowerQuery) {
        return { query, results: [], total: 0 };
    }

    const pk = businessPK(tenantId, businessId);
    const results: SearchResult[] = [];

    // Determine which entity types to search
    const searchTypes = options?.entityTypes ?? [
        STAFF_ENTITY_TYPE.EMPLOYEE,
        STAFF_ENTITY_TYPE.DEPARTMENT,
        STAFF_ENTITY_TYPE.DESIGNATION,
        STAFF_ENTITY_TYPE.TASK,
        STAFF_ENTITY_TYPE.LEAVE_REQUEST,
    ];

    // Search employees
    if (searchTypes.includes(STAFF_ENTITY_TYPE.EMPLOYEE)) {
        const { items } = await queryItems<Record<string, unknown>>(pk, EMP_SK_PREFIX, {
            filterExpression: 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':et': STAFF_ENTITY_TYPE.EMPLOYEE,
                ':false': false,
            },
        });
        for (const item of items) {
            const name = String(item.fullName ?? item.name ?? '');
            const contact = item.contact as Record<string, unknown> | undefined;
            const score = matchScore(name, lowerQuery)
                + matchScore(String(contact?.phone ?? ''), lowerQuery) * 0.5
                + matchScore(String(contact?.email ?? ''), lowerQuery) * 0.5;
            if (score > 0) {
                // Apply extra field filters
                if (options?.filters) {
                    const pass = Object.entries(options.filters).every(
                        ([k, v]) => String((item as Record<string, unknown>)[k] ?? '') === v,
                    );
                    if (!pass) continue;
                }
                results.push({
                    entityType: STAFF_ENTITY_TYPE.EMPLOYEE,
                    id: String(item.id),
                    label: name,
                    sublabel: `Employee • ${item.status ?? 'active'}`,
                    score,
                });
            }
        }
    }

    // Search departments
    if (searchTypes.includes(STAFF_ENTITY_TYPE.DEPARTMENT)) {
        const { items } = await queryItems<Record<string, unknown>>(pk, DEPT_SK_PREFIX, {
            filterExpression: 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':et': STAFF_ENTITY_TYPE.DEPARTMENT,
                ':false': false,
            },
        });
        for (const item of items) {
            const name = String(item.name ?? '');
            const score = matchScore(name, lowerQuery);
            if (score > 0) {
                results.push({
                    entityType: STAFF_ENTITY_TYPE.DEPARTMENT,
                    id: String(item.id),
                    label: name,
                    sublabel: 'Department',
                    score,
                });
            }
        }
    }

    // Search designations
    if (searchTypes.includes(STAFF_ENTITY_TYPE.DESIGNATION)) {
        const { items } = await queryItems<Record<string, unknown>>(pk, DESIG_SK_PREFIX, {
            filterExpression: 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':et': STAFF_ENTITY_TYPE.DESIGNATION,
                ':false': false,
            },
        });
        for (const item of items) {
            const title = String(item.title ?? item.name ?? '');
            const score = matchScore(title, lowerQuery);
            if (score > 0) {
                results.push({
                    entityType: STAFF_ENTITY_TYPE.DESIGNATION,
                    id: String(item.id),
                    label: title,
                    sublabel: 'Designation',
                    score,
                });
            }
        }
    }

    // Search tasks
    if (searchTypes.includes(STAFF_ENTITY_TYPE.TASK)) {
        const { items } = await queryItems<Record<string, unknown>>(pk, TASK_SK_PREFIX, {
            filterExpression: 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':et': STAFF_ENTITY_TYPE.TASK,
                ':false': false,
            },
        });
        for (const item of items) {
            const title = String(item.title ?? '');
            const score = matchScore(title, lowerQuery)
                + matchScore(String(item.description ?? ''), lowerQuery) * 0.3;
            if (score > 0) {
                results.push({
                    entityType: STAFF_ENTITY_TYPE.TASK,
                    id: String(item.id),
                    label: title,
                    sublabel: `Task • ${item.status ?? 'open'}`,
                    score,
                });
            }
        }
    }

    // Search leave requests
    if (searchTypes.includes(STAFF_ENTITY_TYPE.LEAVE_REQUEST)) {
        const { items } = await queryItems<Record<string, unknown>>(pk, LVREQ_SK_PREFIX, {
            filterExpression: 'entity_type = :et AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':et': STAFF_ENTITY_TYPE.LEAVE_REQUEST,
                ':false': false,
            },
        });
        for (const item of items) {
            const empId = String(item.employeeId ?? '');
            const score = matchScore(empId, lowerQuery)
                + matchScore(String(item.leaveTypeId ?? ''), lowerQuery) * 0.5;
            if (score > 0) {
                results.push({
                    entityType: STAFF_ENTITY_TYPE.LEAVE_REQUEST,
                    id: String(item.id),
                    label: `Leave: ${item.from ?? ''} → ${item.to ?? ''}`,
                    sublabel: `Leave Request • ${item.status ?? 'pending'}`,
                    score,
                });
            }
        }
    }

    // Sort by score descending, limit results
    results.sort((a, b) => b.score - a.score);
    const limited = results.slice(0, limit);

    return {
        query,
        results: limited,
        total: results.length,
    };
}

// ── Saved Filters CRUD ──────────────────────────────────────────────────────

export async function createSavedFilter(
    tenantId: string,
    businessId: string,
    filter: Omit<SavedFilter, 'createdAt' | 'updatedAt' | 'tenantId' | 'businessId'>,
): Promise<SavedFilter> {
    const pk = businessPK(tenantId, businessId);
    const sk = savedFilterSK(filter.userId, filter.id);
    const now = new Date().toISOString();

    const item: SavedFilter & { PK: string; SK: string; entity_type: string } = {
        PK: pk,
        SK: sk,
        entity_type: 'STAFF_SAVED_FILTER',
        id: filter.id,
        userId: filter.userId,
        businessId,
        tenantId,
        name: filter.name,
        entityTypes: filter.entityTypes,
        filters: filter.filters,
        sort: filter.sort,
        createdAt: now,
        updatedAt: now,
    };

    await putItem(item as unknown as Record<string, unknown>);
    return {
        id: item.id,
        userId: item.userId,
        businessId: item.businessId,
        tenantId: item.tenantId,
        name: item.name,
        entityTypes: item.entityTypes,
        filters: item.filters,
        sort: item.sort,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
    };
}

export async function listSavedFilters(
    tenantId: string,
    businessId: string,
    userId: string,
): Promise<SavedFilter[]> {
    const pk = businessPK(tenantId, businessId);
    const skPrefix = `${SAVED_FILTER_SK_PREFIX}${userId}#`;

    const { items } = await queryItems<SavedFilter & { PK: string; SK: string }>(
        pk,
        skPrefix,
    );
    return items.map((item) => ({
        id: item.id,
        userId: item.userId,
        businessId: item.businessId,
        tenantId: item.tenantId,
        name: item.name,
        entityTypes: item.entityTypes,
        filters: item.filters,
        sort: item.sort,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
    }));
}

export async function getSavedFilter(
    tenantId: string,
    businessId: string,
    userId: string,
    filterId: string,
): Promise<SavedFilter | null> {
    const pk = businessPK(tenantId, businessId);
    const sk = savedFilterSK(userId, filterId);

    const item = await getItem<SavedFilter & { PK: string; SK: string }>(pk, sk);
    if (!item) return null;
    return {
        id: item.id,
        userId: item.userId,
        businessId: item.businessId,
        tenantId: item.tenantId,
        name: item.name,
        entityTypes: item.entityTypes,
        filters: item.filters,
        sort: item.sort,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
    };
}

export async function deleteSavedFilter(
    tenantId: string,
    businessId: string,
    userId: string,
    filterId: string,
): Promise<boolean> {
    const pk = businessPK(tenantId, businessId);
    const sk = savedFilterSK(userId, filterId);

    try {
        await deleteItem(pk, sk);
        return true;
    } catch {
        return false;
    }
}
