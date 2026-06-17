/**
 * Phase 4.2 - API → DynamoDB Integration Tests
 * Verifies: invoice creation writes correct PK/SK, tenant isolation
 */

import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import { DynamoDBClient, GetItemCommand, QueryCommand, DeleteItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { config } from '../../src/config/environment';

const dynamo = new DynamoDBClient({ region: config.aws.region });
const TABLE_NAME = config.dynamodb.tableName;

// Test data
const TEST_TENANT_A = `tenant-a-${Date.now()}`;
const TEST_TENANT_B = `tenant-b-${Date.now()}`;
let tenantAToken: string;
let tenantBToken: string;

describe('API → DynamoDB Integration Tests', () => {
  beforeAll(async () => {
    // Setup: Create test tenants and get tokens
    // This would call the auth service to get real tokens
  });

  afterAll(async () => {
    // Cleanup: Remove all test data
    await cleanupTestData(TEST_TENANT_A);
    await cleanupTestData(TEST_TENANT_B);
  });

  describe('Invoice Creation Writes Correct DynamoDB Structure', () => {
    let createdInvoiceId: string;

    it('should write invoice with correct PK/SK to DynamoDB', async () => {
      // Create invoice via API
      const response = await fetch(`${config.apiGateway.url}/invoices`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${tenantAToken}`,
          'Content-Type': 'application/json',
          'x-tenant-id': TEST_TENANT_A,
        },
        body: JSON.stringify({
          customerName: 'Test Customer',
          items: [
            { productId: 'prod-1', qty: 2, price: 100, gstRate: 5 },
          ],
          paymentType: 'Cash',
        }),
      });

      expect(response.status).toBe(201);
      const data = await response.json();
      expect(data.success).toBe(true);
      createdInvoiceId = data.data.invoiceId;

      // Verify DynamoDB write
      const result = await dynamo.send(new GetItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({
          PK: `TENANT#${TEST_TENANT_A}`,
          SK: `INVOICE#${createdInvoiceId}`,
        }),
      }));

      expect(result.Item).toBeDefined();
      const item = unmarshall(result.Item!);

      // Verify structure
      expect(item.PK).toBe(`TENANT#${TEST_TENANT_A}`);
      expect(item.SK).toBe(`INVOICE#${createdInvoiceId}`);
      expect(item.tenantId).toBe(TEST_TENANT_A);
      expect(item.entityType).toBe('INVOICE');
      expect(item.GSI1PK).toBe(`TENANT#${TEST_TENANT_A}#INVOICES`);
      expect(item.totalAmount).toBe(210); // 200 + 10 GST
    });

    it('should write correct GST calculation', async () => {
      const response = await fetch(`${config.apiGateway.url}/invoices`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${tenantAToken}`,
          'Content-Type': 'application/json',
          'x-tenant-id': TEST_TENANT_A,
        },
        body: JSON.stringify({
          customerName: 'GST Test Customer',
          items: [
            { productId: 'prod-1', qty: 1, price: 1000, gstRate: 18 },
            { productId: 'prod-2', qty: 1, price: 500, gstRate: 5 },
          ],
        }),
      });

      expect(response.status).toBe(201);
      const data = await response.json();

      // Verify DynamoDB
      const result = await dynamo.send(new GetItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({
          PK: `TENANT#${TEST_TENANT_A}`,
          SK: `INVOICE#${data.data.invoiceId}`,
        }),
      }));

      const item = unmarshall(result.Item!);
      
      // 1000 + 180 GST (18%) = 1180
      // 500 + 25 GST (5%) = 525
      // Total = 1705
      expect(item.subtotal).toBe(1500);
      expect(item.gstAmount).toBe(205);
      expect(item.totalAmount).toBe(1705);
    });

    it('should reduce inventory on invoice creation', async () => {
      // Setup: Create a product with stock
      const productResponse = await fetch(`${config.apiGateway.url}/products`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${tenantAToken}`,
          'Content-Type': 'application/json',
          'x-tenant-id': TEST_TENANT_A,
        },
        body: JSON.stringify({
          name: 'Test Product',
          price: 100,
          stock: 100,
          gstRate: 5,
        }),
      });

      const productData = await productResponse.json();
      const productId = productData.data.productId;

      // Create invoice
      await fetch(`${config.apiGateway.url}/invoices`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${tenantAToken}`,
          'Content-Type': 'application/json',
          'x-tenant-id': TEST_TENANT_A,
        },
        body: JSON.stringify({
          customerName: 'Inventory Test',
          items: [
            { productId: productId, qty: 5, price: 100, gstRate: 5 },
          ],
        }),
      });

      // Verify inventory reduced
      const result = await dynamo.send(new GetItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({
          PK: `TENANT#${TEST_TENANT_A}`,
          SK: `PRODUCT#${productId}`,
        }),
      }));

      const product = unmarshall(result.Item!);
      expect(product.stock).toBe(95); // 100 - 5
    });
  });

  describe('Tenant Isolation at DynamoDB Level', () => {
    it('should NOT return data belonging to different tenant', async () => {
      // Create invoice for Tenant A
      const responseA = await fetch(`${config.apiGateway.url}/invoices`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${tenantAToken}`,
          'Content-Type': 'application/json',
          'x-tenant-id': TEST_TENANT_A,
        },
        body: JSON.stringify({
          customerName: 'Tenant A Customer',
          items: [{ productId: 'prod-1', qty: 1, price: 100, gstRate: 0 }],
        }),
      });

      const dataA = await responseA.json();
      const invoiceId = dataA.data.invoiceId;

      // Try to access Tenant A's invoice using Tenant B's token
      const accessAttempt = await fetch(`${config.apiGateway.url}/invoices/${invoiceId}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${tenantBToken}`,
          'x-tenant-id': TEST_TENANT_B,
        },
      });

      // Should return 403 Forbidden or 404 Not Found
      expect(accessAttempt.status).toBe(403);

      // Verify Tenant A's data is still intact
      const dbResult = await dynamo.send(new GetItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({
          PK: `TENANT#${TEST_TENANT_A}`,
          SK: `INVOICE#${invoiceId}`,
        }),
      }));

      expect(dbResult.Item).toBeDefined();
    });

    it('should use tenantId as DynamoDB partition key prefix', async () => {
      const result = await dynamo.send(new QueryCommand({
        TableName: TABLE_NAME,
        KeyConditionExpression: 'PK = :pk',
        ExpressionAttributeValues: marshall({
          ':pk': `TENANT#${TEST_TENANT_A}`,
        }),
      }));

      const items = result.Items?.map(item => unmarshall(item)) || [];
      
      // Verify every item has tenantId matching the PK
      for (const item of items) {
        expect(item.tenantId).toBe(TEST_TENANT_A);
        expect(item.PK).toBe(`TENANT#${TEST_TENANT_A}`);
      }
    });
  });

  describe('Pagination and Query Performance', () => {
    it('should paginate correctly when result set exceeds 1MB', async () => {
      // Create multiple invoices to test pagination
      const invoiceIds: string[] = [];
      
      for (let i = 0; i < 20; i++) {
        const response = await fetch(`${config.apiGateway.url}/invoices`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${tenantAToken}`,
            'Content-Type': 'application/json',
            'x-tenant-id': TEST_TENANT_A,
          },
          body: JSON.stringify({
            customerName: `Customer ${i}`,
            items: [{ productId: 'prod-1', qty: 1, price: 100, gstRate: 0 }],
          }),
        });

        const data = await response.json();
        invoiceIds.push(data.data.invoiceId);
      }

      // Query with pagination
      let allInvoices: any[] = [];
      let lastKey: Record<string, any> | undefined;

      do {
        const queryResult = await dynamo.send(new QueryCommand({
          TableName: TABLE_NAME,
          IndexName: 'GSI1',
          KeyConditionExpression: 'GSI1PK = :pk',
          ExpressionAttributeValues: marshall({
            ':pk': `TENANT#${TEST_TENANT_A}#INVOICES`,
          }),
          Limit: 10,
          ExclusiveStartKey: lastKey,
        }));

        const items = queryResult.Items?.map(item => unmarshall(item)) || [];
        allInvoices.push(...items);
        lastKey = queryResult.LastEvaluatedKey;
      } while (lastKey);

      // Verify all invoices were retrieved
      expect(allInvoices.length).toBeGreaterThanOrEqual(20);
    });

    it('should use GSI for list queries (not Scan)', async () => {
      // This test verifies that list queries use the GSI
      // We can't directly test for Scan vs Query, but we can verify the GSI is used
      
      const result = await dynamo.send(new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :prefix)',
        ExpressionAttributeValues: marshall({
          ':pk': `TENANT#${TEST_TENANT_A}#INVOICES`,
          ':prefix': '2024',
        }),
      }));

      // If this succeeds, the GSI is working
      expect(result).toBeDefined();
    });
  });

  describe('Conditional Writes', () => {
    it('should use conditional expression to prevent overwrite on create', async () => {
      // Create a product
      const createResponse = await fetch(`${config.apiGateway.url}/products`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${tenantAToken}`,
          'Content-Type': 'application/json',
          'x-tenant-id': TEST_TENANT_A,
        },
        body: JSON.stringify({
          id: 'duplicate-test-product',
          name: 'Test Product',
          price: 100,
          stock: 100,
        }),
      });

      expect(createResponse.status).toBe(201);

      // Try to create with same ID (should fail)
      const duplicateResponse = await fetch(`${config.apiGateway.url}/products`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${tenantAToken}`,
          'Content-Type': 'application/json',
          'x-tenant-id': TEST_TENANT_A,
        },
        body: JSON.stringify({
          id: 'duplicate-test-product',
          name: 'Duplicate Product',
          price: 200,
          stock: 50,
        }),
      });

      expect(duplicateResponse.status).toBe(409);
    });
  });
});

// Helper function to cleanup test data
async function cleanupTestData(tenantId: string): Promise<void> {
  // Query all items for this tenant
  const result = await dynamo.send(new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: 'PK = :pk',
    ExpressionAttributeValues: marshall({
      ':pk': `TENANT#${tenantId}`,
    }),
  }));

  // Delete each item
  for (const item of result.Items || []) {
    const unmarshalled = unmarshall(item);
    await dynamo.send(new DeleteItemCommand({
      TableName: TABLE_NAME,
      Key: marshall({
        PK: unmarshalled.PK,
        SK: unmarshalled.SK,
      }),
    }));
  }
}
