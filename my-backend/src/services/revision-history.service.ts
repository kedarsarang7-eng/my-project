import { v4 as uuidv4 } from 'uuid';
import { Keys, putItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

type RevisionAction = 'create' | 'update' | 'delete' | 'status_change';

const REDACT_KEYS = new Set([
    'password',
    'passwd',
    'pin',
    'secret',
    'token',
    'accessToken',
    'refreshToken',
    'authorization',
    'auth',
    'otp',
    'qrPayload',
    'gatewayResponse',
    'webhookRaw',
    'rawPayload',
]);

const PARTIAL_MASK_KEYS = new Set([
    'phone',
    'customerPhone',
    'patientPhone',
    'email',
    'customerEmail',
    'gstin',
    'vehicleNumber',
    'doctorRegNo',
    'memberId',
    'aadhaar',
    'pan',
    'accountNumber',
    'ifsc',
    'upiId',
]);

function maskValue(value: unknown): unknown {
    if (typeof value !== 'string') return value;
    if (value.length <= 4) return '*'.repeat(value.length);
    return `${value.slice(0, 2)}***${value.slice(-2)}`;
}

function sanitizeRevisionValue(value: unknown): unknown {
    if (value === null || value === undefined) return value;
    if (Array.isArray(value)) {
        return value.map((item) => sanitizeRevisionValue(item));
    }
    if (typeof value !== 'object') return value;
    const record = value as Record<string, unknown>;
    const out: Record<string, unknown> = {};
    for (const [key, inner] of Object.entries(record)) {
        if (REDACT_KEYS.has(key)) {
            out[key] = '[REDACTED]';
            continue;
        }
        if (PARTIAL_MASK_KEYS.has(key)) {
            out[key] = maskValue(inner);
            continue;
        }
        out[key] = sanitizeRevisionValue(inner);
    }
    return out;
}

export async function recordRevision(
    tenantId: string,
    table: string,
    entityId: string,
    action: RevisionAction,
    actor: string,
    before?: Record<string, unknown> | null,
    after?: Record<string, unknown> | null,
    metadata?: Record<string, unknown>,
): Promise<void> {
    const now = new Date().toISOString();
    const id = uuidv4();
    try {
        await putItem({
            PK: Keys.tenantPK(tenantId),
            SK: `REVISION#${table}#${entityId}#${now}#${id}`,
            entityType: 'REVISION_HISTORY',
            id,
            tenantId,
            table,
            entityId,
            action,
            actor,
            before: sanitizeRevisionValue(before || null),
            after: sanitizeRevisionValue(after || null),
            metadata: sanitizeRevisionValue(metadata || null),
            createdAt: now,
        });
    } catch (err: any) {
        logger.warn('revision history write failed', {
            tenantId,
            table,
            entityId,
            action,
            error: err?.message,
        });
    }
}
