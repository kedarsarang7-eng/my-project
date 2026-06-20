/**
 * Tests for tenant_enforcer.ts — Repository-Layer Enforcement and Deployment Gate
 *
 * Validates:
 * - Detection of direct DynamoDB client usage bypassing the repository layer
 * - Deployment gate pass/fail logic
 * - Repository file exemption
 * - Import line skipping
 * - Call location resolution
 */

import * as fs from 'fs';
import * as path from 'path';
import {
  detectRepositoryBypasses,
  enforceDeploymentGate,
  TenantBypassViolation,
} from './tenant_enforcer';

// ─── Test Fixtures ──────────────────────────────────────────────────────────

const TEST_DIR = path.join(__dirname, '__test_fixtures_tenant_enforcer__');

function setupTestDir(): void {
  if (fs.existsSync(TEST_DIR)) {
    fs.rmSync(TEST_DIR, { recursive: true });
  }
  fs.mkdirSync(TEST_DIR, { recursive: true });
}

function teardownTestDir(): void {
  if (fs.existsSync(TEST_DIR)) {
    fs.rmSync(TEST_DIR, { recursive: true });
  }
}

function writeFixture(filename: string, content: string): void {
  fs.writeFileSync(path.join(TEST_DIR, filename), content, 'utf-8');
}

// ─── Tests ──────────────────────────────────────────────────────────────────

describe('tenant_enforcer', () => {
  beforeEach(() => setupTestDir());
  afterEach(() => teardownTestDir());

  describe('detectRepositoryBypasses', () => {
    it('should detect direct DynamoDBClient instantiation', () => {
      writeFixture('handler.ts', `
import { APIGatewayProxyEventV2 } from 'aws-lambda';

export const handler = async (event: APIGatewayProxyEventV2) => {
  const client = new DynamoDBClient({});
  return { statusCode: 200, body: 'ok' };
};
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(1);
      expect(violations[0].handlerFile).toContain('handler.ts');
      expect(violations[0].lineNumber).toBe(5);
      expect(violations[0].description).toContain('DynamoDBClient instantiation');
    });

    it('should detect DynamoDB command usage', () => {
      writeFixture('get-user.ts', `
import { GetCommand } from '@aws-sdk/lib-dynamodb';

export async function getUser(id: string) {
  const command = new GetCommand({
    TableName: 'users',
    Key: { id }
  });
  return command;
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(1);
      expect(violations[0].description).toContain('GetCommand usage');
      expect(violations[0].lineNumber).toBe(5);
    });

    it('should detect multiple violations in a single file', () => {
      writeFixture('multi-violation.ts', `
export async function badHandler() {
  const client = new DynamoDBClient({});
  const putCmd = new PutItemCommand({ TableName: 'orders', Item: {} });
  const getCmd = new GetItemCommand({ TableName: 'orders', Key: {} });
  return { statusCode: 200 };
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(3);
    });

    it('should skip repository implementation files', () => {
      writeFixture('user-repository.ts', `
/**
 * User Repository — tenant-scoped DynamoDB access
 */
export class UserRepository {
  async getUser(tenantId: string, userId: string) {
    const command = new GetCommand({
      TableName: 'users',
      Key: { tenantId, userId }
    });
    return client.send(command);
  }
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(0);
    });

    it('should skip import/require lines', () => {
      writeFixture('imports-only.ts', `
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
const repo = require('../repositories/user-repository');

export async function handler() {
  return repo.getUser('tenant1', 'user1');
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(0);
    });

    it('should skip comment lines', () => {
      writeFixture('comments.ts', `
export async function handler() {
  // const client = new DynamoDBClient({});
  /* new PutItemCommand({ TableName: 'x' }); */
  * new GetCommand({ TableName: 'x' });
  return { statusCode: 200 };
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(0);
    });

    it('should skip test files', () => {
      writeFixture('handler.test.ts', `
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
const client = new DynamoDBClient({});
const cmd = new GetCommand({ TableName: 'test' });
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(0);
    });

    it('should skip .d.ts declaration files', () => {
      writeFixture('types.d.ts', `
declare const client: DynamoDBClient;
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(0);
    });

    it('should detect DynamoDBDocumentClient.from()', () => {
      writeFixture('doc-client.ts', `
export const handler = async () => {
  const baseClient = new DynamoDBClient({});
  const docClient = DynamoDBDocumentClient.from(baseClient);
  return { statusCode: 200 };
};
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(2);
      const labels = violations.map(v => v.description);
      expect(labels.some(l => l.includes('DynamoDBClient instantiation'))).toBe(true);
      expect(labels.some(l => l.includes('DynamoDBDocumentClient.from'))).toBe(true);
    });

    it('should return empty array for clean handlers using repository', () => {
      writeFixture('clean-handler.ts', `
import { userRepository } from '../repositories/user-repository';

export async function handler(event: any) {
  const user = await userRepository.getUser(event.tenantId, event.userId);
  return { statusCode: 200, body: JSON.stringify(user) };
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(0);
    });

    it('should handle non-existent directory gracefully', () => {
      const violations = detectRepositoryBypasses('/non/existent/path');
      expect(violations).toEqual([]);
    });

    it('should scan subdirectories recursively', () => {
      const subDir = path.join(TEST_DIR, 'nested');
      fs.mkdirSync(subDir, { recursive: true });
      fs.writeFileSync(path.join(subDir, 'nested-handler.ts'), `
export async function nestedHandler() {
  const cmd = new QueryCommand({ TableName: 'data' });
  return cmd;
}
`, 'utf-8');

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(1);
      expect(violations[0].handlerFile).toContain('nested-handler.ts');
    });

    it('should include call location with enclosing function name', () => {
      writeFixture('located.ts', `
export async function createOrder(event: any) {
  const tenantId = event.tenantId;
  const cmd = new PutCommand({ TableName: 'orders', Item: { tenantId } });
  return { statusCode: 200 };
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(1);
      expect(violations[0].callLocation).toContain('createOrder');
      expect(violations[0].callLocation).toContain('located.ts');
    });

    it('should detect various DynamoDB send patterns', () => {
      writeFixture('send-patterns.ts', `
export async function handler1() {
  await docClient.send(new GetCommand({}));
}

export async function handler2() {
  await dynamoClient.send(new PutCommand({}));
}

export async function handler3() {
  await ddbClient.send(new QueryCommand({}));
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(3);
    });
  });

  describe('enforceDeploymentGate', () => {
    it('should pass when no violations exist', () => {
      writeFixture('clean.ts', `
import { orderRepository } from '../repositories/order-repository';

export async function handler(event: any) {
  return await orderRepository.getOrders(event.tenantId);
}
`);

      const result = enforceDeploymentGate(TEST_DIR);
      expect(result.pass).toBe(true);
      expect(result.violations).toEqual([]);
    });

    it('should fail when violations exist', () => {
      writeFixture('bad-handler.ts', `
export async function handler() {
  const client = new DynamoDBClient({});
  const cmd = new GetItemCommand({ TableName: 'users', Key: {} });
  return { statusCode: 200 };
}
`);

      const result = enforceDeploymentGate(TEST_DIR);
      expect(result.pass).toBe(false);
      expect(result.violations.length).toBeGreaterThan(0);
    });

    it('should report violating handler name and location', () => {
      writeFixture('violating.ts', `
export async function processPayment(event: any) {
  const cmd = new UpdateCommand({
    TableName: 'transactions',
    Key: { id: event.transactionId },
    UpdateExpression: 'SET #status = :status',
  });
  return { statusCode: 200 };
}
`);

      const result = enforceDeploymentGate(TEST_DIR);
      expect(result.pass).toBe(false);
      expect(result.violations.length).toBe(1);
      expect(result.violations[0].handlerFile).toContain('violating.ts');
      expect(result.violations[0].callLocation).toContain('processPayment');
      expect(result.violations[0].lineNumber).toBe(3);
    });

    it('should handle empty directory', () => {
      const result = enforceDeploymentGate(TEST_DIR);
      expect(result.pass).toBe(true);
      expect(result.violations).toEqual([]);
    });

    it('should log bypasses with handler name and call location to console', () => {
      writeFixture('logged-handler.ts', `
export async function submitOrder(event: any) {
  const client = new DynamoDBClient({});
  return { statusCode: 200 };
}
`);

      const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

      const result = enforceDeploymentGate(TEST_DIR);

      expect(result.pass).toBe(false);
      // Verify console.warn was called with bypass details
      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('[tenant_enforcer] BYPASS DETECTED')
      );
      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('logged-handler.ts')
      );
      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('submitOrder')
      );
      // Verify console.error was called with deployment gate failure summary
      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining('[tenant_enforcer] DEPLOYMENT GATE FAILED')
      );

      warnSpy.mockRestore();
      errorSpy.mockRestore();
    });
  });

  describe('tenant scoping verification for remediated handlers', () => {
    it('should pass when all handlers use repository pattern for DynamoDB access', () => {
      writeFixture('remediated-billing.ts', `
import { billingRepository } from '../repositories/billing-repository';

export async function createInvoice(event: any) {
  const tenantId = event.requestContext.authorizer.claims.tenantId;
  const invoice = JSON.parse(event.body);
  return await billingRepository.createInvoice(tenantId, invoice);
}
`);

      writeFixture('remediated-inventory.ts', `
import { inventoryRepository } from '../repositories/inventory-repository';

export async function getProducts(event: any) {
  const tenantId = event.requestContext.authorizer.claims.tenantId;
  return await inventoryRepository.listProducts(tenantId);
}
`);

      const result = enforceDeploymentGate(TEST_DIR);
      expect(result.pass).toBe(true);
      expect(result.violations).toHaveLength(0);
    });

    it('should detect when a remediated handler bypasses repository for any DynamoDB operation type', () => {
      // Simulates a handler that was partially remediated but still has a direct scan
      writeFixture('partial-remediation.ts', `
import { productRepository } from '../repositories/product-repository';

export async function searchProducts(event: any) {
  const tenantId = event.requestContext.authorizer.claims.tenantId;
  // Uses repository for gets
  const product = await productRepository.getProduct(tenantId, 'p1');
  // But directly scans for search — BYPASS
  const scanCmd = new ScanCommand({ TableName: 'products' });
  return { statusCode: 200 };
}
`);

      const violations = detectRepositoryBypasses(TEST_DIR);
      expect(violations.length).toBe(1);
      expect(violations[0].description).toContain('ScanCommand');
      expect(violations[0].callLocation).toContain('searchProducts');
    });

    it('should verify all DynamoDB operations across multiple remediated handlers in subdirectories', () => {
      const handlers1 = path.join(TEST_DIR, 'billing');
      const handlers2 = path.join(TEST_DIR, 'orders');
      fs.mkdirSync(handlers1, { recursive: true });
      fs.mkdirSync(handlers2, { recursive: true });

      fs.writeFileSync(path.join(handlers1, 'create-invoice.ts'), `
import { billingRepo } from '../repositories/billing-repo';
export async function createInvoice(event: any) {
  return await billingRepo.create(event.tenantId, event.body);
}
`, 'utf-8');

      fs.writeFileSync(path.join(handlers2, 'update-order.ts'), `
export async function updateOrder(event: any) {
  const cmd = new UpdateItemCommand({
    TableName: 'orders',
    Key: { orderId: event.pathParameters.id },
    UpdateExpression: 'SET #s = :s'
  });
  return { statusCode: 200 };
}
`, 'utf-8');

      const result = enforceDeploymentGate(TEST_DIR);
      expect(result.pass).toBe(false);
      expect(result.violations.length).toBe(1);
      expect(result.violations[0].handlerFile).toContain('update-order.ts');
      expect(result.violations[0].callLocation).toContain('updateOrder');
    });
  });
});
