// ============================================================================
// License Service � Key Generation, Activation & Validation (DynamoDB)
// ============================================================================
// Manages the full license key lifecycle:
//   1. Generate DKX-format license keys (admin-only)
//   2. Activate keys ? update tenant plan + record audit
//   3. Query license status
//   4. Deactivate / suspend / revoke keys
//
// Migrated from PostgreSQL to DynamoDB single-table design.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { randomBytes, createHash } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import {
    Keys, TABLE_NAME,
    getItem, putItem, queryItems, updateItem, transactWrite,
} from '../config/dynamodb.config';
import * as kmsService from './kms.service';
import { logger } from '../utils/logger';
import { AppError, NotFoundError } from '../utils/errors';
import { PlanTier, mapToPlanTier } from '../config/plan-feature-registry';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { config } from '../config/environment';
import { LicenseKeyPayload } from '../types/license.types';
import { isKeyDenylisted } from './license-denylist.service';
import { signLicenseToken, LICENSE_TOKEN_TTL_SECONDS } from './license-token.service';

const cloudwatchClient = new CloudWatchClient(configureAwsClient({ region: config.aws.region }));

// -- In-Memory License Validation Cache --------------------------------------
// Lambda warm instances cache validated licenses to avoid repeated DynamoDB reads.
// TTL: 5 minutes. Invalidated on plan upgrade/downgrade.
interface CachedLicense {
    data: LicenseValidationResult;
    expiresAt: number; // Unix ms
}
const LICENSE_CACHE = new Map<string, CachedLicense>();
// LOW-008 FIX: Configurable cache TTL via env var (default: 5 minutes)
const LICENSE_CACHE_TTL_MS = parseInt(config.license.cacheTtlMs || '300000', 10);

/** Invalidate cache for a specific license key or tenant */
export function invalidateLicenseCache(key: string): void {
    LICENSE_CACHE.delete(key);
}

/** Clear entire license cache (used on deployment or manual flush) */
export function clearLicenseCache(): void {
    LICENSE_CACHE.clear();
}

// -- Types -------------------------------------------------------------------

export interface LicenseKeyResult {
    licenseKey: string;
    tenantId: string;
    planTier: string;
    expiresAt: Date | null;
}

/** Owner info for license generation (BUG-LIC-003) */
export interface OwnerInfo {
    ownerName?: string | null;
    ownerEmail?: string | null;
    ownerPhone?: string | null;
    businessName?: string | null;
    notes?: string | null;
    maxDevices?: number;
}

export interface LicenseStatus {
    tenantId: string;
    tenantName: string;
    licenseKey: string | null;
    licenseStatus: string;
    planType: string;
    activatedAt: Date | null;
    expiresAt: Date | null;
    isActive: boolean;
}

export interface ActivationResult {
    success: boolean;
    tenantId: string;
    planTier: string;
    message: string;
    activatedAt: Date;
    expiresAt: Date | null;
}

// -- Key Format --------------------------------------------------------------

const PLAN_PREFIXES: Record<string, string> = {
    basic: 'BASIC',
    premium: 'PREMIUM',
    enterprise: 'ENTERPRISE',
    starter: 'STARTER',
    professional: 'PRO',
    free: 'FREE',
};

// Regex patterns for both supported key formats
const LEGACY_KEY_RE = /^DKX-[A-Z]+-[A-F0-9]{12}$/;           // DKX-PREMIUM-A1B2C3D4E5F6
const STANDALONE_KEY_RE = /^DKX-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;  // DKX-A1B2-C3D4-E5F6

/** Validate that a string matches one of the supported DKX key formats. */
function isValidKeyFormat(key: string): boolean {
    return LEGACY_KEY_RE.test(key) || STANDALONE_KEY_RE.test(key);
}

/**
 * Generate a unique license key in DKX legacy format.
 * Format: DKX-<PLAN>-<12-char hex random>
 */
function generateKeyString(planTier: string): string {
    const prefix = PLAN_PREFIXES[planTier.toLowerCase()] || 'CUSTOM';
    const randomPart = randomBytes(6).toString('hex').toUpperCase();
    return `DKX-${prefix}-${randomPart}`;
}

// -- Generate License Key (Admin Only) ---------------------------------------

/**
 * Generate and assign a new license key to a tenant.
 */
export async function generateLicenseKey(
    tenantId: string,
    planTier: string,
    expiresAt: Date | null,
    adminId: string,
): Promise<LicenseKeyResult> {
    const licenseKey = generateKeyString(planTier);

    logger.info('Generating license key', { tenantId, planTier, adminId });

    // Verify tenant exists
    const tenant = await getItem(Keys.tenantPK(tenantId), Keys.tenantProfileSK());
    if (!tenant) {
        throw new NotFoundError(`Tenant ${tenantId} not found`);
    }

    const now = new Date().toISOString();

    // Store the license key record
    await putItem({
        PK: Keys.licensePK(licenseKey),
        SK: Keys.licenseMetaSK(),
        entityType: 'LICENSE',
        licenseKey,
        tenantId,
        plan: planTier,
        status: 'ACTIVE',
        expiryDate: expiresAt ? expiresAt.toISOString() : null,
        createdBy: adminId,
        activatedDevices: [],
        maxDevices: 5,
        createdAt: now,
        updatedAt: now,
        GSI1PK: Keys.licenseEntityGSI1PK(),
        GSI1SK: now,
    });

    // Update tenant license reference
    await updateItem(
        Keys.tenantPK(tenantId),
        Keys.tenantProfileSK(),
        {
            updateExpression: 'SET licenseKey = :lk, licenseExpiresAt = :exp, licenseStatus = :s, updatedAt = :now',
            expressionAttributeValues: {
                ':lk': licenseKey,
                ':exp': expiresAt ? expiresAt.toISOString() : null,
                ':s': 'inactive',
                ':now': now,
            },
        },
    );

    // Record activation audit
    await putItem({
        PK: Keys.licensePK(licenseKey),
        SK: Keys.licenseActivationSK(now),
        entityType: 'LICENSE_ACTIVATION',
        tenantId,
        licenseKey,
        action: 'generate',
        planTier,
        activatedBy: adminId,
        expiresAt: expiresAt ? expiresAt.toISOString() : null,
        createdAt: now,
    });

    logger.info('License key generated', { tenantId, licenseKey: `${licenseKey.substring(0, 8)}...` });

    return { licenseKey, tenantId, planTier, expiresAt };
}

// -- Generate Standalone License Key (Admin � Auto Tenant Creation) ----------

export interface StandaloneLicenseResult {
    license_key: string;
    tenant_id: string;
    plan: string;
    expiry_date: string;
    business_type: string;
    features: string[];
}

function parseDuration(duration: string): Date | null {
    if (duration.trim().toLowerCase() === 'lifetime') return null;

    const now = new Date();
    const match = duration.trim().match(/^(\d+)\s*(month|months|day|days|year|years)$/i);
    if (!match) {
        const d = new Date(now);
        d.setFullYear(d.getFullYear() + 1);
        return d;
    }

    const amount = parseInt(match[1], 10);
    const unit = match[2].toLowerCase();
    const result = new Date(now);

    if (unit.startsWith('year')) result.setFullYear(result.getFullYear() + amount);
    else if (unit.startsWith('month')) result.setMonth(result.getMonth() + amount);
    else result.setDate(result.getDate() + amount);

    return result;
}

function generateDKNXKey(): string {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const bytes = randomBytes(12);
    const segments: string[] = [];
    for (let s = 0; s < 3; s++) {
        let seg = '';
        for (let i = 0; i < 4; i++) {
            seg += charset[bytes[s * 4 + i] % charset.length];
        }
        segments.push(seg);
    }
    return `DKNX-${segments[0]}-${segments[1]}-${segments[2]}`;
}

/**
 * Generate a standalone license key (not tied to an existing tenant).
 * ENHANCED: Now supports multi-business licenses via allowedBusinessTypes array.
 * Uses DynamoDB TransactWrite for atomic license+tenant creation.
 */
export async function generateStandaloneLicenseKey(
    plan: string,
    duration: string,
    businessType: string,
    features: string[],
    adminId: string,
    ownerInfo?: OwnerInfo,
    allowedBusinessTypes?: string[],
    manualOverrides?: { added?: string[]; removed?: string[] },
    storageLimitGB?: number,
    apiRateLimit?: number,
    renewalPeriodDays?: number,
): Promise<StandaloneLicenseResult> {
    const shortUuid = randomBytes(4).toString('hex').toUpperCase();
    const tenantId = `TNX-${shortUuid}`;
    const licenseKey = generateDKNXKey();
    const expiryDate = parseDuration(duration);
    const now = new Date().toISOString();
    const maxDevices = ownerInfo?.maxDevices || 1;

    // ENHANCED: Handle multi-business license support
    const finalAllowedBusinessTypes = allowedBusinessTypes && allowedBusinessTypes.length > 0 
        ? allowedBusinessTypes 
        : [businessType];

    // BUG-LIC-003: Use real owner info or fallback
    const tenantName = ownerInfo?.businessName || ownerInfo?.ownerName || `Auto-${businessType}-${shortUuid}`;

    // BUG-LIC-004: Duplicate prevention � check if email/phone already has active license
    if (ownerInfo?.ownerEmail) {
        const existing = await checkDuplicateLicense('email', ownerInfo.ownerEmail);
        if (existing) {
            logger.warn('[LICENSE] Duplicate license warning', {
                existingKey: existing.substring(0, 8) + '...',
                email: ownerInfo.ownerEmail,
            });
            // Warn but don't block � Super Admin may intentionally create multiple
        }
    }

    logger.info('[LICENSE] Generating standalone license key', {
        tenantId, plan, duration, businessType, adminId,
        ownerName: ownerInfo?.ownerName,
        ownerEmail: ownerInfo?.ownerEmail,
    });

    // Atomic write: create license + tenant in single transaction
    await transactWrite([
        {
            Put: {
                TableName: TABLE_NAME,
                Item: {
                    PK: Keys.licensePK(licenseKey),
                    SK: Keys.licenseMetaSK(),
                    entityType: 'LICENSE',
                    licenseKey,
                    tenantId,
                    plan,
                    status: 'ACTIVE',
                    businessType,
                    features,
                    // ENHANCED: Multi-business license support
                    allowedBusinessTypes: finalAllowedBusinessTypes,
                    expiryDate: expiryDate ? expiryDate.toISOString() : null,
                    createdBy: adminId,
                    activatedDevices: [],
                    maxDevices,
                    maxUsers: 10,
                    // BUG-LIC-003: Store owner info
                    ownerName: ownerInfo?.ownerName || null,
                    ownerEmail: ownerInfo?.ownerEmail || null,
                    ownerPhone: ownerInfo?.ownerPhone || null,
                    businessName: ownerInfo?.businessName || null,
                    notes: ownerInfo?.notes || null,
                    // ENHANCED: Plan feature system v2 fields
                    manualOverrides: {
                        added: manualOverrides?.added ?? [],
                        removed: manualOverrides?.removed ?? [],
                    },
                    storageLimitGB: storageLimitGB ?? null,
                    apiRateLimit: apiRateLimit ?? null,
                    renewalPeriodDays: renewalPeriodDays ?? null,
                    auditLog: [],
                    createdAt: now,
                    updatedAt: now,
                    GSI1PK: Keys.licenseEntityGSI1PK(),
                    GSI1SK: now,
                },
                ConditionExpression: 'attribute_not_exists(PK)',
            },
        },
        {
            Put: {
                TableName: TABLE_NAME,
                Item: {
                    PK: Keys.tenantPK(tenantId),
                    SK: Keys.tenantProfileSK(),
                    entityType: 'TENANT',
                    tenantId,
                    name: tenantName,
                    businessType,
                    subscriptionPlan: plan,
                    licenseKey,
                    licenseStatus: 'active',
                    isActive: true,
                    // BUG-LIC-003: Store owner contact on tenant
                    email: ownerInfo?.ownerEmail || null,
                    phone: ownerInfo?.ownerPhone || null,
                    ownerName: ownerInfo?.ownerName || null,
                    createdAt: now,
                    updatedAt: now,
                    GSI1PK: 'ENTITY#TENANT',
                    GSI1SK: now,
                },
                ConditionExpression: 'attribute_not_exists(PK)',
            },
        },
        {
            Put: {
                TableName: TABLE_NAME,
                Item: {
                    PK: Keys.tenantPK(tenantId),
                    SK: Keys.tenantLicenseSK(),
                    entityType: 'TENANT_LICENSE',
                    tenantId,
                    licenseKey,
                    status: 'ACTIVE',
                    plan,
                    businessType,
                    // ENHANCED: Multi-business license support
                    allowedBusinessTypes: finalAllowedBusinessTypes,
                    features,
                    expiryDate: expiryDate ? expiryDate.toISOString() : null,
                    maxDevices,
                    maxUsers: 10,
                    ownerName: ownerInfo?.ownerName || null,
                    ownerEmail: ownerInfo?.ownerEmail || null,
                    ownerPhone: ownerInfo?.ownerPhone || null,
                    businessName: ownerInfo?.businessName || null,
                    notes: ownerInfo?.notes || null,
                    // ENHANCED: Plan feature system v2 fields (mirror of LICENSE record)
                    manualOverrides: {
                        added: manualOverrides?.added ?? [],
                        removed: manualOverrides?.removed ?? [],
                    },
                    storageLimitGB: storageLimitGB ?? null,
                    apiRateLimit: apiRateLimit ?? null,
                    renewalPeriodDays: renewalPeriodDays ?? null,
                    createdAt: now,
                    updatedAt: now,
                },
                ConditionExpression: 'attribute_not_exists(PK)',
            },
        },
    ]);

    const expiryDateStr = expiryDate ? expiryDate.toISOString().split('T')[0] : 'Lifetime';

    logger.info('[LICENSE] License key generated and saved (atomic)', {
        tenantId, licenseKey: `${licenseKey.substring(0, 9)}...`, plan, businessType, expiryDate: expiryDateStr,
    });

    return {
        license_key: licenseKey,
        tenant_id: tenantId,
        plan,
        expiry_date: expiryDateStr,
        business_type: businessType,
        features,
    };
}

// -- Activate License Key ----------------------------------------------------

/**
 * Activate a license key for a tenant.
 * Searches the DynamoDB LICENSE# records.
 */
export async function activateLicense(
    licenseKey: string,
    deviceId?: string,
    deviceInfo?: Record<string, unknown>,
    sourceIp?: string,
    userId?: string,
): Promise<ActivationResult> {
    // 1. Validate key format
    if (!isValidKeyFormat(licenseKey)) {
        throw new AppError(
            'Invalid license key format. Expected DKX-<PLAN>-<12hex> or DKX-XXXX-XXXX-XXXX',
            400, 'INVALID_KEY_FORMAT',
        );
    }

    // 2. Look up the license
    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );

    if (!license) {
        // 3. Try legacy: look up tenant by license key via GSI scan (fallback)
        // In practice, all keys should be in the LICENSE# partition after migration
        await emitMetric('InvalidLicenseKeyAttempt', 1);
        throw new NotFoundError('License key not found');
    }

    // Check status
    const status = (license.status || '').toUpperCase();
    if (status === 'ACTIVATED') {
        throw new AppError('This license key is already activated', 409, 'ALREADY_ACTIVE');
    }
    if (status === 'REVOKED' || status === 'SUSPENDED') {
        throw new AppError(`License key is ${status.toLowerCase()}`, 403, 'KEY_DISABLED');
    }
    if (status === 'EXPIRED' || (license.expiryDate && new Date(license.expiryDate) < new Date())) {
        throw new AppError('License key has expired', 410, 'KEY_EXPIRED');
    }

    const planTier = (license.plan || 'basic').toLowerCase();
    const expiresAt = license.expiryDate ? new Date(license.expiryDate) : null;
    const now = new Date();
    const nowISO = now.toISOString();

    // Update the license status to ACTIVATED
    await updateItem(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
        {
            updateExpression: 'SET #s = :activated, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':activated': 'ACTIVATED', ':now': nowISO },
        },
    );

    // Update the tenant profile if it exists
    const tenantProfile = await getItem(Keys.tenantPK(license.tenantId), Keys.tenantProfileSK());
    if (tenantProfile) {
        await updateItem(
            Keys.tenantPK(license.tenantId),
            Keys.tenantProfileSK(),
            {
                updateExpression: 'SET subscriptionPlan = :plan, licenseKey = :lk, licenseStatus = :ls, licenseActivatedAt = :now, licenseExpiresAt = :exp, updatedAt = :now',
                expressionAttributeValues: {
                    ':plan': planTier,
                    ':lk': licenseKey,
                    ':ls': 'active',
                    ':now': nowISO,
                    ':exp': expiresAt ? expiresAt.toISOString() : null,
                },
            },
        );
    }

    // Record activation audit
    try {
        await putItem({
            PK: Keys.licensePK(licenseKey),
            SK: Keys.licenseActivationSK(nowISO),
            entityType: 'LICENSE_ACTIVATION',
            tenantId: license.tenantId,
            licenseKey,
            action: 'activate',
            planTier,
            deviceId: deviceId || null,
            deviceInfo: deviceInfo || {},
            ipAddress: sourceIp || null,
            activatedBy: userId || 'system',
            expiresAt: expiresAt ? expiresAt.toISOString() : null,
            createdAt: nowISO,
        });
    } catch (auditErr) {
        logger.warn('Failed to record license activation audit', {
            error: (auditErr as Error).message,
        });
    }

    logger.info('License activated', {
        tenantId: license.tenantId, planTier, licenseKey: `${licenseKey.substring(0, 8)}...`,
    });

    await emitMetric('LicenseActivation', 1, [
        { Name: 'PlanTier', Value: planTier },
    ]);

    return {
        success: true,
        tenantId: license.tenantId,
        planTier,
        message: `License activated. Plan upgraded to ${planTier}.`,
        activatedAt: now,
        expiresAt,
    };
}

// -- Get License Status ------------------------------------------------------

export async function getLicenseStatus(tenantId: string): Promise<LicenseStatus> {
    const tenant = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.tenantProfileSK(),
    );

    if (!tenant) {
        throw new NotFoundError(`Tenant ${tenantId} not found`);
    }

    // Check if license has expired since last check
    const licenseStatus = tenant.licenseStatus || 'inactive';
    if (licenseStatus === 'active' && tenant.licenseExpiresAt && new Date(tenant.licenseExpiresAt) < new Date()) {
        await updateItem(
            Keys.tenantPK(tenantId),
            Keys.tenantProfileSK(),
            {
                updateExpression: 'SET licenseStatus = :expired, updatedAt = :now',
                expressionAttributeValues: {
                    ':expired': 'expired',
                    ':now': new Date().toISOString(),
                },
            },
        );
        tenant.licenseStatus = 'expired';
    }

    return {
        tenantId: tenant.tenantId || tenantId,
        tenantName: tenant.name || '',
        licenseKey: tenant.licenseKey ? `${tenant.licenseKey.substring(0, 8)}...` : null,
        licenseStatus: tenant.licenseStatus || 'inactive',
        planType: tenant.subscriptionPlan || 'free',
        activatedAt: tenant.licenseActivatedAt ? new Date(tenant.licenseActivatedAt) : null,
        expiresAt: tenant.licenseExpiresAt ? new Date(tenant.licenseExpiresAt) : null,
        isActive: tenant.licenseStatus === 'active' && tenant.isActive !== false,
    };
}

// -- Deactivate / Suspend / Revoke -------------------------------------------

export async function changeLicenseStatus(
    tenantId: string,
    action: 'deactivate' | 'suspend' | 'revoke' | 'reactivate',
    adminId: string,
    reason?: string,
): Promise<void> {
    // BUG-LIC-019: Added reactivate
    const statusMap: Record<string, string> = {
        deactivate: 'inactive',
        suspend: 'suspended',
        revoke: 'revoked',
        reactivate: 'active',
    };
    const newStatus = statusMap[action];
    const now = new Date().toISOString();

    // Get current tenant to capture old status for audit (BUG-LIC-005)
    const tenant = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.tenantProfileSK(),
    );

    if (!tenant) {
        throw new NotFoundError(`Tenant ${tenantId} not found`);
    }

    const oldStatus = tenant.licenseStatus || 'unknown';
    const tenantLicenseKey = tenant.licenseKey || 'N/A';
    const tenantPlan = tenant.subscriptionPlan || 'basic';

    // Update tenant
    await updateItem(
        Keys.tenantPK(tenantId),
        Keys.tenantProfileSK(),
        {
            updateExpression: 'SET licenseStatus = :status, updatedAt = :now',
            expressionAttributeValues: { ':status': newStatus, ':now': now },
        },
    );

    // Also update standing license record
    if (tenantLicenseKey !== 'N/A') {
        try {
            await updateItem(
                Keys.licensePK(tenantLicenseKey),
                Keys.licenseMetaSK(),
                {
                    updateExpression: 'SET #s = :status, updatedAt = :now',
                    expressionAttributeNames: { '#s': 'status' },
                    expressionAttributeValues: { ':status': newStatus.toUpperCase(), ':now': now },
                },
            );
        } catch { /* license record may not exist */ }
    }

    // BUG-LIC-008: Invalidate cache
    invalidateLicenseCache(tenantLicenseKey);

    // BUG-LIC-005: Record audit with old?new values
    await putItem({
        PK: Keys.licensePK(tenantLicenseKey),
        SK: Keys.licenseActivationSK(now),
        entityType: 'LICENSE_STATUS_CHANGE',
        tenantId,
        licenseKey: tenantLicenseKey,
        action,
        oldStatus,
        newStatus,
        reason: reason || null,
        planTier: tenantPlan,
        activatedBy: adminId,
        createdAt: now,
    });

    logger.info('License status changed', { tenantId, action, oldStatus, newStatus, adminId, reason });
}

// -- Admin License Features (List, Upgrade, Transfer, Extend, Convert) --

export interface LicenseItem {
    licenseKey: string;
    tenantId: string;
    tenantName?: string;
    plan: string;
    status: string;
    expiryDate: Date | null;
    createdAt: Date | null;
    type: 'standalone' | 'legacy';
}

/**
 * List all license keys in the system via GSI1 (ENTITY#LICENSE).
 * BUG-LIC-014: Keys masked in list response.
 */
export async function listLicenses(): Promise<LicenseItem[]> {
    const result = await queryItems<Record<string, any>>(
        Keys.licenseEntityGSI1PK(),
        undefined,
        {
            indexName: 'GSI1',
            scanIndexForward: false,
        },
    );

    return result.items.map(item => ({
        // BUG-LIC-014: Mask key in list response
        licenseKey: maskKey(item.licenseKey),
        licenseKeyFull: item.licenseKey, // Available but should be filtered by API layer if needed
        tenantId: item.tenantId,
        tenantName: item.tenantName || item.businessName || item.ownerName || null,
        plan: item.plan,
        status: item.status,
        businessType: item.businessType || null,
        ownerName: item.ownerName || null,
        ownerEmail: item.ownerEmail || null,
        ownerPhone: item.ownerPhone || null,
        maxDevices: item.maxDevices || 1,
        expiryDate: item.expiryDate ? new Date(item.expiryDate) : null,
        createdAt: item.createdAt ? new Date(item.createdAt) : null,
        type: 'standalone' as const,
    }));
}

/** Mask a license key for list display */
function maskKey(key: string): string {
    if (!key || key.length < 10) return '***';
    return `${key.substring(0, 8)}****${key.substring(key.length - 4)}`;
}

/**
 * Get full details for a specific license key.
 */
export async function getLicenseDetails(licenseKey: string) {
    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );

    if (!license) {
        throw new NotFoundError('License key not found');
    }

    // Fetch tenant details if linked
    let tenantDetails = null;
    if (license.tenantId) {
        const tenant = await getItem<Record<string, any>>(
            Keys.tenantPK(license.tenantId),
            Keys.tenantProfileSK(),
        );
        if (tenant) {
            tenantDetails = {
                name: tenant.name,
                email: tenant.email,
                phone: tenant.phone,
            };
        }
    }

    return {
        type: 'standalone',
        data: { ...license, tenant_details: tenantDetails },
    };
}

/**
 * Upgrade (or Convert) a license plan tier.
 */
export async function upgradeLicense(licenseKey: string, newPlanTier: string, adminId: string, maxDevices?: number): Promise<void> {
    const plan = newPlanTier.toLowerCase();
    const now = new Date().toISOString();

    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );

    if (!license) {
        throw new NotFoundError('License key not found');
    }

    // BUG-LIC-005: Capture old values for audit
    const oldPlan = license.plan || 'basic';
    const oldMaxDevices = license.maxDevices || 1;

    // Build update expression dynamically
    let updateExpr = 'SET plan = :plan, updatedAt = :now';
    const exprValues: Record<string, any> = { ':plan': plan, ':now': now };
    if (maxDevices) {
        updateExpr += ', maxDevices = :md';
        exprValues[':md'] = maxDevices;
    }

    // BUG-LIC-006: Use transactWrite for atomic license+tenant update
    const transactItems: any[] = [
        {
            Update: {
                TableName: TABLE_NAME,
                Key: { PK: Keys.licensePK(licenseKey), SK: Keys.licenseMetaSK() },
                UpdateExpression: updateExpr,
                ExpressionAttributeValues: exprValues,
            },
        },
    ];

    if (license.tenantId) {
        transactItems.push({
            Update: {
                TableName: TABLE_NAME,
                Key: { PK: Keys.tenantPK(license.tenantId), SK: Keys.tenantProfileSK() },
                UpdateExpression: 'SET subscriptionPlan = :plan, updatedAt = :now',
                ExpressionAttributeValues: { ':plan': plan, ':now': now },
                ConditionExpression: 'attribute_exists(PK)',
            },
        });
    }

    await transactWrite(transactItems);

    // BUG-LIC-008: Invalidate cache
    invalidateLicenseCache(licenseKey);

    // BUG-LIC-005: Audit with old?new values
    await putItem({
        PK: Keys.licensePK(licenseKey),
        SK: Keys.licenseActivationSK(now),
        entityType: 'LICENSE_UPGRADE',
        tenantId: license.tenantId,
        licenseKey,
        action: 'upgrade',
        oldPlan,
        newPlan: plan,
        oldMaxDevices,
        newMaxDevices: maxDevices || oldMaxDevices,
        activatedBy: adminId,
        createdAt: now,
    });

    logger.info('License upgraded/converted', { licenseKey, oldPlan, newPlan: plan, adminId });
}

export async function convertLicense(licenseKey: string, newPlanTier: string, adminId: string): Promise<void> {
    return upgradeLicense(licenseKey, newPlanTier, adminId);
}

/**
 * Transfer a license to a different tenant ID.
 */
export async function transferLicense(licenseKey: string, newTenantId: string, adminId: string): Promise<void> {
    const now = new Date().toISOString();

    // Validate new tenant exists
    const newTenant = await getItem(Keys.tenantPK(newTenantId), Keys.tenantProfileSK());
    if (!newTenant) {
        throw new NotFoundError(`New Tenant ${newTenantId} not found`);
    }

    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );

    if (!license) {
        throw new NotFoundError('License key not found');
    }

    const oldTenantId = license.tenantId;
    const planTier = license.plan || 'basic';

    // Update the license to point to new tenant
    await updateItem(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
        {
            updateExpression: 'SET tenantId = :newTenant, updatedAt = :now',
            expressionAttributeValues: { ':newTenant': newTenantId, ':now': now },
        },
    );

    // Remove from old tenant
    if (oldTenantId) {
        try {
            await updateItem(
                Keys.tenantPK(oldTenantId),
                Keys.tenantProfileSK(),
                {
                    updateExpression: 'SET licenseStatus = :s, licenseKey = :null, updatedAt = :now',
                    expressionAttributeValues: { ':s': 'inactive', ':null': null, ':now': now },
                },
            );
        } catch { /* old tenant may not exist */ }
    }

    // Audit: suspend from old
    await putItem({
        PK: Keys.licensePK(licenseKey),
        SK: Keys.licenseActivationSK(now + '#old'),
        entityType: 'LICENSE_ACTIVATION',
        tenantId: oldTenantId,
        licenseKey,
        action: 'suspend',
        planTier,
        activatedBy: adminId,
        deviceInfo: { transferTo: newTenantId },
        createdAt: now,
    });

    // Audit: activate for new
    await putItem({
        PK: Keys.licensePK(licenseKey),
        SK: Keys.licenseActivationSK(now + '#new'),
        entityType: 'LICENSE_ACTIVATION',
        tenantId: newTenantId,
        licenseKey,
        action: 'activate',
        planTier,
        activatedBy: adminId,
        deviceInfo: { transferFrom: oldTenantId },
        createdAt: now,
    });

    logger.info('License transferred', { licenseKey, oldTenantId, newTenantId, adminId });
}

function calculateExtendedExpiry(currentExpiry: Date | null, duration: string): Date | null {
    if (duration.trim().toLowerCase() === 'lifetime') return null;

    const baseDate = (currentExpiry && currentExpiry > new Date()) ? new Date(currentExpiry) : new Date();
    const match = duration.trim().match(/^(\d+)\s*(month|months|day|days|year|years)$/i);
    if (!match) {
        baseDate.setFullYear(baseDate.getFullYear() + 1);
        return baseDate;
    }

    const amount = parseInt(match[1], 10);
    const unit = match[2].toLowerCase();
    if (unit.startsWith('year')) baseDate.setFullYear(baseDate.getFullYear() + amount);
    else if (unit.startsWith('month')) baseDate.setMonth(baseDate.getMonth() + amount);
    else baseDate.setDate(baseDate.getDate() + amount);
    return baseDate;
}

/**
 * Extend a license's duration.
 */
export async function extendLicense(licenseKey: string, duration: string, adminId: string): Promise<void> {
    const now = new Date().toISOString();

    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );

    if (!license) {
        throw new NotFoundError('License key not found');
    }

    // BUG-LIC-005: Capture old expiry for audit
    const oldExpiry = license.expiryDate || null;
    const currentExpiry = license.expiryDate ? new Date(license.expiryDate) : null;
    const newExpiry = calculateExtendedExpiry(currentExpiry, duration);
    const newExpiryStr = newExpiry ? newExpiry.toISOString() : null;

    // BUG-LIC-006: Atomic update of license + tenant
    const transactItems: any[] = [
        {
            Update: {
                TableName: TABLE_NAME,
                Key: { PK: Keys.licensePK(licenseKey), SK: Keys.licenseMetaSK() },
                UpdateExpression: 'SET expiryDate = :exp, updatedAt = :now',
                ExpressionAttributeValues: { ':exp': newExpiryStr, ':now': now },
            },
        },
    ];

    if (license.tenantId) {
        transactItems.push({
            Update: {
                TableName: TABLE_NAME,
                Key: { PK: Keys.tenantPK(license.tenantId), SK: Keys.tenantProfileSK() },
                UpdateExpression: 'SET licenseExpiresAt = :exp, updatedAt = :now',
                ExpressionAttributeValues: { ':exp': newExpiryStr, ':now': now },
                ConditionExpression: 'attribute_exists(PK)',
            },
        });
    }

    await transactWrite(transactItems);

    // BUG-LIC-008: Invalidate cache
    invalidateLicenseCache(licenseKey);

    // BUG-LIC-005: Audit with old?new values
    await putItem({
        PK: Keys.licensePK(licenseKey),
        SK: Keys.licenseActivationSK(now),
        entityType: 'LICENSE_EXTENSION',
        tenantId: license.tenantId,
        licenseKey,
        action: 'renew',
        oldExpiry,
        newExpiry: newExpiryStr,
        duration,
        planTier: license.plan,
        activatedBy: adminId,
        createdAt: now,
    });

    logger.info('License extended', { licenseKey, oldExpiry, newExpiry: newExpiryStr, duration, adminId });
}

// -- Public License Validation (Pre-Auth) ------------------------------------

export interface LicenseValidationResult {
    valid: boolean;
    businessType: string;
    plan: string;
    features: string[];
    expiresAt: string | null;
    maxDevices: number;
    maxUsers: number;
    tenantId: string;
}

/**
 * Validate a license key WITHOUT requiring authentication.
 * Used by the Flutter app on first launch (pre-login).
 * Uses in-memory Lambda cache with 5-min TTL.
 */
export async function validateLicenseKey(licenseKey: string): Promise<LicenseValidationResult> {
    // Check in-memory cache first
    const cached = LICENSE_CACHE.get(licenseKey);
    if (cached && cached.expiresAt > Date.now()) {
        return cached.data;
    }

    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );

    if (!license) {
        await emitMetric('InvalidLicenseValidationAttempt', 1);
        throw new AppError('Invalid license key', 404, 'KEY_NOT_FOUND');
    }

    const status = (license.status || '').toUpperCase();

    if (status === 'REVOKED') throw new AppError('License revoked', 403, 'KEY_REVOKED');
    if (status === 'SUSPENDED') throw new AppError('License suspended', 403, 'KEY_SUSPENDED');
    // BUG-LIC-020: Use 402 (Payment Required) not 410 (Gone)
    if (license.expiryDate && new Date(license.expiryDate).getTime() < Date.now()) {
        throw new AppError('License expired', 402, 'LICENSE_EXPIRED');
    }
    if (status === 'INACTIVE' || status === 'DEACTIVATED') {
        throw new AppError('License not activated', 403, 'KEY_INACTIVE');
    }

    // Parse features
    let features: string[] = [];
    if (license.features) {
        if (Array.isArray(license.features)) {
            features = license.features;
        } else if (typeof license.features === 'string') {
            try {
                const parsed = JSON.parse(license.features);
                features = Array.isArray(parsed) ? parsed : [];
            } catch { features = []; }
        }
    } else {
        features = getDefaultFeaturesForPlan(license.plan);
    }

    const result: LicenseValidationResult = {
        valid: true,
        businessType: license.businessType || 'general',
        plan: license.plan || 'basic',
        features,
        expiresAt: license.expiryDate ? new Date(license.expiryDate).toISOString() : null,
        maxDevices: license.maxDevices || 5,
        maxUsers: license.maxUsers || 10,
        tenantId: license.tenantId,
    };

    // Populate cache
    LICENSE_CACHE.set(licenseKey, {
        data: result,
        expiresAt: Date.now() + LICENSE_CACHE_TTL_MS,
    });

    return result;
}

/**
 * Return default feature list based on plan tier.
 *
 * Authoritative source: plan-feature-registry.ts PLAN_CORE_FEATURES.
 * This keeps one source of truth � no divergence between what the generator
 * stamps into a new license and what the plan-guard later enforces.
 * BusinessType-specific features are deliberately NOT included here; the
 * manifest service layers them on at serve time based on the license's
 * allowedBusinessTypes (a license can cover multiple).
 */
export function getDefaultFeaturesForPlan(plan: string): string[] {
    // Lazy-require avoids a circular dependency at module init time.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { PLAN_CORE_FEATURES, mapToPlanTier } = require('../config/plan-feature-registry');
    const tier = mapToPlanTier(plan);
    return [...(PLAN_CORE_FEATURES[tier] || [])];
}

// -- New Endpoints (BUG-LIC-009, 010, 018, 030) -----------------------------

/** BUG-LIC-010: Update owner details on a license */
export async function updateOwnerDetails(
    licenseKey: string,
    details: { ownerName?: string; ownerEmail?: string; ownerPhone?: string; businessName?: string },
    adminId: string,
): Promise<void> {
    const now = new Date().toISOString();
    const license = await getItem<Record<string, any>>(Keys.licensePK(licenseKey), Keys.licenseMetaSK());
    if (!license) throw new NotFoundError('License key not found');

    const updates: string[] = ['updatedAt = :now'];
    const values: Record<string, any> = { ':now': now };
    const oldValues: Record<string, any> = {};

    if (details.ownerName !== undefined) { updates.push('ownerName = :on'); values[':on'] = details.ownerName; oldValues.ownerName = license.ownerName; }
    if (details.ownerEmail !== undefined) { updates.push('ownerEmail = :oe'); values[':oe'] = details.ownerEmail; oldValues.ownerEmail = license.ownerEmail; }
    if (details.ownerPhone !== undefined) { updates.push('ownerPhone = :op'); values[':op'] = details.ownerPhone; oldValues.ownerPhone = license.ownerPhone; }
    if (details.businessName !== undefined) { updates.push('businessName = :bn'); values[':bn'] = details.businessName; oldValues.businessName = license.businessName; }

    await updateItem(Keys.licensePK(licenseKey), Keys.licenseMetaSK(), {
        updateExpression: `SET ${updates.join(', ')}`,
        expressionAttributeValues: values,
    });

    // Also update tenant name if businessName changed
    if (details.businessName && license.tenantId) {
        try {
            await updateItem(Keys.tenantPK(license.tenantId), Keys.tenantProfileSK(), {
                updateExpression: 'SET #n = :name, updatedAt = :now',
                expressionAttributeNames: { '#n': 'name' },
                expressionAttributeValues: { ':name': details.businessName, ':now': now },
            });
        } catch { /* tenant may not exist */ }
    }

    await putItem({
        PK: Keys.licensePK(licenseKey), SK: Keys.licenseActivationSK(now),
        entityType: 'LICENSE_OWNER_UPDATE', tenantId: license.tenantId, licenseKey,
        action: 'update_owner', oldValues, newValues: details,
        activatedBy: adminId, createdAt: now,
    });

    logger.info('Owner details updated', { licenseKey, adminId });
}

/** BUG-LIC-009: Update business type on a license */
export async function updateBusinessType(licenseKey: string, businessType: string, adminId: string): Promise<void> {
    const now = new Date().toISOString();
    const license = await getItem<Record<string, any>>(Keys.licensePK(licenseKey), Keys.licenseMetaSK());
    if (!license) throw new NotFoundError('License key not found');

    const oldBusinessType = license.businessType || 'unknown';

    // Atomic update of license + tenant
    const transactItems: any[] = [
        {
            Update: {
                TableName: TABLE_NAME,
                Key: { PK: Keys.licensePK(licenseKey), SK: Keys.licenseMetaSK() },
                UpdateExpression: 'SET businessType = :bt, updatedAt = :now',
                ExpressionAttributeValues: { ':bt': businessType, ':now': now },
            },
        },
    ];
    if (license.tenantId) {
        transactItems.push({
            Update: {
                TableName: TABLE_NAME,
                Key: { PK: Keys.tenantPK(license.tenantId), SK: Keys.tenantProfileSK() },
                UpdateExpression: 'SET businessType = :bt, updatedAt = :now',
                ExpressionAttributeValues: { ':bt': businessType, ':now': now },
                ConditionExpression: 'attribute_exists(PK)',
            },
        });
    }
    await transactWrite(transactItems);
    invalidateLicenseCache(licenseKey);

    await putItem({
        PK: Keys.licensePK(licenseKey), SK: Keys.licenseActivationSK(now),
        entityType: 'LICENSE_BUSINESS_TYPE_CHANGE', tenantId: license.tenantId, licenseKey,
        action: 'update_business_type', oldBusinessType, newBusinessType: businessType,
        activatedBy: adminId, createdAt: now,
    });

    logger.info('Business type updated', { licenseKey, oldBusinessType, newBusinessType: businessType, adminId });
}

// -- Device Allowance Configuration Validation (Req 5.8, 5.10) ---------------
// The device allowance is the number of machines a single license may activate.
// Per the offline-license-activation spec it defaults to one machine per license
// (Req 5.8) and a Super_Admin may only configure it to an integer in [1, 3];
// any other value is rejected and the previously configured allowance is kept
// (Req 5.10). The pure helpers below are the single source of truth for that
// rule so the handler, the service, and the property tests all agree.

/** Default device allowance: one machine per license (Req 5.8). */
export const DEFAULT_DEVICE_ALLOWANCE = 1;

/** Inclusive lower bound for a configurable device allowance (Req 5.10). */
export const MIN_DEVICE_ALLOWANCE = 1;

/** Inclusive upper bound for a configurable device allowance (Req 5.10). */
export const MAX_DEVICE_ALLOWANCE = 3;

/**
 * A device allowance is configurable only when it is an integer within the
 * inclusive range [1, 3] (Req 5.10). Everything else is invalid: a non-number,
 * a non-integer such as 2.5, NaN/Infinity, or an out-of-range value such as 0
 * or 4.
 */
export function isValidDeviceAllowance(value: unknown): value is number {
    return typeof value === 'number'
        && Number.isInteger(value)
        && value >= MIN_DEVICE_ALLOWANCE
        && value <= MAX_DEVICE_ALLOWANCE;
}

/**
 * Resolve the effective device allowance for a Super_Admin configuration update.
 *
 * Pure and deterministic (Property 8): the proposed value is accepted if and
 * only if it is an integer in [1, 3]; otherwise the previously configured
 * allowance is retained unchanged (Req 5.10). When no previous allowance is
 * supplied it falls back to the default of one machine per license (Req 5.8).
 *
 * @param proposed The allowance value the Super_Admin is attempting to set.
 * @param previous The currently configured allowance (defaults to 1).
 * @returns        The proposed value when valid, otherwise the previous value.
 */
export function resolveDeviceAllowance(
    proposed: unknown,
    previous: number = DEFAULT_DEVICE_ALLOWANCE,
): number {
    return isValidDeviceAllowance(proposed) ? proposed : previous;
}

/** BUG-LIC-018: Update max devices on a license */
export async function updateMaxDevices(licenseKey: string, maxDevices: number, adminId: string): Promise<void> {
    const now = new Date().toISOString();
    const license = await getItem<Record<string, any>>(Keys.licensePK(licenseKey), Keys.licenseMetaSK());
    if (!license) throw new NotFoundError('License key not found');

    const oldMaxDevices = license.maxDevices || DEFAULT_DEVICE_ALLOWANCE;

    // Req 5.10: Accept the allowance update only when it is an integer in [1, 3].
    // Any other value is rejected and the previously configured allowance is
    // retained — by throwing before the write, the stored value is left intact.
    if (!isValidDeviceAllowance(maxDevices)) {
        logger.warn('Rejected device allowance update; retaining previous allowance', {
            licenseKey, proposed: maxDevices, retained: oldMaxDevices, adminId,
        });
        throw new AppError(
            `Device allowance must be an integer between ${MIN_DEVICE_ALLOWANCE} and ${MAX_DEVICE_ALLOWANCE}. ` +
                `Retained the previously configured allowance of ${oldMaxDevices}.`,
            400,
            'INVALID_DEVICE_ALLOWANCE',
        );
    }

    await updateItem(Keys.licensePK(licenseKey), Keys.licenseMetaSK(), {
        updateExpression: 'SET maxDevices = :md, updatedAt = :now',
        expressionAttributeValues: { ':md': maxDevices, ':now': now },
    });
    invalidateLicenseCache(licenseKey);

    await putItem({
        PK: Keys.licensePK(licenseKey), SK: Keys.licenseActivationSK(now),
        entityType: 'LICENSE_DEVICE_UPDATE', tenantId: license.tenantId, licenseKey,
        action: 'update_max_devices', oldMaxDevices, newMaxDevices: maxDevices,
        activatedBy: adminId, createdAt: now,
    });

    logger.info('Max devices updated', { licenseKey, oldMaxDevices, newMaxDevices: maxDevices, adminId });
}

/** BUG-LIC-030: Update notes/remarks on a license */
export async function updateNotes(licenseKey: string, notes: string, adminId: string): Promise<void> {
    const now = new Date().toISOString();
    const license = await getItem<Record<string, any>>(Keys.licensePK(licenseKey), Keys.licenseMetaSK());
    if (!license) throw new NotFoundError('License key not found');

    await updateItem(Keys.licensePK(licenseKey), Keys.licenseMetaSK(), {
        updateExpression: 'SET notes = :notes, updatedAt = :now',
        expressionAttributeValues: { ':notes': notes, ':now': now },
    });

    await putItem({
        PK: Keys.licensePK(licenseKey), SK: Keys.licenseActivationSK(now),
        entityType: 'LICENSE_NOTES_UPDATE', tenantId: license.tenantId, licenseKey,
        action: 'update_notes', activatedBy: adminId, createdAt: now,
    });
}

// -- ENHANCED: Multi-Business License Support ---------------------------------

/**
 * Update allowed business types for a license key.
 * Updates both the license record and tenant license record.
 */
export async function updateAllowedBusinessTypes(
    licenseKey: string,
    allowedBusinessTypes: string[],
    adminId: string,
): Promise<void> {
    const now = new Date().toISOString();
    
    // Get the license record
    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );
    
    if (!license) {
        throw new NotFoundError('License key not found');
    }
    
    // Validate business types
    const { isValid, invalidTypes } = await import('../config/business-types.config').then(m => 
        m.validateBusinessTypes(allowedBusinessTypes)
    );
    
    if (!isValid) {
        throw new AppError(
            `Invalid business types: ${invalidTypes.join(', ')}`,
            400,
            'INVALID_BUSINESS_TYPES'
        );
    }
    
    logger.info('[LICENSE] Updating allowed business types', {
        licenseKey: licenseKey.substring(0, 9) + '...',
        tenantId: license.tenantId,
        oldTypes: license.allowedBusinessTypes || [],
        newTypes: allowedBusinessTypes,
        adminId,
    });
    
    // Update license record
    await updateItem(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
        {
            updateExpression: 'SET allowedBusinessTypes = :types, updatedAt = :updatedAt',
            expressionAttributeValues: {
                ':types': allowedBusinessTypes,
                ':updatedAt': now,
            },
        }
    );
    
    // Update tenant license record
    await updateItem(
        Keys.tenantPK(license.tenantId),
        Keys.tenantLicenseSK(),
        {
            updateExpression: 'SET allowedBusinessTypes = :types, updatedAt = :updatedAt',
            expressionAttributeValues: {
                ':types': allowedBusinessTypes,
                ':updatedAt': now,
            },
        }
    );
    
    // Create audit entry
    await putItem({
        PK: Keys.licensePK(licenseKey),
        SK: `AUDIT#${now}`,
        entityType: 'LICENSE_AUDIT',
        tenantId: license.tenantId,
        licenseKey,
        action: 'update_business_types',
        previousState: { allowedBusinessTypes: license.allowedBusinessTypes || [] },
        newState: { allowedBusinessTypes },
        actorId: adminId,
        createdAt: now,
    });
    
    // Clear license cache
    invalidateLicenseCache(licenseKey);
    
    logger.info('[LICENSE] Allowed business types updated successfully', {
        licenseKey: licenseKey.substring(0, 9) + '...',
        tenantId: license.tenantId,
        newTypes: allowedBusinessTypes,
    });
}

// -- ENHANCED: Manual Feature Override (Plan Feature System v2) -------------

/**
 * Update manual feature overrides for a license key.
 * Allows Super Admin to add or remove individual features regardless of plan.
 * Changes are persisted to the license record with audit logging.
 *
 * @param licenseKey    the license to modify
 * @param delta         { add?: string[], remove?: string[] }
 * @param adminId       who made the change
 * @param reason        optional reason for the override (e.g., "Trial access", "Special agreement")
 */
export async function updateLicenseFeatures(
    licenseKey: string,
    delta: { add?: string[]; remove?: string[] },
    adminId: string,
    reason?: string,
): Promise<{ added: string[]; removed: string[]; current: string[] }> {
    const now = new Date().toISOString();

    // Get the license record
    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );
    if (!license) {
        throw new NotFoundError('License key not found');
    }

    // Current overrides (default to empty if not present)
    const currentOverrides: { added: string[]; removed: string[] } = license.manualOverrides || {
        added: [],
        removed: [],
    };

    // Merge using sets to avoid duplicates
    const addedSet = new Set<string>(currentOverrides.added);
    const removedSet = new Set<string>(currentOverrides.removed);

    // Apply delta: adding a feature removes it from the removed list (and vice versa)
    for (const f of delta.add ?? []) {
        addedSet.add(f);
        removedSet.delete(f);
    }
    for (const f of delta.remove ?? []) {
        removedSet.add(f);
        addedSet.delete(f);
    }

    const newAdded = [...addedSet];
    const newRemoved = [...removedSet];

    // Update the license record
    await updateItem(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
        {
            updateExpression: 'SET manualOverrides = :mo, updatedAt = :now',
            expressionAttributeValues: {
                ':mo': { added: newAdded, removed: newRemoved },
                ':now': now,
            },
        },
    );

    // Also update the tenant license record to keep them in sync
    await updateItem(
        Keys.tenantPK(license.tenantId),
        Keys.tenantLicenseSK(),
        {
            updateExpression: 'SET manualOverrides = :mo, updatedAt = :now',
            expressionAttributeValues: {
                ':mo': { added: newAdded, removed: newRemoved },
                ':now': now,
            },
        },
    );

    // Append to license audit log (inline array; DDB item size limit ~400KB, auditLog is bounded)
    const auditEntry = {
        action: 'manual_feature_override',
        at: now,
        by: adminId,
        reason: reason || 'Manual feature override via admin API',
        delta: { add: delta.add ?? [], remove: delta.remove ?? [] },
        result: { added: newAdded, removed: newRemoved },
    };

    await updateItem(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
        {
            updateExpression: 'SET auditLog = list_append(if_not_exists(auditLog, :empty), :entry)',
            expressionAttributeValues: {
                ':empty': [],
                ':entry': [auditEntry],
            },
        },
    );

    // Create detailed audit record (separate row for long-term history)
    await putItem({
        PK: Keys.licensePK(licenseKey),
        SK: `AUDIT#${now}#FEAT`,
        entityType: 'LICENSE_FEATURE_OVERRIDE',
        tenantId: license.tenantId,
        licenseKey,
        action: 'manual_feature_override',
        previousState: { manualOverrides: currentOverrides },
        newState: { manualOverrides: { added: newAdded, removed: newRemoved } },
        actorId: adminId,
        reason: reason || null,
        createdAt: now,
        TTL: Math.floor(Date.now() / 1000) + (2 * 365 * 24 * 60 * 60), // 2 year TTL
    });

    // Invalidate caches
    invalidateLicenseCache(licenseKey);
    const { invalidateManifest } = await import('../config/manifest-cache');
    await invalidateManifest(license.tenantId);

    // ENHANCED: Push WebSocket notification to desktop clients
    const { broadcastManifestInvalidated } = await import('./websocket.service');
    await broadcastManifestInvalidated(
        license.tenantId,
        `Manual feature override: +${(delta.add ?? []).length} / -${(delta.remove ?? []).length}`,
        adminId,
    ).catch((err: Error) => logger.warn('WebSocket broadcast failed (non-critical)', { error: err.message }));

    // ENHANCED: Write audit log
    const { auditLicenseOverride } = await import('./audit-log.service');
    await auditLicenseOverride(
        adminId,
        licenseKey,
        license.tenantId,
        delta.add ?? [],
        delta.remove ?? [],
        reason,
    ).catch((err: Error) => logger.warn('Audit log failed (non-critical)', { error: err.message }));

    logger.info('[LICENSE] Manual feature overrides updated', {
        licenseKey: licenseKey.substring(0, 9) + '...',
        tenantId: license.tenantId,
        addedCount: (delta.add ?? []).length,
        removedCount: (delta.remove ?? []).length,
        by: adminId,
    });

    return {
        added: newAdded,
        removed: newRemoved,
        current: [...newAdded], // backward compat alias
    };
}

/** BUG-LIC-004: Check for duplicate license by email or phone */
async function checkDuplicateLicense(field: 'email' | 'phone', value: string): Promise<string | null> {
    try {
        // Query all licenses and filter client-side (no GSI on email/phone yet)
        const result = await queryItems<Record<string, any>>(
            Keys.licenseEntityGSI1PK(), undefined,
            { indexName: 'GSI1', scanIndexForward: false },
        );
        const match = result.items.find(item => {
            if (field === 'email') return item.ownerEmail === value;
            return item.ownerPhone === value;
        });
        if (match && (match.status === 'ACTIVE' || match.status === 'ACTIVATED')) {
            return match.licenseKey;
        }
    } catch {
        // Non-critical � don't block generation
    }
    return null;
}

// -- Helpers -----------------------------------------------------------------

/**
 * BUG-LIC-015: Get audit history for a license key.
 * Queries all audit records (SK begins_with AUDIT#) sorted by timestamp descending.
 */
export async function getLicenseHistory(licenseKey: string): Promise<any[]> {
    try {
        const result = await queryItems<Record<string, any>>(
            Keys.licensePK(licenseKey),
            'AUDIT#',
        );
        const items = result.items ?? result as any;

        // Sort newest first
        items.sort((a: any, b: any) => {
            const aTime = a.createdAt || a.SK || '';
            const bTime = b.createdAt || b.SK || '';
            return bTime.localeCompare(aTime);
        });

        return items.slice(0, 50).map((item: any) => ({
            action: item.entityType || item.action || 'unknown',
            performedBy: item.performedBy || item.adminId || 'system',
            timestamp: item.createdAt || item.SK?.replace('AUDIT#', ''),
            oldValues: item.old_value || item.oldValues || null,
            newValues: item.new_value || item.newValues || null,
            details: item.details || item.reason || null,
            ipAddress: item.ipAddress || null,
        }));
    } catch (err) {
        logger.warn('Failed to fetch license history', { licenseKey, error: (err as Error).message });
        return [];
    }
}

async function emitMetric(
    metricName: string,
    value: number,
    dimensions?: { Name: string; Value: string }[],
): Promise<void> {
    try {
        await cloudwatchClient.send(new PutMetricDataCommand({
            Namespace: 'DukanX/Licensing',
            MetricData: [{
                MetricName: metricName,
                Value: value,
                Unit: 'Count',
                Dimensions: dimensions,
            }],
        }));
    } catch (err) {
        logger.warn('Failed to emit license metric', { error: (err as Error).message });
    }
}

// ============================================================================
// Offline License Activation (Task 3.2 — additive, reuse-don't-rebuild)
// ============================================================================
// One-time, machine-bound activation for Offline_Lifetime_Mode. This endpoint
// does NOT reimplement validation, denylist, or activation logic: it composes
// the existing building blocks —
//   • validateLicenseKey()        — invalid / expired / revoked / suspended gate
//   • isKeyDenylisted()           — fail-closed denylist (Req 17.13)
//   • the device-allowance rules  — DEFAULT/MIN/MAX + isValidDeviceAllowance()
//   • signLicenseToken()          — RS256 365-day token over the UNCHANGED
//                                   LicenseKeyPayload, bound to fingerprintHash
// and persists the bound device on the existing LICENSE# record.
//
// On ANY rejection (invalid/expired/revoked/suspended/denylisted/allowance
// exhausted) it throws an AppError and issues NO token (Req 5.3, 5.9, 17.13).
// Cloud_Subscription_Mode is untouched: this is a new function only.
// ============================================================================

/**
 * The Machine_Fingerprint sent by the Activation_Service (Req 5.1). Only the
 * three bound components contribute to the Fingerprint_Hash (Req 5.2); osType
 * and hostname are carried for auditing/drift but never bind the token.
 */
export interface MachineFingerprint {
    cpuId: string;
    macAddress: string;
    hddSerial: string;
    osType?: string;
    hostname?: string;
}

/** Successful offline-activation result: the signed, machine-bound token. */
export interface OfflineActivationResult {
    success: true;
    licenseToken: string;
    fingerprintHash: string;
    tenantId: string;
    plan: string;
    maxDevices: number;
    activatedDeviceCount: number;
    /** Token TTL in seconds (365 days) — informational for the client. */
    ttlSeconds: number;
    expiresAt: string | null;
}

/**
 * Compute the Fingerprint_Hash exactly as the spec defines it (Req 5.2):
 * SHA256(cpuId + macAddress + hddSerial). osType and hostname are intentionally
 * excluded so a hostname/OS change does not rebind the license.
 */
export function computeFingerprintHash(fp: MachineFingerprint): string {
    return createHash('sha256')
        .update(`${fp.cpuId}${fp.macAddress}${fp.hddSerial}`)
        .digest('hex');
}

/**
 * Assemble the UNCHANGED LicenseKeyPayload from a stored license record plus the
 * already-validated public view. No LicenseKeyPayload field is added, removed,
 * renamed, or retyped (Req 2.2) — values are simply read from the record with
 * safe fallbacks that mirror the existing defaults used elsewhere in this file.
 */
function buildLicensePayload(
    license: Record<string, any>,
    validation: LicenseValidationResult,
    allowance: number,
): LicenseKeyPayload {
    const allowedBusinessTypes: string[] = Array.isArray(license.allowedBusinessTypes)
        && license.allowedBusinessTypes.length > 0
        ? license.allowedBusinessTypes
        : [license.businessType || validation.businessType || 'general'];

    return {
        tenantId: license.tenantId,
        plan: mapToPlanTier(license.plan || validation.plan || 'basic'),
        allowedBusinessTypes,
        maxUsers: license.maxUsers || validation.maxUsers || 10,
        maxDevices: allowance,
        features: validation.features,
        expiresAt: validation.expiresAt,
        issuedAt: license.issuedAt || license.createdAt || new Date().toISOString(),
        keyVersion: typeof license.keyVersion === 'number' ? license.keyVersion : 1,
        superAdminOverride: license.superAdminOverride === true,
    };
}

/**
 * Activate a license for a specific machine and return a signed License_Token.
 *
 * Flow (Req 5.3, 5.9, 17.13):
 *   1. Reuse validateLicenseKey() — rejects invalid/expired/revoked/suspended/
 *      inactive keys via the existing, unchanged logic.
 *   2. Reuse isKeyDenylisted() — fail-closed: a denylisted key, OR a denylist
 *      check that errors, denies activation before any token is issued.
 *   3. Enforce the device allowance against the existing activatedDevices list:
 *      re-activating an already-bound machine is idempotent; a brand-new machine
 *      is allowed only while the bound-device count is below the allowance.
 *   4. Sign and return the 365-day RS256 License_Token bound to fingerprintHash.
 *
 * Throws an AppError on every rejection path and issues NO token in that case.
 */
export async function activateOfflineLicense(
    licenseKey: string,
    fingerprint: MachineFingerprint,
    userId?: string,
    sourceIp?: string,
): Promise<OfflineActivationResult> {
    if (!fingerprint || !fingerprint.cpuId || !fingerprint.macAddress || !fingerprint.hddSerial) {
        throw new AppError(
            'A Machine_Fingerprint with cpuId, macAddress, and hddSerial is required.',
            400,
            'FINGERPRINT_REQUIRED',
        );
    }

    // 1. Reuse the existing validation gate (invalid/expired/revoked/suspended).
    //    Throws AppError with the precise rejection reason — no token issued.
    const validation = await validateLicenseKey(licenseKey);

    // 2. Fail-closed denylist enforcement (Req 17.13). isKeyDenylisted already
    //    returns true on internal error, so a check failure also denies.
    if (await isKeyDenylisted(licenseKey)) {
        await emitMetric('OfflineActivationDenylisted', 1);
        throw new AppError('License key is denylisted.', 403, 'KEY_DENYLISTED');
    }

    // Load the full record to read the bound-device list and the fields the
    // token payload needs. validateLicenseKey already proved it exists/valid.
    const license = await getItem<Record<string, any>>(
        Keys.licensePK(licenseKey),
        Keys.licenseMetaSK(),
    );
    if (!license) {
        // Defensive: should not happen after a successful validation.
        throw new NotFoundError('License key not found');
    }

    // 3. Device-allowance enforcement (Req 5.8, 5.9). The configured allowance is
    //    range-clamped by the same single-source-of-truth helper used by 3.3.
    const allowance = resolveDeviceAllowance(
        license.maxDevices,
        DEFAULT_DEVICE_ALLOWANCE,
    );
    const fingerprintHash = computeFingerprintHash(fingerprint);
    const boundDevices: string[] = Array.isArray(license.activatedDevices)
        ? license.activatedDevices.map((d: unknown) => String(d))
        : [];
    const alreadyBound = boundDevices.includes(fingerprintHash);

    if (!alreadyBound && boundDevices.length >= allowance) {
        await emitMetric('OfflineActivationAllowanceExhausted', 1);
        throw new AppError(
            `Device allowance exhausted: this license permits ${allowance} machine(s).`,
            403,
            'DEVICE_ALLOWANCE_EXHAUSTED',
        );
    }

    // Bind the new machine atomically. The condition guards against a race that
    // would otherwise exceed the allowance; on conflict we reject the same way.
    if (!alreadyBound) {
        const now = new Date().toISOString();
        try {
            await updateItem(
                Keys.licensePK(licenseKey),
                Keys.licenseMetaSK(),
                {
                    updateExpression:
                        'SET activatedDevices = list_append(if_not_exists(activatedDevices, :empty), :dev), updatedAt = :now',
                    expressionAttributeValues: {
                        ':empty': [],
                        ':dev': [fingerprintHash],
                        ':now': now,
                        ':allowance': allowance,
                    },
                    // size() of the existing list must still be below the allowance.
                    conditionExpression:
                        'attribute_not_exists(activatedDevices) OR size(activatedDevices) < :allowance',
                },
            );
        } catch (err: any) {
            if (err?.name === 'ConditionalCheckFailedException') {
                await emitMetric('OfflineActivationAllowanceExhausted', 1);
                throw new AppError(
                    `Device allowance exhausted: this license permits ${allowance} machine(s).`,
                    403,
                    'DEVICE_ALLOWANCE_EXHAUSTED',
                );
            }
            throw err;
        }

        // Best-effort activation audit (mirrors activateLicense()).
        try {
            await putItem({
                PK: Keys.licensePK(licenseKey),
                SK: Keys.licenseActivationSK(now),
                entityType: 'LICENSE_OFFLINE_ACTIVATION',
                tenantId: license.tenantId,
                licenseKey,
                action: 'offline_activate',
                fingerprintHash,
                osType: fingerprint.osType || null,
                hostname: fingerprint.hostname || null,
                ipAddress: sourceIp || null,
                activatedBy: userId || 'system',
                createdAt: now,
            });
        } catch (auditErr) {
            logger.warn('Failed to record offline activation audit', {
                error: (auditErr as Error).message,
            });
        }
        invalidateLicenseCache(licenseKey);
    }

    // 4. Sign the machine-bound 365-day License_Token over the UNCHANGED payload.
    const payload = buildLicensePayload(license, validation, allowance);
    const licenseToken = signLicenseToken(payload, fingerprintHash);

    const activatedDeviceCount = alreadyBound
        ? boundDevices.length
        : boundDevices.length + 1;

    logger.info('Offline license activated', {
        tenantId: license.tenantId,
        plan: payload.plan,
        licenseKey: `${licenseKey.substring(0, 8)}...`,
        activatedDeviceCount,
        allowance,
        reactivation: alreadyBound,
    });
    await emitMetric('OfflineActivation', 1, [{ Name: 'PlanTier', Value: String(payload.plan) }]);

    return {
        success: true,
        licenseToken,
        fingerprintHash,
        tenantId: license.tenantId,
        plan: String(payload.plan),
        maxDevices: allowance,
        activatedDeviceCount,
        ttlSeconds: LICENSE_TOKEN_TTL_SECONDS,
        expiresAt: validation.expiresAt,
    };
}
