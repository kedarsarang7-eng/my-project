// ============================================================================
// WhatsApp Automation Module — Collection Workflow Service (Task 10.8)
// ============================================================================
// Pure computation service that advances a payment-collection workflow cursor
// exactly ONE step per payment-status change and produces exactly ONE enqueue
// instruction for that step.
//
// DESIGN CONTRACTS:
// - A collection sequence is an ordered list of steps (e.g., gentle reminder,
//   follow-up, escalation, final notice).
// - Each customer+invoice combination has a cursor tracking which step they are on.
// - On each payment-status change, the cursor advances by EXACTLY one step.
// - Exactly ONE message is enqueued per step advancement — no skips, no duplicates.
// - If the customer is already on the final step, no further advancement occurs.
// - If payment is fully settled (outstanding === 0), the workflow is marked complete.
// - The function is PURE: deterministic, side-effect-free, no DB/IO.
//   (Actual DB writes and enqueue are handled by the caller/engine.)
//
// Requirements: 11.9
// ============================================================================

// ── Types ─────────────────────────────────────────────────────────────────────

/** A single step in a payment-collection workflow sequence. */
export interface CollectionStep {
  /** Unique step identifier within the sequence. */
  stepId: string;
  /** Human-readable name for the step (e.g., "Gentle Reminder"). */
  name: string;
  /** Template ID to use for the message at this step. */
  templateId: string;
  /** Delay in seconds from the status change before sending (0 = immediate). */
  delaySeconds: number;
}

/** The configured collection sequence for a business/workflow. */
export interface CollectionSequence {
  /** Unique ID for this collection sequence configuration. */
  sequenceId: string;
  /** Ordered list of steps. The workflow progresses through them sequentially. */
  steps: CollectionStep[];
}

/** The current workflow cursor state for a specific customer+invoice. */
export interface CollectionWorkflowCursor {
  /** Invoice ID this workflow tracks. */
  invoiceId: string;
  /** Customer ID this workflow tracks. */
  customerId: string;
  /** Business ID (tenant scope). */
  businessId: string;
  /** The sequence ID being followed. */
  sequenceId: string;
  /** Current step index (0-based) — the LAST completed step. -1 means no step taken yet. */
  currentStepIndex: number;
  /** Whether the workflow is complete (paid or all steps exhausted). */
  completed: boolean;
  /** ISO-8601 UTC timestamp of last advancement. */
  lastAdvancedAt: string;
}

/** The payment status change event that triggers workflow advancement. */
export interface PaymentStatusChangeEvent {
  /** Invoice ID whose payment status changed. */
  invoiceId: string;
  /** Customer ID associated with the invoice. */
  customerId: string;
  /** Business ID (tenant scope). */
  businessId: string;
  /** Current outstanding amount in integer paise (0 = fully paid). */
  outstandingAmountPaise: number;
  /** The new payment status label (e.g., "overdue", "partial", "escalated"). */
  newStatus: string;
  /** ISO-8601 UTC timestamp of the status change. */
  timestamp: string;
}

/** Result when the workflow advances one step. */
export interface WorkflowAdvanceResult {
  action: 'advance';
  /** The step that was advanced to. */
  step: CollectionStep;
  /** Updated cursor state after advancement. */
  updatedCursor: CollectionWorkflowCursor;
  /** The enqueue instruction for the message to send. */
  enqueueInstruction: EnqueueInstruction;
}

/** Result when the workflow is complete (fully paid). */
export interface WorkflowCompletedResult {
  action: 'completed';
  /** Reason for completion. */
  reason: string;
  /** Updated cursor state (completed = true). */
  updatedCursor: CollectionWorkflowCursor;
}

/** Result when no further advancement is possible (already at final step). */
export interface WorkflowExhaustedResult {
  action: 'exhausted';
  /** Reason no advancement occurred. */
  reason: string;
  /** Cursor remains unchanged. */
  cursor: CollectionWorkflowCursor;
}

/** Result when the workflow was already completed before this event. */
export interface WorkflowAlreadyCompleteResult {
  action: 'already_complete';
  /** Reason — workflow was completed previously. */
  reason: string;
  /** Cursor remains unchanged. */
  cursor: CollectionWorkflowCursor;
}

/** Union of all possible advancement results. */
export type AdvanceResult =
  | WorkflowAdvanceResult
  | WorkflowCompletedResult
  | WorkflowExhaustedResult
  | WorkflowAlreadyCompleteResult;

/** Instruction for the caller to enqueue exactly one message. */
export interface EnqueueInstruction {
  /** Template ID from the step. */
  templateId: string;
  /** Customer ID (recipient). */
  customerId: string;
  /** Invoice ID (for template placeholders). */
  invoiceId: string;
  /** Business ID. */
  businessId: string;
  /** Step name (for logging/template context). */
  stepName: string;
  /** Step index (0-based) that was advanced to. */
  stepIndex: number;
  /** Delay in seconds before dispatch (from step config). */
  delaySeconds: number;
  /** Current outstanding amount in paise (for template placeholders). */
  outstandingAmountPaise: number;
}

// ── Constants ─────────────────────────────────────────────────────────────────

/** Minimum number of steps a valid collection sequence must have. */
export const MIN_SEQUENCE_STEPS = 1;

/** Maximum number of steps a collection sequence can have. */
export const MAX_SEQUENCE_STEPS = 20;

// ── Validation ────────────────────────────────────────────────────────────────

/**
 * Validates that a collection sequence is well-formed.
 * A valid sequence has 1..20 steps, each with a non-empty stepId and templateId.
 */
export function isValidSequence(sequence: CollectionSequence): boolean {
  if (!sequence || !Array.isArray(sequence.steps)) {
    return false;
  }
  if (
    sequence.steps.length < MIN_SEQUENCE_STEPS ||
    sequence.steps.length > MAX_SEQUENCE_STEPS
  ) {
    return false;
  }
  return sequence.steps.every(
    (step) =>
      typeof step.stepId === 'string' &&
      step.stepId.trim().length > 0 &&
      typeof step.templateId === 'string' &&
      step.templateId.trim().length > 0 &&
      typeof step.delaySeconds === 'number' &&
      Number.isFinite(step.delaySeconds) &&
      step.delaySeconds >= 0,
  );
}

// ── Cursor Initialization ─────────────────────────────────────────────────────

/**
 * Creates the initial cursor state for a new collection workflow.
 * currentStepIndex is -1 indicating no step has been executed yet.
 */
export function createInitialCursor(
  event: PaymentStatusChangeEvent,
  sequenceId: string,
  timestamp: string,
): CollectionWorkflowCursor {
  return {
    invoiceId: event.invoiceId,
    customerId: event.customerId,
    businessId: event.businessId,
    sequenceId,
    currentStepIndex: -1,
    completed: false,
    lastAdvancedAt: timestamp,
  };
}

// ── Core: advanceWorkflow ─────────────────────────────────────────────────────

/**
 * Pure function that advances the payment-collection workflow cursor exactly
 * one step per payment-status change and produces exactly one enqueue
 * instruction for that step.
 *
 * Decision logic (in priority order):
 * 1. If the cursor is already marked complete → `already_complete` (no action)
 * 2. If outstanding amount is 0 (fully paid) → `completed` (mark done, no message)
 * 3. If the cursor is at the final step → `exhausted` (no further steps available)
 * 4. Otherwise → `advance` to the next step and produce one enqueue instruction
 *
 * This function is deterministic and side-effect-free. Given the same inputs
 * it always produces the same output.
 *
 * @param event - The payment status change triggering advancement.
 * @param sequence - The configured collection sequence.
 * @param cursor - The current workflow cursor (null if first time = new workflow).
 * @returns An AdvanceResult describing the action taken and any enqueue instruction.
 *
 * @example
 * ```ts
 * const event: PaymentStatusChangeEvent = {
 *   invoiceId: 'INV-001', customerId: 'CUST-001', businessId: 'BIZ-001',
 *   outstandingAmountPaise: 50000, newStatus: 'overdue',
 *   timestamp: '2024-06-01T10:00:00Z',
 * };
 * const sequence: CollectionSequence = {
 *   sequenceId: 'SEQ-001',
 *   steps: [
 *     { stepId: 'step-1', name: 'Gentle Reminder', templateId: 'TPL-1', delaySeconds: 0 },
 *     { stepId: 'step-2', name: 'Follow-up', templateId: 'TPL-2', delaySeconds: 86400 },
 *   ],
 * };
 * const result = advanceWorkflow(event, sequence, null);
 * // → { action: 'advance', step: steps[0], updatedCursor: {..., currentStepIndex: 0}, ... }
 * ```
 */
export function advanceWorkflow(
  event: PaymentStatusChangeEvent,
  sequence: CollectionSequence,
  cursor: CollectionWorkflowCursor | null,
): AdvanceResult {
  // Initialize cursor if this is the first event for this invoice/customer
  const currentCursor =
    cursor ?? createInitialCursor(event, sequence.sequenceId, event.timestamp);

  // 1. Already complete — no further action
  if (currentCursor.completed) {
    return {
      action: 'already_complete',
      reason: `Workflow for invoice ${event.invoiceId} / customer ${event.customerId} is already complete`,
      cursor: currentCursor,
    };
  }

  // 2. Fully paid — mark complete, no message enqueued
  if (event.outstandingAmountPaise <= 0) {
    const completedCursor: CollectionWorkflowCursor = {
      ...currentCursor,
      completed: true,
      lastAdvancedAt: event.timestamp,
    };
    return {
      action: 'completed',
      reason: `Outstanding amount is zero; invoice ${event.invoiceId} is fully paid`,
      updatedCursor: completedCursor,
    };
  }

  // 3. Determine the next step index
  const nextStepIndex = currentCursor.currentStepIndex + 1;

  // If we've already exhausted all steps, no further advancement
  if (nextStepIndex >= sequence.steps.length) {
    return {
      action: 'exhausted',
      reason: `All ${sequence.steps.length} collection steps have been exhausted for invoice ${event.invoiceId}`,
      cursor: currentCursor,
    };
  }

  // 4. Advance exactly one step
  const nextStep = sequence.steps[nextStepIndex];
  const updatedCursor: CollectionWorkflowCursor = {
    ...currentCursor,
    currentStepIndex: nextStepIndex,
    lastAdvancedAt: event.timestamp,
  };

  const enqueueInstruction: EnqueueInstruction = {
    templateId: nextStep.templateId,
    customerId: event.customerId,
    invoiceId: event.invoiceId,
    businessId: event.businessId,
    stepName: nextStep.name,
    stepIndex: nextStepIndex,
    delaySeconds: nextStep.delaySeconds,
    outstandingAmountPaise: event.outstandingAmountPaise,
  };

  return {
    action: 'advance',
    step: nextStep,
    updatedCursor,
    enqueueInstruction,
  };
}
