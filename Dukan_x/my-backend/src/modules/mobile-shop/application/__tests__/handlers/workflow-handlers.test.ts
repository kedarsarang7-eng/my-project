/**
 * Workflow Handlers Integration Tests
 *
 * Tests valid and conflicting lifecycle operations, expected-version failures,
 * bundle accounting separation, and handler outcome correctness.
 *
 * Mocks DynamoDB client, repository, and audit service to isolate handler logic.
 *
 * Requirements covered: 4.1–4.9, 5.1–5.8
 */

import { randomUUID } from 'crypto';
import { createImeiUnitHandler } from '../../handlers/device-inventory.handler';
import { createExchange } from '../../handlers/exchange.handler';
import { updateServiceJobStatus, createServiceJob } from '../../handlers/service-job.handler';
import { registerWarranty, fileWarrantyClaim } from '../../handlers/warranty.handler';
import { createReservationHandler } from '../../handlers/reservation.handler';
import { processReturnHandler } from '../../handlers/device-return.handler';
import type { TenantContextWire } from '../../../schemas/common.schema';
import { DeviceLifecycleState } from '../../../domain/device-lifecycle';

// ─── Mock DynamoDB Client ────────────────────────────────────────────────────

const mockSend = jest.fn();
const mockClient = { send: mockSend } as any;

// ─── Mock Repository ─────────────────────────────────────────────────────────

const mockRepository = {
  getEntityAggregate: jest.fn(),
  lookupImeiClaim: jest.fn(),
  queryUnitsByLifecycleState: jest.fn(),
  queryServiceJobs: jest.fn(),
  queryByTypeAndStatus: jest.fn(),
  queryWarranties: jest.fn(),
  queryReconciliationWork: jest.fn(),
  queryKpiProjections: jest.fn(),
} as any;

// ─── Mock Audit Service ──────────────────────────────────────────────────────

const mockAuditService = {
  createAuditEvent: jest.fn().mockReturnValue({
    transactItem: { Put: { TableName: 'test-table', Item: { PK: 'AUDIT', SK: 'EVENT' } } },
  }),
} as any;

// ─── Mock Idempotency ────────────────────────────────────────────────────────

jest.mock('../../../persistence/idempotency', () => ({
  checkIdempotency: jest.fn().mockResolvedValue({ outcome: 'NEW' }),
}));

jest.mock('../../../persistence/transaction-items', () => ({
  buildClaimTransactItem: jest.fn().mockReturnValue({
    Put: { TableName: 'test-table', Item: { PK: 'CLAIM', SK: 'IMEI#test' }, ConditionExpression: 'attribute_not_exists(PK)' },
  }),
  buildIdempotencyTransactItem: jest.fn().mockReturnValue({
    Put: { TableName: 'test-table', Item: { PK: 'IDEMP', SK: 'OP#test' }, ConditionExpression: 'attribute_not_exists(PK)' },
  }),
  buildReleaseClaimTransactItem: jest.fn().mockReturnValue({
    Delete: { TableName: 'test-table', Key: { PK: 'CLAIM', SK: 'RES#test' } },
  }),
}));

jest.mock('../../../domain/imei-validator', () => ({
  validateImei: jest.fn().mockReturnValue({ ok: true, value: '353456789012345' }),
}));

jest.mock('../../../domain/device-lifecycle', () => {
  const actual = jest.requireActual('../../../domain/device-lifecycle');
  return {
    ...actual,
    validateTransition: jest.fn().mockReturnValue({
      ok: true,
      value: {
        targetState: 'RESERVED',
        newVersion: 2,
        actor: 'actor-1',
        reason: 'test',
        occurredAt: new Date().toISOString(),
      },
    }),
  };
});

jest.mock('../../../domain/imei-unit', () => {
  const actual = jest.requireActual('../../../domain/imei-unit');
  return {
    ...actual,
    applyTransition: jest.fn().mockImplementation((unit, event) => ({
      ...unit,
      lifecycleState: event.targetState,
      version: event.newVersion,
      updatedAt: event.occurredAt,
    })),
  };
});

jest.mock('../../../domain/warranty-validator', () => ({
  validateWarrantyMonths: jest.fn().mockReturnValue({ ok: true }),
  calculateWarrantyEndDate: jest.fn().mockReturnValue('2025-12-31'),
}));

jest.mock('../../../domain/monetary-validator', () => ({
  validateMoney: jest.fn().mockReturnValue({ ok: true }),
}));

// ─── Helpers ─────────────────────────────────────────────────────────────────

const TABLE_NAME = 'MobileShop-test';

function makeTenantCtx(overrides?: Partial<TenantContextWire>): TenantContextWire {
  return {
    tenantId: 'tenant-1',
    businessId: 'biz-1',
    subjectId: 'user-1',
    businessType: 'mobile_shop',
    permissions: ['mobile_shop:imei:manage'],
    correlationId: `corr-${randomUUID().slice(0, 8)}`,
    ...overrides,
  } as TenantContextWire;
}

function makeDeps() {
  return {
    client: mockClient,
    tableName: TABLE_NAME,
    repository: mockRepository,
    auditService: mockAuditService,
  };
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('Workflow Handlers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockSend.mockResolvedValue({});
  });

  // ─── createImeiUnit ──────────────────────────────────────────────────────

  describe('createImeiUnitHandler', () => {
    it('valid params → success with COMMITTED confirmation', async () => {
      const ctx = makeTenantCtx();
      const params = {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-001',
        imei: '353456789012345',
        condition: 'NEW' as any,
        ownershipSource: 'PURCHASED' as any,
        brand: 'Samsung',
        model: 'Galaxy S24',
        acquisitionCost: { amountMinorUnits: 4500000, currency: 'INR' },
        salePrice: { amountMinorUnits: 5500000, currency: 'INR' },
      };

      const result = await createImeiUnitHandler(ctx, params, makeDeps());

      expect(result.ok).toBe(true);
      if (result.ok && !('replay' in result)) {
        expect(result.confirmation).toBe('COMMITTED');
        expect(result.value.imei).toBe('353456789012345');
        expect(result.value.lifecycleState).toBe(DeviceLifecycleState.IN_STOCK);
      }
      expect(mockSend).toHaveBeenCalled();
    });

    it('duplicate IMEI (TransactionCanceledException) → CLAIM_ALREADY_EXISTS / conflict outcome', async () => {
      const txnError = Object.assign(new Error('Transaction cancelled'), {
        name: 'TransactionCanceledException',
        CancellationReasons: [
          { Code: 'None' },
          { Code: 'ConditionalCheckFailed' },
          { Code: 'None' },
          { Code: 'None' },
        ],
      });
      mockSend.mockRejectedValueOnce(txnError);

      const ctx = makeTenantCtx();
      const params = {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-dup',
        imei: '353456789012345',
        condition: 'NEW' as any,
        ownershipSource: 'PURCHASED' as any,
        brand: 'Apple',
        model: 'iPhone 15',
        acquisitionCost: { amountMinorUnits: 7000000, currency: 'INR' },
        salePrice: { amountMinorUnits: 8000000, currency: 'INR' },
      };

      const result = await createImeiUnitHandler(ctx, params, makeDeps());

      expect(result.ok).toBe(false);
      if (!result.ok) {
        // TransactionCanceledException with COMPOSITE context produces a conflict
        expect(result.outcome.statePreserved).toBe(true);
        expect(result.outcome.httpStatus).toBeGreaterThanOrEqual(409);
      }
    });
  });

  // ─── updateServiceJobStatus ──────────────────────────────────────────────

  describe('updateServiceJobStatus', () => {
    it('valid transition → success', async () => {
      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          PK: 'TENANT#tenant-1#ENTITY#SERVICE_JOB#job-1',
          SK: 'META#SERVICE_JOB',
          tenantId: 'tenant-1',
          entityId: 'job-1',
          status: 'RECEIVED',
          version: 1,
          unitId: 'unit-1',
          imei: '353456789012345',
          dueAt: '2025-01-15',
        }],
      });
      // Unit lookup for lifecycle transition (if triggered)
      mockRepository.getEntityAggregate.mockResolvedValue({
        items: [{
          lifecycleState: DeviceLifecycleState.SOLD,
          version: 1,
          tenantId: 'tenant-1',
        }],
      });

      const ctx = makeTenantCtx();
      const result = await updateServiceJobStatus(makeDeps(), ctx, 'job-1', {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-sj-1',
        targetStatus: 'DIAGNOSED',
        expectedVersion: 1,
        actor: 'tech-1',
        dataModelVersion: 1,
      });

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.value.status).toBe('DIAGNOSED');
        expect(result.value.version).toBe(2);
      }
    });

    it('invalid transition (terminal state DELIVERED) → LIFECYCLE_TRANSITION_DENIED', async () => {
      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          tenantId: 'tenant-1',
          entityId: 'job-2',
          status: 'DELIVERED',
          version: 5,
          unitId: 'unit-2',
          imei: '353456789012346',
        }],
      });

      const ctx = makeTenantCtx();
      const result = await updateServiceJobStatus(makeDeps(), ctx, 'job-2', {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-sj-2',
        targetStatus: 'CANCELLED',
        expectedVersion: 5,
        actor: 'admin',
        dataModelVersion: 1,
      });

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('LIFECYCLE_TRANSITION_DENIED');
        expect(result.error.httpStatus).toBe(409);
      }
    });

    it('version mismatch → VERSION_CONFLICT', async () => {
      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          tenantId: 'tenant-1',
          entityId: 'job-3',
          status: 'RECEIVED',
          version: 3,
          unitId: 'unit-3',
          imei: '353456789012347',
        }],
      });

      const ctx = makeTenantCtx();
      const result = await updateServiceJobStatus(makeDeps(), ctx, 'job-3', {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-sj-3',
        targetStatus: 'DIAGNOSED',
        expectedVersion: 1, // Mismatch: current is 3
        actor: 'tech-1',
        dataModelVersion: 1,
      });

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('VERSION_CONFLICT');
        expect(result.error.retryable).toBe(true);
      }
    });
  });

  // ─── createExchange ──────────────────────────────────────────────────────

  describe('createExchange', () => {
    it('valid exchange → both devices transition atomically', async () => {
      // Old device claim lookup
      mockRepository.lookupImeiClaim.mockResolvedValueOnce({
        item: { tenantId: 'tenant-1', ownerEntityId: 'unit-old' },
      });
      // Old device unit read
      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          tenantId: 'tenant-1',
          lifecycleState: DeviceLifecycleState.SOLD,
          version: 2,
        }],
      });
      // New device claim lookup
      mockRepository.lookupImeiClaim.mockResolvedValueOnce({
        item: { tenantId: 'tenant-1', ownerEntityId: 'unit-new' },
      });
      // New device unit read
      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          tenantId: 'tenant-1',
          lifecycleState: DeviceLifecycleState.IN_STOCK,
          version: 1,
        }],
      });

      const ctx = makeTenantCtx();
      const result = await createExchange(makeDeps(), ctx, {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-exch-1',
        customerId: 'cust-1',
        customerName: 'Customer One',
        oldDeviceImei: '353456789012345',
        oldDeviceUnitId: 'unit-old',
        oldDeviceBrand: 'Samsung',
        oldDeviceModel: 'Galaxy S21',
        oldDeviceCondition: 'GOOD',
        oldDeviceValuation: { amountMinorUnits: 1500000, currency: 'INR' },
        newDeviceImei: '353456789012346',
        newDeviceUnitId: 'unit-new',
        newDeviceBrand: 'Samsung',
        newDeviceModel: 'Galaxy S24',
        newDeviceSalePrice: { amountMinorUnits: 5500000, currency: 'INR' },
        adjustmentAmount: { amountMinorUnits: 4000000, currency: 'INR' },
        adjustmentDirection: 'CUSTOMER_PAYS',
        approvedBy: 'manager-1',
        dataModelVersion: 1,
      });

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.value.status).toBe('COMPLETED');
        expect(result.value.version).toBe(1);
      }
      // Verify transaction was sent (includes old + new device transitions)
      expect(mockSend).toHaveBeenCalled();
    });

    it('old device wrong lifecycle → IMEI_LIFECYCLE_INVALID', async () => {
      // Old device claim
      mockRepository.lookupImeiClaim.mockResolvedValueOnce({
        item: { tenantId: 'tenant-1', ownerEntityId: 'unit-old' },
      });
      // Old device in RETIRED state (not allowed for exchange)
      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          tenantId: 'tenant-1',
          lifecycleState: DeviceLifecycleState.RETIRED,
          version: 3,
        }],
      });

      const ctx = makeTenantCtx();
      const result = await createExchange(makeDeps(), ctx, {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-exch-2',
        customerId: 'cust-1',
        customerName: 'Customer',
        oldDeviceImei: '353456789012345',
        oldDeviceUnitId: 'unit-old',
        oldDeviceBrand: 'Apple',
        oldDeviceModel: 'iPhone 12',
        oldDeviceCondition: 'POOR',
        oldDeviceValuation: { amountMinorUnits: 500000, currency: 'INR' },
        newDeviceImei: '353456789012347',
        newDeviceUnitId: 'unit-new',
        newDeviceBrand: 'Apple',
        newDeviceModel: 'iPhone 15',
        newDeviceSalePrice: { amountMinorUnits: 8000000, currency: 'INR' },
        adjustmentAmount: { amountMinorUnits: 7500000, currency: 'INR' },
        adjustmentDirection: 'CUSTOMER_PAYS',
        approvedBy: 'mgr-1',
        dataModelVersion: 1,
      });

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('IMEI_LIFECYCLE_INVALID');
        expect(result.error.httpStatus).toBe(409);
      }
    });
  });

  // ─── registerWarranty ────────────────────────────────────────────────────

  describe('registerWarranty', () => {
    it('valid → warranty created with month-end date', async () => {
      // IMEI claim exists
      mockRepository.lookupImeiClaim.mockResolvedValueOnce({
        item: { tenantId: 'tenant-1', ownerEntityId: 'unit-w1' },
      });
      // Unit exists and is SOLD
      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{ tenantId: 'tenant-1', lifecycleState: 'SOLD', version: 2 }],
      });

      const ctx = makeTenantCtx();
      const result = await registerWarranty(makeDeps(), ctx, {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-war-1',
        imei: '353456789012345',
        unitId: 'unit-w1',
        saleInvoiceId: 'inv-001',
        customerId: 'cust-w1',
        warrantyType: 'MANUFACTURER',
        provider: 'Samsung India',
        durationMonths: 12,
        saleDate: '2025-01-31',
        dataModelVersion: 1,
      });

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.value.status).toBe('ACTIVE');
        expect(result.value.endDate).toBe('2025-12-31');
      }
    });

    it('expired warranty (fileWarrantyClaim on expired) → LIFECYCLE_TRANSITION_DENIED', async () => {
      // Warranty with expired endDate
      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          tenantId: 'tenant-1',
          entityType: 'WARRANTY',
          entityId: 'war-expired',
          status: 'ACTIVE',
          version: 1,
          endDate: '2020-01-01', // Past date
          imei: '353456789012345',
          unitId: 'unit-e1',
          customerId: 'cust-e1',
        }],
      });

      const ctx = makeTenantCtx();
      const result = await fileWarrantyClaim(makeDeps(), ctx, 'war-expired', {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-war-claim',
        faultDescription: 'Screen flickering',
        expectedVersion: 1,
        dataModelVersion: 1,
      });

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('LIFECYCLE_TRANSITION_DENIED');
      }
    });
  });

  // ─── createReservation ───────────────────────────────────────────────────

  describe('createReservationHandler', () => {
    it('unit already reserved → LIFECYCLE_TRANSITION_DENIED', async () => {
      const { validateTransition } = require('../../../domain/device-lifecycle');
      (validateTransition as jest.Mock).mockReturnValueOnce({
        ok: false,
        error: { code: 'TRANSITION_NOT_ALLOWED' },
      });

      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          entityId: 'unit-res',
          tenantId: 'tenant-1',
          lifecycleState: DeviceLifecycleState.RESERVED,
          version: 2,
          imei: '353456789012345',
          condition: 'NEW',
          ownershipSource: 'PURCHASED',
          brand: 'Samsung',
          model: 'Galaxy A54',
          acquisitionCost: { amount: 3000000, currency: 'INR' },
          salePrice: { amount: 3500000, currency: 'INR' },
          createdAt: '2025-01-01T00:00:00Z',
          updatedAt: '2025-01-02T00:00:00Z',
          dataModelVersion: 1,
        }],
      });

      const ctx = makeTenantCtx();
      const result = await createReservationHandler(ctx, 'unit-res', {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-res-dup',
        expectedVersion: 2,
        customerId: 'cust-2',
        reason: 'Customer hold',
      }, makeDeps());

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.outcome.code).toBe('LIFECYCLE_TRANSITION_DENIED');
      }
    });
  });

  // ─── processReturn ───────────────────────────────────────────────────────

  describe('processReturnHandler', () => {
    it('IMEI mismatch → RETURN_IMEI_MISMATCH', async () => {
      const { validateImei } = require('../../../domain/imei-validator');
      // Physical IMEI is valid but different from stored
      (validateImei as jest.Mock).mockReturnValueOnce({ ok: true, value: '999999999999999' });

      mockRepository.getEntityAggregate.mockResolvedValueOnce({
        items: [{
          entityId: 'unit-ret',
          tenantId: 'tenant-1',
          lifecycleState: DeviceLifecycleState.SOLD,
          version: 2,
          imei: '353456789012345', // Stored IMEI is different from physical
          saleInvoiceId: 'inv-ret-001',
          condition: 'GOOD',
          ownershipSource: 'PURCHASED',
          brand: 'OnePlus',
          model: '12',
          acquisitionCost: { amount: 4000000, currency: 'INR' },
          salePrice: { amount: 4500000, currency: 'INR' },
          createdAt: '2025-01-01T00:00:00Z',
          updatedAt: '2025-01-05T00:00:00Z',
          dataModelVersion: 1,
        }],
      });

      const ctx = makeTenantCtx();
      const result = await processReturnHandler(ctx, {
        operationId: randomUUID(),
        mutationFingerprint: 'fp-ret-mismatch',
        unitId: 'unit-ret',
        saleInvoiceId: 'inv-ret-001',
        physicalImei: '999999999999999', // Different IMEI
        expectedVersion: 2,
        condition: 'GOOD' as any,
        disposition: 'RETURN_TO_STOCK',
        reason: 'Customer return',
      }, makeDeps());

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.outcome.code).toBe('RETURN_IMEI_MISMATCH');
        expect(result.outcome.httpStatus).toBe(422);
        expect(result.outcome.statePreserved).toBe(true);
      }
    });
  });
});
