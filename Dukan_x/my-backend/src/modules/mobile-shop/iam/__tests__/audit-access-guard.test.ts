/**
 * Audit Access Guard Tests — Immutability Enforcement
 *
 * Verifies:
 * - assertNotAuditRecord throws for item with entityType AUDIT
 * - assertNotAuditRecord throws for item with SK starting with AUDIT#
 * - assertNotAuditRecord passes for non-audit item
 * - assertNotAuditOperation throws for UpdateItem on AUDIT entity
 * - assertNotAuditOperation throws for DeleteItem on AUDIT entity
 * - assertNotAuditOperation passes for PutItem on AUDIT entity (append allowed)
 * - isAuditKey returns true for audit PK/SK patterns
 *
 * Requirements: 6.5–6.6, 8.3–8.10, 13.1, 13.6
 */

import {
  assertNotAuditRecord,
  assertNotAuditOperation,
  isAuditKey,
  AuditImmutabilityViolationError,
} from '../audit-access-guard';

// ─── assertNotAuditRecord ───────────────────────────────────────────────────

describe('assertNotAuditRecord', () => {
  it('throws for item with entityType AUDIT', () => {
    expect(() =>
      assertNotAuditRecord({ entityType: 'AUDIT', SK: 'AUDIT#2024-01-01#ev1' }),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('throws for item with entityType AUDIT_EVENT', () => {
    expect(() =>
      assertNotAuditRecord({ entityType: 'AUDIT_EVENT' }),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('throws for item with entityType IMMUTABLE_AUDIT_EVENT', () => {
    expect(() =>
      assertNotAuditRecord({ entityType: 'IMMUTABLE_AUDIT_EVENT' }),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('throws for item with SK starting with AUDIT#', () => {
    expect(() =>
      assertNotAuditRecord({ entityType: 'UNKNOWN', SK: 'AUDIT#2024-01-01#event-123' }),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('throws for item with PK containing AUDIT# segment', () => {
    expect(() =>
      assertNotAuditRecord({ PK: 'TENANT#t1#AUDIT#bucket1' }),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('passes for non-audit item', () => {
    expect(() =>
      assertNotAuditRecord({
        entityType: 'INVOICE',
        PK: 'TENANT#t1#ENTITY#INVOICE#inv-001',
        SK: 'META#INVOICE',
      }),
    ).not.toThrow();
  });

  it('passes for item with no identifying fields', () => {
    expect(() =>
      assertNotAuditRecord({}),
    ).not.toThrow();
  });

  it('error contains the operation and entity type', () => {
    try {
      assertNotAuditRecord({ entityType: 'AUDIT', SK: 'AUDIT#test' });
      fail('Should have thrown');
    } catch (err) {
      expect(err).toBeInstanceOf(AuditImmutabilityViolationError);
      expect((err as AuditImmutabilityViolationError).code).toBe('AUDIT_IMMUTABILITY_VIOLATION');
      expect((err as AuditImmutabilityViolationError).operation).toBe('mutate');
      expect((err as AuditImmutabilityViolationError).entityType).toBe('AUDIT');
    }
  });
});

// ─── assertNotAuditOperation ────────────────────────────────────────────────

describe('assertNotAuditOperation', () => {
  it('throws for UpdateItem on AUDIT entity', () => {
    expect(() =>
      assertNotAuditOperation('UpdateItem', 'AUDIT'),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('throws for DeleteItem on AUDIT entity', () => {
    expect(() =>
      assertNotAuditOperation('DeleteItem', 'AUDIT'),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('throws for Update on AUDIT_EVENT entity', () => {
    expect(() =>
      assertNotAuditOperation('Update', 'AUDIT_EVENT'),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('throws for Delete on IMMUTABLE_AUDIT_EVENT entity', () => {
    expect(() =>
      assertNotAuditOperation('Delete', 'IMMUTABLE_AUDIT_EVENT'),
    ).toThrow(AuditImmutabilityViolationError);
  });

  it('passes for PutItem on AUDIT entity (append is allowed)', () => {
    expect(() =>
      assertNotAuditOperation('PutItem' as any, 'AUDIT'),
    ).not.toThrow();
  });

  it('passes for UpdateItem on non-audit entity', () => {
    expect(() =>
      assertNotAuditOperation('UpdateItem', 'INVOICE'),
    ).not.toThrow();
  });

  it('passes for DeleteItem on non-audit entity', () => {
    expect(() =>
      assertNotAuditOperation('DeleteItem', 'SERVICE_JOB'),
    ).not.toThrow();
  });
});

// ─── isAuditKey ─────────────────────────────────────────────────────────────

describe('isAuditKey', () => {
  it('returns true for PK containing AUDIT# segment', () => {
    expect(isAuditKey('TENANT#t1#AUDIT#bucket1')).toBe(true);
  });

  it('returns true for SK starting with AUDIT#', () => {
    expect(isAuditKey('TENANT#t1#ENTITY#SOMETHING', 'AUDIT#2024-01-01#ev1')).toBe(true);
  });

  it('returns false for non-audit PK/SK', () => {
    expect(isAuditKey('TENANT#t1#ENTITY#INVOICE#inv1', 'META#INVOICE')).toBe(false);
  });

  it('returns false for PK without AUDIT# in it', () => {
    expect(isAuditKey('TENANT#t1#CLAIM')).toBe(false);
  });

  it('returns true when only PK contains AUDIT segment (no SK provided)', () => {
    expect(isAuditKey('TENANT#t1#AUDIT#daily')).toBe(true);
  });
});
