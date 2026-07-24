/**
 * Auth Middleware Tests — MobileShop Authorization
 *
 * Verifies:
 * - Missing/invalid JWT → 401 (non-disclosing)
 * - Wrong business type → 403 (non-disclosing)
 * - Missing tenant_id → 403
 * - Missing permission → 403
 * - Valid auth + permission → handler called with TenantContext
 * - Client-supplied tenantId in body is stripped/ignored
 * - Correlation ID generated if absent, extracted if present
 *
 * Requirements: 6.5–6.6, 6.19, 8.3–8.10, 13.1, 13.6
 */

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import {
  mobileShopHandler,
  parseSanitizedBody,
  type MobileShopHandlerFn,
} from '../auth-middleware';
import { TenantContext } from '../tenant-context';
import { MOBILE_SHOP_PERMISSIONS } from '../../permissions/mobile-shop-permissions';

// ─── Mock Dependencies ──────────────────────────────────────────────────────

jest.mock('../../../../middleware/cognito-auth');
jest.mock('../../../../utils/logger', () => ({
  logger: { debug: jest.fn(), warn: jest.fn(), error: jest.fn(), info: jest.fn() },
}));
jest.mock('uuid', () => ({ v4: () => 'generated-correlation-id' }));

const { verifyAuth, AuthError } = jest.requireMock('../../../../middleware/cognito-auth') as {
  verifyAuth: jest.Mock;
  AuthError: new (msg: string, code?: number) => Error;
};

// ─── Fixtures ───────────────────────────────────────────────────────────────

function makeEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
  return {
    version: '2.0',
    routeKey: 'POST /api/v1/mobile-shop/test',
    rawPath: '/api/v1/mobile-shop/test',
    rawQueryString: '',
    headers: { authorization: 'Bearer valid-token' },
    requestContext: {
      accountId: '123',
      apiId: 'api',
      domainName: 'test.example.com',
      domainPrefix: 'test',
      http: { method: 'POST', path: '/test', protocol: 'HTTP/1.1', sourceIp: '127.0.0.1', userAgent: 'test' },
      requestId: 'req-1',
      routeKey: 'POST /test',
      stage: '$default',
      time: '2024-01-01T00:00:00Z',
      timeEpoch: 0,
    },
    isBase64Encoded: false,
    ...overrides,
  } as APIGatewayProxyEventV2;
}

const mockLambdaContext: Context = {
  callbackWaitsForEmptyEventLoop: false,
  functionName: 'test',
  functionVersion: '1',
  invokedFunctionArn: 'arn:aws:lambda:us-east-1:123:function:test',
  memoryLimitInMB: '128',
  awsRequestId: 'req-1',
  logGroupName: '/aws/lambda/test',
  logStreamName: 'stream',
  getRemainingTimeInMillis: () => 5000,
  done: jest.fn(),
  fail: jest.fn(),
  succeed: jest.fn(),
};

const validAuthContext = {
  sub: 'user-001',
  email: 'user@test.com',
  tenantId: 'tenant-001',
  role: 'owner' as const,
  businessType: 'mobileShop' as const,
};

/** Extract statusCode/body from the result (handles union type) */
function parseResult(result: any): { statusCode: number; body: any } {
  return {
    statusCode: result.statusCode,
    body: typeof result.body === 'string' ? JSON.parse(result.body) : result.body,
  };
}

// ─── Tests ──────────────────────────────────────────────────────────────────

describe('mobileShopHandler', () => {
  let capturedContext: TenantContext | null = null;
  const successHandler: MobileShopHandlerFn = async (_event, _ctx, tenantCtx) => {
    capturedContext = tenantCtx;
    return { statusCode: 200, body: JSON.stringify({ ok: true }) };
  };

  beforeEach(() => {
    capturedContext = null;
    jest.clearAllMocks();
  });

  // ── Authentication Failures ─────────────────────────────────────────────

  it('returns 401 (non-disclosing) when JWT is missing', async () => {
    verifyAuth.mockRejectedValue(
      new (jest.requireMock('../../../../middleware/cognito-auth').AuthError)('Missing Authorization header'),
    );

    const handler = mobileShopHandler({}, successHandler);
    const raw = await handler(makeEvent({ headers: {} }), mockLambdaContext);
    const result = parseResult(raw);

    expect(result.statusCode).toBe(401);
    expect(result.body.error).toBe('UNAUTHORIZED');
    expect(result.body.message).toBe('Authentication required');
    // Non-disclosing: no entity details
    expect(result.body).not.toHaveProperty('tenantId');
    expect(result.body).not.toHaveProperty('entityId');
  });

  it('returns 401 (non-disclosing) when JWT is invalid', async () => {
    verifyAuth.mockRejectedValue(
      new (jest.requireMock('../../../../middleware/cognito-auth').AuthError)('Invalid or expired token'),
    );

    const handler = mobileShopHandler({}, successHandler);
    const raw = await handler(makeEvent(), mockLambdaContext);
    const result = parseResult(raw);

    expect(result.statusCode).toBe(401);
    expect(result.body.error).toBe('UNAUTHORIZED');
    expect(result.body.message).toBe('Authentication required');
  });

  // ── Business Type Failures ──────────────────────────────────────────────

  it('returns 403 (non-disclosing) for wrong business type: grocery', async () => {
    verifyAuth.mockResolvedValue({
      ...validAuthContext,
      businessType: 'grocery',
    });

    const handler = mobileShopHandler({}, successHandler);
    const raw = await handler(makeEvent(), mockLambdaContext);
    const result = parseResult(raw);

    expect(result.statusCode).toBe(403);
    expect(result.body.error).toBe('ACCESS_DENIED');
    expect(result.body.message).toBe('Access denied');
    // Non-disclosing: no entity/reason details
    expect(result.body).not.toHaveProperty('businessType');
    expect(result.body).not.toHaveProperty('reason');
  });

  it('returns 403 (non-disclosing) for wrong business type: electronics', async () => {
    verifyAuth.mockResolvedValue({
      ...validAuthContext,
      businessType: 'electronics',
    });

    const handler = mobileShopHandler({}, successHandler);
    const raw = await handler(makeEvent(), mockLambdaContext);
    const result = parseResult(raw);

    expect(result.statusCode).toBe(403);
    expect(result.body.error).toBe('ACCESS_DENIED');
  });

  // ── Missing Tenant/Permission ───────────────────────────────────────────

  it('returns 403 when tenant_id is missing from claims', async () => {
    verifyAuth.mockResolvedValue({
      ...validAuthContext,
      tenantId: '', // Empty tenant
    });

    const handler = mobileShopHandler({}, successHandler);
    const raw = await handler(makeEvent(), mockLambdaContext);
    const result = parseResult(raw);

    expect(result.statusCode).toBe(403);
    expect(result.body.error).toBe('ACCESS_DENIED');
  });

  it('returns 403 when required permission is missing', async () => {
    // Staff role has limited permissions (no FINANCE_MANAGE)
    verifyAuth.mockResolvedValue({
      ...validAuthContext,
      role: 'staff',
    });

    const handler = mobileShopHandler(
      { requiredPermissions: [MOBILE_SHOP_PERMISSIONS.FINANCE_MANAGE] },
      successHandler,
    );
    const raw = await handler(makeEvent(), mockLambdaContext);
    const result = parseResult(raw);

    expect(result.statusCode).toBe(403);
    expect(result.body.error).toBe('ACCESS_DENIED');
  });

  // ── Successful Authorization ────────────────────────────────────────────

  it('calls handler with TenantContext when auth and permission pass', async () => {
    verifyAuth.mockResolvedValue(validAuthContext);

    const handler = mobileShopHandler(
      { requiredPermissions: [MOBILE_SHOP_PERMISSIONS.IMEI_VIEW] },
      successHandler,
    );
    const raw = await handler(makeEvent(), mockLambdaContext);
    const result = parseResult(raw);

    expect(result.statusCode).toBe(200);
    expect(capturedContext).not.toBeNull();
    expect(capturedContext!.tenantId).toBe('tenant-001');
    expect(capturedContext!.businessType).toBe('mobile_shop');
    expect(capturedContext!.subjectId).toBe('user-001');
    expect(capturedContext!.permissions).toBeInstanceOf(Set);
  });

  it('calls handler without required permissions when none specified', async () => {
    verifyAuth.mockResolvedValue(validAuthContext);

    const handler = mobileShopHandler({}, successHandler);
    const raw = await handler(makeEvent(), mockLambdaContext);
    const result = parseResult(raw);

    expect(result.statusCode).toBe(200);
    expect(capturedContext).not.toBeNull();
  });

  // ── Correlation ID ──────────────────────────────────────────────────────

  it('generates a correlation ID when header is absent', async () => {
    verifyAuth.mockResolvedValue(validAuthContext);

    const handler = mobileShopHandler({}, successHandler);
    await handler(makeEvent({ headers: { authorization: 'Bearer token' } }), mockLambdaContext);

    expect(capturedContext!.correlationId).toBe('generated-correlation-id');
  });

  it('extracts correlation ID from X-Correlation-Id header', async () => {
    verifyAuth.mockResolvedValue(validAuthContext);

    const handler = mobileShopHandler({}, successHandler);
    await handler(
      makeEvent({
        headers: {
          authorization: 'Bearer token',
          'x-correlation-id': 'client-corr-123',
        },
      }),
      mockLambdaContext,
    );

    expect(capturedContext!.correlationId).toBe('client-corr-123');
  });
});

// ─── parseSanitizedBody Tests ─────────────────────────────────────────────

describe('parseSanitizedBody', () => {
  it('strips client-supplied tenantId from body', () => {
    const event = makeEvent({
      body: JSON.stringify({
        tenantId: 'attacker-tenant',
        tenant_id: 'attacker-tenant-2',
        ownerId: 'attacker-owner',
        owner_id: 'attacker-owner-2',
        businessId: 'attacker-biz',
        business_id: 'attacker-biz-2',
        subjectId: 'attacker-sub',
        subject_id: 'attacker-sub-2',
        validField: 'preserved',
      }),
    });

    const result = parseSanitizedBody(event);

    expect(result).not.toBeNull();
    expect(result).not.toHaveProperty('tenantId');
    expect(result).not.toHaveProperty('tenant_id');
    expect(result).not.toHaveProperty('ownerId');
    expect(result).not.toHaveProperty('owner_id');
    expect(result).not.toHaveProperty('businessId');
    expect(result).not.toHaveProperty('business_id');
    expect(result).not.toHaveProperty('subjectId');
    expect(result).not.toHaveProperty('subject_id');
    expect(result!.validField).toBe('preserved');
  });

  it('returns null for missing body', () => {
    const event = makeEvent({ body: undefined });
    expect(parseSanitizedBody(event)).toBeNull();
  });

  it('returns null for invalid JSON body', () => {
    const event = makeEvent({ body: 'not-json' });
    expect(parseSanitizedBody(event)).toBeNull();
  });
});
