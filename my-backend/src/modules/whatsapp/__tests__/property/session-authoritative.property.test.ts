/**
 * Property-Based Tests: Session-Authoritative BusinessID Scoping
 *
 * Feature: openwa-whatsapp-automation, Property 31
 *
 * **Validates: Requirements 12.4**
 *
 * Property 31: BusinessID is session-authoritative
 *   - The handler derives BusinessID exclusively from the authenticated session
 *     (headers set by the auth gateway), NEVER from client-supplied input.
 *   - Even if a client includes a different businessId in the request body,
 *     the handler uses only the session-derived one.
 *   - All repository calls receive the session-derived businessId.
 *   - A body-supplied businessId that differs from the session triggers a
 *     security error (cross-business access denied).
 */

import * as fc from 'fast-check';
import type { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import type { AuthContext } from '../../../../types/tenant.types';
import { UserRole } from '../../../../types/tenant.types';

// ── Generators ───────────────────────────────────────────────────────────────

/** Safe characters for IDs (no # injection) */
const SAFE_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

const safeIdArb = fc.stringOf(
  fc.constantFrom(...SAFE_CHARS.split('')),
  { minLength: 1, maxLength: 32 },
);

/** Valid E.164 phone number */
const e164Arb = fc
  .integer({ min: 10000000, max: 999999999999999 })
  .map((n) => `+${n}`);

// ── Mocks & Helpers ──────────────────────────────────────────────────────────

// Track all arguments passed to repository methods
let repoCalls: Array<{ method: string; tenantId: string; businessId: string; args: unknown[] }> = [];

// Mock the repository
const mockCreate = jest.fn();
const mockGet = jest.fn();
const mockList = jest.fn();
const mockUpdate = jest.fn();
const mockSetConsentState = jest.fn();

jest.mock('../../repositories/customer-profile.repository', () => ({
  CustomerProfileRepository: jest.fn().mockImplementation(() => ({
    create: (...args: unknown[]) => {
      repoCalls.push({ method: 'create', tenantId: args[0] as string, businessId: args[1] as string, args });
      return mockCreate(...args);
    },
    get: (...args: unknown[]) => {
      repoCalls.push({ method: 'get', tenantId: args[0] as string, businessId: args[1] as string, args });
      return mockGet(...args);
    },
    list: (...args: unknown[]) => {
      repoCalls.push({ method: 'list', tenantId: args[0] as string, businessId: args[1] as string, args });
      return mockList(...args);
    },
    update: (...args: unknown[]) => {
      repoCalls.push({ method: 'update', tenantId: args[0] as string, businessId: args[1] as string, args });
      return mockUpdate(...args);
    },
    setConsentState: (...args: unknown[]) => {
      repoCalls.push({ method: 'setConsentState', tenantId: args[0] as string, businessId: args[1] as string, args });
      return mockSetConsentState(...args);
    },
  })),
}));

// Mock buildTenantContext to return the session businessId directly
jest.mock('../../../../dynamodb/tenant-guard', () => ({
  buildTenantContext: jest.fn(async (_auth: AuthContext, businessId: string) => ({
    tenantContext: {
      tenantId: _auth.tenantId,
      businessId,
      hasCrossBusinessAccess: false,
    },
    businessContext: null,
  })),
}));

// Mock audit service
jest.mock('../../services/wa-audit.service', () => ({
  WaAuditService: jest.fn().mockImplementation(() => ({
    recordConsentChange: jest.fn().mockResolvedValue(undefined),
  })),
  AUDIT_ACTIONS: { CONSENT_CHANGE: 'CONSENT_CHANGE' },
  buildAuditTarget: jest.fn((type: string, id: string) => `${type}:${id}`),
}));

// Mock phone validation (always valid for test purposes)
jest.mock('../../services/phone.service', () => ({
  validateE164: jest.fn((number: string) => ({ valid: true, normalized: number, error: null })),
}));

// Mock permission-matrix
jest.mock('../../../../config/permission-matrix', () => ({
  checkPermission: jest.fn(() => ({ allowed: true })),
}));

// Mock plan-feature-registry
jest.mock('../../../../config/plan-feature-registry', () => ({
  FeatureKey: { WA_CORE: 'WA_CORE' },
}));

// Mock authorizedHandler to just call the handler function directly
jest.mock('../../../../middleware/handler-wrapper', () => ({
  authorizedHandler: jest.fn(
    (_roles: unknown, handler: Function, _opts?: unknown) => handler,
  ),
}));

// Mock response utils
jest.mock('../../../../utils/response', () => ({
  success: jest.fn((data: unknown, statusCode = 200) => ({
    statusCode,
    body: JSON.stringify(data),
  })),
  error: jest.fn((statusCode: number, code: string, message: string) => ({
    statusCode,
    body: JSON.stringify({ code, message }),
  })),
}));

// Mock logger
jest.mock('../../../../utils/logger', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

// ── Import handler AFTER mocks are set up ────────────────────────────────────
import { customerHandler } from '../../handlers/customer.handler';

// ── Helper: Build a fake API Gateway event ───────────────────────────────────

function buildEvent(params: {
  method: string;
  sessionBusinessId: string;
  body?: Record<string, unknown>;
  pathId?: string;
}): APIGatewayProxyEventV2 {
  return {
    version: '2.0',
    routeKey: `${params.method} /whatsapp/customers`,
    rawPath: params.pathId
      ? `/whatsapp/customers/${params.pathId}`
      : '/whatsapp/customers',
    rawQueryString: '',
    headers: {
      'x-active-business': params.sessionBusinessId,
    },
    requestContext: {
      http: { method: params.method, path: '/whatsapp/customers', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
      accountId: '123',
      apiId: 'test',
      domainName: 'test',
      domainPrefix: 'test',
      requestId: 'test',
      routeKey: 'test',
      stage: 'test',
      time: new Date().toISOString(),
      timeEpoch: Date.now(),
    },
    body: params.body ? JSON.stringify(params.body) : undefined,
    pathParameters: params.pathId ? { id: params.pathId } : undefined,
    isBase64Encoded: false,
  } as unknown as APIGatewayProxyEventV2;
}

function buildAuth(tenantId: string): AuthContext {
  return {
    sub: 'user-123',
    email: 'owner@test.com',
    tenantId,
    role: UserRole.OWNER,
    businessType: 'grocery' as any,
    planTier: 'premium',
  };
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 31 — BusinessID is session-authoritative', () => {
  beforeEach(() => {
    repoCalls = [];
    mockCreate.mockReset();
    mockGet.mockReset();
    mockList.mockReset();
    mockUpdate.mockReset();
    mockSetConsentState.mockReset();
  });

  it('CREATE: repository receives the session-derived businessId, never a body-supplied one', async () => {
    await fc.assert(
      fc.asyncProperty(
        safeIdArb,  // tenantId
        safeIdArb,  // session businessId (authoritative)
        safeIdArb,  // body businessId (should be ignored)
        e164Arb,    // whatsappNumber
        async (tenantId, sessionBizId, bodyBizId, phone) => {
          repoCalls = [];
          mockCreate.mockResolvedValue({
            id: 'cust-1',
            businessId: sessionBizId,
            tenantId,
            whatsappNumber: phone,
            consentState: 'pending',
            locale: 'en',
            eligible: false,
            isDeleted: false,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          });

          const event = buildEvent({
            method: 'POST',
            sessionBusinessId: sessionBizId,
            body: {
              whatsappNumber: phone,
              businessId: bodyBizId, // client tries to inject a different businessId
            },
          });
          const auth = buildAuth(tenantId);

          // If bodyBizId differs from sessionBizId, expect a security error
          // Otherwise, the handler should use sessionBizId for repository calls
          if (bodyBizId !== sessionBizId) {
            // The handler should throw a cross-business access error
            await expect(
              (customerHandler as Function)(event, {} as Context, auth),
            ).rejects.toThrow(/[Cc]ross-business|[Dd]enied|[Ss]ecurity/);
          } else {
            await (customerHandler as Function)(event, {} as Context, auth);

            // All repository calls MUST use the session-derived businessId
            for (const call of repoCalls) {
              expect(call.businessId).toBe(sessionBizId);
            }
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  it('GET: repository always receives the session-derived businessId regardless of path params', async () => {
    await fc.assert(
      fc.asyncProperty(
        safeIdArb,  // tenantId
        safeIdArb,  // session businessId
        safeIdArb,  // customerId (path param)
        async (tenantId, sessionBizId, customerId) => {
          repoCalls = [];
          mockGet.mockResolvedValue({
            id: customerId,
            businessId: sessionBizId,
            tenantId,
            whatsappNumber: '+919876543210',
            consentState: 'opted_in',
            locale: 'en',
            eligible: true,
            isDeleted: false,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          });

          const event = buildEvent({
            method: 'GET',
            sessionBusinessId: sessionBizId,
            pathId: customerId,
          });
          const auth = buildAuth(tenantId);

          await (customerHandler as Function)(event, {} as Context, auth);

          // Verify repository was called with session-derived businessId
          expect(repoCalls.length).toBeGreaterThan(0);
          for (const call of repoCalls) {
            expect(call.businessId).toBe(sessionBizId);
            expect(call.tenantId).toBe(tenantId);
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  it('LIST: repository always receives the session-derived businessId', async () => {
    await fc.assert(
      fc.asyncProperty(
        safeIdArb,  // tenantId
        safeIdArb,  // session businessId
        async (tenantId, sessionBizId) => {
          repoCalls = [];
          mockList.mockResolvedValue([]);

          const event = buildEvent({
            method: 'GET',
            sessionBusinessId: sessionBizId,
          });
          const auth = buildAuth(tenantId);

          await (customerHandler as Function)(event, {} as Context, auth);

          // All repository calls use session-derived businessId
          expect(repoCalls.length).toBeGreaterThan(0);
          for (const call of repoCalls) {
            expect(call.businessId).toBe(sessionBizId);
            expect(call.tenantId).toBe(tenantId);
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  it('UPDATE: repository uses session businessId even when body contains a different businessId', async () => {
    await fc.assert(
      fc.asyncProperty(
        safeIdArb,  // tenantId
        safeIdArb,  // session businessId
        safeIdArb,  // body businessId (attacker)
        safeIdArb,  // customerId
        e164Arb,    // new phone number
        async (tenantId, sessionBizId, bodyBizId, customerId, newPhone) => {
          repoCalls = [];
          const existing = {
            id: customerId,
            businessId: sessionBizId,
            tenantId,
            whatsappNumber: '+910000000000',
            consentState: 'opted_in' as const,
            locale: 'en',
            eligible: true,
            isDeleted: false,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };
          mockGet.mockResolvedValue(existing);
          mockUpdate.mockResolvedValue({ ...existing, whatsappNumber: newPhone });

          const event = buildEvent({
            method: 'PUT',
            sessionBusinessId: sessionBizId,
            body: {
              whatsappNumber: newPhone,
              businessId: bodyBizId, // attacker tries to inject
            },
            pathId: customerId,
          });
          const auth = buildAuth(tenantId);

          if (bodyBizId !== sessionBizId) {
            // Cross-business mismatch → security error
            await expect(
              (customerHandler as Function)(event, {} as Context, auth),
            ).rejects.toThrow(/[Cc]ross-business|[Dd]enied|[Ss]ecurity/);
          } else {
            await (customerHandler as Function)(event, {} as Context, auth);

            // All repo calls use the session businessId
            for (const call of repoCalls) {
              expect(call.businessId).toBe(sessionBizId);
              expect(call.tenantId).toBe(tenantId);
            }
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  it('the session-derived businessId is extracted from headers, not from the request body', async () => {
    await fc.assert(
      fc.asyncProperty(
        safeIdArb,  // tenantId
        safeIdArb,  // session businessId (in header)
        e164Arb,    // phone
        async (tenantId, sessionBizId, phone) => {
          repoCalls = [];
          mockCreate.mockResolvedValue({
            id: 'cust-1',
            businessId: sessionBizId,
            tenantId,
            whatsappNumber: phone,
            consentState: 'pending',
            locale: 'en',
            eligible: false,
            isDeleted: false,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          });

          // Body has NO businessId — the handler MUST still resolve it from the header
          const event = buildEvent({
            method: 'POST',
            sessionBusinessId: sessionBizId,
            body: { whatsappNumber: phone },
          });
          const auth = buildAuth(tenantId);

          await (customerHandler as Function)(event, {} as Context, auth);

          // Repository was called with session-derived businessId
          expect(repoCalls.length).toBeGreaterThan(0);
          for (const call of repoCalls) {
            expect(call.businessId).toBe(sessionBizId);
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  it('missing session header (no businessId in headers) causes an auth error, never falls back to body', async () => {
    await fc.assert(
      fc.asyncProperty(
        safeIdArb,  // tenantId
        safeIdArb,  // body businessId (should NOT be used as fallback)
        e164Arb,    // phone
        async (tenantId, bodyBizId, phone) => {
          repoCalls = [];

          const event: APIGatewayProxyEventV2 = {
            version: '2.0',
            routeKey: 'POST /whatsapp/customers',
            rawPath: '/whatsapp/customers',
            rawQueryString: '',
            headers: {
              // NO x-active-business or x-business-id header
            },
            requestContext: {
              http: { method: 'POST', path: '/whatsapp/customers', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
              accountId: '123',
              apiId: 'test',
              domainName: 'test',
              domainPrefix: 'test',
              requestId: 'test',
              routeKey: 'test',
              stage: 'test',
              time: new Date().toISOString(),
              timeEpoch: Date.now(),
            },
            body: JSON.stringify({ whatsappNumber: phone, businessId: bodyBizId }),
            isBase64Encoded: false,
          } as unknown as APIGatewayProxyEventV2;

          const auth = buildAuth(tenantId);

          // Must throw auth error — never falls back to body
          await expect(
            (customerHandler as Function)(event, {} as Context, auth),
          ).rejects.toThrow(/[Bb]usiness context|[Aa]uth/);

          // No repository calls should have been made
          expect(repoCalls.length).toBe(0);
        },
      ),
      { numRuns: 100 },
    );
  });
});
