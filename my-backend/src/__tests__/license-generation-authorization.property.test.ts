// @ts-nocheck
/// <reference types="jest" />
// ============================================================================
// Property-Based Test — License-Key Generation Authorization
// ============================================================================
// Feature: offline-license-activation, Property 5: Only Super_Admin can
// generate a license key
//
// **Validates: Requirements 2.5, 2.6**
//
// Property 5 (design.md):
//   For any actor role, license-key generation succeeds if and only if the
//   actor is Super_Admin; when the actor is not Super_Admin, no license key is
//   created or persisted and an authorization error is returned.
//
// How this is driven:
//   The POST /license/generate handler is guarded by
//   authorizedHandler([UserRole.SUPER_ADMIN]) plus requireSuperAdmin. We drive
//   the property at the authorization-guard level by varying the authenticated
//   actor's role across every UserRole value, then asserting:
//     • role === SUPER_ADMIN  → 201 success AND the persistence/generate
//       function (generateStandaloneLicenseKey) IS invoked.
//     • role !== SUPER_ADMIN  → 403 authorization error, NO license key in the
//       response, AND the persistence/generate function is NOT invoked (so no
//       key is created or persisted).
//
// The data layer is mocked (license.service.generateStandaloneLicenseKey) so no
// real persistence happens; we assert call/no-call to prove the persistence
// boundary is never reached for non-super-admin actors. Deterministic: a fixed
// fast-check seed and ≥100 runs.
// ============================================================================

import fc from 'fast-check';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { UserRole } from '../types/tenant.types';

// ── Mocks ───────────────────────────────────────────────────────────────────

// Bypass real Cognito JWT verification; the resolved role is set per-iteration.
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn(),
    requireRole: jest.fn(),
}));

// Mock the data layer so NO real persistence happens. This is the
// persistence/generate boundary we assert is reached only for SUPER_ADMIN.
jest.mock('../services/license.service', () => ({
    generateStandaloneLicenseKey: jest.fn(),
    getDefaultFeaturesForPlan: jest.fn().mockReturnValue([]),
}));

// Prevent async CloudWatch metric emission from racing test teardown.
jest.mock('@aws-sdk/client-cloudwatch', () => ({
    CloudWatchClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({}),
    })),
    PutMetricDataCommand: jest.fn(),
}));

// IMPORTANT: requireSuperAdmin is NOT mocked — the authorization under test is
// exercised for real (both the role gate and the in-handler guard).

const { verifyAuth } = require('../middleware/cognito-auth');
const licenseService = require('../services/license.service');
const license = require('../handlers/license');

// ── Test fixtures ─────────────────────────────────────────────────────────

const mockContext: Context = {
    callbackWaitsForEmptyEventLoop: false,
    functionName: 'test',
    functionVersion: '1',
    invokedFunctionArn: 'arn:aws:lambda:ap-south-1:123:function:test',
    memoryLimitInMB: '128',
    awsRequestId: 'test-req',
    logGroupName: '/aws/lambda/test',
    logStreamName: 'test-stream',
    getRemainingTimeInMillis: () => 30000,
    done: () => {},
    fail: () => {},
    succeed: () => {},
};

function makeGenerateEvent(): APIGatewayProxyEventV2 {
    return {
        version: '2.0',
        routeKey: 'POST /license/generate',
        rawPath: '/license/generate',
        rawQueryString: '',
        headers: { authorization: 'Bearer test-token', 'content-type': 'application/json' },
        queryStringParameters: null,
        pathParameters: null,
        // A fully valid generation body — so the ONLY thing that can change the
        // outcome is the actor's role, isolating the authorization property.
        body: JSON.stringify({ plan: 'premium', duration: '12 months', features: ['reports'] }),
        requestContext: {
            accountId: '123',
            apiId: 'test',
            domainName: 'test.execute-api.ap-south-1.amazonaws.com',
            domainPrefix: 'test',
            http: { method: 'POST', path: '/license/generate', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'jest' },
            requestId: 'test-req-id',
            routeKey: 'POST /license/generate',
            stage: 'test',
            time: new Date().toISOString(),
            timeEpoch: Date.now(),
        },
        isBase64Encoded: false,
    } as APIGatewayProxyEventV2;
}

function parseBody(result: any): any {
    return JSON.parse(result.body || '{}');
}

// Every UserRole value, including SUPER_ADMIN and all non-super-admin roles.
const ALL_ROLES: UserRole[] = Object.values(UserRole) as UserRole[];

// ── Property 5 ──────────────────────────────────────────────────────────────

describe('Feature: offline-license-activation, Property 5: Only Super_Admin can generate a license key', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        // Default successful persistence result for the SUPER_ADMIN path.
        licenseService.generateStandaloneLicenseKey.mockResolvedValue({
            license_key: 'DKNX-AAAA-BBBB-CCCC',
            tenant_id: 'TNX-12345678',
            plan: 'premium',
            expiry_date: '2030-01-01',
            business_type: 'general',
            features: ['reports'],
        });
    });

    it('generation succeeds iff actor is Super_Admin; otherwise authz error and no key persisted (Validates: Requirements 2.5, 2.6)', async () => {
        await fc.assert(
            fc.asyncProperty(fc.constantFrom(...ALL_ROLES), async (role) => {
                // Reset the call ledger for the persistence/generate boundary.
                licenseService.generateStandaloneLicenseKey.mockClear();

                // The authenticated actor carries the generated role.
                verifyAuth.mockResolvedValue({
                    sub: 'actor-1',
                    email: 'actor@example.com',
                    tenantId: 'tenant-1',
                    role,
                    businessType: 'grocery',
                });

                const result: any = await license.generate(makeGenerateEvent(), mockContext);
                const body = parseBody(result);

                const isSuperAdmin = role === UserRole.SUPER_ADMIN;

                if (isSuperAdmin) {
                    // Succeeds: 201 + a created key is returned.
                    expect(result.statusCode).toBe(201);
                    expect(body.success).toBe(true);
                    expect(body.data.license_key).toBeDefined();
                    // The persistence/generate boundary IS reached exactly once.
                    expect(licenseService.generateStandaloneLicenseKey).toHaveBeenCalledTimes(1);
                } else {
                    // Blocked: an authorization error is returned (403 / FORBIDDEN).
                    expect(result.statusCode).toBe(403);
                    expect(body.success).toBe(false);
                    expect(body.error.code).toBe('FORBIDDEN');
                    // No license key created or persisted, and none returned.
                    expect(licenseService.generateStandaloneLicenseKey).not.toHaveBeenCalled();
                    expect(body.data).toBeUndefined();
                }
            }),
            { numRuns: 200, seed: 20260205 },
        );
    });
});
