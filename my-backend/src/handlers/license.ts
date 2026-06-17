// ============================================================================
// License Handlers — Key Activation & Status
// ============================================================================
// POST /license/validate    — Validate key (PUBLIC, rate-limited)
// POST /license/activate    — Activate a license key (OWNER/ADMIN)
// POST /license/activate-offline — Machine-bound offline activation (OWNER/ADMIN)
// GET  /license/status      — Get license status (authenticated)
// POST /license/generate    — Generate a new key (SuperAdmin only)
// POST /license/manage      — Change license status (SuperAdmin only)
// GET  /license/list        — List all licenses (SuperAdmin only)
// GET  /license/:key        — License details (SuperAdmin only)
// POST /license/upgrade     — Upgrade plan (SuperAdmin only)
// POST /license/transfer    — Transfer license (SuperAdmin only)
// POST /license/extend      — Extend duration (SuperAdmin only)
// POST /license/convert     — Convert plan type (SuperAdmin only)
// PATCH /license/:key/owner — Update owner details (SuperAdmin only)
// PATCH /license/:key/business-type — Change business type (SuperAdmin only)
// PATCH /license/:key/devices — Update max devices (SuperAdmin only)
// PATCH /license/:key/notes — Update notes (SuperAdmin only)
// GET  /license/:key/history — Audit history timeline (SuperAdmin only)
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, AuthContext } from '../types/tenant.types';
import { requireSuperAdmin } from '../middleware/super-admin-guard';
import * as licenseService from '../services/license.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';

// ── Rate Limiting (DynamoDB-backed, survives Lambda cold starts) ─────────────
// CRIT-001 FIX: Replaced in-memory Map (useless on Lambda — resets every cold
// start) with DynamoDB atomic counter. TTL auto-cleans expired entries.
import { updateItem as ddbUpdateItem, TABLE_NAME } from '../config/dynamodb.config';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { config } from '../config/environment';

const RATE_LIMIT_WINDOW_SEC = 60; // 1 minute window
const RATE_LIMIT_MAX_ATTEMPTS = 10; // Max 10 attempts per IP per minute

const _rlClient = DynamoDBDocumentClient.from(
    new DynamoDBClient(configureAwsClient({ region: config.aws.region })),
    { marshallOptions: { removeUndefinedValues: true } },
);

/**
 * DynamoDB-backed rate limiter. Uses atomic ADD to increment counter.
 * Item key: PK=RATELIMIT#<ip>, SK=WINDOW.
 * TTL field auto-deletes expired windows.
 * Returns true if allowed, false if blocked.
 */
async function checkRateLimit(ip: string): Promise<boolean> {
    const now = Math.floor(Date.now() / 1000);
    const windowKey = `RATELIMIT#${ip}`;
    const ttl = now + RATE_LIMIT_WINDOW_SEC + 10; // TTL = window + 10s buffer

    try {
        const result = await _rlClient.send(new UpdateCommand({
            TableName: TABLE_NAME,
            Key: { PK: windowKey, SK: 'WINDOW' },
            UpdateExpression: 'SET hitCount = if_not_exists(hitCount, :zero) + :inc, #ttl = if_not_exists(#ttl, :ttl), windowStart = if_not_exists(windowStart, :now)',
            ExpressionAttributeValues: {
                ':zero': 0,
                ':inc': 1,
                ':ttl': ttl,
                ':now': now,
                ':maxAge': now - RATE_LIMIT_WINDOW_SEC,
            },
            ExpressionAttributeNames: { '#ttl': 'TTL' },
            // If window expired, this condition fails — we catch and reset
            ConditionExpression: 'attribute_not_exists(windowStart) OR windowStart >= :maxAge',
            ReturnValues: 'ALL_NEW',
        }));

        const count = (result.Attributes?.hitCount as number) || 0;
        return count <= RATE_LIMIT_MAX_ATTEMPTS;
    } catch (err: any) {
        if (err.name === 'ConditionalCheckFailedException') {
            // Window expired — reset counter
            try {
                await _rlClient.send(new UpdateCommand({
                    TableName: TABLE_NAME,
                    Key: { PK: windowKey, SK: 'WINDOW' },
                    UpdateExpression: 'SET hitCount = :one, #ttl = :ttl, windowStart = :now',
                    ExpressionAttributeValues: { ':one': 1, ':ttl': now + RATE_LIMIT_WINDOW_SEC + 10, ':now': now },
                    ExpressionAttributeNames: { '#ttl': 'TTL' },
                }));
            } catch { /* best-effort reset */ }
            return true; // First request in new window
        }
        // On DynamoDB error, fail-OPEN (allow request) to avoid blocking legit users
        logger.warn('Rate limit check failed, allowing request', { ip, error: err.message });
        return true;
    }
}

// ── POST /license/validate ──────────────────────────────────────────────────
// PUBLIC endpoint: No JWT required. Rate-limited per IP.

export async function validate(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    try {
        // CRIT-001: DynamoDB-backed rate limit (replaces useless in-memory Map)
        const sourceIp = event.requestContext?.http?.sourceIp || 'unknown';
        const allowed = await checkRateLimit(sourceIp);
        if (!allowed) {
            logger.warn('License validation rate limited', { sourceIp });
            return response.error(429, 'RATE_LIMITED', 'Too many validation attempts. Try again later.');
        }

        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const body = JSON.parse(event.body);

        if (!body.licenseKey || typeof body.licenseKey !== 'string') {
            return response.error(400, 'MISSING_LICENSE_KEY', 'licenseKey is required');
        }

        const licenseKey = body.licenseKey.trim().toUpperCase();

        logger.info('License validation request', {
            keyPrefix: licenseKey.substring(0, 8),
            sourceIp,
        });

        const result = await licenseService.validateLicenseKey(licenseKey);

        return response.success(result, 200);
    } catch (err: unknown) {
        if (err instanceof AppError) {
            logger.warn('License validation failed', {
                code: err.code,
                message: err.message,
                sourceIp: event.requestContext?.http?.sourceIp,
            });
            // BUG-LIC-020: Use 402 for expired instead of 410
            const statusCode = err.code === 'KEY_EXPIRED' ? 402 : err.statusCode;
            return response.error(statusCode, err.code || 'VALIDATION_FAILED', err.message);
        }
        logger.error('License validation error', { error: (err as Error).message });
        return response.error(500, 'INTERNAL_ERROR', 'License validation failed');
    }
}

// ── POST /license/activate ──────────────────────────────────────────────────
// Requires auth but any OWNER/ADMIN can activate.

export const activate = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const body = JSON.parse(event.body);

        if (!body.licenseKey || typeof body.licenseKey !== 'string') {
            return response.error(400, 'MISSING_LICENSE_KEY', 'licenseKey is required');
        }

        const result = await licenseService.activateLicense(
            body.licenseKey.trim().toUpperCase(),
            body.deviceId || auth.deviceId,
            body.deviceInfo,
            event.requestContext?.http?.sourceIp,
            auth.sub,
        );

        return response.success(result, 200);
    },
);

// ── POST /license/activate-offline ──────────────────────────────────────────
// Machine-bound offline activation (Task 3.2 / Req 5.3, 5.9, 17.13).
// Requires auth (any OWNER/ADMIN); reuses validateLicenseKey + fail-closed
// isKeyDenylisted, enforces the device allowance, and returns a signed,
// machine-bound 365-day License_Token on success. On any rejection it returns
// the matching failure status WITHOUT issuing a token.

export const activateOffline = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const body = JSON.parse(event.body);

        if (!body.licenseKey || typeof body.licenseKey !== 'string') {
            return response.error(400, 'MISSING_LICENSE_KEY', 'licenseKey is required');
        }

        const fp = body.fingerprint || body.machineFingerprint;
        if (!fp || typeof fp !== 'object'
            || typeof fp.cpuId !== 'string'
            || typeof fp.macAddress !== 'string'
            || typeof fp.hddSerial !== 'string') {
            return response.error(
                400,
                'MISSING_FINGERPRINT',
                'fingerprint with cpuId, macAddress, and hddSerial is required',
            );
        }

        const result = await licenseService.activateOfflineLicense(
            body.licenseKey.trim().toUpperCase(),
            {
                cpuId: fp.cpuId,
                macAddress: fp.macAddress,
                hddSerial: fp.hddSerial,
                osType: typeof fp.osType === 'string' ? fp.osType : undefined,
                hostname: typeof fp.hostname === 'string' ? fp.hostname : undefined,
            },
            auth.sub,
            event.requestContext?.http?.sourceIp,
        );

        return response.success(result, 200);
    },
);

// ── GET /license/status ─────────────────────────────────────────────────────

export const status = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT, UserRole.CASHIER, UserRole.STAFF],
    async (_event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        const result = await licenseService.getLicenseStatus(auth.tenantId);
        return response.success(result, 200);
    },
);

// ── POST /license/generate (SuperAdmin Only) ────────────────────────────────
// BUG-LIC-001: Now requires SUPER_ADMIN role
// BUG-LIC-003: Now accepts owner info fields

export const generate = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        // BUG-LIC-001: Enforce Super Admin
        requireSuperAdmin(auth, event);

        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const body = JSON.parse(event.body);

        if (!body.plan) {
            return response.error(400, 'MISSING_FIELDS', 'plan is required');
        }

        // Accept every PlanTier the registry knows about. Pro must not be rejected.
        const validPlans = ['basic', 'pro', 'premium', 'enterprise'];
        if (!validPlans.includes(body.plan.toLowerCase())) {
            return response.error(400, 'INVALID_PLAN', `plan must be one of: ${validPlans.join(', ')}`);
        }

        const duration = body.duration || '12 months';
        const businessType = body.businessType || 'general';
        const features = Array.isArray(body.features) 
            ? body.features 
            : licenseService.getDefaultFeaturesForPlan(body.plan.toLowerCase());

        // ENHANCED: Multi-business license support
        const allowedBusinessTypes = Array.isArray(body.allowedBusinessTypes)
            ? body.allowedBusinessTypes
            : undefined;

        // BUG-LIC-003: Owner info fields
        const ownerInfo = {
            ownerName: body.ownerName || body.clientName || null,
            ownerEmail: body.ownerEmail || body.clientEmail || null,
            ownerPhone: body.ownerPhone || body.clientPhone || null,
            businessName: body.businessName || body.clientBusinessName || null,
            notes: body.notes || null,
            maxDevices: body.maxDevices || 1,
        };

        // ENHANCED: Plan feature system v2 fields
        const manualOverrides = body.manualOverrides && (body.manualOverrides.added || body.manualOverrides.removed)
            ? { added: body.manualOverrides.added ?? [], removed: body.manualOverrides.removed ?? [] }
            : undefined;
        const storageLimitGB = typeof body.storageLimitGB === 'number' ? body.storageLimitGB : undefined;
        const apiRateLimit = typeof body.apiRateLimit === 'number' ? body.apiRateLimit : undefined;
        const renewalPeriodDays = typeof body.renewalPeriodDays === 'number' ? body.renewalPeriodDays : undefined;

        logger.info('License generation request received', {
            plan: body.plan, duration, businessType,
            ownerName: ownerInfo.ownerName,
            adminId: auth.sub,
        });

        const result = await licenseService.generateStandaloneLicenseKey(
            body.plan.toLowerCase(),
            duration,
            businessType,
            features,
            auth.sub,
            ownerInfo,
            allowedBusinessTypes,
            manualOverrides,
            storageLimitGB,
            apiRateLimit,
            renewalPeriodDays,
        );

        logger.info('License key generated successfully', {
            licenseKey: `${result.license_key.substring(0, 9)}...`,
            tenantId: result.tenant_id,
            plan: result.plan,
            businessType: result.business_type,
            expiryDate: result.expiry_date,
        });

        return response.success(result, 201);
    },
);

// ── POST /license/manage (SuperAdmin Only) ──────────────────────────────────
// BUG-LIC-019: Added 'reactivate' action

export const manage = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);

        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const body = JSON.parse(event.body);

        if (!body.tenantId || !body.action) {
            return response.error(400, 'MISSING_FIELDS', 'tenantId and action are required');
        }

        // BUG-LIC-019: Added reactivate
        const validActions = ['deactivate', 'suspend', 'revoke', 'reactivate'];
        if (!validActions.includes(body.action)) {
            return response.error(400, 'INVALID_ACTION', `action must be one of: ${validActions.join(', ')}`);
        }

        if (!body.reason && body.action !== 'reactivate') {
            return response.error(400, 'MISSING_REASON', 'reason is required for destructive actions');
        }

        await licenseService.changeLicenseStatus(
            body.tenantId,
            body.action,
            auth.sub,
            body.reason,
        );

        return response.success({ success: true, message: `License ${body.action}d` }, 200);
    },
);

// ── GET /license/list (SuperAdmin Only) ─────────────────────────────────────

export const list = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        const result = await licenseService.listLicenses();
        return response.success(result, 200);
    },
);

// ── GET /license/:key (SuperAdmin Only) ─────────────────────────────────────

export const getDetails = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        const key = event.pathParameters?.key;
        if (!key) {
            return response.error(400, 'MISSING_KEY', 'License key is required');
        }
        const result = await licenseService.getLicenseDetails(key);
        return response.success(result, 200);
    },
);

// ── POST /license/upgrade (SuperAdmin Only) ─────────────────────────────────

export const upgrade = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const body = JSON.parse(event.body);

        if (!body.licenseKey || !body.plan) {
            return response.error(400, 'MISSING_FIELDS', 'licenseKey and plan are required');
        }

        // BUG-LIC-018: Pass maxDevices if provided
        await licenseService.upgradeLicense(body.licenseKey, body.plan, auth.sub, body.maxDevices);
        return response.success({ success: true, message: 'License upgraded' }, 200);
    },
);

// ── POST /license/transfer (SuperAdmin Only) ────────────────────────────────

export const transfer = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const body = JSON.parse(event.body);

        if (!body.licenseKey || !body.newTenantId) {
            return response.error(400, 'MISSING_FIELDS', 'licenseKey and newTenantId are required');
        }

        await licenseService.transferLicense(body.licenseKey, body.newTenantId, auth.sub);
        return response.success({ success: true, message: 'License transferred' }, 200);
    },
);

// ── POST /license/extend (SuperAdmin Only) ──────────────────────────────────

export const extend = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const body = JSON.parse(event.body);

        if (!body.licenseKey || !body.duration) {
            return response.error(400, 'MISSING_FIELDS', 'licenseKey and duration are required');
        }

        await licenseService.extendLicense(body.licenseKey, body.duration, auth.sub);
        return response.success({ success: true, message: 'License extended' }, 200);
    },
);

// ── POST /license/convert (SuperAdmin Only) ─────────────────────────────────

export const convert = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const body = JSON.parse(event.body);

        if (!body.licenseKey || !body.plan) {
            return response.error(400, 'MISSING_FIELDS', 'licenseKey and plan are required');
        }

        await licenseService.convertLicense(body.licenseKey, body.plan, auth.sub);
        return response.success({ success: true, message: 'License converted' }, 200);
    },
);

// ── PATCH /license/:key/owner (SuperAdmin Only) ─────────────────────────────
// BUG-LIC-010: New endpoint for updating owner details

export const updateOwner = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const key = event.pathParameters?.key;
        if (!key) return response.error(400, 'MISSING_KEY', 'License key is required');

        const body = JSON.parse(event.body);
        await licenseService.updateOwnerDetails(key, {
            ownerName: body.ownerName,
            ownerEmail: body.ownerEmail,
            ownerPhone: body.ownerPhone,
            businessName: body.businessName,
        }, auth.sub);

        return response.success({ success: true, message: 'Owner details updated' }, 200);
    },
);

// ── PATCH /license/:key/business-type (SuperAdmin Only) ─────────────────────
// BUG-LIC-009: New endpoint for changing business type

export const updateBusinessType = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const key = event.pathParameters?.key;
        if (!key) return response.error(400, 'MISSING_KEY', 'License key is required');

        const body = JSON.parse(event.body);
        if (!body.businessType) {
            return response.error(400, 'MISSING_FIELDS', 'businessType is required');
        }

        await licenseService.updateBusinessType(key, body.businessType, auth.sub);
        return response.success({ success: true, message: 'Business type updated' }, 200);
    },
);

// ── PATCH /license/:key/devices (SuperAdmin Only) ───────────────────────────
// BUG-LIC-018: New endpoint for updating max devices

export const updateDevices = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const key = event.pathParameters?.key;
        if (!key) return response.error(400, 'MISSING_KEY', 'License key is required');

        const body = JSON.parse(event.body);
        // Req 5.10: accept only an integer device allowance in [1, 3]; any other
        // value is rejected so the previously configured allowance is retained.
        if (!licenseService.isValidDeviceAllowance(body.maxDevices)) {
            return response.error(
                400,
                'INVALID_DEVICE_ALLOWANCE',
                `maxDevices must be an integer between ${licenseService.MIN_DEVICE_ALLOWANCE} and ${licenseService.MAX_DEVICE_ALLOWANCE}`,
            );
        }

        await licenseService.updateMaxDevices(key, body.maxDevices, auth.sub);
        return response.success({ success: true, message: `Max devices updated to ${body.maxDevices}` }, 200);
    },
);

// ── PATCH /license/:key/notes (SuperAdmin Only) ─────────────────────────────

export const updateNotes = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const key = event.pathParameters?.key;
        if (!key) return response.error(400, 'MISSING_KEY', 'License key is required');

        const body = JSON.parse(event.body);
        await licenseService.updateNotes(key, body.notes || '', auth.sub);
        return response.success({ success: true, message: 'Notes updated' }, 200);
    },
);

// ── PATCH /license/:key/business-types (SuperAdmin Only) ─────────────────────
// ENHANCED: New endpoint for updating allowed business types (multi-business support)

export const updateBusinessTypes = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        if (!event.body) return response.error(400, 'MISSING_BODY', 'Request body is required');
        const key = event.pathParameters?.key;
        if (!key) return response.error(400, 'MISSING_KEY', 'License key is required');

        const body = JSON.parse(event.body);
        if (!body.allowedBusinessTypes || !Array.isArray(body.allowedBusinessTypes)) {
            return response.error(400, 'MISSING_BUSINESS_TYPES', 'allowedBusinessTypes array is required');
        }

        if (body.allowedBusinessTypes.length === 0) {
            return response.error(400, 'INVALID_BUSINESS_TYPES', 'allowedBusinessTypes cannot be empty');
        }

        await licenseService.updateAllowedBusinessTypes(key, body.allowedBusinessTypes, auth.sub);
        return response.success({ 
            success: true, 
            message: `Business types updated to: ${body.allowedBusinessTypes.join(', ')}` 
        }, 200);
    },
);

// ── GET /license/:key/history (SuperAdmin Only) ─────────────────────────────

// ── POST /admin/license/:key/features (SuperAdmin Only) ───────────────────
// ENHANCED: Manual feature override endpoint for plan feature system v2

export const updateFeatures = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);

        if (!event.body) {
            return response.error(400, 'MISSING_BODY', 'Request body is required');
        }

        const key = event.pathParameters?.key;
        if (!key) {
            return response.error(400, 'MISSING_KEY', 'License key path parameter is required');
        }

        const body = JSON.parse(event.body);

        // Validate delta structure
        const delta: { add?: string[]; remove?: string[] } = {};
        if (body.add && !Array.isArray(body.add)) {
            return response.error(400, 'INVALID_FIELD', 'add must be an array of feature keys');
        }
        if (body.remove && !Array.isArray(body.remove)) {
            return response.error(400, 'INVALID_FIELD', 'remove must be an array of feature keys');
        }
        if (body.add) delta.add = body.add;
        if (body.remove) delta.remove = body.remove;

        if (!delta.add?.length && !delta.remove?.length) {
            return response.error(400, 'MISSING_FIELDS', 'At least one of add[] or remove[] is required');
        }

        const reason = body.reason || undefined;

        const result = await licenseService.updateLicenseFeatures(key, delta, auth.sub, reason);

        return response.success({
            success: true,
            licenseKey: key,
            manualOverrides: {
                added: result.added,
                removed: result.removed,
            },
            message: `Feature overrides applied: +${(delta.add ?? []).length} / -${(delta.remove ?? []).length}`,
        }, 200);
    },
);

// ── GET /license/:key/history (SuperAdmin Only) ─────────────────────────────

export const getLicenseHistory = authorizedHandler(
    [UserRole.SUPER_ADMIN],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
        requireSuperAdmin(auth, event);
        const key = event.pathParameters?.key;
        if (!key) return response.error(400, 'MISSING_KEY', 'License key is required');

        const history = await licenseService.getLicenseHistory(key);
        return response.success({ data: history }, 200);
    },
);
