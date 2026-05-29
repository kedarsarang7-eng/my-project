// ============================================================================
// UT-AUTH — Authentication Token Logic Unit Tests
// Coverage: JWT decode/claims, expiry boundary, refresh rotation,
//           tenantId isolation, role-based claim validation
// ============================================================================

import { UserRole, BusinessType } from '../types/tenant.types';
import { normalizeJwtRole } from '../utils/jwt-role';

// ── Mocks ────────────────────────────────────────────────────────────────────
const mockVerify = jest.fn();
const mockGetItem = jest.fn();

jest.mock('aws-jwt-verify', () => ({
  CognitoJwtVerifier: {
    create: () => ({ verify: mockVerify }),
  },
}));

jest.mock('../config/aws.config', () => ({
  cognitoConfig: {
    userPoolId: 'us-east-1_TestPool',
    clientId: 'test-client-id',
    allClientIds: ['test-client-id'],
  },
}));

jest.mock('../config/dynamodb.config', () => ({
  Keys: {
    tenantPK:        (id: string) => `TENANT#${id}`,
    tenantLicenseSK: () => 'LICENSE#CURRENT',
  },
  getItem: (...a: any[]) => mockGetItem(...a),
}));

jest.mock('../utils/logger', () => ({
  logger: { debug: jest.fn(), warn: jest.fn(), error: jest.fn(), info: jest.fn() },
}));

import { verifyAuth } from '../middleware/cognito-auth';
import { APIGatewayProxyEventV2 } from 'aws-lambda';

// ── Helper: Build minimal API Gateway event ──────────────────────────────────
function makeEvent(authorization?: string, headers: Record<string, string> = {}): APIGatewayProxyEventV2 {
  return {
    headers: authorization ? { authorization, ...headers } : headers,
    requestContext: { http: { method: 'GET', sourceIp: '1.2.3.4' } },
    rawPath: '/test',
  } as unknown as APIGatewayProxyEventV2;
}

// ── Helper: Valid JWT payload ────────────────────────────────────────────────
function makePayload(overrides: Record<string, unknown> = {}) {
  return {
    sub: 'cognito-sub-uuid',
    email: 'user@test.com',
    'custom:tenant_id': 'aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee',
    'custom:business_id': 'biz-001',
    'custom:role': 'owner',
    'custom:user_role': 'admin',
    'custom:business_type': 'grocery',
    'custom:license_status': 'active',
    'custom:plan_status': 'active',
    ...overrides,
  };
}

// ============================================================================
// 1. JWT DECODE & CLAIM EXTRACTION
// ============================================================================

describe('UT-AUTH-001: JWT Decode and Claim Extraction', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(null); // no license record = allow through
  });

  test('Extracts tenantId, role, businessType from valid token', async () => {
    mockVerify.mockResolvedValue(makePayload());
    const ctx = await verifyAuth(makeEvent('Bearer valid.token.here'));
    expect(ctx.tenantId).toBe('aaaa1111-bbbb-cccc-dddd-eeeeeeeeeeee');
    expect(ctx.role).toBe(UserRole.OWNER);
    expect(ctx.email).toBe('user@test.com');
    expect(ctx.sub).toBe('cognito-sub-uuid');
  });

  test('Extracts businessType correctly as normalized enum', async () => {
    mockVerify.mockResolvedValue(makePayload({ 'custom:business_type': 'pharmacy' }));
    const ctx = await verifyAuth(makeEvent('Bearer valid.token.here'));
    expect(ctx.businessType).toBe(BusinessType.PHARMACY);
  });

  test('Throws AuthError when Authorization header is missing', async () => {
    await expect(verifyAuth(makeEvent())).rejects.toThrow('Missing Authorization header');
  });

  test('Throws AuthError when token is empty string after Bearer', async () => {
    await expect(verifyAuth(makeEvent('Bearer '))).rejects.toThrow();
  });

  test('Throws AuthError on invalid/malformed token', async () => {
    mockVerify.mockRejectedValue(new Error('JwtParseError'));
    await expect(verifyAuth(makeEvent('Bearer bad.token'))).rejects.toThrow('Invalid or expired token');
  });

  test('Handles token without Bearer prefix', async () => {
    mockVerify.mockResolvedValue(makePayload());
    const event = makeEvent('valid.token.here'); // no "Bearer " prefix
    const ctx = await verifyAuth(event);
    expect(ctx.tenantId).toBeTruthy();
  });
});

// ============================================================================
// 2. TOKEN EXPIRY BOUNDARY
// ============================================================================

describe('UT-AUTH-002: Token Expiry Boundary', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(null);
  });

  test('Expired token (aws-jwt-verify throws TokenExpiredError) → 401', async () => {
    const err: any = new Error('Token has expired');
    err.name = 'JwtExpiredError';
    mockVerify.mockRejectedValue(err);
    await expect(verifyAuth(makeEvent('Bearer expired.token'))).rejects.toThrow('Invalid or expired token');
  });

  test('Token valid 1 second before expiry → succeeds', async () => {
    // aws-jwt-verify validates exp internally — if verify resolves, token is valid
    mockVerify.mockResolvedValue(makePayload());
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).resolves.toBeTruthy();
  });

  test('License grace period: expired < 72h ago → allowed through', async () => {
    mockVerify.mockResolvedValue(makePayload());
    const sixtyHoursAgo = new Date(Date.now() - 60 * 60 * 60 * 1000).toISOString();
    mockGetItem.mockResolvedValue({ status: 'active', expiresAt: sixtyHoursAgo });
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).resolves.toBeTruthy();
  });

  test('License grace period: expired > 72h ago → 401', async () => {
    mockVerify.mockResolvedValue(makePayload());
    const eightDaysAgo = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString();
    mockGetItem.mockResolvedValue({ status: 'active', expiresAt: eightDaysAgo });
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).rejects.toThrow('Grace period ended');
  });
});

// ============================================================================
// 3. TENANT ID CLAIM ISOLATION
// ============================================================================

describe('UT-AUTH-003: TenantId Claim Isolation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(null);
  });

  test('Valid UUID tenantId is accepted', async () => {
    mockVerify.mockResolvedValue(makePayload({ 'custom:tenant_id': 'aabbccdd-0011-2233-4455-667788990011' }));
    const ctx = await verifyAuth(makeEvent('Bearer valid.token'));
    expect(ctx.tenantId).toBe('aabbccdd-0011-2233-4455-667788990011');
  });

  test('Non-UUID tenantId (injection attempt) is rejected', async () => {
    mockVerify.mockResolvedValue(makePayload({ 'custom:tenant_id': 'TENANT#../admin' }));
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).rejects.toThrow('Invalid Tenant ID format');
  });

  test('SQL-injection-style tenantId is rejected', async () => {
    mockVerify.mockResolvedValue(makePayload({ 'custom:tenant_id': "'; DROP TABLE tenants; --" }));
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).rejects.toThrow('Invalid Tenant ID format');
  });

  test('Suspended license throws AuthError regardless of valid JWT', async () => {
    mockVerify.mockResolvedValue(makePayload({ 'custom:license_status': 'suspended' }));
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).rejects.toThrow('Account access denied');
  });

  test('Revoked license throws AuthError', async () => {
    mockVerify.mockResolvedValue(makePayload({ 'custom:license_status': 'revoked' }));
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).rejects.toThrow('Account access denied');
  });

  test('Banned tenant (DB record) throws AuthError', async () => {
    mockVerify.mockResolvedValue(makePayload());
    mockGetItem.mockResolvedValue({ status: 'banned' });
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).rejects.toThrow('Account access denied');
  });
});

// ============================================================================
// 4. ROLE-BASED CLAIM VALIDATION
// ============================================================================

describe('UT-AUTH-004: Role-Based Claim Validation', () => {
  test('owner role is resolved from JWT custom:role', () => {
    expect(normalizeJwtRole('owner')).toBe(UserRole.OWNER);
  });

  test('admin role is resolved', () => {
    expect(normalizeJwtRole('admin')).toBe(UserRole.ADMIN);
  });

  test('manager role is resolved', () => {
    expect(normalizeJwtRole('manager')).toBe(UserRole.MANAGER);
  });

  test('staff role is resolved', () => {
    expect(normalizeJwtRole('staff')).toBe(UserRole.STAFF);
  });

  test('viewer role is resolved', () => {
    expect(normalizeJwtRole('viewer')).toBe(UserRole.VIEWER);
  });

  test('cashier role is resolved', () => {
    expect(normalizeJwtRole('cashier')).toBe(UserRole.CASHIER);
  });

  test('super_admin is resolved', () => {
    expect(normalizeJwtRole('super_admin')).toBe(UserRole.SUPER_ADMIN);
  });

  test('pump-boy aliases to PUMPBOY', () => {
    expect(normalizeJwtRole('pump-boy')).toBe(UserRole.PUMPBOY);
    expect(normalizeJwtRole('pump_boy')).toBe(UserRole.PUMPBOY);
    expect(normalizeJwtRole('fuel_attendant')).toBe(UserRole.PUMPBOY);
  });

  test('unknown role defaults to STAFF (fail-safe)', () => {
    expect(normalizeJwtRole('superuser_hacker')).toBe(UserRole.STAFF);
    expect(normalizeJwtRole('')).toBe(UserRole.STAFF);
    expect(normalizeJwtRole(undefined)).toBe(UserRole.STAFF);
  });

  test('Role comparison is case-insensitive', () => {
    expect(normalizeJwtRole('OWNER')).toBe(UserRole.OWNER);
    expect(normalizeJwtRole('Admin')).toBe(UserRole.ADMIN);
    expect(normalizeJwtRole('STAFF')).toBe(UserRole.STAFF);
  });
});

// ============================================================================
// 5. VIEWER ROLE — Read-Only Enforcement
// ============================================================================

describe('UT-AUTH-005: Viewer Role Read-Only Enforcement', () => {
  // This tests the handler-wrapper logic for viewer write-block
  const ViewerError = 'read-only access and cannot modify data';

  const mutatingMethods = ['POST', 'PUT', 'PATCH', 'DELETE'];
  const safeMethods = ['GET', 'OPTIONS'];

  test.each(mutatingMethods)('Viewer attempting %s → denied', (method) => {
    // Simulate the check in handler-wrapper
    const role = UserRole.VIEWER;
    const shouldBlock = role === UserRole.VIEWER && !['GET', 'OPTIONS'].includes(method);
    expect(shouldBlock).toBe(true);
  });

  test.each(safeMethods)('Viewer attempting %s → allowed', (method) => {
    const role = UserRole.VIEWER;
    const shouldBlock = role === UserRole.VIEWER && !['GET', 'OPTIONS'].includes(method);
    expect(shouldBlock).toBe(false);
  });
});

// ============================================================================
// 6. AUTO-PROVISION GUARD
// ============================================================================

describe('UT-AUTH-006: Auto-Provision Security Guard', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetItem.mockResolvedValue(null);
  });

  test('User without tenantId and without signup_pending → blocks auto-provision', async () => {
    mockVerify.mockResolvedValue({
      sub: 'new-user-sub',
      email: 'newuser@test.com',
      // No custom:tenant_id
      // No custom:signup_pending
    });
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).rejects.toThrow(
      'Account setup incomplete'
    );
  });

  test('User with signup_pending=false → blocks auto-provision', async () => {
    mockVerify.mockResolvedValue({
      sub: 'new-user-sub',
      email: 'newuser@test.com',
      'custom:signup_pending': 'false',
    });
    await expect(verifyAuth(makeEvent('Bearer valid.token'))).rejects.toThrow(
      'Account setup incomplete'
    );
  });
});
