// ============================================================================
// Unit Tests: Tenant ID Extraction and Validation
// ============================================================================
// Tests for extractTenantId() and validateTenantIdFormat() from
// the tenant-isolation middleware module.
// Validates: Requirement 9.2
// ============================================================================

import {
  extractTenantId,
  validateTenantIdFormat,
  scopeToTenant,
  verifyOwnership,
  logSecurityEvent,
  TENANT_ID_PATTERN,
  TenantValidation,
} from '../tenant-isolation';

// Mock the logger to prevent console output during tests
jest.mock('../../utils/logger', () => ({
  logger: {
    debug: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

// ── validateTenantIdFormat ────────────────────────────────────────────────────

describe('validateTenantIdFormat', () => {
  it('accepts a simple alphanumeric tenant ID', () => {
    expect(validateTenantIdFormat('tenant123')).toBe(true);
  });

  it('accepts tenant ID with hyphens and underscores', () => {
    expect(validateTenantIdFormat('tenant-123_abc')).toBe(true);
  });

  it('accepts a single character tenant ID', () => {
    expect(validateTenantIdFormat('a')).toBe(true);
  });

  it('accepts a 128-character tenant ID (max length)', () => {
    const maxId = 'a'.repeat(128);
    expect(validateTenantIdFormat(maxId)).toBe(true);
  });

  it('rejects an empty string', () => {
    expect(validateTenantIdFormat('')).toBe(false);
  });

  it('rejects a tenant ID longer than 128 characters', () => {
    const tooLong = 'a'.repeat(129);
    expect(validateTenantIdFormat(tooLong)).toBe(false);
  });

  it('rejects tenant ID with special characters (spaces)', () => {
    expect(validateTenantIdFormat('tenant 123')).toBe(false);
  });

  it('rejects tenant ID with dots', () => {
    expect(validateTenantIdFormat('tenant.123')).toBe(false);
  });

  it('rejects tenant ID with @', () => {
    expect(validateTenantIdFormat('tenant@123')).toBe(false);
  });

  it('rejects tenant ID with slashes', () => {
    expect(validateTenantIdFormat('tenant/123')).toBe(false);
  });

  it('rejects tenant ID with newlines', () => {
    expect(validateTenantIdFormat('tenant\n123')).toBe(false);
  });

  it('rejects tenant ID with unicode characters', () => {
    expect(validateTenantIdFormat('tenant™')).toBe(false);
  });
});

// ── extractTenantId ──────────────────────────────────────────────────────────

describe('extractTenantId', () => {
  describe('successful extraction', () => {
    it('extracts from authorizer.claims["custom:tenantId"]', () => {
      const event = {
        requestContext: {
          authorizer: {
            claims: { 'custom:tenantId': 'my-tenant-01' },
          },
        },
      };
      const result = extractTenantId(event);
      expect(result).toEqual({ valid: true, tenantId: 'my-tenant-01' });
    });

    it('extracts from authorizer.claims["custom:tenant_id"]', () => {
      const event = {
        requestContext: {
          authorizer: {
            claims: { 'custom:tenant_id': 'tenant_abc-123' },
          },
        },
      };
      const result = extractTenantId(event);
      expect(result).toEqual({ valid: true, tenantId: 'tenant_abc-123' });
    });

    it('extracts from authorizer.jwt.claims["custom:tenantId"]', () => {
      const event = {
        requestContext: {
          authorizer: {
            jwt: { claims: { 'custom:tenantId': 'jwt-tenant-99' } },
          },
        },
      };
      const result = extractTenantId(event);
      expect(result).toEqual({ valid: true, tenantId: 'jwt-tenant-99' });
    });

    it('extracts from authorizer.jwt.claims["custom:tenant_id"]', () => {
      const event = {
        requestContext: {
          authorizer: {
            jwt: { claims: { 'custom:tenant_id': 'jwt_tenant_99' } },
          },
        },
      };
      const result = extractTenantId(event);
      expect(result).toEqual({ valid: true, tenantId: 'jwt_tenant_99' });
    });

    it('extracts from authorizer.jwt.claims.tenantId', () => {
      const event = {
        requestContext: {
          authorizer: {
            jwt: { claims: { tenantId: 'direct-tenant' } },
          },
        },
      };
      const result = extractTenantId(event);
      expect(result).toEqual({ valid: true, tenantId: 'direct-tenant' });
    });

    it('extracts from authorizer.tenantId (Lambda authorizer)', () => {
      const event = {
        requestContext: {
          authorizer: { tenantId: 'lambda-auth-tenant' },
        },
      };
      const result = extractTenantId(event);
      expect(result).toEqual({ valid: true, tenantId: 'lambda-auth-tenant' });
    });

    it('prefers claims path over direct authorizer property', () => {
      const event = {
        requestContext: {
          authorizer: {
            claims: { 'custom:tenantId': 'claims-tenant' },
            tenantId: 'direct-tenant',
          },
        },
      };
      const result = extractTenantId(event);
      expect(result).toEqual({ valid: true, tenantId: 'claims-tenant' });
    });
  });

  describe('rejection with HTTP 403 (absent/empty/invalid)', () => {
    it('rejects when event has no requestContext', () => {
      const result = extractTenantId({});
      expect(result.valid).toBe(false);
      expect(result.error).toBeDefined();
    });

    it('rejects when event has no authorizer', () => {
      const event = { requestContext: {} };
      const result = extractTenantId(event);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('No authorizer context');
    });

    it('rejects when claims have no tenant ID field', () => {
      const event = {
        requestContext: {
          authorizer: { claims: { sub: 'user-123', email: 'test@test.com' } },
        },
      };
      const result = extractTenantId(event);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('absent or empty');
    });

    it('rejects when tenant ID is an empty string', () => {
      const event = {
        requestContext: {
          authorizer: { claims: { 'custom:tenantId': '' } },
        },
      };
      const result = extractTenantId(event);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('absent or empty');
    });

    it('rejects when tenant ID is whitespace only', () => {
      const event = {
        requestContext: {
          authorizer: { claims: { 'custom:tenantId': '   ' } },
        },
      };
      const result = extractTenantId(event);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('absent or empty');
    });

    it('rejects when tenant ID exceeds 128 characters', () => {
      const longId = 'a'.repeat(200);
      const event = {
        requestContext: {
          authorizer: { claims: { 'custom:tenantId': longId } },
        },
      };
      const result = extractTenantId(event);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('format is invalid');
    });

    it('rejects when tenant ID has invalid characters', () => {
      const event = {
        requestContext: {
          authorizer: { claims: { 'custom:tenantId': 'tenant@hack!' } },
        },
      };
      const result = extractTenantId(event);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('format is invalid');
    });

    it('rejects null event', () => {
      const result = extractTenantId(null);
      expect(result.valid).toBe(false);
    });

    it('rejects undefined event', () => {
      const result = extractTenantId(undefined);
      expect(result.valid).toBe(false);
    });
  });
});

// ── TENANT_ID_PATTERN regex ──────────────────────────────────────────────────

describe('TENANT_ID_PATTERN', () => {
  it('matches valid UUID-like strings', () => {
    expect(TENANT_ID_PATTERN.test('550e8400-e29b-41d4-a716-446655440000')).toBe(true);
  });

  it('matches alphanumeric with underscores', () => {
    expect(TENANT_ID_PATTERN.test('tenant_123_ABC')).toBe(true);
  });

  it('does not match strings with colons', () => {
    expect(TENANT_ID_PATTERN.test('tenant:id')).toBe(false);
  });

  it('does not match empty string', () => {
    expect(TENANT_ID_PATTERN.test('')).toBe(false);
  });
});


// ============================================================================
// Unit Tests: scopeToTenant and verifyOwnership
// ============================================================================
// Tests for scopeToTenant() and verifyOwnership() from the tenant-isolation
// middleware module.
// Validates: Requirements 9.1, 9.3, 9.4
// ============================================================================

import { logger } from '../../utils/logger';

// ── scopeToTenant ────────────────────────────────────────────────────────────

describe('scopeToTenant', () => {
  const tenantId = 'tenant-abc-123';

  describe('query operations (KeyConditionExpression present)', () => {
    it('injects tenantId into an empty KeyConditionExpression scenario', () => {
      const params = {
        TableName: 'MyTable',
        KeyConditionExpression: 'PK = :pk',
        ExpressionAttributeValues: { ':pk': 'PRODUCT#123' },
      };

      const result = scopeToTenant(params, tenantId);

      expect(result.KeyConditionExpression).toBe('PK = :pk AND tenantId = :_tenantId');
      expect(result.ExpressionAttributeValues[':_tenantId']).toBe(tenantId);
      expect(result.ExpressionAttributeValues[':pk']).toBe('PRODUCT#123');
    });

    it('preserves existing ExpressionAttributeValues', () => {
      const params = {
        TableName: 'MyTable',
        KeyConditionExpression: 'PK = :pk AND SK = :sk',
        ExpressionAttributeValues: { ':pk': 'A', ':sk': 'B' },
      };

      const result = scopeToTenant(params, tenantId);

      expect(result.ExpressionAttributeValues[':pk']).toBe('A');
      expect(result.ExpressionAttributeValues[':sk']).toBe('B');
      expect(result.ExpressionAttributeValues[':_tenantId']).toBe(tenantId);
    });

    it('does not mutate the original params', () => {
      const params = {
        TableName: 'MyTable',
        KeyConditionExpression: 'PK = :pk',
        ExpressionAttributeValues: { ':pk': 'X' },
      };

      scopeToTenant(params, tenantId);

      expect(params.KeyConditionExpression).toBe('PK = :pk');
      expect(params.ExpressionAttributeValues).toEqual({ ':pk': 'X' });
    });
  });

  describe('put operations (Item present)', () => {
    it('adds tenantId to the item being written', () => {
      const params = {
        TableName: 'MyTable',
        Item: { PK: 'PRODUCT#1', name: 'Widget', price: 100 },
      };

      const result = scopeToTenant(params, tenantId);

      expect(result.Item.tenantId).toBe(tenantId);
      expect(result.Item.PK).toBe('PRODUCT#1');
      expect(result.Item.name).toBe('Widget');
    });

    it('does not mutate the original item', () => {
      const params = {
        TableName: 'MyTable',
        Item: { PK: 'PRODUCT#1', name: 'Widget' } as Record<string, any>,
      };

      scopeToTenant(params, tenantId);

      expect(params.Item.tenantId).toBeUndefined();
    });
  });

  describe('update operations (Key + UpdateExpression present)', () => {
    it('adds ConditionExpression for tenant ownership check', () => {
      const params = {
        TableName: 'MyTable',
        Key: { PK: 'PRODUCT#1', SK: 'META' },
        UpdateExpression: 'SET #name = :name',
        ExpressionAttributeValues: { ':name': 'New Name' },
      };

      const result = scopeToTenant(params, tenantId);

      expect(result.ConditionExpression).toBe('tenantId = :_tenantId');
      expect(result.ExpressionAttributeValues[':_tenantId']).toBe(tenantId);
      expect(result.ExpressionAttributeValues[':name']).toBe('New Name');
    });

    it('appends to existing ConditionExpression', () => {
      const params = {
        TableName: 'MyTable',
        Key: { PK: 'PRODUCT#1', SK: 'META' },
        UpdateExpression: 'SET stock = :stock',
        ConditionExpression: 'attribute_exists(PK)',
        ExpressionAttributeValues: { ':stock': 50 },
      };

      const result = scopeToTenant(params, tenantId);

      expect(result.ConditionExpression).toBe(
        'attribute_exists(PK) AND tenantId = :_tenantId',
      );
    });
  });

  describe('get/delete operations (Key only, no UpdateExpression, no Item)', () => {
    it('adds ConditionExpression for plain get/delete', () => {
      const params = {
        TableName: 'MyTable',
        Key: { PK: 'PRODUCT#1', SK: 'META' },
      };

      const result = scopeToTenant(params, tenantId);

      expect(result.ConditionExpression).toBe('tenantId = :_tenantId');
      expect(result.ExpressionAttributeValues[':_tenantId']).toBe(tenantId);
    });

    it('uses FilterExpression when FilterExpression is already present', () => {
      const params = {
        TableName: 'MyTable',
        Key: { PK: 'PRODUCT#1', SK: 'META' },
        FilterExpression: 'status = :status',
        ExpressionAttributeValues: { ':status': 'active' },
      };

      const result = scopeToTenant(params, tenantId);

      expect(result.FilterExpression).toBe('status = :status AND tenantId = :_tenantId');
      expect(result.ExpressionAttributeValues[':_tenantId']).toBe(tenantId);
      expect(result.ExpressionAttributeValues[':status']).toBe('active');
    });
  });

  describe('edge cases', () => {
    it('handles params with no ExpressionAttributeValues', () => {
      const params = {
        TableName: 'MyTable',
        KeyConditionExpression: 'PK = :pk',
      };

      const result = scopeToTenant(params, tenantId);

      expect(result.ExpressionAttributeValues[':_tenantId']).toBe(tenantId);
    });

    it('handles empty params object gracefully', () => {
      const params = {};

      const result = scopeToTenant(params, tenantId);

      // No operation type detected, returns params unchanged
      expect(result).toEqual({});
    });
  });
});

// ── verifyOwnership ──────────────────────────────────────────────────────────

describe('verifyOwnership', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns true when resourceTenantId matches authTenantId', () => {
    expect(verifyOwnership('tenant-123', 'tenant-123')).toBe(true);
  });

  it('returns false when resourceTenantId does not match authTenantId', () => {
    expect(verifyOwnership('tenant-A', 'tenant-B')).toBe(false);
  });

  it('logs a security event on cross-tenant access', () => {
    verifyOwnership('tenant-victim', 'tenant-attacker');

    expect(logger.warn).toHaveBeenCalledWith(
      'TENANT_ISOLATION_SECURITY_EVENT',
      expect.objectContaining({
        eventType: 'cross_tenant_access',
        authenticatedTenantId: 'tenant-attacker',
        targetResourceId: 'tenant-victim',
        operationType: 'resource_access',
      }),
    );
  });

  it('does not log a security event when ownership matches', () => {
    verifyOwnership('tenant-same', 'tenant-same');

    expect(logger.warn).not.toHaveBeenCalled();
  });

  it('treats empty string resourceTenantId vs non-empty authTenantId as mismatch', () => {
    expect(verifyOwnership('', 'tenant-123')).toBe(false);
  });

  it('treats different casing as mismatch (case-sensitive comparison)', () => {
    expect(verifyOwnership('Tenant-A', 'tenant-a')).toBe(false);
  });

  it('includes timestamp in the security event log', () => {
    const before = new Date().toISOString();
    verifyOwnership('tenant-A', 'tenant-B');

    const logCall = (logger.warn as jest.Mock).mock.calls[0];
    const loggedTimestamp = logCall[1].timestamp;

    // Timestamp should be a valid ISO string at or after 'before'
    expect(new Date(loggedTimestamp).getTime()).toBeGreaterThanOrEqual(
      new Date(before).getTime() - 1000, // Allow 1s tolerance
    );
  });
});
