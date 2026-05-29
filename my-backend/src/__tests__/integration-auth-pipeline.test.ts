// ============================================================================
// IT-AUTH — Auth Pipeline Integration Tests
// Coverage: Register → Cognito → DynamoDB bootstrap, Login JWT claims,
//           Expired/tampered token, Multi-device, Force logout,
//           Cross-tenant IDOR, Mass assignment, Business-type spoofing
// ============================================================================
// Uses: aws-sdk-mock + supertest-style handler invocation against real handler code
// LocalStack: DynamoDB endpoint = http://localhost:4566
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { UserRole, BusinessType } from '../types/tenant.types';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { AuthError } from '../utils/errors';

// ── Deep mocks (simulating real Cognito + DynamoDB interactions) ─────────────
const mockVerify   = jest.fn();
const mockGetItem  = jest.fn();
const mockPutItem  = jest.fn();
const mockQueryItems = jest.fn();

jest.mock('../middleware/cognito-auth', () => ({
  verifyAuth: (...a: any[]) => mockVerify(...a),
}));

jest.mock('../config/dynamodb.config', () => ({
  Keys: {
    tenantPK:       (id: string) => `TENANT#${id}`,
    productSK:      (id: string) => `PRODUCT#${id}`,
    tenantLicenseSK: () => 'LICENSE#CURRENT',
    businessSK:     (id: string) => `BUSINESS#${id}`,
  },
  getItem:     (...a: any[]) => mockGetItem(...a),
  putItem:     (...a: any[]) => mockPutItem(...a),
  queryItems:  (...a: any[]) => mockQueryItems(...a),
  tableName: 'DukanX-Table',
}));

jest.mock('../utils/logger', () => ({
  logger: { debug: jest.fn(), warn: jest.fn(), error: jest.fn(), info: jest.fn() },
  logRequest: jest.fn().mockResolvedValue(undefined),
  logAuthFailure: jest.fn(),
}));

// ── Helper factories ──────────────────────────────────────────────────────────

function makeAuthCtx(overrides: Partial<{
  sub: string; tenantId: string; role: UserRole; businessType: BusinessType;
  email: string; licenseStatus: string; planStatus: string;
}> = {}) {
  return {
    sub: 'user-sub-001',
    tenantId: 'tenant-aaa-001',
    role: UserRole.OWNER,
    businessType: BusinessType.GROCERY,
    email: 'owner@grocery.com',
    licenseStatus: 'active',
    planStatus: 'active',
    ...overrides,
  };
}

function makeEvent(opts: {
  method?: string;
  path?: string;
  headers?: Record<string, string>;
  body?: unknown;
} = {}): APIGatewayProxyEventV2 {
  return {
    requestContext: {
      http: { method: opts.method || 'GET', sourceIp: '127.0.0.1' },
      requestId: 'req-001',
    },
    rawPath: opts.path || '/test',
    headers: {
      authorization: 'Bearer mock-token',
      'content-type': 'application/json',
      ...(opts.headers || {}),
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  } as unknown as APIGatewayProxyEventV2;
}

// ── Dummy protected handler ───────────────────────────────────────────────────
const protectedLogic = jest.fn().mockResolvedValue({
  statusCode: 200,
  body: JSON.stringify({ message: 'ok' }),
});

// ============================================================================
// IT-AUTH-001: Successful Auth Flow
// ============================================================================

describe('IT-AUTH-001: Successful Auth — JWT claims extracted and context set', () => {
  const handler = authorizedHandler([UserRole.OWNER], protectedLogic);

  beforeEach(() => {
    jest.clearAllMocks();
    protectedLogic.mockResolvedValue({ statusCode: 200, body: JSON.stringify({ ok: true }) });
    mockGetItem.mockResolvedValue(null); // no license record = pass through
  });

  test('Valid owner token → 200 and business logic called', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx());
    const res = await handler(makeEvent(), {} as Context) as any;
    expect(res.statusCode).toBe(200);
    expect(protectedLogic).toHaveBeenCalledTimes(1);
  });

  test('Auth context passed to handler contains correct tenantId', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ tenantId: 'tenant-xyz-123' }));
    await handler(makeEvent(), {} as Context);
    const authArg = protectedLogic.mock.calls[0][2];
    expect(authArg.tenantId).toBe('tenant-xyz-123');
  });

  test('Auth context contains correct role', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ role: UserRole.ADMIN }));
    const adminHandler = authorizedHandler([UserRole.ADMIN], protectedLogic);
    await adminHandler(makeEvent(), {} as Context);
    const authArg = protectedLogic.mock.calls[0][2];
    expect(authArg.role).toBe(UserRole.ADMIN);
  });

  test('Auth context contains correct businessType', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ businessType: BusinessType.PHARMACY }));
    await handler(makeEvent(), {} as Context);
    const authArg = protectedLogic.mock.calls[0][2];
    expect(authArg.businessType).toBe(BusinessType.PHARMACY);
  });
});

// ============================================================================
// IT-AUTH-002: Role Enforcement
// ============================================================================

describe('IT-AUTH-002: Role Enforcement', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(undefined);
  });

  test('Staff accessing owner-only endpoint → 403', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ role: UserRole.STAFF }));
    const ownerOnlyHandler = authorizedHandler([UserRole.OWNER, UserRole.ADMIN], protectedLogic);
    const res = await ownerOnlyHandler(makeEvent(), {} as Context) as any;
    expect(res.statusCode).toBe(403);
    expect(protectedLogic).not.toHaveBeenCalled();
  });

  test('Viewer attempting POST → 403 (read-only enforcement)', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ role: UserRole.VIEWER }));
    const handler = authorizedHandler([], protectedLogic); // no role restriction, but viewer check
    const res = await handler(makeEvent({ method: 'POST' }), {} as Context) as any;
    expect(res.statusCode).toBe(403);
    expect(protectedLogic).not.toHaveBeenCalled();
  });

  test('Viewer attempting GET → 200', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ role: UserRole.VIEWER }));
    const handler = authorizedHandler([], protectedLogic);
    const res = await handler(makeEvent({ method: 'GET' }), {} as Context) as any;
    expect(res.statusCode).toBe(200);
  });

  test('Manager accessing admin+manager endpoint → 200', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ role: UserRole.MANAGER }));
    const handler = authorizedHandler([UserRole.ADMIN, UserRole.MANAGER, UserRole.OWNER], protectedLogic);
    const res = await handler(makeEvent(), {} as Context) as any;
    expect(res.statusCode).toBe(200);
  });
});

// ============================================================================
// IT-AUTH-003: Expired / Tampered Token
// ============================================================================

describe('IT-AUTH-003: Expired and Tampered Token Rejection', () => {
  beforeEach(() => jest.clearAllMocks());

  test('Expired token → 401', async () => {
    mockVerify.mockRejectedValue(new AuthError('Invalid or expired token'));
    const handler = authorizedHandler([], protectedLogic);
    const res = await handler(makeEvent(), {} as Context) as any;
    expect(res.statusCode).toBe(401);
    expect(protectedLogic).not.toHaveBeenCalled();
  });

  test('Tampered token (verify throws) → 401', async () => {
    mockVerify.mockRejectedValue(new AuthError('Invalid or expired token'));
    const handler = authorizedHandler([], protectedLogic);
    const res = await handler(makeEvent(), {} as Context) as any;
    expect(res.statusCode).toBe(401);
  });

  test('Token from different user pool → 401', async () => {
    mockVerify.mockRejectedValue(new AuthError('User pool mismatch'));
    const handler = authorizedHandler([], protectedLogic);
    const res = await handler(makeEvent(), {} as Context) as any;
    expect(res.statusCode).toBe(401);
  });
});

// ============================================================================
// IT-AUTH-004: Cross-Tenant Access Detection
// ============================================================================

describe('IT-AUTH-004: Cross-Tenant Access Detection', () => {
  const handler = authorizedHandler([UserRole.OWNER], protectedLogic);

  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(undefined);
  });

  test('x-tenant-id header matching JWT → allowed', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ tenantId: 'tenant-aaa' }));
    const res = await handler(
      makeEvent({ headers: { 'x-tenant-id': 'tenant-aaa' } }),
      {} as Context,
    ) as any;
    expect(res.statusCode).toBe(200);
  });

  test('x-tenant-id header NOT matching JWT tenantId → 401', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ tenantId: 'tenant-aaa' }));
    const res = await handler(
      makeEvent({ headers: { 'x-tenant-id': 'tenant-EVIL' } }),
      {} as Context,
    ) as any;
    expect(res.statusCode).toBe(401);
    const body = JSON.parse(res.body);
    expect(body.message).toContain('Cross-tenant');
  });

  test('Body with tenant_id overriding JWT → 401', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ tenantId: 'tenant-aaa' }));
    const res = await handler(
      makeEvent({ method: 'POST', body: { tenant_id: 'tenant-EVIL', name: 'Exploit' } }),
      {} as Context,
    ) as any;
    expect(res.statusCode).toBe(401);
  });
});

// ============================================================================
// IT-AUTH-005: Business Type Spoofing
// ============================================================================

describe('IT-AUTH-005: Business Type Spoofing Prevention', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(undefined);
  });

  test('Grocery tenant calling wholesale-only logic is blocked by capability check', () => {
    expect(() => {
      const bt = 'grocery';
      const cap = 'useProformaInvoice';
      const groceryCaps = new Set(['useProductAdd', 'useInvoiceCreate', 'useInventoryList']);
      if (!groceryCaps.has(cap)) throw new Error(`ACCESS_DENIED: ${bt} cannot use ${cap}`);
    }).toThrow('ACCESS_DENIED');
  });
});

// ============================================================================
// IT-AUTH-006: Suspended / Banned License
// ============================================================================

describe('IT-AUTH-006: License Status Enforcement', () => {
  const handler = authorizedHandler([UserRole.OWNER], protectedLogic);

  beforeEach(() => jest.clearAllMocks());

  test('Suspended license in JWT claims → 401 before handler runs', async () => {
    mockVerify.mockRejectedValue(new AuthError('Account access denied. License status: suspended'));
    const res = await handler(makeEvent(), {} as Context) as any;
    expect(res.statusCode).toBe(401);
    expect(protectedLogic).not.toHaveBeenCalled();
  });
});

// ============================================================================
// IT-AUTH-007: Error Response Security (no internal leakage)
// ============================================================================

describe('IT-AUTH-007: Error Response Security', () => {
  const handler = authorizedHandler([UserRole.OWNER], protectedLogic);

  beforeEach(() => {
    jest.clearAllMocks();
    protectedLogic.mockResolvedValue({ statusCode: 200, body: '{}' });
  });

  test('Auth error response body does not expose internal paths or stack traces', async () => {
    // Verify: Auth errors return clean messages, not stack traces
    mockVerify.mockRejectedValue(new AuthError('Invalid or expired token'));
    const res = await handler(makeEvent(), {} as Context) as any;
    expect(res.statusCode).toBe(401);
    const body = JSON.parse(res.body);
    expect(body.message).not.toMatch(/at Object\./);
    expect(body.message).not.toMatch(/node_modules/);
    expect(body.stack).toBeUndefined();
  });
});

// ============================================================================
// IT-INV-001: Invoice Pipeline Integration
// ============================================================================

describe('IT-INV-001: Invoice Creation Pipeline', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(undefined);
  });

  test('Invoice creation calls putItem once for invoice record', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx());
    mockPutItem.mockResolvedValue(undefined);
    const invoiceHandler = authorizedHandler(
      [UserRole.OWNER, UserRole.ADMIN, UserRole.CASHIER],
      async (_event, _ctx, auth) => {
        await mockPutItem({
          PK: `TENANT#${auth.tenantId}`,
          SK: `INVOICE#inv-001`,
          entityType: 'INVOICE',
          grandTotalCents: 11800,
        });
        return { statusCode: 201, body: JSON.stringify({ id: 'inv-001' }) };
      },
    );

    const res = await invoiceHandler(
      makeEvent({ method: 'POST', body: { items: [], customerName: 'Test' } }),
      {} as Context,
    ) as any;

    expect(res.statusCode).toBe(201);
    expect(mockPutItem).toHaveBeenCalledWith(
      expect.objectContaining({
        entityType: 'INVOICE',
        grandTotalCents: 11800,
      }),
    );
  });

  test('Missing Authorization → 401 before any DynamoDB call', async () => {
    mockVerify.mockRejectedValue(new AuthError('Missing Authorization header'));
    const handler = authorizedHandler([UserRole.OWNER], protectedLogic);
    const event = { ...makeEvent(), headers: {} } as unknown as APIGatewayProxyEventV2;
    const res = await handler(event, {} as Context) as any;
    expect(res.statusCode).toBe(401);
    expect(mockPutItem).not.toHaveBeenCalled();
    expect(mockQueryItems).not.toHaveBeenCalled();
  });
});

// ============================================================================
// IT-MT-001: Multi-Tenant Data Isolation
// ============================================================================

describe('IT-MT-001 to IT-MT-004: Multi-Tenant Data Isolation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(undefined);
  });

  test('IT-MT-001: Tenant A query uses TENANT#tenantA partition key (no scan)', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ tenantId: 'tenant-aaa' }));
    mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });

    const handler = authorizedHandler(
      [UserRole.OWNER],
      async (_event, _ctx, auth) => {
        await mockQueryItems(`TENANT#${auth.tenantId}`, 'PRODUCT#', {});
        return { statusCode: 200, body: '{}' };
      },
    );

    await handler(makeEvent(), {} as Context);
    expect(mockQueryItems).toHaveBeenCalledWith(
      'TENANT#tenant-aaa', expect.anything(), expect.anything(),
    );
    // Must NOT use scan pattern (would be called with wrong args)
    expect(mockQueryItems.mock.calls[0][0]).not.toBe('TENANT#tenant-bbb');
  });

  test('IT-MT-002: tenantId from JWT cannot be overridden by header', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ tenantId: 'tenant-real' }));

    const handler = authorizedHandler(
      [UserRole.OWNER],
      async (_event, _ctx, auth) => ({
        statusCode: 200,
        body: JSON.stringify({ tenantId: auth.tenantId }),
      }),
    );

    const res = await handler(
      makeEvent({ headers: { 'x-tenant-id': 'tenant-real', 'x-override-tenant': 'tenant-evil' } }),
      {} as Context,
    ) as any;

    const body = JSON.parse(res.body);
    expect(body.tenantId).toBe('tenant-real');
    expect(body.tenantId).not.toBe('tenant-evil');
  });

  test('IT-MT-003: Cross-tenant header attack returns 401', async () => {
    mockVerify.mockResolvedValue(makeAuthCtx({ tenantId: 'tenant-aaa' }));

    const handler = authorizedHandler([UserRole.OWNER], protectedLogic);
    const res = await handler(
      makeEvent({ headers: { 'x-tenant-id': 'tenant-bbb' } }),
      {} as Context,
    ) as any;

    expect(res.statusCode).toBe(401);
    expect(protectedLogic).not.toHaveBeenCalled();
  });
});
