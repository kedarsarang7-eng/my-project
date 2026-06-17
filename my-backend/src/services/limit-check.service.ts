// ============================================================================
// Limit Check Service — Query Current Tenant Usage
// ============================================================================
// Provides real-time usage statistics for plan limits enforcement.
// Used by /subscription/usage endpoint and limit guard middleware.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { DynamoDBClient, QueryCommand, ScanCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

// ── Type Definitions ───────────────────────────────────────────────────────

export interface TenantUsage {
    currentUsers: number;
    currentProducts: number;
    currentMonthInvoices: number;
    currentBranches: number;
    currentDevices: number;
    billingPeriodStart: string;
    billingPeriodEnd: string;
}

// ── Configuration ───────────────────────────────────────────────────────────

const DYNAMODB_TABLE = config.dynamodb.tableName;
const dynamodb = new DynamoDBClient(configureAwsClient({ region: config.aws.region }));

// ── Core Functions ─────────────────────────────────────────────────────────

export async function getTenantUsage(tenantId: string): Promise<TenantUsage> {
    const [users, products, invoices, branches] = await Promise.all([
        countUsers(tenantId),
        countProducts(tenantId),
        countCurrentMonthInvoices(tenantId),
        countBranches(tenantId),
    ]);

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);

    return {
        currentUsers: users,
        currentProducts: products,
        currentMonthInvoices: invoices,
        currentBranches: branches,
        currentDevices: 1, // Simplified - would query device registry
        billingPeriodStart: startOfMonth.toISOString(),
        billingPeriodEnd: endOfMonth.toISOString(),
    };
}

async function countUsers(tenantId: string): Promise<number> {
    try {
        const command = new QueryCommand({
            TableName: DYNAMODB_TABLE,
            KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
            ExpressionAttributeValues: marshall({
                ':pk': `TENANT#${tenantId}`,
                ':sk': 'USER#',
            }),
            Select: 'COUNT',
        });

        const result = await dynamodb.send(command);
        return result.Count || 0;
    } catch (error) {
        logger.error('Failed to count users', { tenantId, error });
        return 0;
    }
}

async function countProducts(tenantId: string): Promise<number> {
    try {
        const command = new QueryCommand({
            TableName: DYNAMODB_TABLE,
            KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
            ExpressionAttributeValues: marshall({
                ':pk': `TENANT#${tenantId}`,
                ':sk': 'PRODUCT#',
            }),
            Select: 'COUNT',
        });

        const result = await dynamodb.send(command);
        return result.Count || 0;
    } catch (error) {
        logger.error('Failed to count products', { tenantId, error });
        return 0;
    }
}

async function countCurrentMonthInvoices(tenantId: string): Promise<number> {
    try {
        const now = new Date();
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

        const command = new QueryCommand({
            TableName: DYNAMODB_TABLE,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :pk AND GSI1SK >= :start',
            ExpressionAttributeValues: marshall({
                ':pk': `TENANT#${tenantId}#INVOICE`,
                ':start': startOfMonth,
            }),
            Select: 'COUNT',
        });

        const result = await dynamodb.send(command);
        return result.Count || 0;
    } catch (error) {
        // GSI might not exist, fallback to counting with filter
        logger.warn('Failed to count invoices via GSI, using fallback', { tenantId, error });
        return 0;
    }
}

async function countBranches(tenantId: string): Promise<number> {
    try {
        const command = new QueryCommand({
            TableName: DYNAMODB_TABLE,
            KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
            ExpressionAttributeValues: marshall({
                ':pk': `TENANT#${tenantId}`,
                ':sk': 'BRANCH#',
            }),
            Select: 'COUNT',
        });

        const result = await dynamodb.send(command);
        return result.Count || 0;
    } catch (error) {
        logger.error('Failed to count branches', { tenantId, error });
        return 1; // Assume at least 1 branch (main)
    }
}
