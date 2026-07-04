// ============================================================================
// Property-Based Test — Reminder Scheduling
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 18
//
// Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.6, 5.7, 5.8
//
// Property 18 (design.md): Reminder scheduling honors offsets, cap,
// cancellation, and partial-payment continuation.
//
// For any invoice, reminder configuration (offsets of 1–365 days before/after
// due date, maximum count of 1–100), and payment history, the set of reminder
// Outbound_Messages produced is exactly those whose scheduled time is due while
// the outstanding balance is greater than zero, never exceeds the configured
// maximum count, produces none after the invoice is fully paid, and continues
// using the updated outstanding amount after a partial payment that leaves a
// positive balance.
//
// Sub-properties tested:
// 1. Before-due reminders are scheduled at correct offsets before due date
// 2. After-due reminders are scheduled at correct offsets after due date
// 3. Max reminder count cap is always respected
// 4. Fully paid invoice cancels all reminders (empty schedule)
// 5. Partial payment continues reminders with updated outstanding amount
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  computeReminderSchedule,
  computeBeforeDueReminderTime,
  computeAfterDueReminderTime,
  shouldCancelReminders,
  computeUpdatedReminderContent,
  computeOutstandingAmount,
  type ReminderInvoice,
  type ReminderConfig,
  type ReminderHistory,
} from '../../services/reminder-schedule.service';

const NUM_RUNS = 100;
const MILLIS_PER_DAY = 24 * 60 * 60 * 1000;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a valid offset in days (1–365). */
const offsetDaysArb: fc.Arbitrary<number> = fc.integer({ min: 1, max: 365 });

/** Generates a valid max reminder count (1–100). */
const maxReminderCountArb: fc.Arbitrary<number> = fc.integer({ min: 1, max: 100 });

/** Generates an array of unique before-due offsets (1–365 days). */
const beforeDueDaysArb: fc.Arbitrary<number[]> = fc.uniqueArray(offsetDaysArb, {
  minLength: 0,
  maxLength: 10,
});

/** Generates an array of unique after-due offsets (1–365 days). */
const afterDueDaysArb: fc.Arbitrary<number[]> = fc.uniqueArray(offsetDaysArb, {
  minLength: 0,
  maxLength: 10,
});

/** Generates a valid ReminderConfig. */
const reminderConfigArb: fc.Arbitrary<ReminderConfig> = fc.record({
  beforeDueDateDays: beforeDueDaysArb,
  afterDueDateDays: afterDueDaysArb,
  maxReminderCount: maxReminderCountArb,
});

/** Generates a positive integer amount in paise. */
const paiseAmountArb: fc.Arbitrary<number> = fc.integer({ min: 100, max: 10_000_000 });

/** Generates a due date within a reasonable range (2020-2030). */
const dueDateArb: fc.Arbitrary<string> = fc
  .date({
    min: new Date('2020-01-01T00:00:00Z'),
    max: new Date('2030-12-31T23:59:59Z'),
  })
  .map((d) => d.toISOString());

/** Generates a businessId. */
const businessIdArb: fc.Arbitrary<string> = fc.hexaString({ minLength: 8, maxLength: 16 });

/** Generates a customerId. */
const customerIdArb: fc.Arbitrary<string> = fc.hexaString({ minLength: 8, maxLength: 16 });

/** Generates an invoiceId. */
const invoiceIdArb: fc.Arbitrary<string> = fc.hexaString({ minLength: 8, maxLength: 16 });

/** Generates an unpaid invoice (outstanding > 0). */
const unpaidInvoiceArb: fc.Arbitrary<ReminderInvoice> = fc
  .record({
    invoiceId: invoiceIdArb,
    customerId: customerIdArb,
    businessId: businessIdArb,
    dueDate: dueDateArb,
    totalAmountPaise: paiseAmountArb,
    partialPaidFraction: fc.double({ min: 0, max: 0.99, noNaN: true }),
  })
  .map(({ totalAmountPaise, partialPaidFraction, ...rest }) => ({
    ...rest,
    totalAmountPaise,
    paidAmountPaise: Math.floor(totalAmountPaise * partialPaidFraction),
    isPaid: false,
  }));

/** Generates a fully paid invoice. */
const paidInvoiceArb: fc.Arbitrary<ReminderInvoice> = fc
  .record({
    invoiceId: invoiceIdArb,
    customerId: customerIdArb,
    businessId: businessIdArb,
    dueDate: dueDateArb,
    totalAmountPaise: paiseAmountArb,
  })
  .map((fields) => ({
    ...fields,
    paidAmountPaise: fields.totalAmountPaise,
    isPaid: true,
  }));

/** Generates a partial-payment invoice (0 < paid < total). */
const partialPaymentInvoiceArb: fc.Arbitrary<ReminderInvoice> = fc
  .record({
    invoiceId: invoiceIdArb,
    customerId: customerIdArb,
    businessId: businessIdArb,
    dueDate: dueDateArb,
    totalAmountPaise: fc.integer({ min: 200, max: 10_000_000 }),
    paidFraction: fc.double({ min: 0.01, max: 0.99, noNaN: true }),
  })
  .map(({ totalAmountPaise, paidFraction, ...rest }) => {
    const paidAmountPaise = Math.max(1, Math.floor(totalAmountPaise * paidFraction));
    return {
      ...rest,
      totalAmountPaise,
      paidAmountPaise: Math.min(paidAmountPaise, totalAmountPaise - 1), // ensure not fully paid
      isPaid: false,
    };
  });

/** Generates a reminder history with a sent count. */
const historyArb: fc.Arbitrary<ReminderHistory> = fc
  .integer({ min: 0, max: 50 })
  .map((sentCount) => ({ sentCount }));

// ── Property 18: Reminder scheduling honors offsets, cap, cancellation, and partial-payment continuation ──

describe('Feature: openwa-whatsapp-automation, Property 18: Reminder scheduling honors offsets, cap, cancellation, and partial-payment continuation', () => {
  /**
   * **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.6, 5.7, 5.8**
   */

  // ── Sub-property 1: Before-due reminders are at correct offsets (Req 5.1) ──

  test('before-due reminders are scheduled at the correct day offsets before the due date', () => {
    fc.assert(
      fc.property(
        unpaidInvoiceArb,
        beforeDueDaysArb.filter((arr) => arr.length > 0),
        maxReminderCountArb,
        (invoice, beforeDays, maxCount) => {
          const config: ReminderConfig = {
            beforeDueDateDays: beforeDays,
            afterDueDateDays: [],
            maxReminderCount: Math.max(maxCount, beforeDays.length), // ensure cap doesn't interfere
          };
          const history: ReminderHistory = { sentCount: 0 };

          const result = computeReminderSchedule(invoice, config, history);

          // All produced reminders should be before_due type
          const beforeReminders = result.reminders.filter((r) => r.type === 'before_due');

          // Each before-due reminder's scheduledAt must equal dueDate - offsetDays
          for (const reminder of beforeReminders) {
            const expectedTime = computeBeforeDueReminderTime(invoice.dueDate, Math.abs(reminder.offsetDays));
            expect(new Date(reminder.scheduledAt).getTime()).toBe(new Date(expectedTime).getTime());
          }

          // The offsets should match the configured before days (sorted by time)
          const producedOffsets = beforeReminders.map((r) => Math.abs(r.offsetDays)).sort((a, b) => a - b);
          const expectedOffsets = [...beforeDays].sort((a, b) => a - b);
          expect(producedOffsets).toEqual(expectedOffsets);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: After-due reminders are at correct offsets (Req 5.2) ──

  test('after-due reminders are scheduled at the correct day offsets after the due date', () => {
    fc.assert(
      fc.property(
        unpaidInvoiceArb,
        afterDueDaysArb.filter((arr) => arr.length > 0),
        maxReminderCountArb,
        (invoice, afterDays, maxCount) => {
          const config: ReminderConfig = {
            beforeDueDateDays: [],
            afterDueDateDays: afterDays,
            maxReminderCount: Math.max(maxCount, afterDays.length), // ensure cap doesn't interfere
          };
          const history: ReminderHistory = { sentCount: 0 };

          const result = computeReminderSchedule(invoice, config, history);

          // All produced reminders should be after_due type
          const afterReminders = result.reminders.filter((r) => r.type === 'after_due');

          // Each after-due reminder's scheduledAt must equal dueDate + offsetDays
          for (const reminder of afterReminders) {
            const expectedTime = computeAfterDueReminderTime(invoice.dueDate, reminder.offsetDays);
            expect(new Date(reminder.scheduledAt).getTime()).toBe(new Date(expectedTime).getTime());
          }

          // The offsets should match the configured after days (sorted)
          const producedOffsets = afterReminders.map((r) => r.offsetDays).sort((a, b) => a - b);
          const expectedOffsets = [...afterDays].sort((a, b) => a - b);
          expect(producedOffsets).toEqual(expectedOffsets);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: Max reminder count cap is always respected (Req 5.6, 5.7) ──

  test('newly scheduled reminders never exceed the remaining budget (maxCount - sentCount)', () => {
    fc.assert(
      fc.property(
        unpaidInvoiceArb,
        reminderConfigArb,
        historyArb,
        (invoice, config, history) => {
          const result = computeReminderSchedule(invoice, config, history);

          // The remaining budget is max(0, maxReminderCount - sentCount)
          const remainingBudget = Math.max(0, config.maxReminderCount - history.sentCount);

          // New reminders must never exceed the remaining budget
          expect(result.reminders.length).toBeLessThanOrEqual(remainingBudget);

          // If history already at/above cap, no new reminders should be produced
          if (history.sentCount >= config.maxReminderCount) {
            expect(result.reminders).toHaveLength(0);
            expect(result.maxCountReached).toBe(true);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: Fully paid invoice cancels all reminders (Req 5.4) ──

  test('fully paid invoice produces zero reminders and sets cancelledDueToPaid', () => {
    fc.assert(
      fc.property(
        paidInvoiceArb,
        reminderConfigArb,
        historyArb,
        (paidInvoice, config, history) => {
          const result = computeReminderSchedule(paidInvoice, config, history);

          // No reminders should be scheduled for a paid invoice
          expect(result.reminders).toHaveLength(0);
          // The result must indicate cancellation due to payment
          expect(result.cancelledDueToPaid).toBe(true);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 5: Partial payment continues with updated amount (Req 5.8) ──

  test('partial payment continues reminders with the updated outstanding amount', () => {
    fc.assert(
      fc.property(
        partialPaymentInvoiceArb,
        reminderConfigArb.filter(
          (c) => c.beforeDueDateDays.length + c.afterDueDateDays.length > 0,
        ),
        (invoice, config) => {
          // Ensure the max count allows at least one reminder
          const adjustedConfig: ReminderConfig = {
            ...config,
            maxReminderCount: Math.max(config.maxReminderCount, 1),
          };
          const history: ReminderHistory = { sentCount: 0 };

          const result = computeReminderSchedule(invoice, adjustedConfig, history);

          // Invoice is NOT fully paid, so reminders should not be cancelled
          expect(result.cancelledDueToPaid).toBe(false);

          // If reminders were produced, they must reflect the updated outstanding amount
          const expectedOutstanding = computeOutstandingAmount(invoice);
          expect(expectedOutstanding).toBeGreaterThan(0); // partial payment → still owed

          for (const reminder of result.reminders) {
            expect(reminder.content.outstandingAmountPaise).toBe(expectedOutstanding);
            expect(reminder.content.dueDate).toBe(invoice.dueDate);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Invariant: shouldCancelReminders agrees with computeReminderSchedule ──

  test('shouldCancelReminders returns true iff invoice is fully paid', () => {
    fc.assert(
      fc.property(
        fc.oneof(paidInvoiceArb, unpaidInvoiceArb),
        (invoice) => {
          const cancelResult = shouldCancelReminders(invoice);

          if (invoice.isPaid || invoice.paidAmountPaise >= invoice.totalAmountPaise) {
            expect(cancelResult.shouldCancel).toBe(true);
          } else {
            expect(cancelResult.shouldCancel).toBe(false);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Invariant: computeUpdatedReminderContent continues when outstanding > 0 ──

  test('computeUpdatedReminderContent continues with correct amount for partial payments', () => {
    fc.assert(
      fc.property(
        partialPaymentInvoiceArb,
        (invoice) => {
          const result = computeUpdatedReminderContent(invoice);

          // Partial payment → should continue
          expect(result.shouldContinue).toBe(true);
          expect(result.content).not.toBeNull();

          // Content outstanding must equal total - paid
          const expectedOutstanding = invoice.totalAmountPaise - invoice.paidAmountPaise;
          expect(result.content!.outstandingAmountPaise).toBe(expectedOutstanding);
          expect(result.content!.dueDate).toBe(invoice.dueDate);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Invariant: History at or above max → zero new reminders (Req 5.7) ──

  test('when sentCount >= maxReminderCount, zero new reminders are scheduled', () => {
    fc.assert(
      fc.property(
        unpaidInvoiceArb,
        reminderConfigArb,
        (invoice, config) => {
          // Set history to be at or above the max count
          const history: ReminderHistory = { sentCount: config.maxReminderCount };

          const result = computeReminderSchedule(invoice, config, history);

          expect(result.reminders).toHaveLength(0);
          expect(result.maxCountReached).toBe(true);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
