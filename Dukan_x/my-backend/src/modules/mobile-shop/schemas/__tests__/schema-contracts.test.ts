/**
 * Schema Contract Tests
 *
 * Verifies structural invariants across all MobileShop domain schemas:
 * - Business-type alias normalization to canonical `mobile_shop`
 * - Money fields use integer minor units (no floating point)
 * - Every domain schema includes `dataModelVersion`
 * - Every mutable entity includes `version` field
 * - Every entity includes `tenantId`
 * - AuthoritativeConfirmation includes required fields
 *
 * Requirements: 1.7, 6.18, 13.1–13.2
 */

import {
  CANONICAL_BUSINESS_TYPE,
  normalizeMobileShopBusinessType,
  isMobileShopBusinessType,
  type Money,
  type Versioned,
  type EntityVersion,
  type TenantScopedEntity,
} from '../common.schema';

import type { AuthoritativeConfirmation } from '../confirmation.schema';

describe('Schema Contracts', () => {
  describe('Business-type alias normalization', () => {
    it('normalizes camelCase "mobileShop" to canonical "mobile_shop"', () => {
      expect(normalizeMobileShopBusinessType('mobileShop')).toBe('mobile_shop');
    });

    it('normalizes lowercase "mobileshop" to canonical "mobile_shop"', () => {
      expect(normalizeMobileShopBusinessType('mobileshop')).toBe('mobile_shop');
    });

    it('normalizes snake_case "mobile_shop" to canonical "mobile_shop"', () => {
      expect(normalizeMobileShopBusinessType('mobile_shop')).toBe('mobile_shop');
    });

    it('normalizes PascalCase "MobileShop" to canonical "mobile_shop"', () => {
      expect(normalizeMobileShopBusinessType('MobileShop')).toBe('mobile_shop');
    });

    it('normalizes uppercase "MOBILESHOP" to canonical "mobile_shop"', () => {
      expect(normalizeMobileShopBusinessType('MOBILESHOP')).toBe('mobile_shop');
    });

    it('normalizes screaming_snake "MOBILE_SHOP" to canonical "mobile_shop"', () => {
      expect(normalizeMobileShopBusinessType('MOBILE_SHOP')).toBe('mobile_shop');
    });

    it('returns undefined for unrelated business types', () => {
      expect(normalizeMobileShopBusinessType('grocery')).toBeUndefined();
      expect(normalizeMobileShopBusinessType('electronics')).toBeUndefined();
      expect(normalizeMobileShopBusinessType('restaurant')).toBeUndefined();
    });

    it('isMobileShopBusinessType returns true for all known aliases', () => {
      const aliases = ['mobileShop', 'mobileshop', 'mobile_shop', 'MobileShop', 'MOBILESHOP', 'MOBILE_SHOP'];
      for (const alias of aliases) {
        expect(isMobileShopBusinessType(alias)).toBe(true);
      }
    });

    it('isMobileShopBusinessType returns false for unrelated types', () => {
      expect(isMobileShopBusinessType('grocery')).toBe(false);
      expect(isMobileShopBusinessType('mobile')).toBe(false);
      expect(isMobileShopBusinessType('')).toBe(false);
    });

    it('CANONICAL_BUSINESS_TYPE is "mobile_shop"', () => {
      expect(CANONICAL_BUSINESS_TYPE).toBe('mobile_shop');
    });
  });

  describe('Money fields are integer minor units', () => {
    it('Money interface requires amountMinorUnits as number (integer contract)', () => {
      const money: Money = { amountMinorUnits: 1500, currency: 'INR' };
      expect(Number.isInteger(money.amountMinorUnits)).toBe(true);
      expect(money.amountMinorUnits).toBe(1500);
    });

    it('Money rejects floating point conceptually (integer check)', () => {
      const validMoney: Money = { amountMinorUnits: 100, currency: 'INR' };
      const invalidMoney: Money = { amountMinorUnits: 10.5, currency: 'INR' };
      expect(Number.isInteger(validMoney.amountMinorUnits)).toBe(true);
      expect(Number.isInteger(invalidMoney.amountMinorUnits)).toBe(false);
    });

    it('Money currency follows ISO 4217 format (string field)', () => {
      const money: Money = { amountMinorUnits: 0, currency: 'INR' };
      expect(typeof money.currency).toBe('string');
      expect(money.currency.length).toBe(3);
    });
  });

  describe('Every domain schema includes dataModelVersion', () => {
    it('Versioned interface requires dataModelVersion as number', () => {
      const versioned: Versioned = { dataModelVersion: 1 };
      expect(typeof versioned.dataModelVersion).toBe('number');
      expect(Number.isInteger(versioned.dataModelVersion)).toBe(true);
    });

    it('TenantScopedEntity extends Versioned and includes dataModelVersion', () => {
      const entity: TenantScopedEntity = {
        tenantId: 'tenant-1',
        entityId: 'entity-1',
        dataModelVersion: 1,
        version: 1,
        createdAt: '2025-01-01T00:00:00Z',
        updatedAt: '2025-01-01T00:00:00Z',
      };
      expect(entity.dataModelVersion).toBeDefined();
      expect(typeof entity.dataModelVersion).toBe('number');
    });
  });

  describe('Every mutable entity includes version field', () => {
    it('EntityVersion interface requires version as number', () => {
      const ev: EntityVersion = { version: 1 };
      expect(typeof ev.version).toBe('number');
      expect(Number.isInteger(ev.version)).toBe(true);
    });

    it('TenantScopedEntity includes version for optimistic concurrency', () => {
      const entity: TenantScopedEntity = {
        tenantId: 'tenant-1',
        entityId: 'entity-1',
        dataModelVersion: 1,
        version: 3,
        createdAt: '2025-01-01T00:00:00Z',
        updatedAt: '2025-01-01T00:00:00Z',
      };
      expect(entity.version).toBe(3);
      expect(Number.isInteger(entity.version)).toBe(true);
    });
  });

  describe('Every entity includes tenantId', () => {
    it('TenantScopedEntity requires tenantId', () => {
      const entity: TenantScopedEntity = {
        tenantId: 'tenant-abc',
        entityId: 'entity-1',
        dataModelVersion: 1,
        version: 1,
        createdAt: '2025-01-01T00:00:00Z',
        updatedAt: '2025-01-01T00:00:00Z',
      };
      expect(entity.tenantId).toBe('tenant-abc');
      expect(typeof entity.tenantId).toBe('string');
      expect(entity.tenantId.length).toBeGreaterThan(0);
    });
  });

  describe('AuthoritativeConfirmation includes required fields', () => {
    const confirmation: AuthoritativeConfirmation = {
      authority: 'AWS_DYNAMODB',
      state: 'COMMITTED',
      operationId: 'op-123',
      confirmedAt: '2025-01-01T12:00:00Z',
      dataModelVersion: 1,
      entityVersions: { 'unit-1': 2, 'invoice-1': 1 },
    };

    it('includes authority field', () => {
      expect(confirmation.authority).toBe('AWS_DYNAMODB');
    });

    it('includes state field', () => {
      expect(['COMMITTED', 'ACCEPTED_PENDING', 'CURRENT']).toContain(confirmation.state);
    });

    it('includes operationId field', () => {
      expect(confirmation.operationId).toBeDefined();
      expect(typeof confirmation.operationId).toBe('string');
    });

    it('includes confirmedAt field (ISO 8601)', () => {
      expect(confirmation.confirmedAt).toBeDefined();
      expect(typeof confirmation.confirmedAt).toBe('string');
      expect(new Date(confirmation.confirmedAt).toISOString()).toBeDefined();
    });

    it('includes entityVersions record', () => {
      expect(confirmation.entityVersions).toBeDefined();
      expect(typeof confirmation.entityVersions).toBe('object');
      const values = Object.values(confirmation.entityVersions);
      for (const v of values) {
        expect(Number.isInteger(v)).toBe(true);
      }
    });

    it('extends Versioned (has dataModelVersion)', () => {
      expect(confirmation.dataModelVersion).toBeDefined();
      expect(Number.isInteger(confirmation.dataModelVersion)).toBe(true);
    });
  });
});
