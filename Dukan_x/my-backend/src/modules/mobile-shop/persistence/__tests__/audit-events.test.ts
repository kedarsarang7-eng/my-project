/**
 * Audit & Change Event Persistence Tests
 *
 * Verifies:
 * - buildAuditEventItem produces correct key structure (PK, SK, GSI2PK, GSI2SK)
 * - Audit item has no updatedAt field (immutable)
 * - buildChangeEventItem produces correct key structure
 * - Change item has expiresAt TTL field
 * - buildAuditTransactItem uses attribute_not_exists condition
 *
 * Requirements: 8.14, 13.6
 */

import {
  buildAuditEventItem,
  buildChangeEventItem,
  buildAuditTransactItem,
  buildChangeTransactItem,
} from '../audit-events';
import { AuditEventService } from '../../application/audit-service';

describe('buildAuditEventItem', () => {
  const params = {
    tenantId: 'tenant-audit-001',
    eventId: 'evt-001',
    entityType: 'UNIT',
    entityId: 'unit-001',
    action: 'LIFECYCLE_TRANSITION' as const,
    actorId: 'user-001',
    correlationId: 'corr-001',
    operationId: 'op-001',
    occurredAt: '2025-01-15T10:00:00.000Z',
  };

  it('produces correct PK structure', () => {
    const item = buildAuditEventItem(params);

    // PK = TENANT#<tenantId>#AUDIT#<bucket>
    expect(item.PK).toContain('TENANT#tenant-audit-001#');
    expect(item.PK).toContain('AUDIT');
  });

  it('produces correct SK structure (occurredAt#eventId)', () => {
    const item = buildAuditEventItem(params);

    expect(item.SK).toBe('2025-01-15T10:00:00.000Z#evt-001');
  });

  it('produces correct GSI2PK structure', () => {
    const item = buildAuditEventItem(params);

    // GSI2PK = TENANT#<tenantId>#AUDIT#<entityType>#<entityId>
    expect(item.GSI2PK).toContain('TENANT#tenant-audit-001#');
    expect(item.GSI2PK).toContain('UNIT#unit-001');
  });

  it('produces correct GSI2SK structure', () => {
    const item = buildAuditEventItem(params);

    // GSI2SK = <occurredAt>#<eventId>
    expect(item.GSI2SK).toContain('2025-01-15T10:00:00.000Z');
    expect(item.GSI2SK).toContain('evt-001');
  });

  it('has no updatedAt field (immutable by design)', () => {
    const item = buildAuditEventItem(params);

    expect('updatedAt' in item).toBe(false);
    expect(item.createdAt).toBeDefined();
  });

  it('includes all required fields', () => {
    const item = buildAuditEventItem(params);

    expect(item.tenantId).toBe('tenant-audit-001');
    expect(item.eventId).toBe('evt-001');
    expect(item.entityType).toBe('UNIT');
    expect(item.entityId).toBe('unit-001');
    expect(item.action).toBe('LIFECYCLE_TRANSITION');
    expect(item.actorId).toBe('user-001');
    expect(item.correlationId).toBe('corr-001');
    expect(item.operationId).toBe('op-001');
    expect(item.dataModelVersion).toBeGreaterThan(0);
  });
});

describe('buildChangeEventItem', () => {
  const params = {
    tenantId: 'tenant-change-001',
    eventId: 'change-evt-001',
    entityType: 'UNIT',
    entityId: 'unit-002',
    entityVersion: 3,
    action: 'UPDATED',
    sequence: '00000001',
  };

  it('produces correct PK structure', () => {
    const item = buildChangeEventItem(params);

    // PK = TENANT#<tenantId>#CHANGE#<bucket>
    expect(item.PK).toContain('TENANT#tenant-change-001#');
    expect(item.PK).toContain('CHANGE');
  });

  it('produces correct SK structure (sequence#eventId)', () => {
    const item = buildChangeEventItem(params);

    expect(item.SK).toBe('00000001#change-evt-001');
  });

  it('has expiresAt TTL field', () => {
    const item = buildChangeEventItem(params);

    expect(item.expiresAt).toBeGreaterThan(0);
    // TTL should be in the future (at least current epoch)
    const nowEpoch = Math.floor(Date.now() / 1000);
    expect(item.expiresAt).toBeGreaterThan(nowEpoch);
  });

  it('includes all required fields', () => {
    const item = buildChangeEventItem(params);

    expect(item.tenantId).toBe('tenant-change-001');
    expect(item.eventId).toBe('change-evt-001');
    expect(item.entityType).toBe('UNIT');
    expect(item.entityId).toBe('unit-002');
    expect(item.entityVersion).toBe(3);
    expect(item.action).toBe('UPDATED');
    expect(item.dataModelVersion).toBeGreaterThan(0);
    expect(item.createdAt).toBeDefined();
  });
});

describe('buildAuditTransactItem', () => {
  it('uses attribute_not_exists condition (append-only)', () => {
    const auditItem = buildAuditEventItem({
      tenantId: 'tenant-txn-001',
      eventId: 'evt-txn-001',
      entityType: 'UNIT',
      entityId: 'unit-003',
      action: 'INTAKE_ACCEPTED',
      actorId: 'user-001',
      correlationId: 'corr-txn-001',
      operationId: 'op-txn-001',
      occurredAt: '2025-01-15T12:00:00.000Z',
    });

    const transactItem = buildAuditTransactItem('MobileShopTable', auditItem);

    expect(transactItem.Put).toBeDefined();
    expect(transactItem.Put.TableName).toBe('MobileShopTable');
    expect(transactItem.Put.ConditionExpression).toBe(
      'attribute_not_exists(PK) AND attribute_not_exists(SK)',
    );
    expect(transactItem.Put.Item).toEqual(auditItem);
  });
});

describe('buildChangeTransactItem', () => {
  it('uses attribute_not_exists condition (append-only)', () => {
    const changeItem = buildChangeEventItem({
      tenantId: 'tenant-txn-002',
      eventId: 'change-txn-001',
      entityType: 'UNIT',
      entityId: 'unit-004',
      entityVersion: 1,
      action: 'CREATED',
      sequence: '00000002',
    });

    const transactItem = buildChangeTransactItem('MobileShopTable', changeItem);

    expect(transactItem.Put).toBeDefined();
    expect(transactItem.Put.TableName).toBe('MobileShopTable');
    expect(transactItem.Put.ConditionExpression).toBe(
      'attribute_not_exists(PK) AND attribute_not_exists(SK)',
    );
    expect(transactItem.Put.Item).toEqual(changeItem);
  });
});

describe('AuditEventService.computeDigest', () => {
  it('is deterministic (same input → same hash)', () => {
    const state = { name: 'Device X', status: 'IN_STOCK', version: 1 };
    const hash1 = AuditEventService.computeDigest(state);
    const hash2 = AuditEventService.computeDigest(state);

    expect(hash1).toBe(hash2);
    expect(hash1).toHaveLength(64); // SHA-256 hex
  });

  it('is order-independent (different key order → same hash)', () => {
    const stateA = { name: 'Device X', status: 'IN_STOCK', version: 1 };
    const stateB = { version: 1, status: 'IN_STOCK', name: 'Device X' };

    const hashA = AuditEventService.computeDigest(stateA);
    const hashB = AuditEventService.computeDigest(stateB);

    expect(hashA).toBe(hashB);
  });
});

describe('AuditEventService.createCorrectionEvent', () => {
  it('has correctsEventId linking to original', () => {
    const service = new AuditEventService('MobileShopTable');
    const ctx = {
      tenantId: 'tenant-correction-001',
      businessId: 'biz-001',
      subjectId: 'user-001',
      businessType: 'mobile_shop' as const,
      permissions: ['mobile_shop:write'],
      correlationId: 'corr-correction-001',
    };

    const result = service.createCorrectionEvent(ctx, {
      entityType: 'UNIT',
      entityId: 'unit-005',
      operationId: 'op-correction-001',
      originalEventId: 'evt-original-001',
      reason: 'Data entry error',
    });

    expect(result.auditItem.correctsEventId).toBe('evt-original-001');
    expect(result.auditItem.action).toBe('CORRECTION');
    expect(result.auditItem.tenantId).toBe('tenant-correction-001');
    expect(result.transactItem.Put).toBeDefined();
  });
});

describe('AuditEventService immutability (no update/delete)', () => {
  it('has no updateAuditEvent or deleteAuditEvent methods', () => {
    const service = new AuditEventService('MobileShopTable');

    expect('updateAuditEvent' in service).toBe(false);
    expect('deleteAuditEvent' in service).toBe(false);
    expect(typeof (service as any).updateAuditEvent).toBe('undefined');
    expect(typeof (service as any).deleteAuditEvent).toBe('undefined');
  });
});
