// ============================================================================
// Property-Based Test — Reminder Content
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 19
//
// Validates: Requirements 5.5
//
// Property 19 (design.md): Reminder content includes the current outstanding
// amount and due date.
//
// Every computed reminder must include:
// 1. The outstanding amount (totalAmountPaise - paidAmountPaise, clamped >= 0)
// 2. The invoice due date
// 3. Amount is in integer paise (non-negative integer)
// 4. Due date is ISO-8601 UTC
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  buildReminderContent,
  computeReminderSchedule,
  computeOutstandingAmount,
} from '../../services/reminder-schedule.service';
import type {
  ReminderInvoice,
  ReminderConfig,
  ReminderHistory,
  ReminderContent,
  ScheduledReminder,
} from '../../services/reminder-schedule.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** ISO-8601 UTC date string generator (valid dates in reasonable range). */
const isoDateArb: fc.Arbitrary<string> = fc
  .date({
    min: new Date('2020-01-01T00:00:00.000Z'),
    max: new Date('2030-12-31T23:59:59.999Z'),
  })
  .map((d) => d.toISOString());

/** Integer paise amount generator (0 to 10 crore = 100,000,000 paise). */
const paiseAmountArb: fc.Arbitrary<number> = fc.integer({ min: 0, max: 100_000_000 });

/** Positive paise amount (at least 1 paisa outstanding). */
const positivePaiseArb: fc.Arbitrary<number> = fc.integer({ min: 1, max: 100_000_000 });

/** Valid offset days (1–365). */
const offsetDaysArb: fc.Arbitrary<number> = fc.integer({ min: 1, max: 365 });

/** Array of 1–5 valid offset days (for before/after due date configs). */
const offsetDaysArrayArb: fc.Arbitrary<number[]> = fc.array(offsetDaysArb, { minLength: 1, maxLength: 5 });

/** Valid max reminder count (1–100). */
const maxReminderCountArb: fc.Arbitrary<number> = fc.integer({ min: 1, max: 100 });

/** Generates a ReminderInvoice with outstanding balance > 0 (not fully paid). */
const unpaidInvoiceArb: fc.Arbitrary<ReminderInvoice> = fc
  .tuple(
    fc.uuid(),
    fc.uuid(),
    fc.uuid(),
    isoDateArb,
    positivePaiseArb,
  )
  .chain(([invoiceId, customerId, businessId, dueDate, totalAmountPaise]) =>
    fc.integer({ min: 0, max: totalAmountPaise - 1 }).map((paidAmountPaise) => ({
      invoiceId,
      customerId,
      businessId,
      dueDate,
      totalAmountPaise,
      paidAmountPaise,
      isPaid: false,
    })),
  );

/** Generates a valid ReminderConfig. */
const reminderConfigArb: fc.Arbitrary<ReminderConfig> = fc.tuple(
  offsetDaysArrayArb,
  offsetDaysArrayArb,
  maxReminderCountArb,
).map(([beforeDueDateDays, afterDueDateDays, maxReminderCount]) => ({
  beforeDueDateDays,
  afterDueDateDays,
  maxReminderCount,
}));

/** Generates a ReminderHistory with 0 sent (so reminders will be generated). */
const zeroHistoryArb: fc.Arbitrary<ReminderHistory> = fc.constant({ sentCount: 0 });

/** ISO-8601 UTC regex for validation. */
const ISO_8601_UTC_REGEX = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$/;

// ── Property 19: Reminder content includes outstanding amount and due date ──

describe('Feature: openwa-whatsapp-automation, Property 19: Reminder content includes the current outstanding amount and due date', () => {
  // ── 1) Every computed reminder includes the outstanding amount ─────────────

  test('every computed reminder includes the outstanding amount (Req 5.5)', () => {
    fc.assert(
      fc.property(unpaidInvoiceArb, reminderConfigArb, zeroHistoryArb, (invoice, config, history) => {
        const result = computeReminderSchedule(invoice, config, history);

        // Should have at least one reminder since invoice is unpaid and history is 0
        expect(result.cancelledDueToPaid).toBe(false);

        const expectedOutstanding = computeOutstandingAmount(invoice);

        for (const reminder of result.reminders) {
          expect(reminder.content.outstandingAmountPaise).toBe(expectedOutstanding);
        }
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 2) Every reminder includes the due date ───────────────────────────────

  test('every computed reminder includes the invoice due date (Req 5.5)', () => {
    fc.assert(
      fc.property(unpaidInvoiceArb, reminderConfigArb, zeroHistoryArb, (invoice, config, history) => {
        const result = computeReminderSchedule(invoice, config, history);

        for (const reminder of result.reminders) {
          expect(reminder.content.dueDate).toBe(invoice.dueDate);
        }
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 3) Amount is in integer paise (non-negative integer) ───────────────────

  test('outstanding amount in content is a non-negative integer (paise) (Req 5.5)', () => {
    fc.assert(
      fc.property(unpaidInvoiceArb, reminderConfigArb, zeroHistoryArb, (invoice, config, history) => {
        const result = computeReminderSchedule(invoice, config, history);

        for (const reminder of result.reminders) {
          const amount = reminder.content.outstandingAmountPaise;
          // Must be a non-negative integer
          expect(Number.isInteger(amount)).toBe(true);
          expect(amount).toBeGreaterThanOrEqual(0);
        }
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 4) Due date is ISO-8601 UTC ───────────────────────────────────────────

  test('due date in content is a valid ISO-8601 UTC string (Req 5.5)', () => {
    fc.assert(
      fc.property(unpaidInvoiceArb, reminderConfigArb, zeroHistoryArb, (invoice, config, history) => {
        const result = computeReminderSchedule(invoice, config, history);

        for (const reminder of result.reminders) {
          const dueDate = reminder.content.dueDate;
          // Must match ISO-8601 UTC format (ends with 'Z')
          expect(dueDate).toMatch(ISO_8601_UTC_REGEX);
          // Must be a parseable date
          expect(new Date(dueDate).toISOString()).toBe(dueDate);
        }
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── buildReminderContent directly: outstanding amount correctness ──────────

  test('buildReminderContent computes outstanding = total - paid, clamped to >= 0 (Req 5.5)', () => {
    fc.assert(
      fc.property(
        fc.uuid(),
        fc.uuid(),
        fc.uuid(),
        isoDateArb,
        paiseAmountArb,
        paiseAmountArb,
        (invoiceId, customerId, businessId, dueDate, totalAmountPaise, paidAmountPaise) => {
          const invoice: ReminderInvoice = {
            invoiceId,
            customerId,
            businessId,
            dueDate,
            totalAmountPaise,
            paidAmountPaise,
            isPaid: paidAmountPaise >= totalAmountPaise,
          };

          const content = buildReminderContent(invoice);

          const expectedOutstanding = Math.max(0, totalAmountPaise - paidAmountPaise);
          expect(content.outstandingAmountPaise).toBe(expectedOutstanding);
          expect(Number.isInteger(content.outstandingAmountPaise)).toBe(true);
          expect(content.outstandingAmountPaise).toBeGreaterThanOrEqual(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── buildReminderContent directly: due date preservation ──────────────────

  test('buildReminderContent preserves the invoice due date as ISO-8601 UTC (Req 5.5)', () => {
    fc.assert(
      fc.property(unpaidInvoiceArb, (invoice) => {
        const content = buildReminderContent(invoice);

        expect(content.dueDate).toBe(invoice.dueDate);
        expect(content.dueDate).toMatch(ISO_8601_UTC_REGEX);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Partial payment: updated outstanding reflected in content (Req 5.8) ───

  test('after partial payment, reminder content reflects the updated outstanding balance (Req 5.5, 5.8)', () => {
    fc.assert(
      fc.property(
        unpaidInvoiceArb,
        reminderConfigArb,
        zeroHistoryArb,
        (invoice, config, history) => {
          // Simulate a partial payment: add some amount (still keep balance > 0)
          const additionalPayment = Math.floor((invoice.totalAmountPaise - invoice.paidAmountPaise) / 2);
          if (additionalPayment <= 0) return; // skip degenerate case

          const updatedInvoice: ReminderInvoice = {
            ...invoice,
            paidAmountPaise: invoice.paidAmountPaise + additionalPayment,
            isPaid: false,
          };

          const result = computeReminderSchedule(updatedInvoice, config, history);
          const expectedOutstanding = updatedInvoice.totalAmountPaise - updatedInvoice.paidAmountPaise;

          for (const reminder of result.reminders) {
            // Content reflects the UPDATED outstanding amount after partial payment
            expect(reminder.content.outstandingAmountPaise).toBe(expectedOutstanding);
            // Due date is still present
            expect(reminder.content.dueDate).toBe(invoice.dueDate);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
