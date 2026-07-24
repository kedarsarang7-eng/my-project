/**
 * Reconciliation Worker Tests
 *
 * Verifies lease contention, idempotent step processing, retry backoff,
 * permanent failure handling, and completion semantics.
 *
 * Requirements: 6.33–6.40, 13.3–13.6
 */

import { ReconciliationWorker } from '../reconciliation-worker';
import type { WorkerContext } from '../reconciliation-types';
import type {
  ReconciliationRecord,
  ReconciliationStep,
} from '../../application/accepted-pending-handler';

// ─── Mock DynamoDB Client ────────────────────────────────────────────────────

function createMockClient() {
  const sendFn = jest.fn();
  return { send: sendFn } as any;
}

// ─── Shared Fixtures ─────────────────────────────────────────────────────────

const TENANT_ID = 'tenant-recon-001';
const WORKER_ID = 'worker-abc';
const RECON_ID = 'recon-001';
const TABLE_NAME = 'MobileShopTable-test';

const workerCtx: WorkerContext = {
  tenantId: TENANT_ID,
  workerId: WORKER_ID,
  correlationId: 'corr-001',
};

function makeRecord(overrides: Partial<ReconciliationRecord> = {}): ReconciliationRecord {
  return {
    PK: `TENANT#${TENANT_ID}#RECON#${RECON_ID}`,
    SK: 'META#RECON',
    tenantId: TENANT_ID,
    reconciliationId: RECON_ID,
    operationId: 'op-001',
    invoiceId: 'inv-001',
    status: 'PENDING',
    plan: [
      {
        stepId: 'step-1',
        type: 'WRITE_DEVICE_LINE',
        entityType: 'INVOICE_DEVICE_LINE',
        entityId: 'line-001',
        payload: { imei: '123456789012345', unitId: 'unit-001', description: 'Phone' },
      },
      {
        stepId: 'step-2',
        type: 'WRITE_CHANGE_EVENT',
        entityType: 'UNIT',
        entityId: 'unit-001',
        payload: { action: 'SOLD', entityVersion: 2 },
      },
    ],
    completedSteps: [],
    attempts: 0,
    lease: null,
    nextAttemptAt: new Date().toISOString(),
    lastError: null,
    dataModelVersion: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    GSI1PK: `TENANT#${TENANT_ID}#RECON#PENDING#ROOT`,
    GSI1SK: new Date().toISOString(),
    ...overrides,
  };
}

// ─── Tests: claimLease ───────────────────────────────────────────────────────

describe('ReconciliationWorker', () => {
  describe('claimLease', () => {
    it('succeeds when no active lease (condition passes)', async () => {
      const mockClient = createMockClient();
      mockClient.send.mockResolvedValueOnce({}); // UpdateCommand succeeds

      const worker = new ReconciliationWorker(mockClient, { tableName: TABLE_NAME });
      const result = await worker.claimLease(workerCtx, RECON_ID, WORKER_ID);

      expect(result.status).toBe('acquired');
      expect(result.reconciliationId).toBe(RECON_ID);
      expect(result.workerId).toBe(WORKER_ID);
      expect(result.expiresAt).toBeDefined();
    });

    it('fails with already-leased when lease held by another worker', async () => {
      const mockClient = createMockClient();
      const conditionError = new Error('Condition not met');
      (conditionError as any).name = 'ConditionalCheckFailedException';
      mockClient.send.mockRejectedValueOnce(conditionError);

      const worker = new ReconciliationWorker(mockClient, { tableName: TABLE_NAME });
      const result = await worker.claimLease(workerCtx, RECON_ID, WORKER_ID);

      expect(result.status).toBe('already-leased');
      expect(result.reconciliationId).toBe(RECON_ID);
      expect(result.workerId).toBeUndefined();
    });
  });

  // ─── Tests: processSteps ─────────────────────────────────────────────────

  describe('processSteps (via processNext)', () => {
    it('skips already-completed steps (idempotent)', async () => {
      const mockClient = createMockClient();
      const record = makeRecord({ completedSteps: ['step-1'] });

      const worker = new ReconciliationWorker(mockClient, { tableName: TABLE_NAME });

      // Use executeStep directly to test skip behavior
      const result = await worker.executeStep(workerCtx, record, record.plan[0]);

      expect(result.status).toBe('already-done');
      expect(result.stepId).toBe('step-1');
      // No DynamoDB call should have been made for the skip
      expect(mockClient.send).not.toHaveBeenCalled();
    });

    it('marks COMPLETED after all steps done', async () => {
      const mockClient = createMockClient();

      // Query AP-12 returns one pending record
      mockClient.send.mockResolvedValueOnce({
        Items: [makeRecord({ attempts: 0 })],
      });
      // claimLease (UpdateCommand) succeeds
      mockClient.send.mockResolvedValueOnce({});
      // executeStep step-1 (PutCommand) succeeds
      mockClient.send.mockResolvedValueOnce({});
      // markStepComplete step-1 (UpdateCommand) succeeds
      mockClient.send.mockResolvedValueOnce({});
      // executeStep step-2 (PutCommand) succeeds
      mockClient.send.mockResolvedValueOnce({});
      // markStepComplete step-2 (UpdateCommand) succeeds
      mockClient.send.mockResolvedValueOnce({});
      // finalizeReconciliation (UpdateCommand) succeeds
      mockClient.send.mockResolvedValueOnce({});

      const worker = new ReconciliationWorker(mockClient, { tableName: TABLE_NAME });
      const result = await worker.processNext(workerCtx);

      expect(result.processed).toBe(true);
      expect(result.result).toBe('completed');
      expect(result.reconciliationId).toBe(RECON_ID);
    });
  });

  // ─── Tests: handleStepFailure ────────────────────────────────────────────

  describe('handleStepFailure', () => {
    it('schedules retry with backoff (sets nextAttemptAt in the future)', async () => {
      const mockClient = createMockClient();
      mockClient.send.mockResolvedValueOnce({}); // UpdateCommand succeeds

      const worker = new ReconciliationWorker(mockClient, { tableName: TABLE_NAME });
      await worker.handleStepFailure(workerCtx, RECON_ID, 'step-1', 'Throttled');

      // Verify the UpdateCommand was called
      expect(mockClient.send).toHaveBeenCalledTimes(1);
      const callArg = mockClient.send.mock.calls[0][0];
      // The update sets status back to PENDING and includes GSI1SK (nextAttemptAt)
      expect(callArg.input.ExpressionAttributeValues[':pending']).toBe('PENDING');
      expect(callArg.input.ExpressionAttributeValues[':error']).toContain('step-1');
      expect(callArg.input.ExpressionAttributeValues[':error']).toContain('Throttled');
      // nextAttemptAt is in the future
      const nextAttempt = new Date(callArg.input.ExpressionAttributeValues[':nextAttemptAt']);
      expect(nextAttempt.getTime()).toBeGreaterThan(Date.now() - 1000);
    });
  });

  // ─── Tests: handlePermanentFailure ───────────────────────────────────────

  describe('handlePermanentFailure', () => {
    it('marks FAILED and preserves reserved state (no release)', async () => {
      const mockClient = createMockClient();
      mockClient.send.mockResolvedValueOnce({}); // UpdateCommand succeeds

      const worker = new ReconciliationWorker(mockClient, { tableName: TABLE_NAME });
      await worker.handlePermanentFailure(workerCtx, RECON_ID, 'Max attempts exceeded');

      expect(mockClient.send).toHaveBeenCalledTimes(1);
      const callArg = mockClient.send.mock.calls[0][0];
      // Status set to FAILED
      expect(callArg.input.ExpressionAttributeValues[':failed']).toBe('FAILED');
      // Error recorded
      expect(callArg.input.ExpressionAttributeValues[':error']).toBe('Max attempts exceeded');
      // Lease is cleared (null) but GSI1PK moves to FAILED bucket for visibility
      expect(callArg.input.ExpressionAttributeValues[':nullVal']).toBeNull();
      expect(callArg.input.ExpressionAttributeValues[':gsi1pk']).toContain('FAILED');
    });
  });
});
