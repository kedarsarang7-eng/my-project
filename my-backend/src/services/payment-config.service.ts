// ============================================================================
// Payment Config Service — Merchant Credential Management (DynamoDB)
// ============================================================================
// Migrated from PostgreSQL to DynamoDB single-table design.
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    Keys,
    getItem, putItem, queryItems, updateItem,
} from '../config/dynamodb.config';
import * as kmsService from './kms.service';
import { getGateway } from './gateway/gateway.factory';
import {
    GatewayType,
    GatewayConfigStatus,
    GatewayCredentials,
    TenantPaymentConfig,
} from '../types/payment.types';
import { logger } from '../utils/logger';
import { AppError, NotFoundError } from '../utils/errors';

export async function saveGatewayConfig(
    tenantId: string,
    gatewayType: GatewayType,
    credentials: GatewayCredentials,
    displayName?: string
): Promise<TenantPaymentConfig> {
    const plaintext = JSON.stringify(credentials);
    const encrypted = await kmsService.encryptCredentials(plaintext, tenantId);
    const kmsKeyId = kmsService.getKmsKeyId();
    const now = new Date().toISOString();
    const configId = `${tenantId}#${gatewayType}`;

    const item: Record<string, any> = {
        PK: Keys.tenantPK(tenantId),
        SK: `PAYCONFIG#${gatewayType}`,
        entityType: 'PAYMENT_CONFIG',
        id: configId,
        tenantId,
        gatewayType,
        encryptedCredentials: encrypted,
        kmsKeyId,
        status: 'pending_verification',
        displayName: displayName || null,
        isDefault: false,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
    };

    await putItem(item);
    logger.info('Gateway config saved', { tenantId, gatewayType, status: 'pending_verification' });
    return mapItem(item);
}

export async function getGatewayConfigs(tenantId: string): Promise<TenantPaymentConfig[]> {
    const result = await queryItems<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'PAYCONFIG#',
        {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        },
    );
    return result.items.map(mapItem);
}

export async function getGatewayConfig(tenantId: string, gatewayType: GatewayType): Promise<TenantPaymentConfig | null> {
    const item = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), `PAYCONFIG#${gatewayType}`);
    if (!item || item.isDeleted) return null;
    return mapItem(item);
}

export async function verifyAndActivate(tenantId: string, gatewayType: GatewayType): Promise<TenantPaymentConfig> {
    const item = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), `PAYCONFIG#${gatewayType}`);
    if (!item || item.isDeleted) throw new NotFoundError('Payment gateway config');

    const decrypted = await kmsService.decryptCredentials(item.encryptedCredentials, tenantId);
    const credentials = JSON.parse(decrypted) as GatewayCredentials;
    const gateway = getGateway(gatewayType);
    const isValid = await gateway.validateCredentials(credentials);
    const newStatus = isValid ? GatewayConfigStatus.ACTIVE : GatewayConfigStatus.FAILED;
    const now = new Date().toISOString();

    await updateItem(
        Keys.tenantPK(tenantId),
        `PAYCONFIG#${gatewayType}`,
        {
            updateExpression: 'SET #s = :status, verifiedAt = :now, lastVerifiedAt = :now, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':status': newStatus, ':now': now },
        },
    );

    if (!isValid) {
        throw new AppError('Gateway credential verification failed.', 400, 'GATEWAY_VERIFICATION_FAILED');
    }

    item.status = newStatus;
    item.verifiedAt = now;
    return mapItem(item);
}

export async function getDecryptedConfig(
    tenantId: string,
    gatewayType: GatewayType
): Promise<{ config: TenantPaymentConfig; credentials: GatewayCredentials }> {
    const item = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), `PAYCONFIG#${gatewayType}`);
    if (!item || item.isDeleted || item.status !== 'active') {
        throw new AppError(`No active ${gatewayType} configuration found`, 400, 'NO_ACTIVE_GATEWAY');
    }

    const decrypted = await kmsService.decryptCredentials(item.encryptedCredentials, tenantId);
    return { config: mapItem(item), credentials: JSON.parse(decrypted) as GatewayCredentials };
}

export async function getActiveGateway(
    tenantId: string
): Promise<{ gatewayType: GatewayType; config: TenantPaymentConfig } | null> {
    const result = await queryItems<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'PAYCONFIG#',
        {
            filterExpression: '#s = :active AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':active': 'active', ':false': false },
        },
    );

    if (result.items.length === 0) return null;
    // Prefer default, then most recently verified
    const sorted = result.items.sort((a, b) => {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return (b.verifiedAt || '').localeCompare(a.verifiedAt || '');
    });

    const config = mapItem(sorted[0]);
    return { gatewayType: config.gatewayType, config };
}

export async function deleteGatewayConfig(tenantId: string, gatewayType: GatewayType): Promise<void> {
    try {
        await updateItem(
            Keys.tenantPK(tenantId),
            `PAYCONFIG#${gatewayType}`,
            {
                updateExpression: 'SET isDeleted = :true, #s = :inactive, updatedAt = :now',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':true': true, ':inactive': 'inactive', ':now': new Date().toISOString() },
                conditionExpression: 'attribute_exists(PK) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            },
        );
    } catch (err: any) {
        if (err.name === 'ConditionalCheckFailedException') throw new NotFoundError('Payment gateway config');
        throw err;
    }
    logger.info('Gateway config deleted', { tenantId, gatewayType });
}

// Auto-disable

import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { config } from '../config/environment';
const snsClient = new SNSClient({ region: config.aws.region });

export async function autoDisableMerchant(tenantId: string, reason: string, triggeredBy = 'system'): Promise<void> {
    const configs = await queryItems<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'PAYCONFIG#',
        {
            filterExpression: '#s = :active',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':active': 'active' },
        },
    );

    for (const config of configs.items) {
        await updateItem(
            config.PK,
            config.SK,
            {
                updateExpression: 'SET #s = :inactive, autoDisabledAt = :now, autoDisabledReason = :reason, updatedAt = :now',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':inactive': 'inactive', ':now': new Date().toISOString(), ':reason': reason },
            },
        );
    }

    logger.error('SECURITY: Merchant auto-disabled', { tenantId, reason, triggeredBy });

    const topicArn = config.awsSns.securityAlertTopicArn;
    if (topicArn) {
        try {
            await snsClient.send(new PublishCommand({
                TopicArn: topicArn,
                Subject: `SECURITY: Merchant auto-disabled — ${tenantId}`,
                Message: JSON.stringify({ event: 'merchant_auto_disabled', tenantId, reason, triggeredBy, timestamp: new Date().toISOString() }, null, 2),
            }));
        } catch (err) { logger.warn('Failed to send SNS alert', { error: (err as Error).message }); }
    }
}

export async function reEnableMerchant(tenantId: string, gatewayType: GatewayType, reEnabledBy: string): Promise<TenantPaymentConfig | null> {
    const now = new Date().toISOString();
    const result = await updateItem(
        Keys.tenantPK(tenantId),
        `PAYCONFIG#${gatewayType}`,
        {
            updateExpression: 'SET #s = :active, autoDisabledAt = :null, autoDisabledReason = :null, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':active': 'active', ':null': null, ':now': now },
        },
    );

    if (!result) return null;
    logger.info('Merchant re-enabled', { tenantId, gatewayType, reEnabledBy });
    return mapItem(result);
}

function mapItem(row: any): TenantPaymentConfig {
    return {
        id: row.id || row.SK,
        tenantId: row.tenantId || row.tenant_id,
        gatewayType: (row.gatewayType || row.gateway_type) as GatewayType,
        status: (row.status) as GatewayConfigStatus,
        displayName: row.displayName || row.display_name,
        isDefault: row.isDefault || row.is_default || false,
        verifiedAt: row.verifiedAt || row.verified_at ? new Date(row.verifiedAt || row.verified_at) : undefined,
        createdAt: new Date(row.createdAt || row.created_at),
        updatedAt: new Date(row.updatedAt || row.updated_at),
    };
}
