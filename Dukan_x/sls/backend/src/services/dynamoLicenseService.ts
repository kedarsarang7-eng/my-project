// ============================================
// DynamoDB License Service — Serverless Data Layer
// ============================================
// This service provides DynamoDB operations for the LicenseKeys table.
// It runs alongside the existing PostgreSQL-based licenseService.
// Use this for the dedicated Lambda endpoints (generate-key, validate, stats, revoke).

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
    DynamoDBDocumentClient,
    PutCommand,
    GetCommand,
    UpdateCommand,
    QueryCommand,
    ScanCommand,
} from '@aws-sdk/lib-dynamodb';
import crypto from 'crypto';
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

const TABLE_NAME = process.env.DYNAMODB_LICENSE_TABLE || 'sls-licensing-backend-license-keys-dev';

// ---- Types ----

export type DynamoLicenseStatus = 'NEW' | 'ACTIVE' | 'INACTIVE' | 'BANNED';

// All supported business types (must match Flutter BusinessType enum)
export const VALID_BUSINESS_TYPES = [
    'grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics',
    'mobileShop', 'computerShop', 'hardware', 'service', 'wholesale',
    'petrolPump', 'vegetablesBroker', 'clinic', 'other',
] as const;
export type BusinessType = typeof VALID_BUSINESS_TYPES[number];

export interface DynamoLicenseKey {
    license_key: string;
    status: DynamoLicenseStatus;
    business_type: BusinessType;
    hwid: string | null;
    allowed_hwids: string[];           // Admin-approved additional HWIDs for multi-PC sharing
    client_name: string | null;
    client_email: string | null;
    tier: string;
    license_type: string;
    max_devices: number;
    feature_flags: Record<string, boolean | number | string>;
    created_at: string;
    activation_date: string | null;
    expires_at: string | null;
    last_validated_at: string | null;
    issued_by: string | null;
    notes: string | null;
    revoked_at: string | null;
    revoked_reason: string | null;
}

// ---- Key Generation Constants ----

const KEY_CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I/O/0/1
const KEY_SEGMENTS = 5;
const KEY_SEGMENT_LENGTH = 5;

// ============================================
// Generate a cryptographically secure license key
// ============================================
function generateKeyString(): string {
    const parts: string[] = [];
    for (let i = 0; i < KEY_SEGMENTS; i++) {
        const bytes = crypto.randomBytes(KEY_SEGMENT_LENGTH);
        let segment = '';
        for (let j = 0; j < KEY_SEGMENT_LENGTH; j++) {
            segment += KEY_CHARSET[bytes[j] % KEY_CHARSET.length];
        }
        parts.push(segment);
    }
    return parts.join('-');
}

// ============================================
// CREATE: Generate and store a new license key
// ============================================
export async function generateLicenseKey(params: {
    business_type: BusinessType;
    client_name?: string;
    client_email?: string;
    tier?: string;
    license_type?: string;
    max_devices?: number;
    feature_flags?: Record<string, boolean | number | string>;
    expires_at?: string;
    notes?: string;
    issued_by?: string;
}): Promise<DynamoLicenseKey> {
    const licenseKey = generateKeyString();
    const now = new Date().toISOString();

    const item: DynamoLicenseKey = {
        license_key: licenseKey,
        status: 'NEW',
        business_type: params.business_type,
        hwid: null,
        allowed_hwids: [],
        client_name: params.client_name || null,
        client_email: params.client_email || null,
        tier: params.tier || 'basic',
        license_type: params.license_type || 'standard',
        max_devices: params.max_devices || 1,
        feature_flags: params.feature_flags || {},
        created_at: now,
        activation_date: null,
        expires_at: params.expires_at || null,
        last_validated_at: null,
        issued_by: params.issued_by || null,
        notes: params.notes || null,
        revoked_at: null,
        revoked_reason: null,
    };

    await docClient.send(new PutCommand({
        TableName: TABLE_NAME,
        Item: item,
        // Ensure key uniqueness (extremely unlikely collision, but defense-in-depth)
        ConditionExpression: 'attribute_not_exists(license_key)',
    }));

    logger.info('DynamoDB: License key generated', {
        license_key: licenseKey,
        tier: item.tier,
        type: item.license_type,
    });

    return item;
}

// ============================================
// READ: Get a license key by its value
// ============================================
export async function getLicenseKey(licenseKey: string): Promise<DynamoLicenseKey | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAME,
        Key: { license_key: licenseKey },
    }));

    return (result.Item as DynamoLicenseKey) || null;
}

// ============================================
// VALIDATE: Validate license key + bind HWID
// ============================================
// Multi-HWID logic:
//   1. Primary HWID (hwid field): Bound on first activation.
//   2. Allowed HWIDs (allowed_hwids array): Admin-approved additional devices.
//   If machineHwid matches primary OR is in allowed_hwids → valid.
//   If mismatch → reject. Admin must add HWID to allowed_hwids for multi-PC sharing.
export async function validateAndBindHwid(
    licenseKey: string,
    machineHwid: string
): Promise<{ success: boolean; message: string; license?: DynamoLicenseKey }> {
    const license = await getLicenseKey(licenseKey);

    if (!license) {
        return { success: false, message: 'Invalid license key' };
    }

    // ---- Status: BANNED ----
    if (license.status === 'BANNED') {
        return { success: false, message: 'This license key has been banned' };
    }

    // ---- Status: INACTIVE (revoked) ----
    if (license.status === 'INACTIVE') {
        return { success: false, message: 'This license key has been deactivated' };
    }

    // ---- Check expiry ----
    if (license.expires_at && new Date(license.expires_at) < new Date()) {
        await updateLicenseStatus(licenseKey, 'INACTIVE');
        return { success: false, message: 'This license key has expired' };
    }

    // ---- Status: NEW → First activation (bind primary HWID) ----
    if (license.status === 'NEW') {
        const now = new Date().toISOString();

        const result = await docClient.send(new UpdateCommand({
            TableName: TABLE_NAME,
            Key: { license_key: licenseKey },
            UpdateExpression: 'SET #status = :active, hwid = :hwid, activation_date = :now, last_validated_at = :now',
            ExpressionAttributeNames: { '#status': 'status' },
            ExpressionAttributeValues: {
                ':active': 'ACTIVE',
                ':hwid': machineHwid,
                ':now': now,
            },
            ConditionExpression: '#status = :new',
            ReturnValues: 'ALL_NEW',
        }));

        const updated = result.Attributes as DynamoLicenseKey;

        logger.info('DynamoDB: License activated (first device)', {
            license_key: licenseKey,
            hwid: machineHwid.substring(0, 12) + '...',
        });

        return {
            success: true,
            message: 'License activated successfully',
            license: updated,
        };
    }

    // ---- Status: ACTIVE → Validate HWID ----
    if (license.status === 'ACTIVE') {
        const allowedHwids = license.allowed_hwids || [];
        const isPrimaryMatch = license.hwid === machineHwid;
        const isAllowedMatch = allowedHwids.includes(machineHwid);

        if (!isPrimaryMatch && !isAllowedMatch) {
            // Count total bound devices: 1 (primary) + allowed_hwids.length
            const totalDevices = 1 + allowedHwids.length;

            logger.warn('DynamoDB: HWID mismatch', {
                license_key: licenseKey,
                expected_hwid: license.hwid?.substring(0, 8) + '...',
                received_hwid: machineHwid.substring(0, 8) + '...',
                total_bound: totalDevices,
                max_devices: license.max_devices,
            });

            return {
                success: false,
                message: 'Invalid Machine — this license is bound to a different device. Contact admin to allow this device.',
            };
        }

        // HWID matches (primary or allowed) — update last_validated_at
        const now = new Date().toISOString();
        await docClient.send(new UpdateCommand({
            TableName: TABLE_NAME,
            Key: { license_key: licenseKey },
            UpdateExpression: 'SET last_validated_at = :now',
            ExpressionAttributeValues: { ':now': now },
        }));

        return {
            success: true,
            message: 'License is valid',
            license: { ...license, last_validated_at: now },
        };
    }

    return { success: false, message: 'Unknown license status' };
}

// ============================================
// HWID MANAGEMENT: Admin-controlled multi-PC sharing
// ============================================

/** Reset the primary HWID so the license can be re-activated on a new machine */
export async function resetPrimaryHwid(licenseKey: string): Promise<DynamoLicenseKey | null> {
    try {
        const result = await docClient.send(new UpdateCommand({
            TableName: TABLE_NAME,
            Key: { license_key: licenseKey },
            UpdateExpression: 'SET hwid = :null, #status = :new REMOVE activation_date',
            ExpressionAttributeNames: { '#status': 'status' },
            ExpressionAttributeValues: { ':null': null, ':new': 'NEW' },
            ConditionExpression: 'attribute_exists(license_key)',
            ReturnValues: 'ALL_NEW',
        }));

        logger.info('DynamoDB: Primary HWID reset', { license_key: licenseKey });
        return result.Attributes as DynamoLicenseKey;
    } catch (error: any) {
        if (error.name === 'ConditionalCheckFailedException') return null;
        throw error;
    }
}

/** Add an HWID to the allowed list (admin grants multi-PC sharing for a client) */
export async function addAllowedHwid(
    licenseKey: string,
    hwid: string,
    deviceName?: string
): Promise<{ success: boolean; message: string; license?: DynamoLicenseKey }> {
    const license = await getLicenseKey(licenseKey);
    if (!license) return { success: false, message: 'License not found' };

    const currentAllowed = license.allowed_hwids || [];
    // Check if HWID is already primary or allowed
    if (license.hwid === hwid || currentAllowed.includes(hwid)) {
        return { success: false, message: 'This HWID is already bound to this license' };
    }

    // Check device limit: primary (1) + allowed_hwids.length < max_devices
    const totalAfterAdd = 1 + currentAllowed.length + 1;
    if (totalAfterAdd > license.max_devices) {
        return {
            success: false,
            message: `Device limit reached. Max ${license.max_devices} devices allowed. Currently ${1 + currentAllowed.length} bound.`,
        };
    }

    const result = await docClient.send(new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { license_key: licenseKey },
        UpdateExpression: 'SET allowed_hwids = list_append(if_not_exists(allowed_hwids, :empty), :newHwid)',
        ExpressionAttributeValues: {
            ':newHwid': [hwid],
            ':empty': [],
        },
        ReturnValues: 'ALL_NEW',
    }));

    logger.info('DynamoDB: Allowed HWID added', {
        license_key: licenseKey,
        hwid: hwid.substring(0, 12) + '...',
        device_name: deviceName,
    });

    return {
        success: true,
        message: 'Device added successfully',
        license: result.Attributes as DynamoLicenseKey,
    };
}

/** Remove an HWID from the allowed list */
export async function removeAllowedHwid(
    licenseKey: string,
    hwid: string
): Promise<{ success: boolean; message: string }> {
    const license = await getLicenseKey(licenseKey);
    if (!license) return { success: false, message: 'License not found' };

    const currentAllowed = license.allowed_hwids || [];
    const index = currentAllowed.indexOf(hwid);
    if (index === -1) {
        return { success: false, message: 'HWID not found in allowed list' };
    }

    // Remove by index
    await docClient.send(new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { license_key: licenseKey },
        UpdateExpression: `REMOVE allowed_hwids[${index}]`,
    }));

    logger.info('DynamoDB: Allowed HWID removed', {
        license_key: licenseKey,
        hwid: hwid.substring(0, 12) + '...',
    });

    return { success: true, message: 'Device removed successfully' };
}

/** Get all devices (primary + allowed) for a license */
export async function getDeviceList(licenseKey: string): Promise<{
    primary_hwid: string | null;
    allowed_hwids: string[];
    total_devices: number;
    max_devices: number;
} | null> {
    const license = await getLicenseKey(licenseKey);
    if (!license) return null;

    const allowedHwids = license.allowed_hwids || [];
    return {
        primary_hwid: license.hwid,
        allowed_hwids: allowedHwids,
        total_devices: (license.hwid ? 1 : 0) + allowedHwids.length,
        max_devices: license.max_devices,
    };
}

// ============================================
// UPDATE: Change license status
// ============================================
export async function updateLicenseStatus(
    licenseKey: string,
    newStatus: DynamoLicenseStatus,
    reason?: string
): Promise<DynamoLicenseKey | null> {
    const now = new Date().toISOString();

    let updateExpr = 'SET #status = :status';
    const exprNames: Record<string, string> = { '#status': 'status' };
    const exprValues: Record<string, any> = { ':status': newStatus };

    if (newStatus === 'BANNED' || newStatus === 'INACTIVE') {
        updateExpr += ', revoked_at = :now';
        exprValues[':now'] = now;
        if (reason) {
            updateExpr += ', revoked_reason = :reason';
            exprValues[':reason'] = reason;
        }
    }

    try {
        const result = await docClient.send(new UpdateCommand({
            TableName: TABLE_NAME,
            Key: { license_key: licenseKey },
            UpdateExpression: updateExpr,
            ExpressionAttributeNames: exprNames,
            ExpressionAttributeValues: exprValues,
            ConditionExpression: 'attribute_exists(license_key)',
            ReturnValues: 'ALL_NEW',
        }));

        logger.info('DynamoDB: License status updated', {
            license_key: licenseKey,
            new_status: newStatus,
        });

        return result.Attributes as DynamoLicenseKey;
    } catch (error: any) {
        if (error.name === 'ConditionalCheckFailedException') {
            return null; // Key doesn't exist
        }
        throw error;
    }
}

// ============================================
// STATS: Get license counts by status
// ============================================
export async function getLicenseStats(): Promise<{
    total: number;
    new: number;
    active: number;
    inactive: number;
    banned: number;
}> {
    // Query each status using the GSI
    const statuses: DynamoLicenseStatus[] = ['NEW', 'ACTIVE', 'INACTIVE', 'BANNED'];
    const counts: Record<string, number> = {};

    await Promise.all(
        statuses.map(async (status) => {
            const result = await docClient.send(new QueryCommand({
                TableName: TABLE_NAME,
                IndexName: 'status-created_at-index',
                KeyConditionExpression: '#status = :status',
                ExpressionAttributeNames: { '#status': 'status' },
                ExpressionAttributeValues: { ':status': status },
                Select: 'COUNT',
            }));
            counts[status] = result.Count || 0;
        })
    );

    const total = Object.values(counts).reduce((sum, c) => sum + c, 0);

    return {
        total,
        new: counts['NEW'] || 0,
        active: counts['ACTIVE'] || 0,
        inactive: counts['INACTIVE'] || 0,
        banned: counts['BANNED'] || 0,
    };
}

// ============================================
// LIST: Get all license keys (paginated scan)
// ============================================
export async function listLicenseKeys(params?: {
    status?: DynamoLicenseStatus;
    limit?: number;
    lastKey?: Record<string, any>;
}): Promise<{
    items: DynamoLicenseKey[];
    lastKey?: Record<string, any>;
}> {
    const limit = params?.limit || 50;

    if (params?.status) {
        // Use GSI for status-filtered queries
        const result = await docClient.send(new QueryCommand({
            TableName: TABLE_NAME,
            IndexName: 'status-created_at-index',
            KeyConditionExpression: '#status = :status',
            ExpressionAttributeNames: { '#status': 'status' },
            ExpressionAttributeValues: { ':status': params.status },
            ScanIndexForward: false, // newest first
            Limit: limit,
            ExclusiveStartKey: params.lastKey,
        }));

        return {
            items: (result.Items || []) as DynamoLicenseKey[],
            lastKey: result.LastEvaluatedKey,
        };
    }

    // Full table scan (use sparingly — for admin panel only)
    const result = await docClient.send(new ScanCommand({
        TableName: TABLE_NAME,
        Limit: limit,
        ExclusiveStartKey: params?.lastKey,
    }));

    return {
        items: (result.Items || []) as DynamoLicenseKey[],
        lastKey: result.LastEvaluatedKey,
    };
}
