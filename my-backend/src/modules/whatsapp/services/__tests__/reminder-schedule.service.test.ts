// ============================================================================
// Unit Tests — Reminder Schedule Service (Task 10.1)
// ============================================================================
// Tests cover: before/after due-date computation, max-count cap,
// cancel-on-paid, partial-payment continuation, and content inclusion.
//
// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8
// ============================================================================

import {
  computeReminderSchedule,
  computeOutstandingAmount,
  isInvoiceFullyPaid,
  computeBeforeDueReminderTime,
  computeAfterDueReminderTime,
  buildReminderContent,
  shouldCancelReminders,
  computeUpdatedReminderContent,
  filterDueReminders,
  filterFutureReminders,
  isValidOffsetDays,
  isValidMaxReminderCount,
  validateReminderConfig,
  formatPaiseAmount,
  formatDate,
  ReminderInvoice,
  ReminderConfig,
  ReminderHistory,
} from '../reminder-schedule.service';

// ── Test fixtures ─────────────────────────────────────────────────────────────

const baseInvoice: ReminderInvoice = {
  invoiceId: 'INV-001',
  customerId: 'CUST-001',
  businessId: 'BIZ-001',
  dueDate: '2025-02-15T00:00:00.000Z',
  totalAmountPaise: 100000, // ₹1,000.00
  paidAmountPaise: 0,
  isPaid: false,
};

const baseConfig: ReminderConfig = {
  beforeDueDateDays: [7, 3, 1],
  afterDueDateDays: [1, 3, 7, 14],
  maxReminderCount: 10,
};

const emptyHistory: ReminderHistory = { sentCount: 0 };

// ── Validation tests ──────────────────────────────────────────────────────────

describe('reminder-schedule.service validation', () => {
  test('isValidOffsetDays accepts 1–365', () => {
    expect(isValidOffsetDays(1)).toBe(true);
    expect(isValidOffsetDays(365)).toBe(true);
    expect(isValidOffsetDays(100)).toBe(true);
  });

  test('isValidOffsetDays rejects out-of-range values', () => {
    expect(isValidOffsetDays(0)).toBe(false);
    expect(isValidOffsetDays(-1)).toBe(false);
    expect(isValidOffsetDays(366)).toBe(false);
    expect(isValidOffsetDays(1.5)).toBe(false);
  });

  test('isValidMaxReminderCount accepts 1–100', () => {
    expect(isValidMaxReminderCount(1)).toBe(true);
    expect(isValidMaxReminderCount(100)).toBe(true);
    expect(isValidMaxReminderCount(50)).toBe(true);
  });

  test('isValidMaxReminderCount rejects out-of-range values', () => {
    expect(isValidMaxReminderCount(0)).toBe(false);
    expect(isValidMaxReminderCount(101)).toBe(false);
    expect(isValidMaxReminderCount(-1)).toBe(false);
  });

  test('validateReminderConfig returns null for valid config', () => {
    expect(validateReminderConfig(baseConfig)).toBeNull();
  });

  test('validateReminderConfig rejects invalid maxReminderCount', () => {
    const result = validateReminderConfig({ ...baseConfig, maxReminderCount: 0 });
    expect(result).toContain('maxReminderCount');
  });

  test('validateReminderConfig rejects invalid beforeDueDateDays', () => {
    const result = validateReminderConfig({ ...baseConfig, beforeDueDateDays: [0] });
    expect(result).toContain('beforeDueDateDays');
  });

  test('validateReminderConfig rejects invalid afterDueDateDays', () => {
    const result = validateReminderConfig({ ...baseConfig, afterDueDateDays: [366] });
    expect(result).toContain('afterDueDateDays');
  });
});

// ── Outstanding amount computation ────────────────────────────────────────────

describe('computeOutstandingAmount', () => {
  test('returns full amount when nothing paid', () => {
    expect(computeOutstandingAmount(baseInvoice)).toBe(100000);
  });

  test('returns reduced amount after partial payment', () => {
    const invoice = { ...baseInvoice, paidAmountPaise: 30000 };
    expect(computeOutstandingAmount(invoice)).toBe(70000);
  });

  test('returns 0 when fully paid', () => {
    const invoice = { ...baseInvoice, paidAmountPaise: 100000, isPaid: true };
    expect(computeOutstandingAmount(invoice)).toBe(0);
  });

  test('clamps to 0 when overpaid', () => {
    const invoice = { ...baseInvoice, paidAmountPaise: 110000 };
    expect(computeOutstandingAmount(invoice)).toBe(0);
  });
});

// ── Fully paid check ──────────────────────────────────────────────────────────

describe('isInvoiceFullyPaid', () => {
  test('returns false when unpaid', () => {
    expect(isInvoiceFullyPaid(baseInvoice)).toBe(false);
  });

  test('returns true when isPaid flag is set', () => {
    expect(isInvoiceFullyPaid({ ...baseInvoice, isPaid: true })).toBe(true);
  });

  test('returns true when paid >= total', () => {
    expect(isInvoiceFullyPaid({ ...baseInvoice, paidAmountPaise: 100000 })).toBe(true);
  });

  test('returns false when partially paid', () => {
    expect(isInvoiceFullyPaid({ ...baseInvoice, paidAmountPaise: 50000 })).toBe(false);
  });
});

// ── Time computation ──────────────────────────────────────────────────────────

describe('computeBeforeDueReminderTime', () => {
  test('computes correct time for 7 days before', () => {
    const result = computeBeforeDueReminderTime('2025-02-15T00:00:00.000Z', 7);
    expect(result).toBe('2025-02-08T00:00:00.000Z');
  });

  test('computes correct time for 1 day before', () => {
    const result = computeBeforeDueReminderTime('2025-02-15T00:00:00.000Z', 1);
    expect(result).toBe('2025-02-14T00:00:00.000Z');
  });
});

describe('computeAfterDueReminderTime', () => {
  test('computes correct time for 1 day after', () => {
    const result = computeAfterDueReminderTime('2025-02-15T00:00:00.000Z', 1);
    expect(result).toBe('2025-02-16T00:00:00.000Z');
  });

  test('computes correct time for 14 days after', () => {
    const result = computeAfterDueReminderTime('2025-02-15T00:00:00.000Z', 14);
    expect(result).toBe('2025-03-01T00:00:00.000Z');
  });
});

// ── Content building (Req 5.5) ────────────────────────────────────────────────

describe('buildReminderContent', () => {
  test('includes outstanding amount and due date', () => {
    const content = buildReminderContent(baseInvoice);
    expect(content.outstandingAmountPaise).toBe(100000);
    expect(content.dueDate).toBe('2025-02-15T00:00:00.000Z');
    expect(content.formattedOutstandingAmount).toContain('1,000');
    expect(content.formattedDueDate).toBe('15-Feb-2025');
  });

  test('reflects partial payment in outstanding amount (Req 5.8)', () => {
    const invoice = { ...baseInvoice, paidAmountPaise: 40000 };
    const content = buildReminderContent(invoice);
    expect(content.outstandingAmountPaise).toBe(60000);
    expect(content.formattedOutstandingAmount).toContain('600');
  });
});

// ── Format helpers ────────────────────────────────────────────────────────────

describe('formatPaiseAmount', () => {
  test('formats zero', () => {
    expect(formatPaiseAmount(0)).toBe('₹0.00');
  });

  test('formats large amounts with Indian locale', () => {
    const result = formatPaiseAmount(1234567);
    expect(result).toContain('12,345.67');
  });
});

describe('formatDate', () => {
  test('formats ISO date correctly', () => {
    expect(formatDate('2025-02-15T00:00:00.000Z')).toBe('15-Feb-2025');
  });

  test('formats another date', () => {
    expect(formatDate('2025-12-01T12:00:00.000Z')).toBe('01-Dec-2025');
  });
});

// ── Main schedule computation ─────────────────────────────────────────────────

describe('computeReminderSchedule', () => {
  // Req 5.4: Cancel-on-paid
  test('returns empty schedule when invoice is fully paid', () => {
    const paidInvoice = { ...baseInvoice, paidAmountPaise: 100000, isPaid: true };
    const result = computeReminderSchedule(paidInvoice, baseConfig, emptyHistory);

    expect(result.reminders).toHaveLength(0);
    expect(result.cancelledDueToPaid).toBe(true);
    expect(result.maxCountReached).toBe(false);
  });

  // Req 5.1, 5.2: Before and after due-date reminders
  test('schedules before and after due-date reminders', () => {
    const result = computeReminderSchedule(baseInvoice, baseConfig, emptyHistory);

    expect(result.reminders.length).toBe(7); // 3 before + 4 after
    expect(result.cancelledDueToPaid).toBe(false);

    // Check types
    const beforeReminders = result.reminders.filter((r) => r.type === 'before_due');
    const afterReminders = result.reminders.filter((r) => r.type === 'after_due');
    expect(beforeReminders).toHaveLength(3);
    expect(afterReminders).toHaveLength(4);
  });

  // Req 5.5: Content includes outstanding amount and due date
  test('every reminder includes outstanding amount and due date', () => {
    const result = computeReminderSchedule(baseInvoice, baseConfig, emptyHistory);

    for (const reminder of result.reminders) {
      expect(reminder.content.outstandingAmountPaise).toBe(100000);
      expect(reminder.content.dueDate).toBe('2025-02-15T00:00:00.000Z');
      expect(reminder.content.formattedOutstandingAmount).toBeTruthy();
      expect(reminder.content.formattedDueDate).toBeTruthy();
    }
  });

  // Req 5.6, 5.7: Max count cap
  test('caps reminders at maxReminderCount', () => {
    const limitedConfig: ReminderConfig = {
      beforeDueDateDays: [7, 3, 1],
      afterDueDateDays: [1, 3, 7, 14],
      maxReminderCount: 4,
    };
    const result = computeReminderSchedule(baseInvoice, limitedConfig, emptyHistory);

    expect(result.reminders).toHaveLength(4);
    expect(result.maxCountReached).toBe(true);
  });

  // Req 5.7: Suppress when max already reached
  test('returns empty when sentCount already equals max', () => {
    const history: ReminderHistory = { sentCount: 10 };
    const result = computeReminderSchedule(baseInvoice, baseConfig, history);

    expect(result.reminders).toHaveLength(0);
    expect(result.maxCountReached).toBe(true);
    expect(result.suppressionReason).toContain('Maximum reminder count');
  });

  // Req 5.7: Partial history respects remaining budget
  test('respects remaining budget from history', () => {
    const history: ReminderHistory = { sentCount: 8 };
    const result = computeReminderSchedule(baseInvoice, baseConfig, history);

    // maxReminderCount is 10, sentCount is 8, so remaining budget is 2
    expect(result.reminders).toHaveLength(2);
    expect(result.maxCountReached).toBe(true);
  });

  // Req 5.8: Partial payment continuation
  test('continues with updated outstanding amount after partial payment', () => {
    const partialPaidInvoice = { ...baseInvoice, paidAmountPaise: 30000 };
    const result = computeReminderSchedule(partialPaidInvoice, baseConfig, emptyHistory);

    expect(result.reminders.length).toBeGreaterThan(0);
    expect(result.cancelledDueToPaid).toBe(false);

    // Every reminder should have the UPDATED outstanding amount
    for (const reminder of result.reminders) {
      expect(reminder.content.outstandingAmountPaise).toBe(70000);
    }
  });

  test('returns error for invalid config', () => {
    const invalidConfig: ReminderConfig = {
      beforeDueDateDays: [0], // invalid
      afterDueDateDays: [1],
      maxReminderCount: 5,
    };
    const result = computeReminderSchedule(baseInvoice, invalidConfig, emptyHistory);

    expect(result.reminders).toHaveLength(0);
    expect(result.suppressionReason).toContain('Invalid reminder config');
  });

  // Reminders are ordered by scheduled time
  test('reminders are ordered by scheduled time ascending', () => {
    const result = computeReminderSchedule(baseInvoice, baseConfig, emptyHistory);

    for (let i = 1; i < result.reminders.length; i++) {
      const prev = new Date(result.reminders[i - 1].scheduledAt).getTime();
      const curr = new Date(result.reminders[i].scheduledAt).getTime();
      expect(curr).toBeGreaterThanOrEqual(prev);
    }
  });

  // Sequence numbers are correct
  test('sequence numbers are sequential starting from sentCount + 1', () => {
    const history: ReminderHistory = { sentCount: 3 };
    const result = computeReminderSchedule(baseInvoice, baseConfig, history);

    for (let i = 0; i < result.reminders.length; i++) {
      expect(result.reminders[i].sequenceNumber).toBe(4 + i);
    }
  });

  // Each reminder targets the correct invoice and customer
  test('reminders carry correct invoice, customer, and business IDs', () => {
    const result = computeReminderSchedule(baseInvoice, baseConfig, emptyHistory);

    for (const reminder of result.reminders) {
      expect(reminder.invoiceId).toBe('INV-001');
      expect(reminder.customerId).toBe('CUST-001');
      expect(reminder.businessId).toBe('BIZ-001');
    }
  });
});

// ── shouldCancelReminders ─────────────────────────────────────────────────────

describe('shouldCancelReminders', () => {
  test('returns shouldCancel=true for fully paid invoice', () => {
    const paid = { ...baseInvoice, paidAmountPaise: 100000, isPaid: true };
    const result = shouldCancelReminders(paid);
    expect(result.shouldCancel).toBe(true);
    expect(result.reason).toContain('fully paid');
  });

  test('returns shouldCancel=false for unpaid invoice', () => {
    const result = shouldCancelReminders(baseInvoice);
    expect(result.shouldCancel).toBe(false);
    expect(result.reason).toContain('outstanding balance');
  });
});

// ── computeUpdatedReminderContent ─────────────────────────────────────────────

describe('computeUpdatedReminderContent', () => {
  test('returns shouldContinue=false for fully paid', () => {
    const paid = { ...baseInvoice, paidAmountPaise: 100000, isPaid: true };
    const result = computeUpdatedReminderContent(paid);
    expect(result.shouldContinue).toBe(false);
    expect(result.content).toBeNull();
  });

  test('returns updated content for partial payment', () => {
    const partial = { ...baseInvoice, paidAmountPaise: 60000 };
    const result = computeUpdatedReminderContent(partial);
    expect(result.shouldContinue).toBe(true);
    expect(result.content).not.toBeNull();
    expect(result.content!.outstandingAmountPaise).toBe(40000);
  });
});

// ── filterDueReminders / filterFutureReminders ────────────────────────────────

describe('filterDueReminders', () => {
  test('returns reminders scheduled at or before current time', () => {
    const result = computeReminderSchedule(baseInvoice, baseConfig, emptyHistory);
    // Current time is after all scheduled times
    const dueReminders = filterDueReminders(result.reminders, '2025-03-15T00:00:00.000Z');
    expect(dueReminders).toHaveLength(result.reminders.length);
  });

  test('returns empty when no reminders are due', () => {
    const result = computeReminderSchedule(baseInvoice, baseConfig, emptyHistory);
    // Current time is before all scheduled times
    const dueReminders = filterDueReminders(result.reminders, '2025-01-01T00:00:00.000Z');
    expect(dueReminders).toHaveLength(0);
  });
});

describe('filterFutureReminders', () => {
  test('returns reminders scheduled after current time', () => {
    const result = computeReminderSchedule(baseInvoice, baseConfig, emptyHistory);
    // Current time is before all scheduled times
    const futureReminders = filterFutureReminders(result.reminders, '2025-01-01T00:00:00.000Z');
    expect(futureReminders).toHaveLength(result.reminders.length);
  });

  test('returns empty when all reminders are past', () => {
    const result = computeReminderSchedule(baseInvoice, baseConfig, emptyHistory);
    const futureReminders = filterFutureReminders(result.reminders, '2025-03-15T00:00:00.000Z');
    expect(futureReminders).toHaveLength(0);
  });
});
