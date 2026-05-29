import { config } from '../config/environment';
import { v4 as uuidv4 } from 'uuid';
import { getItem, Keys, putItem, queryItems } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

export interface AtgConnectorConfig {
    enabled?: boolean;
    protocol?: 'mock' | 'json_v1';
    endpointUrl?: string;
    apiKeyEnv?: string;
    defaultFuelType?: 'petrol' | 'diesel' | 'cng' | 'other';
    tankMappings?: Array<{ externalTankId: string; tankId: string; fuelType?: string }>;
    mockReadings?: Array<{
        externalTankId: string;
        measuredVolumeLiters: number;
        measuredAt?: string;
        waterLevelMm?: number;
        temperatureCelsius?: number;
        leakDetected?: boolean;
        highWaterAlarm?: boolean;
    }>;
}

interface ConnectorReading {
    externalTankId: string;
    measuredVolumeLiters: number;
    measuredAt: string;
    waterLevelMm?: number;
    temperatureCelsius?: number;
    leakDetected?: boolean;
    highWaterAlarm?: boolean;
}

export async function pollAtgReadingsForTenant(
    tenantId: string,
    actor = 'system',
): Promise<{ inserted: number; skipped: number; errors: string[] }> {
    const errors: string[] = [];
    const cfg = await getItem<AtgConnectorConfig>(Keys.tenantPK(tenantId), 'ATGCONFIG#META');
    if (!cfg || cfg.enabled === false) {
        return { inserted: 0, skipped: 0, errors: ['ATG config not enabled'] };
    }

    const protocol = cfg.protocol || 'mock';
    const rows = await fetchAtgRows(protocol, cfg);
    const mapping = new Map((cfg.tankMappings || []).map(m => [String(m.externalTankId), m]));

    let inserted = 0;
    let skipped = 0;
    for (const row of rows) {
        const map = mapping.get(String(row.externalTankId));
        if (!map || !map.tankId) {
            skipped += 1;
            continue;
        }
        const now = new Date().toISOString();
        const id = uuidv4();
        const measuredAt = row.measuredAt || now;
        const fuelType = map.fuelType || cfg.defaultFuelType || 'other';
        try {
            await putItem({
                PK: Keys.tenantPK(tenantId),
                SK: `TANKATG#${map.tankId}#${measuredAt}#${id}`,
                entityType: 'TANK_ATG_READING',
                id,
                tenantId,
                tankId: map.tankId,
                fuelType,
                measuredVolumeLiters: Number(row.measuredVolumeLiters || 0),
                measuredAt,
                waterLevelMm: row.waterLevelMm ?? null,
                temperatureCelsius: row.temperatureCelsius ?? null,
                leakDetected: row.leakDetected ?? null,
                highWaterAlarm: row.highWaterAlarm ?? null,
                source: 'atg_connector_poll',
                createdBy: actor,
                createdAt: now,
            });
            inserted += 1;
        } catch (err: any) {
            errors.push(`put failed ${map.tankId}: ${err?.message || 'unknown'}`);
        }
    }

    logger.info('ATG poll completed', { tenantId, inserted, skipped, errors: errors.length });
    return { inserted, skipped, errors };
}

export async function pollAtgReadingsAllTenants(): Promise<{
    tenants: number;
    inserted: number;
    skipped: number;
    failed: number;
}> {
    const tenants = await queryItems<Record<string, any>>('ENTITY#TENANT', undefined, { indexName: 'GSI1' });
    let inserted = 0;
    let skipped = 0;
    let failed = 0;

    for (const t of tenants.items) {
        const tenantId = String(t.tenantId || t.id || '');
        if (!tenantId) continue;
        try {
            const r = await pollAtgReadingsForTenant(tenantId, 'atg-scheduler');
            inserted += r.inserted;
            skipped += r.skipped;
        } catch {
            failed += 1;
        }
    }

    return { tenants: tenants.items.length, inserted, skipped, failed };
}

async function fetchAtgRows(
    protocol: 'mock' | 'json_v1',
    cfg: AtgConnectorConfig,
): Promise<ConnectorReading[]> {
    if (protocol === 'mock') {
        const now = new Date().toISOString();
        return (cfg.mockReadings || [])
            .map(r => ({
                externalTankId: String(r.externalTankId),
                measuredVolumeLiters: Number(r.measuredVolumeLiters || 0),
                measuredAt: r.measuredAt || now,
                waterLevelMm: r.waterLevelMm,
                temperatureCelsius: r.temperatureCelsius,
                leakDetected: r.leakDetected,
                highWaterAlarm: r.highWaterAlarm,
            }))
            .filter(r => r.externalTankId && r.measuredVolumeLiters > 0);
    }

    const endpoint = String(cfg.endpointUrl || '').trim();
    if (!endpoint) return [];
    const apiKey = cfg.apiKeyEnv ? process.env[cfg.apiKeyEnv] : config.pump.atgConnectorToken;
    const headers: Record<string, string> = { 'content-type': 'application/json' };
    if (apiKey) headers.authorization = `Bearer ${apiKey}`;

    const res = await fetch(endpoint, { method: 'GET', headers });
    if (!res.ok) throw new Error(`ATG connector HTTP ${res.status}`);
    const data = await res.json() as any;
    const arr = Array.isArray(data) ? data : (Array.isArray(data?.readings) ? data.readings : []);
    const now = new Date().toISOString();

    return arr.map((r: any) => ({
        externalTankId: String(r.externalTankId || r.tankId || ''),
        measuredVolumeLiters: Number(r.measuredVolumeLiters || r.volumeLiters || 0),
        measuredAt: String(r.measuredAt || r.ts || now),
        waterLevelMm: r.waterLevelMm == null ? undefined : Number(r.waterLevelMm),
        temperatureCelsius: r.temperatureCelsius == null ? undefined : Number(r.temperatureCelsius),
        leakDetected: r.leakDetected == null ? undefined : Boolean(r.leakDetected),
        highWaterAlarm: r.highWaterAlarm == null ? undefined : Boolean(r.highWaterAlarm),
    })).filter((r: ConnectorReading) => r.externalTankId && r.measuredVolumeLiters > 0);
}
