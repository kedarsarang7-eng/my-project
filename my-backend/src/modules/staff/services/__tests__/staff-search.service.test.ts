// ============================================================================
// Staff Module — Global Search & Saved Filters Service Tests (Task 13.2)
// ============================================================================
// Tests for the matchScore utility (pure function) and saved filter CRUD logic.
// DynamoDB interactions are tested via mocking the config module.
// Requirements: 9.7
// ============================================================================

// Mock the DynamoDB config before importing the module under test
jest.mock('../../../../config/dynamodb.config', () => ({
    queryItems: jest.fn(),
    putItem: jest.fn(),
    getItem: jest.fn(),
    queryAllItems: jest.fn(),
    deleteItem: jest.fn(),
}));

jest.mock('../../../../dynamodb/keys', () => ({
    businessPK: (tenantId: string, businessId: string) =>
        `TENANT#${tenantId}#BIZ#${businessId}`,
    gsi1PK: jest.fn(),
    gsi1SK: jest.fn(),
}));

import { globalStaffSearch, createSavedFilter, listSavedFilters, deleteSavedFilter } from '../staff-search.service';
import { queryItems, putItem, getItem, deleteItem } from '../../../../config/dynamodb.config';

const mockQueryItems = queryItems as jest.MockedFunction<typeof queryItems>;
const mockPutItem = putItem as jest.MockedFunction<typeof putItem>;
const mockDeleteItem = deleteItem as jest.MockedFunction<typeof deleteItem>;

describe('Staff Search Service', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('globalStaffSearch', () => {
        it('should return empty results for empty query', async () => {
            const result = await globalStaffSearch('t1', 'b1', '');
            expect(result.results).toHaveLength(0);
            expect(result.total).toBe(0);
        });

        it('should return empty results for whitespace-only query', async () => {
            const result = await globalStaffSearch('t1', 'b1', '   ');
            expect(result.results).toHaveLength(0);
        });

        it('should search employees by name', async () => {
            mockQueryItems.mockImplementation(async (_pk, skPrefix) => {
                if (skPrefix === 'EMP#') {
                    return {
                        items: [
                            { id: 'emp-1', fullName: 'Alice Johnson', status: 'active', entity_type: 'STAFF_EMP' },
                            { id: 'emp-2', fullName: 'Bob Smith', status: 'active', entity_type: 'STAFF_EMP' },
                        ],
                    };
                }
                return { items: [] };
            });

            const result = await globalStaffSearch('t1', 'b1', 'Alice');
            expect(result.results.length).toBeGreaterThan(0);
            expect(result.results[0].label).toBe('Alice Johnson');
            expect(result.results[0].entityType).toBe('STAFF_EMP');
        });

        it('should search across multiple entity types', async () => {
            mockQueryItems.mockImplementation(async (_pk, skPrefix) => {
                if (skPrefix === 'EMP#') {
                    return {
                        items: [
                            { id: 'emp-1', fullName: 'Dev Team Lead', status: 'active', entity_type: 'STAFF_EMP' },
                        ],
                    };
                }
                if (skPrefix === 'DEPT#') {
                    return {
                        items: [
                            { id: 'dept-1', name: 'Development', entity_type: 'STAFF_DEPT' },
                        ],
                    };
                }
                if (skPrefix === 'TASK#') {
                    return {
                        items: [
                            { id: 'task-1', title: 'Develop feature X', status: 'open', entity_type: 'STAFF_TASK' },
                        ],
                    };
                }
                return { items: [] };
            });

            const result = await globalStaffSearch('t1', 'b1', 'Dev');
            expect(result.results.length).toBeGreaterThanOrEqual(3);
            const types = result.results.map((r) => r.entityType);
            expect(types).toContain('STAFF_EMP');
            expect(types).toContain('STAFF_DEPT');
            expect(types).toContain('STAFF_TASK');
        });

        it('should respect the limit option', async () => {
            const manyEmployees = Array.from({ length: 10 }, (_, i) => ({
                id: `emp-${i}`,
                fullName: `Employee Match ${i}`,
                status: 'active',
                entity_type: 'STAFF_EMP',
            }));

            mockQueryItems.mockImplementation(async (_pk, skPrefix) => {
                if (skPrefix === 'EMP#') return { items: manyEmployees };
                return { items: [] };
            });

            const result = await globalStaffSearch('t1', 'b1', 'Match', { limit: 3 });
            expect(result.results.length).toBe(3);
            expect(result.total).toBe(10);
        });

        it('should filter by entity types when specified', async () => {
            mockQueryItems.mockImplementation(async (_pk, skPrefix) => {
                if (skPrefix === 'DEPT#') {
                    return {
                        items: [
                            { id: 'dept-1', name: 'Marketing', entity_type: 'STAFF_DEPT' },
                        ],
                    };
                }
                return { items: [] };
            });

            const result = await globalStaffSearch('t1', 'b1', 'Marketing', {
                entityTypes: ['STAFF_DEPT'],
            });
            expect(result.results.length).toBe(1);
            expect(result.results[0].entityType).toBe('STAFF_DEPT');
        });

        it('should sort results by relevance (exact match first)', async () => {
            mockQueryItems.mockImplementation(async (_pk, skPrefix) => {
                if (skPrefix === 'EMP#') {
                    return {
                        items: [
                            { id: 'emp-1', fullName: 'Contains alice somewhere', status: 'active', entity_type: 'STAFF_EMP' },
                            { id: 'emp-2', fullName: 'alice', status: 'active', entity_type: 'STAFF_EMP' },
                            { id: 'emp-3', fullName: 'Alice starts here', status: 'active', entity_type: 'STAFF_EMP' },
                        ],
                    };
                }
                return { items: [] };
            });

            const result = await globalStaffSearch('t1', 'b1', 'alice');
            // Exact match should be ranked highest
            expect(result.results[0].label).toBe('alice');
            // Starts-with should be next
            expect(result.results[1].label).toBe('Alice starts here');
        });
    });

    describe('Saved Filters CRUD', () => {
        it('should create a saved filter', async () => {
            mockPutItem.mockResolvedValue(undefined);

            const filter = await createSavedFilter('t1', 'b1', {
                id: 'filter-1',
                userId: 'user-1',
                name: 'Active Employees',
                entityTypes: ['STAFF_EMP'],
                filters: { status: 'active' },
                sort: { field: 'fullName', direction: 'asc' },
            });

            expect(filter.id).toBe('filter-1');
            expect(filter.name).toBe('Active Employees');
            expect(filter.userId).toBe('user-1');
            expect(filter.tenantId).toBe('t1');
            expect(filter.businessId).toBe('b1');
            expect(filter.createdAt).toBeDefined();
            expect(mockPutItem).toHaveBeenCalledTimes(1);
        });

        it('should list saved filters for a user', async () => {
            mockQueryItems.mockResolvedValue({
                items: [
                    {
                        PK: 'TENANT#t1#BIZ#b1',
                        SK: 'SRCHFILTER#user-1#filter-1',
                        id: 'filter-1',
                        userId: 'user-1',
                        businessId: 'b1',
                        tenantId: 't1',
                        name: 'My Filter',
                        createdAt: '2024-01-01T00:00:00Z',
                        updatedAt: '2024-01-01T00:00:00Z',
                    },
                ],
            });

            const filters = await listSavedFilters('t1', 'b1', 'user-1');
            expect(filters).toHaveLength(1);
            expect(filters[0].name).toBe('My Filter');
        });

        it('should delete a saved filter', async () => {
            mockDeleteItem.mockResolvedValue(undefined);

            const result = await deleteSavedFilter('t1', 'b1', 'user-1', 'filter-1');
            expect(result).toBe(true);
            expect(mockDeleteItem).toHaveBeenCalledTimes(1);
        });

        it('should return false when delete fails', async () => {
            mockDeleteItem.mockRejectedValue(new Error('NotFound'));

            const result = await deleteSavedFilter('t1', 'b1', 'user-1', 'filter-999');
            expect(result).toBe(false);
        });
    });
});
