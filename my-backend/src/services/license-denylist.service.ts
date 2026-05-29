// ============================================================================
// License Denylist Service — Revoked Key Enforcement (DynamoDB)
// ============================================================================

import { getItem, putItem, queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

const DENYLIST_CACHE = new Map<string, { denied: boolean; expiresAt: number }>();
const CACHE_TTL = 60_000;

export async function isKeyDenylisted(licenseKey: string): Promise<boolean> {
    const cached = DENYLIST_CACHE.get(licenseKey);
    if (cached && cached.expiresAt > Date.now()) return cached.denied;

    try {
        const entry = await getItem<Record<string, any>>(`DENYLIST#${licenseKey}`, 'META');
        const denied = !!entry;
        DENYLIST_CACHE.set(licenseKey, { denied, expiresAt: Date.now() + CACHE_TTL });
        return denied;
    } catch (err) {
        logger.error('Denylist check failed — FAIL-CLOSED', { error: (err as Error).message });
        return true;
    }
}

export async function addToDenylist(
    licenseKey: string, tenantId: string, revokedBy: string, reason: string,
): Promise<void> {
    const now = new Date().toISOString();
    await putItem({
        PK: `DENYLIST#${licenseKey}`, SK: 'META', entityType: 'LICENSE_DENYLIST',
        licenseKey, tenantId, revokedBy, reason, revokedAt: now, createdAt: now,
        GSI1PK: 'ENTITY#DENYLIST', GSI1SK: now,
    });
    DENYLIST_CACHE.set(licenseKey, { denied: true, expiresAt: Date.now() + CACHE_TTL });
    logger.info('Key denylisted', { licenseKey: licenseKey.substring(0, 8) + '...', tenantId });
}

export async function listDenylist() {
    const result = await queryItems<Record<string, any>>('ENTITY#DENYLIST', undefined, { indexName: 'GSI1', scanIndexForward: false });
    return result.items.map(i => ({ licenseKey: i.licenseKey, tenantId: i.tenantId, revokedBy: i.revokedBy, reason: i.reason, revokedAt: i.revokedAt }));
}

export function clearDenylistCache(): void { DENYLIST_CACHE.clear(); }
