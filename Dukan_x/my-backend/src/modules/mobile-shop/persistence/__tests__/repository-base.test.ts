/**
 * Repository Base Tests (mock DynamoDB)
 *
 * Verifies:
 * - Items with mismatched tenantId are filtered out silently
 * - Security fault is logged for tenant mismatch
 * - Empty result returns correctly
 * - Pagination limits are clamped to config bounds
 *
 * Requirements: 6.5–6.6, 6.14, 6.19, 6.25, 6.28–6.30, 13.4, 13.6
 */

import { RepositoryBase, type RepositoryLogger, type RepositoryBaseConfig } from '../repository-base';
import type { QueryInput, GetInput } from '../access-patterns';
import type { TenantContextWire } from '../../schemas/common.schema';
import { PAGINATION_CONFIG } from '../../config/pagination.config';

// ─── Test Doubles ────────────────────────────────────────────────────────────

const TENANT_A = 'tenant-abc-123';
const TENANT_B = 'tenant-xyz-789';

const mockCtx: TenantContextWire = {
  tenantId: TENANT_A,
  businessId: 'biz-001',
  subjectId: 'sub-001',
  businessType: 'mobile_shop',
  permissions: ['mobile_shop:view'],
  correlationId: 'corr-test-001',
};

function createMockLogger(): RepositoryLogger & { calls: { method: string; args: unknown[] }[] } {
  const calls: { method: string; args: unknown[] }[] = [];
  return {
    calls,
    warn(msg: string, meta?: Record<string, unknown>) { calls.push({ method: 'warn', args: [msg, meta] }); },
    error(msg: string, meta?: Record<string, unknown>) { calls.push({ method: 'error', args: [msg, meta] }); },
    info(msg: string, meta?: Record<string, unknown>) { calls.push({ method: 'info', args: [msg, meta] }); },
  };
}

/**
 * Concrete test subclass to access protected methods of RepositoryBase.
 */
class TestRepository extends RepositoryBase {
  constructor(mockClient: any, config: RepositoryBaseConfig) {
    super(mockClient, config);
  }

  // Expose protected methods for testing
  public async testExecuteQuery(ctx: TenantContextWire, input: QueryInput) {
    return this.executeQuery(ctx, input);
  }

  public async testExecuteGet(ctx: TenantContextWire, input: GetInput) {
    return this.executeGet(ctx, input);
  }

  public testClampLimit(limit?: number) {
    return this.clampLimit(limit);
  }
}

function createMockClient(queryResult?: { Items?: Record<string, unknown>[]; LastEvaluatedKey?: Record<string, unknown> }, getResult?: { Item?: Record<string, unknown> }) {
  return {
    send: jest.fn().mockImplementation((command: any) => {
      const cmdName = command.constructor?.name || command.input?.constructor?.name;
      // Check if it's a QueryCommand by looking at command structure
      if (command.input?.KeyConditionExpression !== undefined || cmdName === 'QueryCommand') {
        return Promise.resolve({
          Items: queryResult?.Items ?? [],
          LastEvaluatedKey: queryResult?.LastEvaluatedKey,
          ConsumedCapacity: { TableName: 'test-table', CapacityUnits: 1 },
        });
      }
      // GetCommand
      return Promise.resolve({
        Item: getResult?.Item ?? undefined,
        ConsumedCapacity: { TableName: 'test-table', CapacityUnits: 0.5 },
      });
    }),
  };
}

// Mock the @aws-sdk/lib-dynamodb module
jest.mock('@aws-sdk/lib-dynamodb', () => {
  class MockQueryCommand {
    input: any;
    constructor(input: any) { this.input = input; }
  }
  class MockGetCommand {
    input: any;
    constructor(input: any) { this.input = input; }
  }
  return {
    QueryCommand: MockQueryCommand,
    GetCommand: MockGetCommand,
  };
});

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('RepositoryBase', () => {
  const baseQueryInput: QueryInput = {
    accessPatternId: 'AP-03',
    indexName: 'GSI1',
    keyConditionExpression: '#gsi1pk = :gsi1pk',
    expressionAttributeValues: { ':gsi1pk': `TENANT#${TENANT_A}#UNIT#IN_STOCK` },
    expressionAttributeNames: { '#gsi1pk': 'GSI1PK' },
    limit: 25,
    scanIndexForward: false,
    consistentRead: false,
  };

  describe('tenant mismatch filtering', () => {
    it('filters out items with mismatched tenantId silently', async () => {
      const logger = createMockLogger();
      const items = [
        { tenantId: TENANT_A, PK: `TENANT#${TENANT_A}#ENTITY#UNIT#u1`, SK: 'META#UNIT', status: 'IN_STOCK' },
        { tenantId: TENANT_B, PK: `TENANT#${TENANT_B}#ENTITY#UNIT#u2`, SK: 'META#UNIT', status: 'IN_STOCK' }, // cross-tenant
        { tenantId: TENANT_A, PK: `TENANT#${TENANT_A}#ENTITY#UNIT#u3`, SK: 'META#UNIT', status: 'SOLD' },
      ];

      const client = createMockClient({ Items: items });
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      const result = await repo.testExecuteQuery(mockCtx, baseQueryInput);

      // Only items with matching tenant should be returned
      expect(result.items).toHaveLength(2);
      expect(result.items[0]).toEqual(items[0]);
      expect(result.items[1]).toEqual(items[2]);
      expect(result.count).toBe(2);
    });

    it('logs security fault for tenant mismatch', async () => {
      const logger = createMockLogger();
      const items = [
        { tenantId: TENANT_B, PK: `TENANT#${TENANT_B}#ENTITY#UNIT#u2`, SK: 'META#UNIT' },
      ];

      const client = createMockClient({ Items: items });
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      await repo.testExecuteQuery(mockCtx, baseQueryInput);

      // Should have logged a security fault
      const errorCalls = logger.calls.filter((c) => c.method === 'error');
      expect(errorCalls.length).toBeGreaterThan(0);
      expect(errorCalls[0].args[0]).toContain('SECURITY_FAULT');
      expect(errorCalls[0].args[0]).toContain('Tenant mismatch');
    });

    it('does not expose mismatched items in result', async () => {
      const logger = createMockLogger();
      const items = [
        { tenantId: TENANT_B, PK: `TENANT#${TENANT_B}#CLAIM`, SK: 'IMEI#123456789012345' },
      ];

      const client = createMockClient({ Items: items });
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      const result = await repo.testExecuteQuery(mockCtx, baseQueryInput);

      expect(result.items).toHaveLength(0);
      expect(result.count).toBe(0);
    });
  });

  describe('executeGet — tenant verification', () => {
    const getInput: GetInput = {
      accessPatternId: 'AP-02',
      key: { PK: `TENANT#${TENANT_A}#CLAIM`, SK: 'IMEI#123456789012345' },
      consistentRead: true,
    };

    it('returns item when tenantId matches', async () => {
      const logger = createMockLogger();
      const item = { tenantId: TENANT_A, PK: `TENANT#${TENANT_A}#CLAIM`, SK: 'IMEI#123456789012345' };

      const client = createMockClient(undefined, { Item: item });
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      const result = await repo.testExecuteGet(mockCtx, getInput);

      expect(result.item).toEqual(item);
    });

    it('returns null and logs fault for mismatched tenantId', async () => {
      const logger = createMockLogger();
      const item = { tenantId: TENANT_B, PK: `TENANT#${TENANT_B}#CLAIM`, SK: 'IMEI#123456789012345' };

      const client = createMockClient(undefined, { Item: item });
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      const result = await repo.testExecuteGet(mockCtx, getInput);

      expect(result.item).toBeNull();
      const errorCalls = logger.calls.filter((c) => c.method === 'error');
      expect(errorCalls.length).toBeGreaterThan(0);
      expect(errorCalls[0].args[0]).toContain('SECURITY_FAULT');
    });

    it('returns null for non-existent item', async () => {
      const logger = createMockLogger();
      const client = createMockClient(undefined, { Item: undefined });
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      const result = await repo.testExecuteGet(mockCtx, getInput);

      expect(result.item).toBeNull();
      // No security fault logged for simply missing items
      const errorCalls = logger.calls.filter((c) => c.method === 'error');
      expect(errorCalls).toHaveLength(0);
    });
  });

  describe('empty result handling', () => {
    it('returns empty items array for empty query result', async () => {
      const logger = createMockLogger();
      const client = createMockClient({ Items: [] });
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      const result = await repo.testExecuteQuery(mockCtx, baseQueryInput);

      expect(result.items).toEqual([]);
      expect(result.count).toBe(0);
      expect(result.hasMore).toBe(false);
      expect(result.lastEvaluatedKey).toBeUndefined();
    });

    it('returns hasMore=true when LastEvaluatedKey is present', async () => {
      const logger = createMockLogger();
      const lastKey = { PK: `TENANT#${TENANT_A}#ENTITY#UNIT#u10`, SK: 'META#UNIT' };
      const items = [
        { tenantId: TENANT_A, PK: `TENANT#${TENANT_A}#ENTITY#UNIT#u1`, SK: 'META#UNIT' },
      ];
      const client = createMockClient({ Items: items, LastEvaluatedKey: lastKey });
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      const result = await repo.testExecuteQuery(mockCtx, baseQueryInput);

      expect(result.hasMore).toBe(true);
      expect(result.lastEvaluatedKey).toEqual(lastKey);
    });
  });

  describe('pagination limit clamping', () => {
    it('returns defaultPageSize when no limit provided', () => {
      const logger = createMockLogger();
      const client = createMockClient();
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      expect(repo.testClampLimit(undefined)).toBe(PAGINATION_CONFIG.defaultPageSize);
    });

    it('clamps limit to maxPageSize when above maximum', () => {
      const logger = createMockLogger();
      const client = createMockClient();
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      expect(repo.testClampLimit(500)).toBe(PAGINATION_CONFIG.maxPageSize);
    });

    it('clamps limit to minPageSize when below minimum', () => {
      const logger = createMockLogger();
      const client = createMockClient();
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      expect(repo.testClampLimit(0)).toBe(PAGINATION_CONFIG.minPageSize);
    });

    it('passes through valid limit within bounds', () => {
      const logger = createMockLogger();
      const client = createMockClient();
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      expect(repo.testClampLimit(50)).toBe(50);
    });

    it('clamps negative limit to minPageSize', () => {
      const logger = createMockLogger();
      const client = createMockClient();
      const repo = new TestRepository(client, { tableName: 'test-table', logger });

      expect(repo.testClampLimit(-10)).toBe(PAGINATION_CONFIG.minPageSize);
    });
  });
});
