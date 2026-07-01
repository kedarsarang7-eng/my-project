// ============================================================================
// Test Fixtures — Seed Data for Tenant Isolation Integration Tests
// ============================================================================
// Defines synthetic data for 2 tenants. These fixtures are used in-memory
// by mock DynamoDB calls, not written to real tables.
// ============================================================================

import { TENANT_A, TENANT_B, USERS } from './jwt-factory';

// ── Data IDs ─────────────────────────────────────────────────────────────────

export const IDS = {
    // Tenant A resources
    A_PRODUCT_1: 'prod-a-001',
    A_PRODUCT_2: 'prod-a-002',
    A_PRODUCT_3: 'prod-a-003',
    A_INVOICE_1: 'inv-a-001',
    A_INVOICE_2: 'inv-a-002',
    A_CUSTOMER_1: 'cust-a-001',
    A_CUSTOMER_2: 'cust-a-002',
    A_BUSINESS_1: 'biz-a-001',

    // Tenant B resources
    B_PRODUCT_1: 'prod-b-001',
    B_PRODUCT_2: 'prod-b-002',
    B_INVOICE_1: 'inv-b-001',
    B_CUSTOMER_1: 'cust-b-001',
    B_BUSINESS_1: 'biz-b-001',
} as const;

// ── DynamoDB Items ───────────────────────────────────────────────────────────

const now = new Date().toISOString();

/**
 * All items that would exist in the single-table DynamoDB for testing.
 * Keyed by PK#SK for easy lookup by mock implementations.
 */
export const SEED_ITEMS: Record<string, Record<string, unknown>> = {
    // ── Tenant A Products ──────────────────────────────────────────────────
    [`TENANT#${TENANT_A.tenantId}#PRODUCT#${IDS.A_PRODUCT_1}`]: {
        PK: `TENANT#${TENANT_A.tenantId}`,
        SK: `PRODUCT#${IDS.A_PRODUCT_1}`,
        id: IDS.A_PRODUCT_1,
        tenantId: TENANT_A.tenantId,
        name: 'Alpha Widget A',
        price: 9999,  // paise
        sku: 'AW-001',
        category: 'electronics',
        createdAt: now,
        updatedAt: now,
    },
    [`TENANT#${TENANT_A.tenantId}#PRODUCT#${IDS.A_PRODUCT_2}`]: {
        PK: `TENANT#${TENANT_A.tenantId}`,
        SK: `PRODUCT#${IDS.A_PRODUCT_2}`,
        id: IDS.A_PRODUCT_2,
        tenantId: TENANT_A.tenantId,
        name: 'Alpha Widget B',
        price: 14999,
        sku: 'AW-002',
        category: 'electronics',
        createdAt: now,
        updatedAt: now,
    },
    [`TENANT#${TENANT_A.tenantId}#PRODUCT#${IDS.A_PRODUCT_3}`]: {
        PK: `TENANT#${TENANT_A.tenantId}`,
        SK: `PRODUCT#${IDS.A_PRODUCT_3}`,
        id: IDS.A_PRODUCT_3,
        tenantId: TENANT_A.tenantId,
        name: 'Alpha Widget C',
        price: 24999,
        sku: 'AW-003',
        category: 'electronics',
        createdAt: now,
        updatedAt: now,
    },

    // ── Tenant A Invoices ──────────────────────────────────────────────────
    [`TENANT#${TENANT_A.tenantId}#INVOICE#${IDS.A_INVOICE_1}`]: {
        PK: `TENANT#${TENANT_A.tenantId}`,
        SK: `INVOICE#${IDS.A_INVOICE_1}`,
        id: IDS.A_INVOICE_1,
        tenantId: TENANT_A.tenantId,
        invoiceNumber: 'INV-A-0001',
        totalPaise: 24998,
        customerId: IDS.A_CUSTOMER_1,
        status: 'paid',
        createdAt: now,
    },
    [`TENANT#${TENANT_A.tenantId}#INVOICE#${IDS.A_INVOICE_2}`]: {
        PK: `TENANT#${TENANT_A.tenantId}`,
        SK: `INVOICE#${IDS.A_INVOICE_2}`,
        id: IDS.A_INVOICE_2,
        tenantId: TENANT_A.tenantId,
        invoiceNumber: 'INV-A-0002',
        totalPaise: 14999,
        customerId: IDS.A_CUSTOMER_2,
        status: 'pending',
        createdAt: now,
    },

    // ── Tenant A Customers ─────────────────────────────────────────────────
    [`TENANT#${TENANT_A.tenantId}#CUSTOMER#${IDS.A_CUSTOMER_1}`]: {
        PK: `TENANT#${TENANT_A.tenantId}`,
        SK: `CUSTOMER#${IDS.A_CUSTOMER_1}`,
        id: IDS.A_CUSTOMER_1,
        tenantId: TENANT_A.tenantId,
        name: 'Customer Alpha-1',
        phone: '9876543210',
        createdAt: now,
    },
    [`TENANT#${TENANT_A.tenantId}#CUSTOMER#${IDS.A_CUSTOMER_2}`]: {
        PK: `TENANT#${TENANT_A.tenantId}`,
        SK: `CUSTOMER#${IDS.A_CUSTOMER_2}`,
        id: IDS.A_CUSTOMER_2,
        tenantId: TENANT_A.tenantId,
        name: 'Customer Alpha-2',
        phone: '9876543211',
        createdAt: now,
    },

    // ── Tenant A Business ──────────────────────────────────────────────────
    [`TENANT#${TENANT_A.tenantId}#BUSINESS#${IDS.A_BUSINESS_1}`]: {
        PK: `TENANT#${TENANT_A.tenantId}`,
        SK: `BUSINESS#${IDS.A_BUSINESS_1}`,
        id: IDS.A_BUSINESS_1,
        tenantId: TENANT_A.tenantId,
        name: TENANT_A.name,
        type: 'electronics',
        createdAt: now,
    },

    // ── Tenant B Products ──────────────────────────────────────────────────
    [`TENANT#${TENANT_B.tenantId}#PRODUCT#${IDS.B_PRODUCT_1}`]: {
        PK: `TENANT#${TENANT_B.tenantId}`,
        SK: `PRODUCT#${IDS.B_PRODUCT_1}`,
        id: IDS.B_PRODUCT_1,
        tenantId: TENANT_B.tenantId,
        name: 'Bravo Medicine X',
        price: 5999,
        sku: 'BM-001',
        category: 'pharmacy',
        createdAt: now,
        updatedAt: now,
    },
    [`TENANT#${TENANT_B.tenantId}#PRODUCT#${IDS.B_PRODUCT_2}`]: {
        PK: `TENANT#${TENANT_B.tenantId}`,
        SK: `PRODUCT#${IDS.B_PRODUCT_2}`,
        id: IDS.B_PRODUCT_2,
        tenantId: TENANT_B.tenantId,
        name: 'Bravo Medicine Y',
        price: 12999,
        sku: 'BM-002',
        category: 'pharmacy',
        createdAt: now,
        updatedAt: now,
    },

    // ── Tenant B Invoices ──────────────────────────────────────────────────
    [`TENANT#${TENANT_B.tenantId}#INVOICE#${IDS.B_INVOICE_1}`]: {
        PK: `TENANT#${TENANT_B.tenantId}`,
        SK: `INVOICE#${IDS.B_INVOICE_1}`,
        id: IDS.B_INVOICE_1,
        tenantId: TENANT_B.tenantId,
        invoiceNumber: 'INV-B-0001',
        totalPaise: 5999,
        customerId: IDS.B_CUSTOMER_1,
        status: 'paid',
        createdAt: now,
    },

    // ── Tenant B Customers ─────────────────────────────────────────────────
    [`TENANT#${TENANT_B.tenantId}#CUSTOMER#${IDS.B_CUSTOMER_1}`]: {
        PK: `TENANT#${TENANT_B.tenantId}`,
        SK: `CUSTOMER#${IDS.B_CUSTOMER_1}`,
        id: IDS.B_CUSTOMER_1,
        tenantId: TENANT_B.tenantId,
        name: 'Customer Bravo-1',
        phone: '9123456789',
        createdAt: now,
    },

    // ── Tenant B Business ──────────────────────────────────────────────────
    [`TENANT#${TENANT_B.tenantId}#BUSINESS#${IDS.B_BUSINESS_1}`]: {
        PK: `TENANT#${TENANT_B.tenantId}`,
        SK: `BUSINESS#${IDS.B_BUSINESS_1}`,
        id: IDS.B_BUSINESS_1,
        tenantId: TENANT_B.tenantId,
        name: TENANT_B.name,
        type: 'pharmacy',
        createdAt: now,
    },
};

// ── Query Helpers ────────────────────────────────────────────────────────────

/**
 * Simulate a DynamoDB query by PK + SK prefix — returns items matching
 * the given tenant's partition key and optional SK prefix.
 */
export function queryByPKPrefix(pk: string, skPrefix?: string): Record<string, unknown>[] {
    return Object.values(SEED_ITEMS).filter((item) => {
        if (item.PK !== pk) return false;
        if (skPrefix && typeof item.SK === 'string') {
            return item.SK.startsWith(skPrefix);
        }
        return true;
    });
}

/**
 * Simulate a DynamoDB GetItem by PK + SK.
 */
export function getByPKSK(pk: string, sk: string): Record<string, unknown> | null {
    const key = `${pk}#${sk}`;
    return SEED_ITEMS[key] || null;
}

/**
 * Get all items for a specific tenant.
 */
export function getTenantItems(tenantId: string): Record<string, unknown>[] {
    return queryByPKPrefix(`TENANT#${tenantId}`);
}

/**
 * Get all items of a specific type for a tenant.
 */
export function getTenantItemsByType(tenantId: string, entityType: string): Record<string, unknown>[] {
    return queryByPKPrefix(`TENANT#${tenantId}`, `${entityType}#`);
}

// ── Assertions ───────────────────────────────────────────────────────────────

/**
 * Verify that a result set contains ONLY items from the expected tenant.
 */
export function assertNoLeakage(
    items: Record<string, unknown>[],
    expectedTenantId: string,
): void {
    for (const item of items) {
        if (item.tenantId && item.tenantId !== expectedTenantId) {
            throw new Error(
                `TENANT ISOLATION BREACH: Expected tenantId=${expectedTenantId} ` +
                `but found item with tenantId=${item.tenantId}: ${JSON.stringify(item)}`,
            );
        }
        if (typeof item.PK === 'string' && !item.PK.includes(expectedTenantId)) {
            throw new Error(
                `TENANT ISOLATION BREACH: Item PK=${item.PK} does not belong to ` +
                `tenant ${expectedTenantId}: ${JSON.stringify(item)}`,
            );
        }
    }
}
