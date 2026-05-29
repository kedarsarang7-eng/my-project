// ============================================================================
// Tests — Notification Retention Configuration Handler
// ============================================================================
// Covers:
//   - GET as admin returns the current config
//   - PUT as admin validates, audits, persists, and returns the new config
//   - Unauthenticated request rejected (401)
//   - Non-admin authenticated request rejected (403)
//   - PUT validation rejects invalid values (400)
//   - PUT returns 503 when Audit_Log subsystem is unavailable (REQ 13.4a)
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { describe, test, expect, beforeEach, jest } from '@jest/globals';

// ---- Auth mock ----------------------------------------------------------

const mockVerifyAuth = jest.fn<(...args: unknown[]) => Promise<unknown>>();
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: (...args: unknown[]) => mockVerifyAuth(...args),
}));

// ---- Service mock -------------------------------------------------------
//
// We mock the retention-config service surface rather than the underlying
// DynamoDB calls because the handler is a thin adapter — it should be
// tested for routing, validation, and error mapping, not for DB internals.

const mockGetRetentionConfig = jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockSetRetentionConfig = jest.fn<(...args: unknown[]) => Promise<unknown>>();

jest.mock('../notifications/retention', () => {
    const actual = jest.requireActual('../notifications/retention') as Record<
        string,
        unknown
    >;
    return {
        ...actual,
        getRetentionConfig: (...args: unknown[]) =>
            mockGetRetentionConfig(...args),
        setRetentionConfig: (...args: unknown[]) =>
            mockSetRetentionConfig(...args),
    };
});

// Stub the audit middleware so unrelated cross-tenant logic stays quiet.
jest.mock('../middleware/audit', () => ({
    logAudit: jest.fn<() => Promise<void>>().mockResolvedValue(undefined),
}));

// Stub the software-lock middleware so the handler-wrapper does not try
// to reach AWS subscription services in unit tests. The bizmate codebase
// follows the pattern of mocking only what each test exercises; here we
// neutralise the lock by always returning `NONE`.
jest.mock('../middleware/software-lock', () => ({
    LockLevel: { NONE: 'none', WARNING: 'warning', BLOCKED: 'blocked' },
    checkSoftwareLock: jest.fn<() => Promise<unknown>>().mockResolvedValue({
        allowed: true,
        lockLevel: 'none',
        userMessage: '',
        metadata: {},
    }),
}));

// ---- Imports under test (after mocks) -----------------------------------

import {
    getRetentionConfigHandler,
    updateRetentionConfigHandler,
} from '../handlers/notification-retention';
import {
    AuditLogUnavailableError,
    MAX_ARCHIVE_PERIOD_DAYS,
    MIN_ARCHIVE_PERIOD_DAYS,
} from '../notifications/retention';
import { UserRole, BusinessType } from '../types/tenant.types';
import { AuthError } from '../utils/errors';

// ---- Helpers ------------------------------------------------------------

function makeEvent(
    method: 'GET' | 'PUT',
    body?: unknown,
): APIGatewayProxyEventV2 {
    return {
        version: '2.0',
        routeKey: `${method} /notifications/retention-config`,
        rawPath: '/notifications/retention-config',
        rawQueryString: '',
        headers: {
            authorization: 'Bearer test-token',
            'content-type': 'application/json',
        },
        requestContext: {
            accountId: '123',
            apiId: 'test',
            domainName: 'test.local',
            domainPrefix: 'test',
            http: {
                method,
                path: '/notifications/retention-config',
                protocol: 'HTTP/1.1',
                sourceIp: '127.0.0.1',
                userAgent: 'jest',
            },
            requestId: 'req-1',
            routeKey: `${method} /notifications/retention-config`,
            stage: '$default',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
        body: body === undefined ? undefined : JSON.stringify(body),
    } as APIGatewayProxyEventV2;
}

const ctx = {} as Context;

function adminAuth(role: UserRole = UserRole.ADMIN) {
    return {
        sub: 'admin-user-id',
        email: 'admin@test.com',
        tenantId: 'tenant-aaa',
        role,
        businessType: BusinessType.GROCERY,
    };
}

function parsed(result: unknown): { statusCode: number; body: any } {
    const r = result as { statusCode?: number; body?: string };
    return {
        statusCode: r.statusCode ?? 0,
        body: JSON.parse(r.body || '{}'),
    };
}

beforeEach(() => {
    jest.clearAllMocks();
});

// ---------------------------------------------------------------------------
// GET — read
// ---------------------------------------------------------------------------

describe('GET /notifications/retention-config', () => {
    test('admin call returns the persisted configuration', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.ADMIN));
        mockGetRetentionConfig.mockResolvedValueOnce({
            archive_period_days: 120,
            updated_at: '2026-01-01T00:00:00.000Z',
            updated_by: 'admin-user-id',
            version: 2,
        });

        const result = await getRetentionConfigHandler(makeEvent('GET'), ctx);
        const { statusCode, body } = parsed(result);

        expect(statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data).toEqual({
            archive_period_days: 120,
            updated_at: '2026-01-01T00:00:00.000Z',
            updated_by: 'admin-user-id',
            version: 2,
        });
    });

    test('owner is also permitted', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.OWNER));
        mockGetRetentionConfig.mockResolvedValueOnce({
            archive_period_days: 90,
            updated_at: new Date(0).toISOString(),
            updated_by: null,
            version: 0,
        });

        const result = await getRetentionConfigHandler(makeEvent('GET'), ctx);
        expect(parsed(result).statusCode).toBe(200);
    });

    test('unauthenticated request is rejected with 401', async () => {
        mockVerifyAuth.mockRejectedValueOnce(
            new AuthError('Missing or invalid Authorization header', 401),
        );

        const result = await getRetentionConfigHandler(makeEvent('GET'), ctx);
        const { statusCode } = parsed(result);

        expect(statusCode).toBe(401);
        expect(mockGetRetentionConfig).not.toHaveBeenCalled();
    });

    test('non-admin role (cashier) is rejected with 403', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.CASHIER));

        const result = await getRetentionConfigHandler(makeEvent('GET'), ctx);
        const { statusCode } = parsed(result);

        expect(statusCode).toBe(403);
        expect(mockGetRetentionConfig).not.toHaveBeenCalled();
    });

    test('non-admin role (manager) is rejected with 403', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.MANAGER));

        const result = await getRetentionConfigHandler(makeEvent('GET'), ctx);
        expect(parsed(result).statusCode).toBe(403);
    });
});

// ---------------------------------------------------------------------------
// PUT — update
// ---------------------------------------------------------------------------

describe('PUT /notifications/retention-config', () => {
    test('admin call updates and returns the new configuration', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.ADMIN));
        mockSetRetentionConfig.mockResolvedValueOnce({
            archive_period_days: 180,
            updated_at: '2026-04-01T12:34:56.000Z',
            updated_by: 'admin-user-id',
            version: 1,
        });

        const result = await updateRetentionConfigHandler(
            makeEvent('PUT', { archive_period_days: 180 }),
            ctx,
        );
        const { statusCode, body } = parsed(result);

        expect(statusCode).toBe(200);
        expect(body.success).toBe(true);
        expect(body.data.archive_period_days).toBe(180);
        expect(body.data.updated_by).toBe('admin-user-id');

        expect(mockSetRetentionConfig).toHaveBeenCalledWith({
            archive_period_days: 180,
            actor_id: 'admin-user-id',
        });
    });

    test('unauthenticated request is rejected with 401', async () => {
        mockVerifyAuth.mockRejectedValueOnce(
            new AuthError('Missing or invalid Authorization header', 401),
        );

        const result = await updateRetentionConfigHandler(
            makeEvent('PUT', { archive_period_days: 180 }),
            ctx,
        );

        expect(parsed(result).statusCode).toBe(401);
        expect(mockSetRetentionConfig).not.toHaveBeenCalled();
    });

    test('non-admin role (cashier) is rejected with 403', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.CASHIER));

        const result = await updateRetentionConfigHandler(
            makeEvent('PUT', { archive_period_days: 180 }),
            ctx,
        );

        expect(parsed(result).statusCode).toBe(403);
        expect(mockSetRetentionConfig).not.toHaveBeenCalled();
    });

    test('rejects body with non-integer archive_period_days', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.ADMIN));

        const result = await updateRetentionConfigHandler(
            makeEvent('PUT', { archive_period_days: 30.5 }),
            ctx,
        );

        expect(parsed(result).statusCode).toBe(400);
        expect(mockSetRetentionConfig).not.toHaveBeenCalled();
    });

    test('rejects body with archive_period_days below MIN', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.ADMIN));

        const result = await updateRetentionConfigHandler(
            makeEvent('PUT', {
                archive_period_days: MIN_ARCHIVE_PERIOD_DAYS - 1,
            }),
            ctx,
        );

        expect(parsed(result).statusCode).toBe(400);
    });

    test('rejects body with archive_period_days above MAX', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.ADMIN));

        const result = await updateRetentionConfigHandler(
            makeEvent('PUT', {
                archive_period_days: MAX_ARCHIVE_PERIOD_DAYS + 1,
            }),
            ctx,
        );

        expect(parsed(result).statusCode).toBe(400);
    });

    test('rejects body without archive_period_days field', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.ADMIN));

        const result = await updateRetentionConfigHandler(
            makeEvent('PUT', {}),
            ctx,
        );

        expect(parsed(result).statusCode).toBe(400);
        expect(mockSetRetentionConfig).not.toHaveBeenCalled();
    });

    test('rejects body with non-JSON content', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.ADMIN));

        const event = makeEvent('PUT');
        (event as { body?: string }).body = 'not-json';

        const result = await updateRetentionConfigHandler(event, ctx);

        expect(parsed(result).statusCode).toBe(400);
    });

    test('returns 503 when Audit_Log subsystem is unavailable (REQ 13.4a)', async () => {
        mockVerifyAuth.mockResolvedValueOnce(adminAuth(UserRole.ADMIN));
        mockSetRetentionConfig.mockRejectedValueOnce(
            new AuditLogUnavailableError(new Error('DynamoDB unreachable')),
        );

        const result = await updateRetentionConfigHandler(
            makeEvent('PUT', { archive_period_days: 180 }),
            ctx,
        );
        const { statusCode, body } = parsed(result);

        expect(statusCode).toBe(503);
        expect(body.error?.code).toBe('SERVICE_UNAVAILABLE');
    });
});
