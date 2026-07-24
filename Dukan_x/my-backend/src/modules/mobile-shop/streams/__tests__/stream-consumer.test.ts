/**
 * Stream Consumer Tests
 *
 * Verifies duplicate event deduplication, out-of-order processing,
 * and partial-batch failure handling.
 *
 * Requirements: 7.10, 13.3–13.6
 */

import type { DynamoDBStreamEvent, DynamoDBRecord } from 'aws-lambda';
import { handler } from '../stream-consumer';

// ─── Mock WebSocket Fanout ───────────────────────────────────────────────────

jest.mock('../websocket-fanout', () => ({
  fanoutPullHints: jest.fn().mockResolvedValue(undefined),
}));

// ─── Fixture Helpers ─────────────────────────────────────────────────────────

function makeStreamRecord(overrides: {
  eventId?: string;
  sequenceNumber?: string;
  entityType?: string;
  entityId?: string;
  version?: number;
  eventName?: 'INSERT' | 'MODIFY' | 'REMOVE';
  pk?: string;
}): DynamoDBRecord {
  const {
    eventId = 'evt-001',
    sequenceNumber = 'seq-001',
    entityType = 'UNIT',
    entityId = 'unit-001',
    version = 1,
    eventName = 'INSERT',
    pk = 'TENANT#tenant-001#ENTITY#UNIT#unit-001',
  } = overrides;

  return {
    eventID: `${eventId}-raw`,
    eventName,
    dynamodb: {
      SequenceNumber: sequenceNumber,
      NewImage: {
        PK: { S: pk },
        SK: { S: 'META#UNIT' },
        tenantId: { S: 'tenant-001' },
        entityType: { S: entityType },
        entityId: { S: entityId },
        eventId: { S: eventId },
        version: { N: String(version) },
        dataModelVersion: { N: '1' },
      },
      ApproximateCreationDateTime: Date.now() / 1000,
    },
  } as unknown as DynamoDBRecord;
}

function makeEvent(records: DynamoDBRecord[]): DynamoDBStreamEvent {
  return { Records: records };
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('StreamConsumer', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Duplicate event deduplication', () => {
    it('processes same eventId in batch only once', async () => {
      const { fanoutPullHints } = require('../websocket-fanout');

      const record1 = makeStreamRecord({ eventId: 'evt-dup', sequenceNumber: 'seq-001' });
      const record2 = makeStreamRecord({ eventId: 'evt-dup', sequenceNumber: 'seq-002' });

      const event = makeEvent([record1, record2]);
      const result = await handler(event);

      // Both succeed (duplicate is silently skipped)
      expect(result.batchItemFailures).toHaveLength(0);
      // Fanout called only once (second is deduplicated)
      expect(fanoutPullHints).toHaveBeenCalledTimes(1);
    });
  });

  describe('Out-of-order events', () => {
    it('processes each event independently regardless of version order', async () => {
      const { fanoutPullHints } = require('../websocket-fanout');

      // Version 3 arrives before version 2 — both should be processed independently
      const recordV3 = makeStreamRecord({
        eventId: 'evt-v3',
        sequenceNumber: 'seq-003',
        version: 3,
      });
      const recordV2 = makeStreamRecord({
        eventId: 'evt-v2',
        sequenceNumber: 'seq-002',
        version: 2,
      });

      const event = makeEvent([recordV3, recordV2]);
      const result = await handler(event);

      // No failures — out-of-order doesn't cause rejection
      expect(result.batchItemFailures).toHaveLength(0);
      // Both records processed independently
      expect(fanoutPullHints).toHaveBeenCalledTimes(2);
    });
  });

  describe('Partial-batch failure', () => {
    it('one record fails, others succeed, batchItemFailures contains only failed', async () => {
      const { fanoutPullHints } = require('../websocket-fanout');

      // First record succeeds, second throws
      fanoutPullHints
        .mockResolvedValueOnce(undefined) // record 1 succeeds
        .mockRejectedValueOnce(new Error('WebSocket send failed')) // record 2 fails
        .mockResolvedValueOnce(undefined); // record 3 succeeds

      const record1 = makeStreamRecord({
        eventId: 'evt-ok-1',
        sequenceNumber: 'seq-100',
      });
      const record2 = makeStreamRecord({
        eventId: 'evt-fail',
        sequenceNumber: 'seq-101',
      });
      const record3 = makeStreamRecord({
        eventId: 'evt-ok-2',
        sequenceNumber: 'seq-102',
      });

      const event = makeEvent([record1, record2, record3]);
      const result = await handler(event);

      // Only the failed record appears in batchItemFailures
      expect(result.batchItemFailures).toHaveLength(1);
      expect(result.batchItemFailures[0].itemIdentifier).toBe('seq-101');
    });
  });
});
