// ============================================================================
// DynamoDB Schema Configuration — Payment & Billing Tables
// ============================================================================
// Complete DynamoDB single-table design for Razorpay multi-merchant payment system
// Tables: Bills, BusinessOwners, PaymentEvents
// ============================================================================

import {
    DynamoDBClient,
    CreateTableCommand,
    DeleteTableCommand,
    ListTablesCommand,
    waitUntilTableExists,
    waitUntilTableNotExists,
    BillingMode,
    AttributeValue,
} from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { v4 as uuidv4 } from 'uuid';
import { config } from './environment';

// ============================================================================
// Table Name Constants (Environment-based)
// ============================================================================

const ENV = config.app.stage || 'development';

export const TABLE_NAMES = {
    BILLS: `SaasBilling-Bills-${ENV}`,
    BUSINESS_OWNERS: `SaasBilling-BusinessOwners-${ENV}`,
    PAYMENT_EVENTS: `SaasBilling-PaymentEvents-${ENV}`,
} as const;

// ============================================================================
// TypeScript Interfaces
// ============================================================================

export type PaymentMode = 'CASH' | 'UPI' | 'ONLINE' | 'CARD';
export type PaymentStatus = 'PENDING' | 'PAID' | 'FAILED' | 'EXPIRED' | 'DUPLICATE';
export type BusinessType = 'grocery' | 'restaurant' | 'clinic' | 'petrol_pump' | 'pharmacy' | 
    'hardware' | 'computer_shop' | 'mobile_shop' | 'wholesale' | 'autoparts' | 
    'clothing_store' | 'bookstore' | 'vegetable_broker' | 'electronics';
export type PaymentEventType = 'CREATED' | 'CAPTURED' | 'FAILED' | 'EXPIRED' | 'REFUNDED' | 'DUPLICATE';

export interface BillItem {
    productId: string;
    productName: string;
    quantity: number;
    unitPrice: number;
    discountAmount: number;
    taxAmount: number;
    totalAmount: number;
}

export interface Bill {
    // Primary Keys
    PK: string;           // BILL#<billId>
    SK: string;           // METADATA
    
    // Core Identifiers
    billId: string;
    tenantId: string;
    businessId: string;
    customerId?: string;
    staffId: string;
    
    // Business Info
    invoiceNumber: string;
    businessType: BusinessType;
    
    // Line Items & Amounts
    lineItems: BillItem[];
    subtotal: number;
    taxAmount: number;
    discountAmount: number;
    totalAmount: number;
    
    // Payment Info
    paymentMode: PaymentMode;
    paymentStatus: PaymentStatus;
    
    // Razorpay Integration
    razorpayOrderId?: string;
    razorpayPaymentId?: string;
    razorpayQrId?: string;
    
    // QR Code
    qrImageUrl?: string;
    qrExpiresAt?: string;  // ISO 8601
    
    // Timestamps
    paidAt?: string;       // ISO 8601
    failureReason?: string;
    failureCode?: string;
    
    // Metadata
    createdAt: string;     // ISO 8601
    updatedAt: string;     // ISO 8601
    createdBy: string;     // Cognito sub
    
    // GSI Keys (for querying)
    GSI1PK: string;      // BUSINESS#<businessId>
    GSI1SK: string;      // DATE#<createdAt>
    GSI2PK?: string;     // ORDER#<razorpayOrderId> (if payment pending/completed)
    GSI3PK: string;      // STATUS#<paymentStatus>
}

export interface BusinessOwner {
    // Primary Keys
    PK: string;           // BUSINESS#<businessId>
    SK: string;           // OWNER#METADATA
    
    // Core Identifiers
    businessId: string;
    tenantId: string;
    ownerId: string;      // Cognito sub
    
    // Business Details
    businessName: string;
    businessType: BusinessType;
    email: string;
    phone: string;
    
    // Razorpay Integration
    razorpayLinkedAccountId?: string;
    razorpayAccountStatus: 'pending' | 'active' | 'suspended' | 'failed';
    
    // Bank Verification
    bankVerified: boolean;
    onboardingComplete: boolean;
    
    // Bank Details (encrypted at rest)
    bankAccountNumberHash?: string;  // SHA256 hash for lookup, not actual number
    ifscCode?: string;
    
    // Metadata
    createdAt: string;
    updatedAt: string;
    
    // GSI Keys
    GSI1PK: string;      // OWNER#<ownerId>
    GSI1SK: string;      // DATE#<createdAt>
}

export interface PaymentEvent {
    // Primary Keys
    PK: string;           // EVENT#<eventId>
    SK: string;           // BILL#<billId>
    
    // Core Identifiers
    eventId: string;
    billId: string;
    
    // Event Details
    eventType: PaymentEventType;
    razorpayEventId?: string;  // Razorpay's event ID for idempotency
    
    // Raw Payload (for debugging)
    rawPayload: Record<string, unknown>;
    
    // Processing
    processedAt: string;   // ISO 8601
    processedBy?: string;  // Lambda function name/ID
    
    // TTL for auto-deletion (90 days)
    TTL: number;          // Unix timestamp
    
    // GSI Keys
    GSI1PK: string;      // BILL#<billId>
    GSI1SK: string;      // TIME#<processedAt>
}

// ============================================================================
// Key Builders (Type-safe construction)
// ============================================================================

export const PaymentKeys = {
    // Bill keys
    billPK: (billId: string) => `BILL#${billId}`,
    billSK: () => 'METADATA',
    
    // Business keys
    businessPK: (businessId: string) => `BUSINESS#${businessId}`,
    businessSK: () => 'OWNER#METADATA',
    
    // Event keys
    eventPK: (eventId: string) => `EVENT#${eventId}`,
    eventSK: (billId: string) => `BILL#${billId}`,
    
    // GSI Keys
    gsi1Business: (businessId: string) => `BUSINESS#${businessId}`,
    gsi1Date: (createdAt: string) => `DATE#${createdAt}`,
    gsi2Order: (orderId: string) => `ORDER#${orderId}`,
    gsi3Status: (status: PaymentStatus) => `STATUS#${status}`,
    gsi1Owner: (ownerId: string) => `OWNER#${ownerId}`,
    gsi1EventBill: (billId: string) => `BILL#${billId}`,
    gsi1EventTime: (processedAt: string) => `TIME#${processedAt}`,
};

// ============================================================================
// DynamoDB Client Configuration
// ============================================================================

const dynamoClient = new DynamoDBClient({
    region: config.aws.region,
    ...(config.dynamodb.local && {
        endpoint: 'http://localhost:8000',
        credentials: {
            accessKeyId: 'local',
            secretAccessKey: 'local',
        },
    }),
});

export const docClient = DynamoDBDocumentClient.from(dynamoClient, {
    marshallOptions: {
        convertEmptyValues: false,
        removeUndefinedValues: true,
        convertClassInstanceToMap: true,
    },
    unmarshallOptions: {
        wrapNumbers: false,
    },
});

// ============================================================================
// Table Creation Functions
// ============================================================================

export async function createBillsTable(): Promise<void> {
    const command = new CreateTableCommand({
        TableName: TABLE_NAMES.BILLS,
        BillingMode: BillingMode.PAY_PER_REQUEST,
        AttributeDefinitions: [
            { AttributeName: 'PK', AttributeType: 'S' },
            { AttributeName: 'SK', AttributeType: 'S' },
            { AttributeName: 'GSI1PK', AttributeType: 'S' },
            { AttributeName: 'GSI1SK', AttributeType: 'S' },
            { AttributeName: 'GSI2PK', AttributeType: 'S' },
            { AttributeName: 'GSI3PK', AttributeType: 'S' },
        ],
        KeySchema: [
            { AttributeName: 'PK', KeyType: 'HASH' },
            { AttributeName: 'SK', KeyType: 'RANGE' },
        ],
        GlobalSecondaryIndexes: [
            {
                IndexName: 'businessId-createdAt-index',
                KeySchema: [
                    { AttributeName: 'GSI1PK', KeyType: 'HASH' },
                    { AttributeName: 'GSI1SK', KeyType: 'RANGE' },
                ],
                Projection: { ProjectionType: 'ALL' },
            },
            {
                IndexName: 'razorpayOrderId-index',
                KeySchema: [
                    { AttributeName: 'GSI2PK', KeyType: 'HASH' },
                ],
                Projection: { ProjectionType: 'ALL' },
            },
            {
                IndexName: 'paymentStatus-createdAt-index',
                KeySchema: [
                    { AttributeName: 'GSI3PK', KeyType: 'HASH' },
                    { AttributeName: 'GSI1SK', KeyType: 'RANGE' },
                ],
                Projection: { ProjectionType: 'ALL' },
            },
        ],
        StreamSpecification: {
            StreamEnabled: true,
            StreamViewType: 'NEW_AND_OLD_IMAGES',
        },
        Tags: [
            { Key: 'Environment', Value: ENV },
            { Key: 'Service', Value: 'SaasBilling' },
            { Key: 'TableType', Value: 'Bills' },
        ],
    });

    await dynamoClient.send(command);
    await waitUntilTableExists({ client: dynamoClient, maxWaitTime: 60 }, { TableName: TABLE_NAMES.BILLS });
    console.log(`? Table ${TABLE_NAMES.BILLS} created successfully`);
}

export async function createBusinessOwnersTable(): Promise<void> {
    const command = new CreateTableCommand({
        TableName: TABLE_NAMES.BUSINESS_OWNERS,
        BillingMode: BillingMode.PAY_PER_REQUEST,
        AttributeDefinitions: [
            { AttributeName: 'PK', AttributeType: 'S' },
            { AttributeName: 'SK', AttributeType: 'S' },
            { AttributeName: 'GSI1PK', AttributeType: 'S' },
            { AttributeName: 'GSI1SK', AttributeType: 'S' },
        ],
        KeySchema: [
            { AttributeName: 'PK', KeyType: 'HASH' },
            { AttributeName: 'SK', KeyType: 'RANGE' },
        ],
        GlobalSecondaryIndexes: [
            {
                IndexName: 'ownerId-index',
                KeySchema: [
                    { AttributeName: 'GSI1PK', KeyType: 'HASH' },
                    { AttributeName: 'GSI1SK', KeyType: 'RANGE' },
                ],
                Projection: { ProjectionType: 'ALL' },
            },
        ],
        Tags: [
            { Key: 'Environment', Value: ENV },
            { Key: 'Service', Value: 'SaasBilling' },
            { Key: 'TableType', Value: 'BusinessOwners' },
        ],
    });

    await dynamoClient.send(command);
    await waitUntilTableExists({ client: dynamoClient, maxWaitTime: 60 }, { TableName: TABLE_NAMES.BUSINESS_OWNERS });
    console.log(`? Table ${TABLE_NAMES.BUSINESS_OWNERS} created successfully`);
}

export async function createPaymentEventsTable(): Promise<void> {
    const command = new CreateTableCommand({
        TableName: TABLE_NAMES.PAYMENT_EVENTS,
        BillingMode: BillingMode.PAY_PER_REQUEST,
        AttributeDefinitions: [
            { AttributeName: 'PK', AttributeType: 'S' },
            { AttributeName: 'SK', AttributeType: 'S' },
            { AttributeName: 'GSI1PK', AttributeType: 'S' },
            { AttributeName: 'GSI1SK', AttributeType: 'S' },
        ],
        KeySchema: [
            { AttributeName: 'PK', KeyType: 'HASH' },
            { AttributeName: 'SK', KeyType: 'RANGE' },
        ],
        GlobalSecondaryIndexes: [
            {
                IndexName: 'billId-index',
                KeySchema: [
                    { AttributeName: 'GSI1PK', KeyType: 'HASH' },
                    { AttributeName: 'GSI1SK', KeyType: 'RANGE' },
                ],
                Projection: { ProjectionType: 'ALL' },
            },
        ],
        Tags: [
            { Key: 'Environment', Value: ENV },
            { Key: 'Service', Value: 'SaasBilling' },
            { Key: 'TableType', Value: 'PaymentEvents' },
        ],
    });

    await dynamoClient.send(command);
    await waitUntilTableExists({ client: dynamoClient, maxWaitTime: 60 }, { TableName: TABLE_NAMES.PAYMENT_EVENTS });
    console.log(`? Table ${TABLE_NAMES.PAYMENT_EVENTS} created successfully`);
}

// ============================================================================
// Master Setup Function
// ============================================================================

export async function setupAllTables(): Promise<void> {
    console.log(`?? Setting up DynamoDB tables for environment: ${ENV}`);
    
    try {
        await createBillsTable();
        await createBusinessOwnersTable();
        await createPaymentEventsTable();
        console.log('? All tables created successfully');
    } catch (error) {
        console.error('? Error creating tables:', error);
        throw error;
    }
}

// ============================================================================
// Table Cleanup (for testing/reset)
// ============================================================================

export async function deleteAllTables(): Promise<void> {
    const tables = [TABLE_NAMES.BILLS, TABLE_NAMES.BUSINESS_OWNERS, TABLE_NAMES.PAYMENT_EVENTS];
    
    for (const tableName of tables) {
        try {
            const listCommand = new ListTablesCommand({});
            const { TableNames } = await dynamoClient.send(listCommand);
            
            if (TableNames?.includes(tableName)) {
                await dynamoClient.send(new DeleteTableCommand({ TableName: tableName }));
                await waitUntilTableNotExists({ client: dynamoClient, maxWaitTime: 60 }, { TableName: tableName });
                console.log(`???  Table ${tableName} deleted`);
            }
        } catch (error) {
            console.log(`??  Could not delete ${tableName}:`, (error as Error).message);
        }
    }
}

// ============================================================================
// Seed Data for Local Testing
// ============================================================================

export async function seedTestData(): Promise<void> {
    const now = new Date().toISOString();
    const tenantId = 'tenant-test-001';
    const businessId = 'biz-test-001';
    const ownerId = 'owner-test-001';
    const staffId = 'staff-test-001';
    
    // Seed Business Owner
    const businessOwner: BusinessOwner = {
        PK: PaymentKeys.businessPK(businessId),
        SK: PaymentKeys.businessSK(),
        businessId,
        tenantId,
        ownerId,
        businessName: 'Test Grocery Store',
        businessType: 'grocery',
        email: 'owner@teststore.com',
        phone: '9876543210',
        razorpayAccountStatus: 'active',
        bankVerified: true,
        onboardingComplete: true,
        createdAt: now,
        updatedAt: now,
        GSI1PK: PaymentKeys.gsi1Owner(ownerId),
        GSI1SK: PaymentKeys.gsi1Date(now),
    };
    
    await docClient.send(new PutCommand({
        TableName: TABLE_NAMES.BUSINESS_OWNERS,
        Item: businessOwner,
    }));
    
    // Seed a test bill (unpaid)
    const billId = uuidv4();
    const bill: Bill = {
        PK: PaymentKeys.billPK(billId),
        SK: PaymentKeys.billSK(),
        billId,
        tenantId,
        businessId,
        staffId,
        invoiceNumber: 'INV-001',
        businessType: 'grocery',
        lineItems: [
            {
                productId: 'prod-001',
                productName: 'Test Product',
                quantity: 2,
                unitPrice: 100,
                discountAmount: 0,
                taxAmount: 5,
                totalAmount: 205,
            },
        ],
        subtotal: 200,
        taxAmount: 10,
        discountAmount: 0,
        totalAmount: 210,
        paymentMode: 'CASH',
        paymentStatus: 'PENDING',
        createdAt: now,
        updatedAt: now,
        createdBy: staffId,
        GSI1PK: PaymentKeys.gsi1Business(businessId),
        GSI1SK: PaymentKeys.gsi1Date(now),
        GSI3PK: PaymentKeys.gsi3Status('PENDING'),
    };
    
    await docClient.send(new PutCommand({
        TableName: TABLE_NAMES.BILLS,
        Item: bill,
    }));
    
    // Seed a paid bill
    const paidBillId = uuidv4();
    const paidBill: Bill = {
        PK: PaymentKeys.billPK(paidBillId),
        SK: PaymentKeys.billSK(),
        billId: paidBillId,
        tenantId,
        businessId,
        staffId,
        invoiceNumber: 'INV-002',
        businessType: 'grocery',
        lineItems: [
            {
                productId: 'prod-002',
                productName: 'Paid Product',
                quantity: 1,
                unitPrice: 500,
                discountAmount: 50,
                taxAmount: 25,
                totalAmount: 475,
            },
        ],
        subtotal: 500,
        taxAmount: 25,
        discountAmount: 50,
        totalAmount: 475,
        paymentMode: 'CASH',
        paymentStatus: 'PAID',
        paidAt: now,
        createdAt: now,
        updatedAt: now,
        createdBy: staffId,
        GSI1PK: PaymentKeys.gsi1Business(businessId),
        GSI1SK: PaymentKeys.gsi1Date(now),
        GSI3PK: PaymentKeys.gsi3Status('PAID'),
    };
    
    await docClient.send(new PutCommand({
        TableName: TABLE_NAMES.BILLS,
        Item: paidBill,
    }));
    
    console.log('? Test data seeded successfully');
    console.log(`   Business: ${businessId}`);
    console.log(`   Pending Bill: ${billId}`);
    console.log(`   Paid Bill: ${paidBillId}`);
}

// ============================================================================
// Utility Functions
// ============================================================================

export async function getBillById(billId: string): Promise<Bill | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAMES.BILLS,
        Key: {
            PK: PaymentKeys.billPK(billId),
            SK: PaymentKeys.billSK(),
        },
    }));
    return result.Item as Bill | null;
}

export async function getBillByOrderId(orderId: string): Promise<Bill | null> {
    const result = await docClient.send(new QueryCommand({
        TableName: TABLE_NAMES.BILLS,
        IndexName: 'razorpayOrderId-index',
        KeyConditionExpression: 'GSI2PK = :orderId',
        ExpressionAttributeValues: {
            ':orderId': PaymentKeys.gsi2Order(orderId),
        },
        Limit: 1,
    }));
    return result.Items?.[0] as Bill | null;
}

export async function getBusinessOwner(businessId: string): Promise<BusinessOwner | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAMES.BUSINESS_OWNERS,
        Key: {
            PK: PaymentKeys.businessPK(businessId),
            SK: PaymentKeys.businessSK(),
        },
    }));
    return result.Item as BusinessOwner | null;
}

export async function getPaymentEventsForBill(billId: string): Promise<PaymentEvent[]> {
    const result = await docClient.send(new QueryCommand({
        TableName: TABLE_NAMES.PAYMENT_EVENTS,
        IndexName: 'billId-index',
        KeyConditionExpression: 'GSI1PK = :billId',
        ExpressionAttributeValues: {
            ':billId': PaymentKeys.gsi1EventBill(billId),
        },
        ScanIndexForward: false, // Most recent first
    }));
    return (result.Items || []) as PaymentEvent[];
}

// ============================================================================
// Local Testing Script
// ============================================================================

if (require.main === module) {
    (async () => {
        const args = process.argv.slice(2);
        const command = args[0];
        
        switch (command) {
            case 'setup':
                await setupAllTables();
                break;
            case 'reset':
                await deleteAllTables();
                await setupAllTables();
                await seedTestData();
                break;
            case 'seed':
                await seedTestData();
                break;
            case 'delete':
                await deleteAllTables();
                break;
            default:
                console.log(`
Usage: ts-node payment-tables.config.ts [command]

Commands:
  setup  - Create all tables
  reset  - Delete, recreate, and seed tables
  seed   - Add test data
  delete - Remove all tables
                `);
        }
        
        process.exit(0);
    })();
}
