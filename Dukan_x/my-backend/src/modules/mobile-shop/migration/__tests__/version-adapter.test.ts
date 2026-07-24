/**
 * Version Adapter, Queued Mutation Compat, and Resumable Backfill Tests
 *
 * Verifies model-version compatibility, read/upgrade identity,
 * queued mutation validation, and idempotent backfill start.
 *
 * Requirements: 6.20–6.22, 6.33–6.36, 13.3–13.6
 */

import { VersionAdapter } from '../version-adapter';
import { QueuedMutationCompat } from '../queued-mutation-compat';
import { ResumableBackfill } from '../resumable-backfill';
import { MODEL_VERSION_CONFIG } from '../../config/model-version.config';

// ─── VersionAdapter Tests ────────────────────────────────────────────────────

describe('VersionAdapter', () => {
  const adapter = new VersionAdapter({
    currentVersion: 1,
    minSupportedVersion: 1,
    maxSupportedVersion: 1,
  });

  describe('isSupported', () => {
    it('current version → true', () => {
      expect(adapter.isSupported(MODEL_VERSION_CONFIG.currentVersion)).toBe(true);
    });

    it('below min → false', () => {
      expect(adapter.isSupported(0)).toBe(false);
    });

    it('above max → false', () => {
      expect(adapter.isSupported(MODEL_VERSION_CONFIG.maxSupportedVersion + 1)).toBe(false);
    });

    it('non-integer → false', () => {
      expect(adapter.isSupported(1.5)).toBe(false);
    });
  });

  describe('readAndUpgrade', () => {
    it('item at current version → no-op (identity)', () => {
      const item = {
        dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
        entityType: 'UNIT',
        entityId: 'u-001',
        status: 'IN_STOCK',
      };

      const result = adapter.readAndUpgrade(item);

      expect('error' in result).toBe(false);
      if (!('error' in result)) {
        expect(result.upgraded).toBe(false);
        expect(result.originalVersion).toBe(MODEL_VERSION_CONFIG.currentVersion);
        expect(result.currentVersion).toBe(MODEL_VERSION_CONFIG.currentVersion);
        expect(result.appliedSteps).toHaveLength(0);
        // Item content preserved
        expect(result.item.entityType).toBe('UNIT');
        expect(result.item.entityId).toBe('u-001');
        expect(result.item.status).toBe('IN_STOCK');
      }
    });

    it('item missing dataModelVersion → error', () => {
      const item = {
        entityType: 'UNIT',
        entityId: 'u-002',
        status: 'SOLD',
      };

      const result = adapter.readAndUpgrade(item);

      expect('error' in result).toBe(true);
      if ('error' in result) {
        expect(result.error.type).toBe('VERSION_MISSING');
        expect(result.error.message).toContain('missing');
      }
    });

    it('unsupported version → error', () => {
      const item = {
        dataModelVersion: 999,
        entityType: 'UNIT',
      };

      const adapterWide = new VersionAdapter({
        currentVersion: 1,
        minSupportedVersion: 1,
        maxSupportedVersion: 1,
      });

      const result = adapterWide.readAndUpgrade(item);

      expect('error' in result).toBe(true);
      if ('error' in result) {
        expect(result.error.type).toBe('VERSION_UNSUPPORTED');
      }
    });
  });
});

// ─── QueuedMutationCompat Tests ──────────────────────────────────────────────

describe('QueuedMutationCompat', () => {
  const compat = new QueuedMutationCompat({
    currentVersion: MODEL_VERSION_CONFIG.currentVersion,
    minSupportedVersion: MODEL_VERSION_CONFIG.minSupportedVersion,
    maxQueuedAge: MODEL_VERSION_CONFIG.queuedMutationMaxAge,
  });

  it('current version → COMPATIBLE (no upgrade)', () => {
    const mutation = {
      payload: { item: 'data', value: 100 },
      dataModelVersion: MODEL_VERSION_CONFIG.currentVersion,
      operationId: 'op-001',
      mutationFingerprint: 'fp-001',
    };

    const result = compat.validate(mutation);

    expect(result.status).toBe('COMPATIBLE');
    if (result.status === 'COMPATIBLE') {
      expect(result.upgraded).toBe(false);
      expect(result.payload).toEqual(mutation.payload);
    }
  });

  it('future version → UPGRADE_REQUIRED', () => {
    const mutation = {
      payload: { item: 'data' },
      dataModelVersion: MODEL_VERSION_CONFIG.currentVersion + 1,
      operationId: 'op-002',
      mutationFingerprint: 'fp-002',
    };

    const result = compat.validate(mutation);

    expect(result.status).toBe('UPGRADE_REQUIRED');
    if (result.status === 'UPGRADE_REQUIRED') {
      expect(result.clientVersion).toBe(MODEL_VERSION_CONFIG.currentVersion + 1);
      expect(result.reason).toContain('newer');
    }
  });

  it('version too old (exceeds maxQueuedAge) → UPGRADE_REQUIRED', () => {
    // With currentVersion=1 and maxQueuedAge=1, version 0 is below min
    // but also out of age window. Let's test with a wider config:
    const wideCompat = new QueuedMutationCompat({
      currentVersion: 5,
      minSupportedVersion: 3,
      maxQueuedAge: 1,
    });

    const mutation = {
      payload: { item: 'old-data' },
      dataModelVersion: 3, // delta = 2, exceeds maxQueuedAge of 1
      operationId: 'op-003',
      mutationFingerprint: 'fp-003',
    };

    const result = wideCompat.validate(mutation);

    expect(result.status).toBe('UPGRADE_REQUIRED');
    if (result.status === 'UPGRADE_REQUIRED') {
      expect(result.reason).toContain('too old');
    }
  });
});

// ─── ResumableBackfill Tests ─────────────────────────────────────────────────

describe('ResumableBackfill', () => {
  describe('start is idempotent', () => {
    it('second call returns existing checkpoint instead of re-creating', async () => {
      const backfill = new ResumableBackfill({ defaultPageSize: 25 });
      const backfillId = 'bf-idem-001';
      const existingCheckpoint = {
        PK: `TENANT#tenant-001#BACKFILL#${backfillId}`,
        SK: 'META#BACKFILL',
        tenantId: 'tenant-001',
        backfillId,
        status: 'IN_PROGRESS' as const,
        params: { fromVersion: 1, toVersion: 2 },
        processedCount: 50,
        skippedCount: 5,
        failedCount: 0,
        pagesCompleted: 2,
        startedAt: '2025-01-01T00:00:00.000Z',
        lastCheckpointAt: '2025-01-01T00:05:00.000Z',
        dataModelVersion: 1,
      };

      const sendMock = jest.fn();
      // First call: PutCommand fails with ConditionalCheckFailedException
      const condError = new Error('Condition failed');
      (condError as any).name = 'ConditionalCheckFailedException';
      sendMock.mockRejectedValueOnce(condError);
      // GetCommand returns existing checkpoint
      sendMock.mockResolvedValueOnce({ Item: existingCheckpoint });

      const ctx = {
        tenantId: 'tenant-001',
        tableName: 'MobileShopTable-test',
        correlationId: 'corr-001',
        send: sendMock,
      };

      const result = await backfill.start(ctx, backfillId, { fromVersion: 1, toVersion: 2 });

      // Returns existing checkpoint (not a new one)
      expect(result.status).toBe('IN_PROGRESS');
      expect(result.processedCount).toBe(50);
      expect(result.pagesCompleted).toBe(2);
    });

    it('first call creates a new INITIALIZED checkpoint', async () => {
      const backfill = new ResumableBackfill({ defaultPageSize: 25 });
      const backfillId = 'bf-new-001';

      const sendMock = jest.fn();
      // PutCommand succeeds (new checkpoint)
      sendMock.mockResolvedValueOnce({});

      const ctx = {
        tenantId: 'tenant-002',
        tableName: 'MobileShopTable-test',
        correlationId: 'corr-002',
        send: sendMock,
      };

      const result = await backfill.start(ctx, backfillId, { fromVersion: 1, toVersion: 2 });

      expect(result.status).toBe('INITIALIZED');
      expect(result.backfillId).toBe(backfillId);
      expect(result.tenantId).toBe('tenant-002');
      expect(result.processedCount).toBe(0);
    });
  });
});
