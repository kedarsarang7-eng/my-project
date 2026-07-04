// ============================================================================
// WhatsApp Automation Module — Reminder Schedule Service (Task 10.1)
// ============================================================================
// Pure computation of payment reminder schedules: before/after due-date
// reminder times, max-count cap, cancel-on-paid, partial-payment continuation,
// and inclusion of current outstanding amount + due date in content.
//
// DESIGN CONTRACTS:
// - All functions are pure (deterministic, side-effect-free) for testability
// - Money is integer paise (never floating-point)
// - Timestamps are ISO-8601 UTC strings
// - Before due-date reminders: configurable 1–365 days before
// - After due-date reminders: configurable 1–365 days after, while unpaid
// - Max reminder count: 1–100; once reached, suppress with logged reason
// - Cancel-on-paid: fully paid invoice → all pending/future reminders cancelled
// - Partial-payment: balance still > 0 → continue with updated amount
// - Content includes current outstanding amount and due date (Req 5.5)
//
// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8
// ============================================================================

// ── Types ─────────────────────────────────────────────────────────────────────

/** Invoice data needed for reminder computation. */
export interface ReminderInvoice {
  /** Unique invoice identifier. */
  invoiceId: string;
  /** The customer this invoice belongs to. */
  customerId: string;
  /** BusinessID scope. */
  businessId: string;
  /** Invoice due date as ISO-8601 UTC string. */
  dueDate: string;
  /** Total invoice amount in integer paise. */
  totalAmountPaise: number;
  /** Amount already paid in integer paise. */
  paidAmountPaise: number;
  /** Whether the invoice is fully paid (totalAmountPaise === paidAmountPaise). */
  isPaid: boolean;
}

/** Configuration for reminder scheduling. */
export interface ReminderConfig {
  /**
   * Days before the due date to send reminders (1–365 each).
   * E.g. [7, 3, 1] means send at 7 days, 3 days, and 1 day before due.
   */
  beforeDueDateDays: number[];
  /**
   * Days after the due date to send reminders (1–365 each).
   * E.g. [1, 3, 7, 14] means send at 1 day, 3 days, 7 days, 14 days after due.
   * Only applies while the invoice remains unpaid.
   */
  afterDueDateDays: number[];
  /**
   * Maximum total number of reminders for a single invoice (1–100).
   * Once reached, no further reminders are scheduled.
   */
  maxReminderCount: number;
}

/** A single computed reminder with its scheduled time and content context. */
export interface ScheduledReminder {
  /** Unique identifier for this reminder (invoiceId + sequence). */
  reminderId: string;
  /** The invoice this reminder is for. */
  invoiceId: string;
  /** The customer to notify. */
  customerId: string;
  /** BusinessID scope. */
  businessId: string;
  /** Scheduled dispatch time as ISO-8601 UTC string. */
  scheduledAt: string;
  /** Whether this is a before-due or after-due reminder. */
  type: 'before_due' | 'after_due';
  /** Offset in days from due date (positive for after, negative for before). */
  offsetDays: number;
  /** The sequence number of this reminder (1-based). */
  sequenceNumber: number;
  /** Content context for template rendering. */
  content: ReminderContent;
}

/** Content data included in every reminder (Req 5.5). */
export interface ReminderContent {
  /** Current outstanding amount in integer paise at time of computation. */
  outstandingAmountPaise: number;
  /** Invoice due date as ISO-8601 UTC string. */
  dueDate: string;
  /** Human-readable formatted outstanding amount (for template convenience). */
  formattedOutstandingAmount: string;
  /** Human-readable formatted due date (for template convenience). */
  formattedDueDate: string;
}

/** Result of computing a reminder schedule. */
export interface ReminderScheduleResult {
  /** The computed reminders that should be scheduled. */
  reminders: ScheduledReminder[];
  /** Whether the max count cap was reached. */
  maxCountReached: boolean;
  /** Whether the invoice is fully paid (all reminders cancelled). */
  cancelledDueToPaid: boolean;
  /** Suppression reason if applicable. */
  suppressionReason?: string;
}

/** Input describing reminders already sent for an invoice. */
export interface ReminderHistory {
  /** Number of reminders already sent for this invoice. */
  sentCount: number;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const MILLIS_PER_DAY = 24 * 60 * 60 * 1000;
const MIN_OFFSET_DAYS = 1;
const MAX_OFFSET_DAYS = 365;
const MIN_MAX_REMINDERS = 1;
const MAX_MAX_REMINDERS = 100;

// ── Validation Helpers ────────────────────────────────────────────────────────

/**
 * Validates that a day offset is within the allowed range (1–365).
 */
export function isValidOffsetDays(days: number): boolean {
  return Number.isInteger(days) && days >= MIN_OFFSET_DAYS && days <= MAX_OFFSET_DAYS;
}

/**
 * Validates that a max reminder count is within the allowed range (1–100).
 */
export function isValidMaxReminderCount(count: number): boolean {
  return Number.isInteger(count) && count >= MIN_MAX_REMINDERS && count <= MAX_MAX_REMINDERS;
}

/**
 * Validates a full ReminderConfig.
 * Returns an error message string on invalid, or null if valid.
 */
export function validateReminderConfig(config: ReminderConfig): string | null {
  if (!isValidMaxReminderCount(config.maxReminderCount)) {
    return `maxReminderCount must be an integer between ${MIN_MAX_REMINDERS} and ${MAX_MAX_REMINDERS}, got ${config.maxReminderCount}`;
  }

  for (const days of config.beforeDueDateDays) {
    if (!isValidOffsetDays(days)) {
      return `beforeDueDateDays contains invalid offset ${days}; must be integer between ${MIN_OFFSET_DAYS} and ${MAX_OFFSET_DAYS}`;
    }
  }

  for (const days of config.afterDueDateDays) {
    if (!isValidOffsetDays(days)) {
      return `afterDueDateDays contains invalid offset ${days}; must be integer between ${MIN_OFFSET_DAYS} and ${MAX_OFFSET_DAYS}`;
    }
  }

  return null;
}

// ── Core Computation Functions ────────────────────────────────────────────────

/**
 * Computes the outstanding amount for an invoice in integer paise.
 * Always non-negative (clamps to 0 if overpaid).
 */
export function computeOutstandingAmount(invoice: ReminderInvoice): number {
  const outstanding = invoice.totalAmountPaise - invoice.paidAmountPaise;
  return Math.max(0, outstanding);
}

/**
 * Determines whether an invoice is fully paid.
 * An invoice is fully paid when paid amount >= total amount.
 */
export function isInvoiceFullyPaid(invoice: ReminderInvoice): boolean {
  return invoice.isPaid || invoice.paidAmountPaise >= invoice.totalAmountPaise;
}

/**
 * Computes the scheduled time for a before-due-date reminder.
 * Returns the ISO-8601 UTC timestamp that is `daysBefore` days before the due date.
 */
export function computeBeforeDueReminderTime(dueDate: string, daysBefore: number): string {
  const dueDateMs = new Date(dueDate).getTime();
  const reminderMs = dueDateMs - daysBefore * MILLIS_PER_DAY;
  return new Date(reminderMs).toISOString();
}

/**
 * Computes the scheduled time for an after-due-date reminder.
 * Returns the ISO-8601 UTC timestamp that is `daysAfter` days after the due date.
 */
export function computeAfterDueReminderTime(dueDate: string, daysAfter: number): string {
  const dueDateMs = new Date(dueDate).getTime();
  const reminderMs = dueDateMs + daysAfter * MILLIS_PER_DAY;
  return new Date(reminderMs).toISOString();
}

/**
 * Builds the reminder content data that MUST be included in every reminder.
 * Contains the current outstanding amount and due date (Req 5.5).
 */
export function buildReminderContent(invoice: ReminderInvoice): ReminderContent {
  const outstandingAmountPaise = computeOutstandingAmount(invoice);
  return {
    outstandingAmountPaise,
    dueDate: invoice.dueDate,
    formattedOutstandingAmount: formatPaiseAmount(outstandingAmountPaise),
    formattedDueDate: formatDate(invoice.dueDate),
  };
}

/**
 * Formats an amount in paise to a human-readable string (e.g. "₹1,234.56").
 * Uses Indian locale formatting with 2 decimal places.
 */
export function formatPaiseAmount(paise: number): string {
  const rupees = paise / 100;
  return `₹${rupees.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

/**
 * Formats an ISO-8601 date string to a human-readable date (DD-MMM-YYYY).
 */
export function formatDate(isoDate: string): string {
  const date = new Date(isoDate);
  const day = String(date.getUTCDate()).padStart(2, '0');
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const month = months[date.getUTCMonth()];
  const year = date.getUTCFullYear();
  return `${day}-${month}-${year}`;
}

// ── Main Schedule Computation ─────────────────────────────────────────────────

/**
 * Computes the full reminder schedule for an invoice.
 *
 * This is the primary pure function that implements all reminder scheduling logic:
 *
 * 1. Cancel-on-paid (Req 5.4): If the invoice is fully paid, returns empty
 *    schedule with cancelledDueToPaid = true. ALL pending/future reminders
 *    are cancelled — no further reminder is enqueued.
 *
 * 2. Before due-date reminders (Req 5.1): Schedules reminders at each
 *    configured offset (1–365 days) before the due date.
 *
 * 3. After due-date reminders (Req 5.2, 5.3): Schedules reminders at each
 *    configured offset (1–365 days) after the due date while the invoice
 *    remains unpaid. The outstanding balance is checked at computation time.
 *
 * 4. Max-count cap (Req 5.6, 5.7): Never exceeds the configured maximum
 *    (1–100). Once reached, further reminders are suppressed and the reason
 *    is recorded.
 *
 * 5. Content (Req 5.5): Every reminder includes the current outstanding
 *    amount and the invoice due date.
 *
 * 6. Partial-payment continuation (Req 5.8): If a partial payment reduces
 *    the balance but not to zero, the schedule continues with the UPDATED
 *    outstanding amount reflected in the content.
 *
 * @param invoice - The invoice to compute reminders for
 * @param config - The reminder scheduling configuration
 * @param history - The history of previously sent reminders
 * @param currentTime - The current time for filtering due reminders (ISO-8601)
 * @returns The computed reminder schedule result
 */
export function computeReminderSchedule(
  invoice: ReminderInvoice,
  config: ReminderConfig,
  history: ReminderHistory,
  currentTime?: string,
): ReminderScheduleResult {
  // ── Validate config ─────────────────────────────────────────────────────
  const configError = validateReminderConfig(config);
  if (configError) {
    return {
      reminders: [],
      maxCountReached: false,
      cancelledDueToPaid: false,
      suppressionReason: `Invalid reminder config: ${configError}`,
    };
  }

  // ── Cancel-on-paid (Req 5.4) ────────────────────────────────────────────
  // When an invoice is fully paid, ALL pending/future reminders are cancelled.
  if (isInvoiceFullyPaid(invoice)) {
    return {
      reminders: [],
      maxCountReached: false,
      cancelledDueToPaid: true,
      suppressionReason: 'Invoice is fully paid; all reminders cancelled',
    };
  }

  // ── Max-count cap check (Req 5.6, 5.7) ─────────────────────────────────
  // If the max count has already been reached, suppress immediately.
  if (history.sentCount >= config.maxReminderCount) {
    return {
      reminders: [],
      maxCountReached: true,
      cancelledDueToPaid: false,
      suppressionReason: `Maximum reminder count (${config.maxReminderCount}) reached for invoice ${invoice.invoiceId}; further reminders suppressed`,
    };
  }

  // ── Compute remaining budget ────────────────────────────────────────────
  const remainingBudget = config.maxReminderCount - history.sentCount;

  // ── Build reminder content with current outstanding amount (Req 5.5, 5.8) ──
  const content = buildReminderContent(invoice);

  // ── Compute all candidate reminder times ────────────────────────────────
  const candidates: Array<{ scheduledAt: string; type: 'before_due' | 'after_due'; offsetDays: number }> = [];

  // Before due-date reminders (Req 5.1): sorted ascending by date (earliest first)
  const sortedBeforeDays = [...config.beforeDueDateDays].sort((a, b) => b - a); // larger offset = earlier date
  for (const daysBefore of sortedBeforeDays) {
    candidates.push({
      scheduledAt: computeBeforeDueReminderTime(invoice.dueDate, daysBefore),
      type: 'before_due',
      offsetDays: -daysBefore,
    });
  }

  // After due-date reminders (Req 5.2, 5.3): sorted ascending by date
  const sortedAfterDays = [...config.afterDueDateDays].sort((a, b) => a - b);
  for (const daysAfter of sortedAfterDays) {
    candidates.push({
      scheduledAt: computeAfterDueReminderTime(invoice.dueDate, daysAfter),
      type: 'after_due',
      offsetDays: daysAfter,
    });
  }

  // Sort all candidates by scheduled time ascending
  candidates.sort((a, b) => new Date(a.scheduledAt).getTime() - new Date(b.scheduledAt).getTime());

  // ── Apply max-count cap and build final reminders ───────────────────────
  const reminders: ScheduledReminder[] = [];
  let sequenceNumber = history.sentCount + 1;

  for (const candidate of candidates) {
    if (reminders.length >= remainingBudget) {
      break;
    }

    reminders.push({
      reminderId: `${invoice.invoiceId}_reminder_${sequenceNumber}`,
      invoiceId: invoice.invoiceId,
      customerId: invoice.customerId,
      businessId: invoice.businessId,
      scheduledAt: candidate.scheduledAt,
      type: candidate.type,
      offsetDays: candidate.offsetDays,
      sequenceNumber,
      content,
    });

    sequenceNumber++;
  }

  const totalAfterScheduling = history.sentCount + reminders.length;
  const maxCountReached = totalAfterScheduling >= config.maxReminderCount;

  return {
    reminders,
    maxCountReached,
    cancelledDueToPaid: false,
    suppressionReason: maxCountReached
      ? `Maximum reminder count (${config.maxReminderCount}) will be reached after scheduling; no further reminders after these`
      : undefined,
  };
}

// ── Cancellation Helpers ──────────────────────────────────────────────────────

/**
 * Determines whether all pending reminders for an invoice should be cancelled.
 * Returns true when the invoice is fully paid (Req 5.4).
 *
 * This is a convenience wrapper for the cancel-on-paid check, usable by
 * the scheduler/engine when a payment.received event arrives.
 */
export function shouldCancelReminders(invoice: ReminderInvoice): {
  shouldCancel: boolean;
  reason: string;
} {
  if (isInvoiceFullyPaid(invoice)) {
    return {
      shouldCancel: true,
      reason: `Invoice ${invoice.invoiceId} is fully paid (paid: ${invoice.paidAmountPaise} paise >= total: ${invoice.totalAmountPaise} paise); cancelling all pending/future reminders`,
    };
  }

  return {
    shouldCancel: false,
    reason: `Invoice ${invoice.invoiceId} still has outstanding balance of ${computeOutstandingAmount(invoice)} paise; reminders continue`,
  };
}

/**
 * Determines whether reminder content needs to be updated due to a partial payment.
 * Returns updated content when the balance changed but is still > 0 (Req 5.8).
 *
 * Use case: A partial payment arrives, reducing the outstanding balance.
 * Future reminders should use the UPDATED outstanding amount.
 */
export function computeUpdatedReminderContent(invoice: ReminderInvoice): {
  shouldContinue: boolean;
  content: ReminderContent | null;
  reason: string;
} {
  if (isInvoiceFullyPaid(invoice)) {
    return {
      shouldContinue: false,
      content: null,
      reason: `Invoice ${invoice.invoiceId} is fully paid; reminders should be cancelled`,
    };
  }

  // Partial payment: balance still > 0, continue with updated amount (Req 5.8)
  const content = buildReminderContent(invoice);
  return {
    shouldContinue: true,
    content,
    reason: `Invoice ${invoice.invoiceId} has updated outstanding balance of ${content.outstandingAmountPaise} paise; reminders continue with updated amount`,
  };
}

// ── Filtering: Due Reminders ──────────────────────────────────────────────────

/**
 * Filters a list of scheduled reminders to return only those that are due
 * (scheduled time <= current time). Used by the scheduler sweeper.
 */
export function filterDueReminders(
  reminders: ScheduledReminder[],
  currentTime: string,
): ScheduledReminder[] {
  const currentMs = new Date(currentTime).getTime();
  return reminders.filter((r) => new Date(r.scheduledAt).getTime() <= currentMs);
}

/**
 * Filters a list of scheduled reminders to return only future ones
 * (scheduled time > current time). Used for cancellation: these are the
 * reminders that should be cancelled when an invoice is paid.
 */
export function filterFutureReminders(
  reminders: ScheduledReminder[],
  currentTime: string,
): ScheduledReminder[] {
  const currentMs = new Date(currentTime).getTime();
  return reminders.filter((r) => new Date(r.scheduledAt).getTime() > currentMs);
}
