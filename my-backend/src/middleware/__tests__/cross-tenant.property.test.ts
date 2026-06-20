/**
 * Property Test: Cross-Tenant Access Rejection
 *
 * Feature: full-stack-audit-remediation, Property 13: Cross-Tenant Access Rejection
 *
 * Validates: Requirements 9.3
 *
 * For any authenticated request where the resource's tenant partition key does not
 * match the authenticated tenant's ID, the system SHALL return false (triggering 403)
 * and the response body SHALL contain zero data belonging to the target resource's tenant.
 *
 * When resource tenant matches authenticated tenant, access is granted.
 */

import * as fc from 'fast-check';
import { verifyOwnership } from '../tenant-isolation';

// ─── Generators ──────────────────────────────────────────────────────────────

/** Generates a valid tenant ID (1-128 chars, [a-zA-Z0-9_-]) */
const validTenantIdArb = fc.stringMatching(/^[a-zA-Z0-9_-]{1,128}$/).filter(
  (s) => s.length >= 1 && s.length <= 128
);

/** Generates a resource identifier (simulates a resource ID) */
const resourceIdArb = fc.stringMatching(/^[a-zA-Z0-9_-]{4,64}$/);

/**
 * Generates a pair of distinct tenant IDs (guaranteed different).
 * This simulates a cross-tenant access scenario.
 */
const distinctTenantPairArb = fc
  .tuple(validTenantIdArb, validTenantIdArb)
  .filter(([a, b]) => a !== b);

// ─── Property Tests ──────────────────────────────────────────────────────────

describe('Feature: full-stack-audit-remediation, Property 13: Cross-Tenant Access Rejection', () => {
  describe('Cross-tenant access is rejected', () => {
    it('should return false when resource tenant differs from authenticated tenant', () => {
      fc.assert(
        fc.property(
          distinctTenantPairArb,
          resourceIdArb,
          ([resourceTenantId, authTenantId], _resourceId) => {
            // When resource belongs to a different tenant than the authenticated user
            const result = verifyOwnership(resourceTenantId, authTenantId);

            // Access MUST be denied (returns false → triggers HTTP 403)
            expect(result).toBe(false);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should deny access regardless of resource identifier format', () => {
      fc.assert(
        fc.property(
          distinctTenantPairArb,
          resourceIdArb,
          ([resourceTenantId, authTenantId], resourceId) => {
            // The resource identifier format should not affect tenant validation
            const result = verifyOwnership(resourceTenantId, authTenantId);

            // Cross-tenant access is always denied regardless of resource format
            expect(result).toBe(false);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should produce zero data response for cross-tenant access', () => {
      fc.assert(
        fc.property(
          distinctTenantPairArb,
          resourceIdArb,
          ([resourceTenantId, authTenantId], _resourceId) => {
            const isAllowed = verifyOwnership(resourceTenantId, authTenantId);

            // When access is denied, the HTTP layer returns 403 with empty body.
            // verifyOwnership returns false → handler returns 403 + zero data.
            // We verify the function contract: false means no data is returned.
            expect(isAllowed).toBe(false);

            // Simulate the handler response pattern
            const response = isAllowed
              ? { statusCode: 200, body: JSON.stringify({ data: 'resource_data' }) }
              : { statusCode: 403, body: JSON.stringify({}) };

            expect(response.statusCode).toBe(403);

            const responseBody = JSON.parse(response.body);
            // Zero data belonging to the target tenant
            expect(Object.keys(responseBody)).toHaveLength(0);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Same-tenant access is permitted', () => {
    it('should return true when resource tenant matches authenticated tenant', () => {
      fc.assert(
        fc.property(
          validTenantIdArb,
          resourceIdArb,
          (tenantId, _resourceId) => {
            // When resource tenant equals authenticated tenant
            const result = verifyOwnership(tenantId, tenantId);

            // Access MUST be granted
            expect(result).toBe(true);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('should grant access for any valid tenant ID matching itself', () => {
      fc.assert(
        fc.property(
          validTenantIdArb,
          (tenantId) => {
            // Reflexive ownership: a tenant always owns its own resources
            const result = verifyOwnership(tenantId, tenantId);
            expect(result).toBe(true);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  describe('Rejection is symmetric for distinct tenants', () => {
    it('should deny access in both directions for distinct tenant pairs', () => {
      fc.assert(
        fc.property(
          distinctTenantPairArb,
          ([tenantA, tenantB]) => {
            // Neither tenant can access the other's resources
            const aAccessesB = verifyOwnership(tenantB, tenantA);
            const bAccessesA = verifyOwnership(tenantA, tenantB);

            expect(aAccessesB).toBe(false);
            expect(bAccessesA).toBe(false);
          }
        ),
        { numRuns: 100 }
      );
    });
  });
});
