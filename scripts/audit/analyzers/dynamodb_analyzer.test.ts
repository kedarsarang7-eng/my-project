/**
 * Unit tests for DynamoDB Access Pattern Analyzer
 *
 * Tests scanOperations() and isDynamicConstruction() against
 * realistic handler file content.
 */

import * as fs from 'fs';
import * as path from 'path';
import { scanOperations, isDynamicConstruction } from './dynamodb_analyzer';
import { DynamoDbOperation } from '../types';

// ─── Test Fixtures ──────────────────────────────────────────────────────────

const TEST_DIR = path.join(__dirname, '__test_fixtures__');
const HANDLERS_DIR = path.join(TEST_DIR, 'handlers');

beforeAll(() => {
  // Create test fixture directories
  fs.mkdirSync(HANDLERS_DIR, { recursive: true });
});

afterAll(() => {
  // Clean up test fixtures
  fs.rmSync(TEST_DIR, { recursive: true, force: true });
});

function writeFixture(filename: string, content: string): void {
  fs.writeFileSync(path.join(HANDLERS_DIR, filename), content, 'utf-8');
}

// ─── scanOperations() Tests ─────────────────────────────────────────────────

describe('scanOperations', () => {
  beforeEach(() => {
    // Clean fixture dir between tests
    const files = fs.readdirSync(HANDLERS_DIR);
    for (const f of files) {
      fs.unlinkSync(path.join(HANDLERS_DIR, f));
    }
  });

  it('should detect GetItemCommand operations', () => {
    writeFixture('get-handler.ts', `
import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall } from '@aws-sdk/util-dynamodb';

const dynamodb = new DynamoDBClient({});

export async function getUser(tenantId: string, userId: string) {
  const command = new GetItemCommand({
    TableName: 'users-table',
    Key: marshall({ PK: \`TENANT#\${tenantId}\`, SK: \`USER#\${userId}\` }),
  });
  return await dynamodb.send(command);
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    expect(ops.length).toBeGreaterThanOrEqual(1);

    const getOp = ops.find(op => op.type === 'get');
    expect(getOp).toBeDefined();
    expect(getOp!.tableName).toBe('users-table');
    expect(getOp!.handlerFile).toContain('get-handler.ts');
  });

  it('should detect QueryCommand with KeyConditionExpression', () => {
    writeFixture('query-handler.ts', `
import { DynamoDBClient, QueryCommand } from '@aws-sdk/client-dynamodb';
import { marshall } from '@aws-sdk/util-dynamodb';

const dynamodb = new DynamoDBClient({});
const TABLE = 'main-table';

export async function listOrders(tenantId: string) {
  const command = new QueryCommand({
    TableName: TABLE,
    KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
    FilterExpression: 'status = :active',
    ExpressionAttributeValues: marshall({
      ':pk': \`TENANT#\${tenantId}\`,
      ':sk': 'ORDER#',
      ':active': 'active',
    }),
  });
  return await dynamodb.send(command);
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    const queryOp = ops.find(op => op.type === 'query');
    expect(queryOp).toBeDefined();
    expect(queryOp!.tableName).toBe('TABLE');
    expect(queryOp!.keyCondition).toBe('PK = :pk AND begins_with(SK, :sk)');
    expect(queryOp!.filterExpression).toBe('status = :active');
  });

  it('should detect ScanCommand operations', () => {
    writeFixture('scan-handler.ts', `
import { DynamoDBClient, ScanCommand } from '@aws-sdk/client-dynamodb';

const dynamodb = new DynamoDBClient({});

export async function scanAll() {
  const command = new ScanCommand({
    TableName: 'products-table',
    FilterExpression: 'begins_with(PK, :prefix)',
  });
  return await dynamodb.send(command);
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    const scanOp = ops.find(op => op.type === 'scan');
    expect(scanOp).toBeDefined();
    expect(scanOp!.tableName).toBe('products-table');
    expect(scanOp!.filterExpression).toBe('begins_with(PK, :prefix)');
  });

  it('should detect PutItemCommand operations', () => {
    writeFixture('put-handler.ts', `
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall } from '@aws-sdk/util-dynamodb';

const dynamodb = new DynamoDBClient({});

export async function createRecord(tenantId: string) {
  const command = new PutItemCommand({
    TableName: 'records-table',
    Item: marshall({ PK: \`TENANT#\${tenantId}\`, SK: 'RECORD#123', data: 'value' }),
  });
  return await dynamodb.send(command);
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    const putOp = ops.find(op => op.type === 'put');
    expect(putOp).toBeDefined();
    expect(putOp!.tableName).toBe('records-table');
  });

  it('should detect UpdateItemCommand operations', () => {
    writeFixture('update-handler.ts', `
import { DynamoDBClient, UpdateItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall } from '@aws-sdk/util-dynamodb';

const dynamodb = new DynamoDBClient({});

export async function updateRecord(tenantId: string) {
  const command = new UpdateItemCommand({
    TableName: 'main-table',
    Key: marshall({ PK: \`TENANT#\${tenantId}\`, SK: 'METADATA' }),
    UpdateExpression: 'SET #status = :s',
    ExpressionAttributeValues: marshall({ ':s': 'active' }),
  });
  return await dynamodb.send(command);
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    const updateOp = ops.find(op => op.type === 'update');
    expect(updateOp).toBeDefined();
    expect(updateOp!.tableName).toBe('main-table');
  });

  it('should detect DeleteItemCommand operations', () => {
    writeFixture('delete-handler.ts', `
import { DynamoDBClient, DeleteItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall } from '@aws-sdk/util-dynamodb';

const dynamodb = new DynamoDBClient({});

export async function deleteRecord(tenantId: string, recordId: string) {
  const command = new DeleteItemCommand({
    TableName: 'main-table',
    Key: marshall({ PK: \`TENANT#\${tenantId}\`, SK: \`RECORD#\${recordId}\` }),
  });
  return await dynamodb.send(command);
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    const deleteOp = ops.find(op => op.type === 'delete');
    expect(deleteOp).toBeDefined();
    expect(deleteOp!.tableName).toBe('main-table');
  });

  it('should detect helper function operations (queryItems, updateItem)', () => {
    writeFixture('helper-handler.ts', `
import { queryItems, updateItem } from '../db/helpers';
import { Keys, TABLE_NAME } from '../config';

export async function listProducts(tenantId: string) {
  const pk = Keys.tenantPK(tenantId);
  const products = await queryItems<Record<string, any>>(pk, 'PRODUCT#', {
    filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
    expressionAttributeValues: { ':false': false },
    limit: 100,
  });
  return products;
}

export async function markActive(tenantId: string, productId: string) {
  const pk = Keys.tenantPK(tenantId);
  const sk = 'PRODUCT#' + productId;
  await updateItem(pk, sk, {
    updateExpression: 'SET isActive = :val',
    expressionAttributeValues: { ':val': true },
  });
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    expect(ops.length).toBeGreaterThanOrEqual(2);

    const queryOp = ops.find(op => op.type === 'query');
    expect(queryOp).toBeDefined();
    expect(queryOp!.filterExpression).toBe(
      '(attribute_not_exists(isDeleted) OR isDeleted = :false)'
    );

    const updateOp = ops.find(op => op.type === 'update');
    expect(updateOp).toBeDefined();
  });

  it('should detect TransactWriteItems inline operations', () => {
    writeFixture('transact-handler.ts', `
import { transactWrite } from '../db/helpers';
import { Keys, TABLE_NAME } from '../config';

export async function createOrder(tenantId: string) {
  const pk = Keys.tenantPK(tenantId);
  const now = new Date().toISOString();

  const transactItems: any[] = [];
  transactItems.push({
    Put: {
      TableName: TABLE_NAME,
      Item: { PK: pk, SK: 'ORDER#123', createdAt: now },
    },
  });
  transactItems.push({
    Update: {
      TableName: TABLE_NAME,
      Key: { PK: pk, SK: 'COUNTER#ORDERS' },
      UpdateExpression: 'SET #val = #val + :one',
      ExpressionAttributeValues: { ':one': 1 },
    },
  });

  await transactWrite(transactItems);
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    // Should find the transactWrite helper call + inline Put/Update
    const putOps = ops.filter(op => op.type === 'put');
    const updateOps = ops.filter(op => op.type === 'update');
    expect(putOps.length + updateOps.length).toBeGreaterThanOrEqual(1);
  });

  it('should detect lib-dynamodb commands (GetCommand, PutCommand, etc)', () => {
    writeFixture('lib-dynamo-handler.ts', `
import { DynamoDBDocumentClient, GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export async function getItem(id: string) {
  const result = await docClient.send(new GetCommand({
    TableName: 'items-table',
    Key: { PK: 'ITEM#' + id, SK: 'META' },
  }));
  return result.Item;
}

export async function putItem(data: any) {
  await docClient.send(new PutCommand({
    TableName: 'items-table',
    Item: data,
  }));
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    const getOp = ops.find(op => op.type === 'get');
    const putOp = ops.find(op => op.type === 'put');
    expect(getOp).toBeDefined();
    expect(putOp).toBeDefined();
    expect(getOp!.tableName).toBe('items-table');
    expect(putOp!.tableName).toBe('items-table');
  });

  it('should return empty array for non-existent directory', () => {
    const ops = scanOperations('/non/existent/path');
    expect(ops).toEqual([]);
  });

  it('should skip test files and declaration files', () => {
    writeFixture('handler.test.ts', `
import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb';
const command = new GetItemCommand({ TableName: 'test-table' });
`);
    writeFixture('types.d.ts', `
declare const command: any;
`);
    writeFixture('real-handler.ts', `
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
const command = new PutItemCommand({ TableName: 'real-table' });
`);

    const ops = scanOperations(HANDLERS_DIR);
    // Should only find the real-handler, not test or declaration files
    expect(ops.every(op => !op.handlerFile.includes('.test.ts'))).toBe(true);
    expect(ops.every(op => !op.handlerFile.includes('.d.ts'))).toBe(true);
    expect(ops.some(op => op.tableName === 'real-table')).toBe(true);
  });

  it('should include correct line numbers', () => {
    writeFixture('lined-handler.ts', `// Line 1
// Line 2
// Line 3
import { DynamoDBClient, QueryCommand } from '@aws-sdk/client-dynamodb';
// Line 5
export async function doQuery() {
  const command = new QueryCommand({
    TableName: 'my-table',
    KeyConditionExpression: 'PK = :pk',
  });
}
`);

    const ops = scanOperations(HANDLERS_DIR);
    const queryOp = ops.find(op => op.type === 'query');
    expect(queryOp).toBeDefined();
    expect(queryOp!.lineNumber).toBe(7); // Line 7 is where `new QueryCommand` is
  });
});

// ─── isDynamicConstruction() Tests ──────────────────────────────────────────

describe('isDynamicConstruction', () => {
  it('should return true for template literal table names', () => {
    const op: DynamoDbOperation = {
      type: 'get',
      tableName: '`${env}-users-table`',
      keyCondition: '',
      filterExpression: '',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: false,
    };
    expect(isDynamicConstruction(op)).toBe(true);
  });

  it('should return true for concatenation-based table names', () => {
    const op: DynamoDbOperation = {
      type: 'query',
      tableName: 'prefix + "-table"',
      keyCondition: '',
      filterExpression: '',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: false,
    };
    expect(isDynamicConstruction(op)).toBe(true);
  });

  it('should return true for environment variable references', () => {
    const op: DynamoDbOperation = {
      type: 'put',
      tableName: 'process.env.TABLE_NAME',
      keyCondition: '',
      filterExpression: '',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: false,
    };
    expect(isDynamicConstruction(op)).toBe(true);
  });

  it('should return true for config object references', () => {
    const op: DynamoDbOperation = {
      type: 'scan',
      tableName: 'config.dynamodb.tableName',
      keyCondition: '',
      filterExpression: '',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: false,
    };
    expect(isDynamicConstruction(op)).toBe(true);
  });

  it('should return true for dynamic key conditions', () => {
    const op: DynamoDbOperation = {
      type: 'query',
      tableName: 'static-table',
      keyCondition: '`PK = ${dynamicKey}`',
      filterExpression: '',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: false,
    };
    expect(isDynamicConstruction(op)).toBe(true);
  });

  it('should return true when isDynamic flag is already set', () => {
    const op: DynamoDbOperation = {
      type: 'get',
      tableName: 'users-table',
      keyCondition: 'PK = :pk',
      filterExpression: '',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: true,
    };
    expect(isDynamicConstruction(op)).toBe(true);
  });

  it('should return false for static string literal table names', () => {
    const op: DynamoDbOperation = {
      type: 'get',
      tableName: 'users-table',
      keyCondition: 'PK = :pk AND begins_with(SK, :sk)',
      filterExpression: 'status = :active',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: false,
    };
    expect(isDynamicConstruction(op)).toBe(false);
  });

  it('should return false for TABLE_NAME constant references', () => {
    const op: DynamoDbOperation = {
      type: 'query',
      tableName: 'TABLE_NAME',
      keyCondition: 'PK = :pk',
      filterExpression: '',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: false,
    };
    expect(isDynamicConstruction(op)).toBe(false);
  });

  it('should return false for empty table name', () => {
    const op: DynamoDbOperation = {
      type: 'put',
      tableName: '',
      keyCondition: '',
      filterExpression: '',
      handlerFile: 'test.ts',
      lineNumber: 1,
      isDynamic: false,
    };
    expect(isDynamicConstruction(op)).toBe(false);
  });
});
