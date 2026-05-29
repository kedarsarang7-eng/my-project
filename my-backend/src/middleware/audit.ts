// ============================================================================
// Audit Logging Middleware (DynamoDB)
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import { Keys, putItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import * as context from '../utils/context';

export interface AuditEntry {
    action: string;
    resource: string;
    resourceId?: string;
    metadata?: Record<string, unknown>;
    ip?: string;
}

export async function logAudit(entry: AuditEntry): Promise<void> {
    const tenantId = context.getTenantId();
    const userId = context.getUserId();

    if (!tenantId || !userId) {
        logger.warn('Audit log skipped: missing context', { action: entry.action, resource: entry.resource });
        return;
    }

    try {
        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(tenantId),
            SK: `AUDIT#${now}#${uuidv4().substring(0, 8)}`,
            entityType: 'AUDIT_LOG',
            tenantId, userId,
            action: entry.action,
            resource: entry.resource,
            resourceId: entry.resourceId || null,
            metadata: entry.metadata || {},
            ip: entry.ip || null,
            createdAt: now,
        });
    } catch (err) {
        logger.error('Failed to write audit log', { error: (err as Error).message, action: entry.action, resource: entry.resource });
    }
}

export const PlanAuditEvent = {
    UNAUTHORIZED_PLAN_ACCESS: 'UNAUTHORIZED_PLAN_ACCESS',
    PLAN_UPGRADE_REQUEST: 'PLAN_UPGRADE_REQUEST',
    PLAN_DOWNGRADE_REQUEST: 'PLAN_DOWNGRADE_REQUEST',
    FEATURE_BYPASS_ATTEMPT: 'FEATURE_BYPASS_ATTEMPT',
    MANIFEST_REFRESH: 'MANIFEST_REFRESH',
    PLAN_KEY_DECRYPTION: 'PLAN_KEY_DECRYPTION',
} as const;

export type PlanAuditEventType = typeof PlanAuditEvent[keyof typeof PlanAuditEvent];

export interface PlanAuditEntry {
    eventType: PlanAuditEventType;
    severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
    featureKey?: string;
    requestPath?: string;
    details?: Record<string, unknown>;
}

export async function logPlanAudit(entry: PlanAuditEntry): Promise<void> {
    const tenantId = context.getTenantId();
    const userId = context.getUserId();

    await logAudit({
        action: entry.eventType,
        resource: 'plan',
        metadata: { severity: entry.severity, featureKey: entry.featureKey, requestPath: entry.requestPath, ...entry.details },
    });

    if (!tenantId || !userId) return;

    try {
        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(tenantId),
            SK: `PLANAUDIT#${now}#${uuidv4().substring(0, 8)}`,
            entityType: 'PLAN_AUDIT_LOG',
            tenantId, userId,
            eventType: entry.eventType,
            severity: entry.severity,
            featureKey: entry.featureKey || null,
            requestPath: entry.requestPath || null,
            details: entry.details || {},
            createdAt: now,
        });
    } catch (err) {
        logger.error('Failed to write plan audit log', { error: (err as Error).message, eventType: entry.eventType });
    }
}
