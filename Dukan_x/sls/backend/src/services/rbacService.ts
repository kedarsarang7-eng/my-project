
// ============================================
// RBAC Service — Role-Based Access Control
// ============================================
// Handles fetching effective permissions for a user, including
// merging Role permissions with User override permissions.
// Enforces the "Lease" logic for offline security.

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
    DynamoDBDocumentClient,
    GetCommand,
    QueryCommand,
} from '@aws-sdk/lib-dynamodb';
import { logger } from '../utils/logger';

// ---- DynamoDB Client Setup ----

const ddbClient = new DynamoDBClient({
    region: process.env.AWS_REGION || 'ap-south-1',
});

const docClient = DynamoDBDocumentClient.from(ddbClient, {
    marshallOptions: {
        removeUndefinedValues: true,
        convertEmptyValues: false,
    },
});

const TABLE_NAME = process.env.DYNAMODB_RBAC_TABLE || 'sls-licensing-backend-rbac-dev';
const LEASE_DURATION_SECONDS = 7 * 24 * 60 * 60; // 7 days

// ---- Types ----

export interface RbacUser {
    PK: string; // TENANT#<id>
    SK: string; // USER#<id>
    RoleId: string;
    CustomPermissions?: string[]; // Overrides: ["+bill.delete", "-bill.view"]
    IsActive: boolean;
    LastLeaseRenewal?: string;
}

export interface RbacRole {
    PK: string; // TENANT#<id>
    SK: string; // ROLE#<id>
    RoleName: string;
    Permissions: string[];
}

export interface SyncResponse {
    permissions: string[];
    lease_duration_seconds: number;
    lease_expiry: string;
}

// ============================================
// SYNC: Calculate effective permissions
// ============================================
export async function syncPermissions(
    tenantId: string,
    userId: string
): Promise<SyncResponse> {

    // 1. Fetch User
    const userResult = await docClient.send(new GetCommand({
        TableName: TABLE_NAME,
        Key: {
            PK: `TENANT#${tenantId}`,
            SK: `USER#${userId}`,
        },
    }));

    const user = userResult.Item as RbacUser | undefined;

    // Guard: User not found
    if (!user) {
        logger.warn('RBAC: User not found', { tenantId, userId });
        throw new Error('User not found or access denied');
    }

    // Guard: User inactive (Instant Lockout)
    if (user.IsActive === false) {
        logger.warn('RBAC: User is inactive', { tenantId, userId });
        return {
            permissions: [], // Return empty permissions to effectively lock
            lease_duration_seconds: 0,
            lease_expiry: new Date().toISOString(), // Expired immediately
        };
    }

    // 2. Fetch Role
    const roleResult = await docClient.send(new GetCommand({
        TableName: TABLE_NAME,
        Key: {
            PK: `TENANT#${tenantId}`,
            SK: `ROLE#${user.RoleId}`,
        },
    }));

    const role = roleResult.Item as RbacRole | undefined;

    // Guard: Role not found (Configuration Error)
    if (!role) {
        logger.error('RBAC: Role not found for user', { tenantId, userId, roleId: user.RoleId });
        // Fallback to safe default
        return {
            permissions: [],
            lease_duration_seconds: 0,
            lease_expiry: new Date().toISOString(),
        };
    }

    // 3. Merge Permissions
    const effectivePermissions = new Set<string>(role.Permissions || []);

    if (user.CustomPermissions && Array.isArray(user.CustomPermissions)) {
        for (const perm of user.CustomPermissions) {
            if (perm.startsWith('-')) {
                // Deny/Revoke: "-bill.delete"
                effectivePermissions.delete(perm.substring(1));
            } else if (perm.startsWith('+')) {
                // Grant: "+bill.export"
                effectivePermissions.add(perm.substring(1));
            } else {
                // Default to Grant if no prefix
                effectivePermissions.add(perm);
            }
        }
    }

    // 4. Calculate Lease
    const now = new Date();
    const expiry = new Date(now.getTime() + LEASE_DURATION_SECONDS * 1000);

    logger.info('RBAC: Permissions synced', {
        tenantId,
        userId,
        role: role.RoleName,
        permissionCount: effectivePermissions.size
    });

    return {
        permissions: Array.from(effectivePermissions),
        lease_duration_seconds: LEASE_DURATION_SECONDS,
        lease_expiry: expiry.toISOString(),
    };
}
