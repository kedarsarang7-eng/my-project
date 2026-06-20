/**
 * Property-Based Test: DynamoDB Tenant Isolation Detection
 *
 * Feature: full-stack-audit-remediation, Property 6: DynamoDB Tenant Isolation Detection
 *
 * Validates: Requirements 4.2, 4.3
 *
 * For any DynamoDB operation extracted from a handler file, the analyzer SHALL
 * flag it as a P0 security issue if and only if neither the partition key
 * condition nor the filter expression references a tenant identifier matching
 * the configurable pattern (default: tenantId or tenant_id).
 */

import * as fc from 'fast-check';
import { hasTenantIsolation } from './dynamodb_analyzer';
import { DynamoDbOperation } from '../types';

// ── Generators ───────────────────────────────────────────────────────────────

/** Valid DynamoDB operation types */
const opTypeArb = fc.constantFrom<DynamoDbOperation['type']>(
  'get', 'put', 'query', 'scan', 'update', 'delete'
);

/** Generate a tenant identifier reference (various forms) */
const tenantRefArb = fc.constantFrom(
  'tenantId = :tid',
  'tenant_id = :tenantId',
  'tenantId = :tenantId',
  'TENANT#',
  'tenant_Id = :val',
  'TenantId = :id',
  'begins_with(PK, TENANT#)',
);

/** Generate a non-tenant key condition (no tenant reference at all) */
const nonTenantConditionArb = fc.constantFrom(
  'PK = :pk AND begins_with(SK, :sk)',
  'PK = :pk',
  'category = :cat AND status = :status',
  'userId = :uid',
  'orderId = :oid AND timestamp > :ts',
  'productId = :pid',
  '',
);

/** Generate a random table name */
const tableNameArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz-_'.split('')),
  { minLength: 3, maxLength: 20 }
);

/** Base DynamoDB operation without tenant references */
const baseOperationArb = fc.record({
  type: opTypeArb,
  tableName: tableNameArb,
  handlerFile: fc.constant('handler.ts'),
  lineNumber: fc.integer({ min: 1, max: 300 }),
  isDynamic: fc.constant(false),
});

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Property 6: DynamoDB Tenant Isolation Detection', () => {
  it('returns true (isolation present) IFF key condition contains tenant reference', () => {
    fc.assert(
      fc.property(
        baseOperationArb,
        tenantRefArb,
        nonTenantConditionArb,
        (base, tenantRef, nonTenantFilter) => {
          // Operation WITH tenant reference in key condition → should be isolated
          const withTenantInKey: DynamoDbOperation = {
            ...base,
            keyCondition: `PK = :pk AND ${tenantRef}`,
            filterExpression: nonTenantFilter,
          };
          expect(hasTenantIsolation(withTenantInKey)).toBe(true);
        }
      ),
      { numRuns: 100 }
    );
  });

  it('returns true (isolation present) IFF filter expression contains tenant reference', () => {
    fc.assert(
      fc.property(
        baseOperationArb,
        tenantRefArb,
        nonTenantConditionArb,
        (base, tenantRef, nonTenantKey) => {
          // Operation WITH tenant reference in filter → should be isolated
          const withTenantInFilter: DynamoDbOperation = {
            ...base,
            keyCondition: nonTenantKey,
            filterExpression: `status = :active AND ${tenantRef}`,
          };
          expect(hasTenantIsolation(withTenantInFilter)).toBe(true);
        }
      ),
      { numRuns: 100 }
    );
  });

  it('returns false (P0 flagged) IFF no tenant reference exists in key or filter', () => {
    fc.assert(
      fc.property(
        baseOperationArb,
        nonTenantConditionArb,
        nonTenantConditionArb,
        (base, keyCondition, filterExpression) => {
          const op: DynamoDbOperation = {
            ...base,
            keyCondition,
            filterExpression,
          };

          const result = hasTenantIsolation(op);

          // Verify: if neither key nor filter contains tenant pattern, result is false
          const defaultPattern = /tenant[_]?id/i;
          const tenantPattern = /TENANT#/i;
          const keyHasTenant =
            (keyCondition && (defaultPattern.test(keyCondition) || tenantPattern.test(keyCondition)));
          const filterHasTenant =
            (filterExpression && (defaultPattern.test(filterExpression) || tenantPattern.test(filterExpression)));

          if (!keyHasTenant && !filterHasTenant) {
            expect(result).toBe(false);
          } else {
            expect(result).toBe(true);
          }
        }
      ),
      { numRuns: 100 }
    );
  });

  it('supports custom tenant pattern via regex parameter', () => {
    fc.assert(
      fc.property(
        baseOperationArb,
        fc.constantFrom('orgId', 'org_id', 'organizationId'),
        (base, customField) => {
          const customPattern = /org[_]?id|organizationId/i;

          // Operation with custom tenant field in key condition
          const op: DynamoDbOperation = {
            ...base,
            keyCondition: `PK = :pk AND ${customField} = :orgVal`,
            filterExpression: '',
          };

          expect(hasTenantIsolation(op, customPattern)).toBe(true);

          // Same operation WITHOUT custom field should return false
          const opWithout: DynamoDbOperation = {
            ...base,
            keyCondition: 'PK = :pk AND SK = :sk',
            filterExpression: 'status = :active',
          };

          expect(hasTenantIsolation(opWithout, customPattern)).toBe(false);
        }
      ),
      { numRuns: 100 }
    );
  });
});
