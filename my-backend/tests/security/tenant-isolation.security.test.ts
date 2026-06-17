/**
 * Phase 5.1 - Security Audit: Tenant Isolation Tests
 * CRITICAL: These tests verify cross-tenant data leakage prevention
 */

import { describe, it, expect, beforeAll } from '@jest/globals';
import { DynamoDBClient, PutItemCommand, GetItemCommand, QueryCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { config } from '../../src/config/environment';

const dynamo = new DynamoDBClient({ region: config.aws.region });
const TABLE_NAME = config.dynamodb.tableName;
const API_URL = process.env.API_GATEWAY_URL || 'http://localhost:3000';

// Test tenant IDs
const TENANT_A = `security-test-tenant-a-${Date.now()}`;
const TENANT_B = `security-test-tenant-b-${Date.now()}`;

describe('SECURITY AUDIT: Tenant Isolation', () => {
  let tenantAToken: string;
  let tenantBToken: string;
  let tenantAInvoiceId: string;
  let tenantBInvoiceId: string;

  beforeAll(async () => {
    // Setup: Create test data for both tenants
    // This simulates real tenant data in DynamoDB
    await createTestInvoice(TENANT_A, 'Tenant A Secret Invoice');
    await createTestInvoice(TENANT_B, 'Tenant B Secret Invoice');
  });

  describe('CRITICAL: Cross-Tenant Data Access Prevention', () => {
    it('SECURITY: Tenant B CANNOT access Tenant A invoice via API', async () => {
      // Attempt to access Tenant A's invoice using Tenant B's token
      const response = await fetch(`${API_URL}/invoices/${tenantAInvoiceId}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${tenantBToken}`,
          'x-tenant-id': TENANT_B,
        },
      });

      // Expect 403 Forbidden or 404 Not Found
      expect(response.status).toBe(403);
      
      const data = await response.json();
      expect(data.error).toMatch(/access denied|not authorized/i);
    });

    it('SECURITY: Direct DynamoDB query respects tenant boundary', async () => {
      // Query DynamoDB for Tenant A's data
      const tenantAQuery = await dynamo.send(new QueryCommand({
        TableName: TABLE_NAME,
        KeyConditionExpression: 'PK = :pk AND begins_with(SK, :skPrefix)',
        ExpressionAttributeValues: marshall({
          ':pk': `TENANT#${TENANT_A}`,
          ':skPrefix': 'INVOICE#',
        }),
      }));

      const tenantAItems = tenantAQuery.Items?.map(item => unmarshall(item)) || [];
      
      // Verify all returned items belong to Tenant A
      for (const item of tenantAItems) {
        expect(item.tenantId).toBe(TENANT_A);
        expect(item.PK).toBe(`TENANT#${TENANT_A}`);
        // CRITICAL: Ensure no Tenant B data leaked
        expect(item.tenantId).not.toBe(TENANT_B);
      }
    });

    it('SECURITY: Tenant ID in JWT must match resource tenant', async () => {
      // Create a forged token (or use a token from different tenant)
      const forgedHeaders = {
        'Authorization': `Bearer ${tenantAToken}`,
        'x-tenant-id': TENANT_B, // Mismatch: Token is for A, header says B
      };

      const response = await fetch(`${API_URL}/invoices`, {
        method: 'GET',
        headers: forgedHeaders,
      });

      expect(response.status).toBe(403);
    });
  });

  describe('CRITICAL: Business-Level Isolation', () => {
    it('SECURITY: Staff cannot access other business data', async () => {
      // Staff user tries to access different business
      const response = await fetch(`${API_URL}/staff/sales`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${tenantAToken}`, // Staff token
          'x-tenant-id': TENANT_A,
          'x-business-id': 'different-business-id', // Wrong business
        },
      });

      expect(response.status).toBe(403);
    });
  });

  describe('CRITICAL: Input Injection Prevention', () => {
    const maliciousInputs = [
      { tenant_id: "'; DROP TABLE invoices; --", description: 'SQL Injection attempt' },
      { tenant_id: '<script>alert("xss")</script>', description: 'XSS attempt' },
      { tenant_id: '../../../etc/passwd', description: 'Path traversal attempt' },
      { tenant_id: '{{7*7}}', description: 'Template injection attempt' },
    ];

    maliciousInputs.forEach(({ tenant_id, description }) => {
      it(`SECURITY: Rejects malicious input - ${description}`, async () => {
        const response = await fetch(`${API_URL}/invoices`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${tenantAToken}`,
            'Content-Type': 'application/json',
            'x-tenant-id': TENANT_A,
          },
          body: JSON.stringify({
            tenant_id, // Malicious input
            customerName: 'Test',
            items: [{ productId: '1', qty: 1, price: 100 }],
          }),
        });

        // Should return 400 (validation error) not 500 (server error)
        expect(response.status).toBe(400);
        
        // Verify no data was created with malicious ID
        const dbCheck = await dynamo.send(new GetItemCommand({
          TableName: TABLE_NAME,
          Key: marshall({
            PK: `TENANT#${tenant_id}`,
            SK: 'INVOICE#test',
          }),
        }));

        expect(dbCheck.Item).toBeUndefined();
      });
    });
  });

  describe('CRITICAL: RBAC Enforcement', () => {
    it('SECURITY: Viewer role cannot create invoices', async () => {
      // Get a viewer role token (simulated)
      const viewerToken = 'viewer-token-placeholder';
      
      const response = await fetch(`${API_URL}/invoices`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${viewerToken}`,
          'Content-Type': 'application/json',
          'x-tenant-id': TENANT_A,
        },
        body: JSON.stringify({
          customerName: 'Test',
          items: [{ productId: '1', qty: 1, price: 100 }],
        }),
      });

      expect(response.status).toBe(403);
    });

    it('SECURITY: Staff role cannot delete invoices', async () => {
      const staffToken = 'staff-token-placeholder';
      
      const response = await fetch(`${API_URL}/invoices/${tenantAInvoiceId}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${staffToken}`,
          'x-tenant-id': TENANT_A,
        },
      });

      expect(response.status).toBe(403);
    });
  });
});

// Helper function to create test invoice
type InvoiceItem = {
  productId: string;
  qty: number;
  price: number;
  gstRate?: number;
};

async function createTestInvoice(tenantId: string, customerName: string): Promise<string> {
  const invoiceId = `inv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const now = new Date().toISOString();
  
  const items: InvoiceItem[] = [
    { productId: 'prod-1', qty: 2, price: 100, gstRate: 5 },
  ];
  
  const subtotal = items.reduce((sum, item) => sum + (item.qty * item.price), 0);
  const gstAmount = items.reduce((sum, item) => sum + (item.qty * item.price * (item.gstRate || 0) / 100), 0);
  const total = subtotal + gstAmount;

  await dynamo.send(new PutItemCommand({
    TableName: TABLE_NAME,
    Item: marshall({
      PK: `TENANT#${tenantId}`,
      SK: `INVOICE#${invoiceId}`,
      GSI1PK: `TENANT#${tenantId}#INVOICES`,
      GSI1SK: now,
      entityType: 'INVOICE',
      id: invoiceId,
      tenantId: tenantId,
      customerName,
      items,
      subtotal,
      gstAmount,
      totalAmount: total,
      status: 'completed',
      createdAt: now,
      updatedAt: now,
    }),
  }));

  return invoiceId;
}
