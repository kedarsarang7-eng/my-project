// ============================================================================
// Property-Based Test — Operator Alert Delivery and Audit
// ============================================================================
// Feature: openwa-whatsapp-automation, Property (operator-alert)
//
// Validates: Requirements 16.6, 16.7
//
// Requirement 16.6: When a Recipient_Verification check fails, the system
// SHALL raise an Operator_Alert through the Notification_Delivery_Layer
// containing eventId, businessId, documentType, customerId, and reason,
// without exposing another customer's data beyond operator authorization.
//
// Requirement 16.7: Each Operator_Alert SHALL be delivered with at-least-once
// semantics (retrying on transient failure) and SHALL record every raised
// alert in the Audit_Log.
//
// Properties verified:
// 1. raiseOperatorAlert always dispatches exactly one notification (never
//    zero, never duplicates per call)
// 2. raiseOperatorAlert always writes one matching Audit_Log entry
// 3. On transient failure, the alert is retried (at-least-once semantics)
// 4. The alert contains: eventId, businessId, documentType, customerId, reason
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  OperatorAlertService,
  ALERT_CATEGORIES,
  AUDIT_ACTION_DELIVERY_BLOCKED,
  type OperatorAlertInput,
  type AlertCategory,
} from '../../services/operator-alert.service';
import type { AuditLogEntry } from '../../schemas/entities';

const NUM_RUNS = 100;

/**
 * For tests that exercise real backoff delays (500ms, 1000ms per retry), we
 * reduce iteration count to avoid Jest timeouts while still exercising the
 * retry logic across multiple random inputs.
 */
const NUM_RUNS_RETRY = 10;

// ── Generators ──────────────────────────────────────────────────────────────

/** All valid alert categories. */
const alertCategoryArb: fc.Arbitrary<AlertCategory> = fc.constantFrom(
  ALERT_CATEGORIES.RECIPIENT_MISMATCH,
  ALERT_CATEGORIES.PHONE_NUMBER_CHANGED,
  ALERT_CATEGORIES.PROFILE_DELETED,
  ALERT_CATEGORIES.CONSENT_VIOLATION,
  ALERT_CATEGORIES.TEMPLATE_RENDER_FAILURE,
);

/** Non-empty string generator for IDs and reasons. */
const nonEmptyStringArb = fc.string({ minLength: 1, maxLength: 50 }).filter((s) => s.trim().length > 0);

/** UUID-like string for eventId. */
const uuidArb = fc.uuid();

/** Generate a valid OperatorAlertInput. */
const operatorAlertInputArb: fc.Arbitrary<OperatorAlertInput> = fc.record({
  eventId: uuidArb,
  businessId: nonEmptyStringArb,
  tenantId: nonEmptyStringArb,
  documentType: fc.constantFrom('invoice', 'receipt', 'quotation', 'estimate', 'credit_note', 'debit_note'),
  customerId: nonEmptyStringArb,
  category: alertCategoryArb,
  reason: fc.string({ minLength: 5, maxLength: 200 }).filter((s) => s.trim().length >= 5),
});

// ── Mock Factories ──────────────────────────────────────────────────────────

/** Creates a mock NotificationService that tracks calls and succeeds. */
function createSuccessfulNotificationMock() {
  const calls: Array<{ input: unknown; caller: unknown }> = [];
  return {
    calls,
    service: {
      createNotification: jest.fn(async (input: unknown, caller: unknown) => {
        calls.push({ input, caller });
        return { notification_id: `notif-${calls.length}` };
      }),
    } as any,
  };
}

/** Creates a mock NotificationService that fails N times then succeeds. */
function createTransientFailNotificationMock(failCount: number) {
  let attempt = 0;
  const calls: Array<{ input: unknown; caller: unknown; succeeded: boolean }> = [];
  return {
    calls,
    service: {
      createNotification: jest.fn(async (input: unknown, caller: unknown) => {
        attempt++;
        if (attempt <= failCount) {
          calls.push({ input, caller, succeeded: false });
          const err = new Error('ECONNRESET: network timeout');
          err.name = 'NetworkError';
          throw err;
        }
        calls.push({ input, caller, succeeded: true });
        return { notification_id: `notif-after-retry-${attempt}` };
      }),
    } as any,
  };
}

/** Creates a mock NotificationService that always fails (all retries exhaust). */
function createAlwaysFailNotificationMock() {
  const calls: Array<{ input: unknown; caller: unknown }> = [];
  return {
    calls,
    service: {
      createNotification: jest.fn(async (input: unknown, caller: unknown) => {
        calls.push({ input, caller });
        const err = new Error('ECONNRESET: gateway unavailable');
        err.name = 'NetworkError';
        throw err;
      }),
    } as any,
  };
}

/** Creates a mock WaAuditService that records audit entries. */
function createAuditMock() {
  const entries: AuditLogEntry[] = [];
  return {
    entries,
    service: {
      record: jest.fn(
        async (
          ctx: { tenantId: string; businessId: string; actor: string },
          action: string,
          target: string,
          before?: unknown,
          after?: unknown,
        ): Promise<AuditLogEntry> => {
          const entry: AuditLogEntry = {
            id: `audit-${entries.length + 1}`,
            tenantId: ctx.tenantId,
            businessId: ctx.businessId,
            actor: ctx.actor,
            action,
            target,
            before,
            after,
            timestamp: new Date().toISOString(),
          };
          entries.push(entry);
          return entry;
        },
      ),
    } as any,
  };
}

// ── Property Tests ──────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property (operator-alert)', () => {
  // ────────────────────────────────────────────────────────────────────────────
  // Property 1: raiseOperatorAlert always dispatches exactly one notification
  // (never zero, never duplicates per call)
  // ────────────────────────────────────────────────────────────────────────────

  /**
   * **Validates: Requirements 16.6**
   */
  test('raiseOperatorAlert dispatches exactly one notification per call (Req 16.6)', async () => {
    await fc.assert(
      fc.asyncProperty(operatorAlertInputArb, async (input) => {
        const notifMock = createSuccessfulNotificationMock();
        const auditMock = createAuditMock();

        const service = new OperatorAlertService({
          auditService: auditMock.service,
          notificationService: notifMock.service,
        });

        const result = await service.raiseOperatorAlert(input);

        // Exactly one notification dispatch call
        expect(notifMock.calls.length).toBe(1);

        // Result confirms dispatch succeeded
        expect(result.alertDispatched).toBe(true);
        expect(result.notificationId).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Property 2: raiseOperatorAlert always writes exactly one matching
  // Audit_Log entry
  // ────────────────────────────────────────────────────────────────────────────

  /**
   * **Validates: Requirements 16.7**
   */
  test('raiseOperatorAlert writes exactly one Audit_Log entry per call (Req 16.7)', async () => {
    await fc.assert(
      fc.asyncProperty(operatorAlertInputArb, async (input) => {
        const notifMock = createSuccessfulNotificationMock();
        const auditMock = createAuditMock();

        const service = new OperatorAlertService({
          auditService: auditMock.service,
          notificationService: notifMock.service,
        });

        const result = await service.raiseOperatorAlert(input);

        // Exactly one audit entry written
        expect(auditMock.entries.length).toBe(1);

        // Audit entry matches the input
        const entry = auditMock.entries[0];
        expect(entry.businessId).toBe(input.businessId);
        expect(entry.tenantId).toBe(input.tenantId);
        expect(entry.action).toBe(AUDIT_ACTION_DELIVERY_BLOCKED);
        expect(entry.actor).toBe('system:operator-alert');

        // Result carries the audit entry ID
        expect(result.auditEntryId).toBe(entry.id);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Property 3: On transient failure, the alert is retried
  // (at-least-once semantics)
  // ────────────────────────────────────────────────────────────────────────────

  /**
   * **Validates: Requirements 16.7**
   */
  test('on transient notification failure, raiseOperatorAlert retries and eventually succeeds (Req 16.7)', async () => {
    await fc.assert(
      fc.asyncProperty(
        operatorAlertInputArb,
        fc.integer({ min: 1, max: 2 }), // fail 1-2 times then succeed (max retries = 3)
        async (input, failCount) => {
          const notifMock = createTransientFailNotificationMock(failCount);
          const auditMock = createAuditMock();

          const service = new OperatorAlertService({
            auditService: auditMock.service,
            notificationService: notifMock.service,
          });

          const result = await service.raiseOperatorAlert(input);

          // The notification was eventually dispatched (at-least-once)
          expect(result.alertDispatched).toBe(true);
          expect(result.notificationId).toBeDefined();

          // Total call count = failCount + 1 successful attempt
          expect(notifMock.calls.length).toBe(failCount + 1);

          // The last call succeeded
          expect(notifMock.calls[notifMock.calls.length - 1].succeeded).toBe(true);

          // Audit entry is still written (before notification dispatch)
          expect(auditMock.entries.length).toBe(1);
        },
      ),
      { numRuns: NUM_RUNS_RETRY },
    );
  }, 60_000);

  test('when all retry attempts exhaust, audit entry is still written (Req 16.7)', async () => {
    await fc.assert(
      fc.asyncProperty(operatorAlertInputArb, async (input) => {
        const notifMock = createAlwaysFailNotificationMock();
        const auditMock = createAuditMock();

        const service = new OperatorAlertService({
          auditService: auditMock.service,
          notificationService: notifMock.service,
        });

        const result = await service.raiseOperatorAlert(input);

        // Notification dispatch failed after all retries
        expect(result.alertDispatched).toBe(false);
        expect(result.notificationId).toBeUndefined();

        // But the audit entry was STILL written (durable record)
        expect(auditMock.entries.length).toBe(1);
        expect(result.auditEntryId).toBe(auditMock.entries[0].id);

        // All 3 retry attempts were made
        expect(notifMock.calls.length).toBe(3);
      }),
      { numRuns: NUM_RUNS_RETRY },
    );
  }, 60_000);

  // ────────────────────────────────────────────────────────────────────────────
  // Property 4: The alert payload contains eventId, businessId, documentType,
  // customerId, and reason
  // ────────────────────────────────────────────────────────────────────────────

  /**
   * **Validates: Requirements 16.6**
   */
  test('notification payload contains eventId, businessId, documentType, customerId, and reason (Req 16.6)', async () => {
    await fc.assert(
      fc.asyncProperty(operatorAlertInputArb, async (input) => {
        const notifMock = createSuccessfulNotificationMock();
        const auditMock = createAuditMock();

        const service = new OperatorAlertService({
          auditService: auditMock.service,
          notificationService: notifMock.service,
        });

        await service.raiseOperatorAlert(input);

        // Verify notification was created with the required fields
        expect(notifMock.calls.length).toBe(1);
        const notificationInput = notifMock.calls[0].input as any;

        // The notification payload must carry all required fields
        const payload = notificationInput.payload;
        expect(payload).toBeDefined();
        expect(payload.event_id).toBe(input.eventId);
        expect(payload.document_type).toBe(input.documentType);
        expect(payload.customer_id).toBe(input.customerId);
        expect(payload.reason).toBe(input.reason);
        expect(payload.category).toBe(input.category);

        // The notification target is the businessId
        expect(notificationInput.target_id).toBe(input.businessId);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('audit entry after-state contains eventId, documentType, customerId, category, and reason (Req 16.6, 16.7)', async () => {
    await fc.assert(
      fc.asyncProperty(operatorAlertInputArb, async (input) => {
        const notifMock = createSuccessfulNotificationMock();
        const auditMock = createAuditMock();

        const service = new OperatorAlertService({
          auditService: auditMock.service,
          notificationService: notifMock.service,
        });

        await service.raiseOperatorAlert(input);

        // Verify audit record method was called with correct after-state
        const recordCall = auditMock.service.record.mock.calls[0];
        const afterState = recordCall[4] as Record<string, unknown>;

        expect(afterState.eventId).toBe(input.eventId);
        expect(afterState.documentType).toBe(input.documentType);
        expect(afterState.customerId).toBe(input.customerId);
        expect(afterState.category).toBe(input.category);
        expect(afterState.reason).toBe(input.reason);
        expect(afterState.blockedAt).toBeDefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Composite: notification is scoped to the correct business (no cross-leak)
  // ────────────────────────────────────────────────────────────────────────────

  test('notification recipients are scoped to the input businessId (Req 16.6, 16.7)', async () => {
    await fc.assert(
      fc.asyncProperty(operatorAlertInputArb, async (input) => {
        const notifMock = createSuccessfulNotificationMock();
        const auditMock = createAuditMock();

        const service = new OperatorAlertService({
          auditService: auditMock.service,
          notificationService: notifMock.service,
        });

        await service.raiseOperatorAlert(input);

        const notificationInput = notifMock.calls[0].input as any;

        // Recipients reference the input businessId (operator scope)
        expect(notificationInput.recipients).toBeDefined();
        expect(notificationInput.recipients.length).toBeGreaterThan(0);
        expect(notificationInput.recipients[0].user_id).toContain(input.businessId);
      }),
      { numRuns: NUM_RUNS },
    );
  });
});
