// ============================================================================
// Property-Based Test — Collection Workflow Advancement
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 22
//
// Validates: Requirements 11.9
//
// Property 22 (design.md): Payment-collection workflow advances exactly one
// step per status change.
//
// Verifies:
// 1. Each status change advances exactly one step
// 2. Only one message per step (exactly one enqueue instruction)
// 3. Steps cannot be skipped
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  advanceWorkflow,
  createInitialCursor,
  isValidSequence,
  MIN_SEQUENCE_STEPS,
  MAX_SEQUENCE_STEPS,
  type CollectionStep,
  type CollectionSequence,
  type CollectionWorkflowCursor,
  type PaymentStatusChangeEvent,
  type AdvanceResult,
} from '../../services/collection-workflow.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a businessId string. */
const businessIdArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'), {
    minLength: 4,
    maxLength: 16,
  })
  .map((s) => `biz_${s}`);

/** Generates a customerId string. */
const customerIdArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'), {
    minLength: 4,
    maxLength: 16,
  })
  .map((s) => `cust_${s}`);

/** Generates an invoiceId string. */
const invoiceIdArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'), {
    minLength: 4,
    maxLength: 16,
  })
  .map((s) => `inv_${s}`);

/** Generates a valid ISO-8601 UTC timestamp. */
const timestampArb: fc.Arbitrary<string> = fc
  .date({ min: new Date('2020-01-01T00:00:00Z'), max: new Date('2030-12-31T23:59:59Z') })
  .map((d) => d.toISOString());

/** Generates a single valid CollectionStep. */
const collectionStepArb = (index: number): fc.Arbitrary<CollectionStep> =>
  fc.record({
    stepId: fc.constant(`step_${index}`),
    name: fc.constantFrom(
      'Gentle Reminder',
      'Follow-up',
      'Escalation',
      'Final Notice',
      'Legal Warning',
    ).map((name) => `${name} ${index}`),
    templateId: fc.constant(`tpl_step_${index}`),
    delaySeconds: fc.integer({ min: 0, max: 86400 }),
  });

/** Generates a valid CollectionSequence with 1..20 steps. */
const collectionSequenceArb: fc.Arbitrary<CollectionSequence> = fc
  .integer({ min: MIN_SEQUENCE_STEPS, max: Math.min(MAX_SEQUENCE_STEPS, 10) })
  .chain((numSteps) => {
    const stepArbs = Array.from({ length: numSteps }, (_, i) => collectionStepArb(i));
    return fc.tuple(...stepArbs).map((steps) => ({
      sequenceId: `seq_${numSteps}`,
      steps,
    }));
  });

/** Generates a PaymentStatusChangeEvent with a positive outstanding amount. */
const unpaidEventArb: fc.Arbitrary<PaymentStatusChangeEvent> = fc.record({
  invoiceId: invoiceIdArb,
  customerId: customerIdArb,
  businessId: businessIdArb,
  outstandingAmountPaise: fc.integer({ min: 1, max: 10_000_000 }),
  newStatus: fc.constantFrom('overdue', 'partial', 'escalated', 'reminder'),
  timestamp: timestampArb,
});

/** Generates a PaymentStatusChangeEvent with zero outstanding (fully paid). */
const paidEventArb: fc.Arbitrary<PaymentStatusChangeEvent> = fc.record({
  invoiceId: invoiceIdArb,
  customerId: customerIdArb,
  businessId: businessIdArb,
  outstandingAmountPaise: fc.constant(0),
  newStatus: fc.constant('paid'),
  timestamp: timestampArb,
});

// ── Property 22: Payment-collection workflow advances exactly one step per status change ──

describe('Feature: openwa-whatsapp-automation, Property 22: Payment-collection workflow advances exactly one step per status change', () => {
  // ── Sub-property 1: Each status change advances exactly one step ────────────

  test('each status change on an incomplete workflow advances cursor by exactly one step (Req 11.9)', () => {
    fc.assert(
      fc.property(
        collectionSequenceArb,
        unpaidEventArb,
        (sequence, event) => {
          // Start with a fresh cursor (null = first time)
          const result = advanceWorkflow(event, sequence, null);

          // First call should advance to step 0
          expect(result.action).toBe('advance');
          if (result.action === 'advance') {
            expect(result.updatedCursor.currentStepIndex).toBe(0);
            // Verify the step matches the sequence
            expect(result.step).toEqual(sequence.steps[0]);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('advancing from step N moves to step N+1 (exactly one step, no skips) (Req 11.9)', () => {
    fc.assert(
      fc.property(
        collectionSequenceArb.filter((seq) => seq.steps.length >= 2),
        unpaidEventArb,
        fc.integer({ min: 0, max: 100 }),
        (sequence, event, startStepSeed) => {
          // Pick a valid non-final step index
          const maxStartIndex = sequence.steps.length - 2; // at least one step left
          const startIndex = startStepSeed % (maxStartIndex + 1);

          const cursor: CollectionWorkflowCursor = {
            invoiceId: event.invoiceId,
            customerId: event.customerId,
            businessId: event.businessId,
            sequenceId: sequence.sequenceId,
            currentStepIndex: startIndex,
            completed: false,
            lastAdvancedAt: '2024-01-01T00:00:00Z',
          };

          const result = advanceWorkflow(event, sequence, cursor);

          // Should advance exactly one step
          expect(result.action).toBe('advance');
          if (result.action === 'advance') {
            expect(result.updatedCursor.currentStepIndex).toBe(startIndex + 1);
            // Step matches the next sequential step
            expect(result.step).toEqual(sequence.steps[startIndex + 1]);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: Only one message per step ──────────────────────────────

  test('each advancement produces exactly one enqueue instruction (Req 11.9)', () => {
    fc.assert(
      fc.property(
        collectionSequenceArb,
        unpaidEventArb,
        (sequence, event) => {
          const result = advanceWorkflow(event, sequence, null);

          if (result.action === 'advance') {
            // Exactly one enqueue instruction is produced
            expect(result.enqueueInstruction).toBeDefined();
            // The enqueue instruction targets the correct recipient
            expect(result.enqueueInstruction.customerId).toBe(event.customerId);
            expect(result.enqueueInstruction.invoiceId).toBe(event.invoiceId);
            expect(result.enqueueInstruction.businessId).toBe(event.businessId);
            // Template matches the step
            expect(result.enqueueInstruction.templateId).toBe(result.step.templateId);
            // Step index matches
            expect(result.enqueueInstruction.stepIndex).toBe(
              result.updatedCursor.currentStepIndex,
            );
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('non-advance results produce no enqueue instruction (Req 11.9)', () => {
    fc.assert(
      fc.property(
        collectionSequenceArb,
        paidEventArb,
        (sequence, event) => {
          // Fully paid event should NOT produce an enqueue instruction
          const result = advanceWorkflow(event, sequence, null);

          expect(result.action).toBe('completed');
          // No enqueueInstruction on completed result
          expect((result as any).enqueueInstruction).toBeUndefined();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: Steps cannot be skipped ────────────────────────────────

  test('sequential status changes step through the sequence in order without skipping (Req 11.9)', () => {
    fc.assert(
      fc.property(
        collectionSequenceArb,
        unpaidEventArb,
        (sequence, baseEvent) => {
          let cursor: CollectionWorkflowCursor | null = null;
          const visitedStepIndices: number[] = [];

          // Apply one status change per step
          for (let i = 0; i < sequence.steps.length; i++) {
            const event: PaymentStatusChangeEvent = {
              ...baseEvent,
              timestamp: new Date(
                Date.parse(baseEvent.timestamp) + i * 86400_000,
              ).toISOString(),
            };

            const result = advanceWorkflow(event, sequence, cursor);

            if (result.action === 'advance') {
              visitedStepIndices.push(result.updatedCursor.currentStepIndex);
              cursor = result.updatedCursor;
            } else {
              break; // unexpected — shouldn't happen for unpaid events within step range
            }
          }

          // Each step should be visited exactly in order: 0, 1, 2, ... N-1
          const expectedIndices = Array.from(
            { length: sequence.steps.length },
            (_, i) => i,
          );
          expect(visitedStepIndices).toEqual(expectedIndices);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('after exhausting all steps, no further advancement occurs (Req 11.9)', () => {
    fc.assert(
      fc.property(
        collectionSequenceArb,
        unpaidEventArb,
        (sequence, event) => {
          // Put cursor at the final step
          const cursor: CollectionWorkflowCursor = {
            invoiceId: event.invoiceId,
            customerId: event.customerId,
            businessId: event.businessId,
            sequenceId: sequence.sequenceId,
            currentStepIndex: sequence.steps.length - 1, // already at last step
            completed: false,
            lastAdvancedAt: '2024-01-01T00:00:00Z',
          };

          const result = advanceWorkflow(event, sequence, cursor);

          // No further advancement possible
          expect(result.action).toBe('exhausted');
          // Cursor step index remains unchanged
          if (result.action === 'exhausted') {
            expect(result.cursor.currentStepIndex).toBe(sequence.steps.length - 1);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('completed workflows do not advance regardless of event (Req 11.9)', () => {
    fc.assert(
      fc.property(
        collectionSequenceArb,
        unpaidEventArb,
        fc.integer({ min: -1, max: 19 }),
        (sequence, event, stepIdx) => {
          const clampedIndex = Math.min(stepIdx, sequence.steps.length - 1);
          const cursor: CollectionWorkflowCursor = {
            invoiceId: event.invoiceId,
            customerId: event.customerId,
            businessId: event.businessId,
            sequenceId: sequence.sequenceId,
            currentStepIndex: clampedIndex,
            completed: true, // already marked complete
            lastAdvancedAt: '2024-01-01T00:00:00Z',
          };

          const result = advanceWorkflow(event, sequence, cursor);

          // Should not advance — already complete
          expect(result.action).toBe('already_complete');
          if (result.action === 'already_complete') {
            expect(result.cursor.currentStepIndex).toBe(clampedIndex);
            expect(result.cursor.completed).toBe(true);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Additional properties: full-paid stops workflow ─────────────────────────

  test('fully paid event (outstanding = 0) marks workflow complete without enqueuing (Req 11.9)', () => {
    fc.assert(
      fc.property(
        collectionSequenceArb,
        paidEventArb,
        fc.integer({ min: -1, max: 19 }),
        (sequence, event, stepIdx) => {
          const clampedIndex = Math.min(stepIdx, sequence.steps.length - 1);
          const cursor: CollectionWorkflowCursor = {
            invoiceId: event.invoiceId,
            customerId: event.customerId,
            businessId: event.businessId,
            sequenceId: sequence.sequenceId,
            currentStepIndex: clampedIndex,
            completed: false,
            lastAdvancedAt: '2024-01-01T00:00:00Z',
          };

          const result = advanceWorkflow(event, sequence, cursor);

          expect(result.action).toBe('completed');
          if (result.action === 'completed') {
            expect(result.updatedCursor.completed).toBe(true);
            // No enqueue instruction
            expect((result as any).enqueueInstruction).toBeUndefined();
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sequence validation properties ─────────────────────────────────────────

  test('isValidSequence accepts sequences with 1..20 well-formed steps', () => {
    fc.assert(
      fc.property(collectionSequenceArb, (sequence) => {
        expect(isValidSequence(sequence)).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('isValidSequence rejects empty sequences', () => {
    const emptySeq: CollectionSequence = { sequenceId: 'empty', steps: [] };
    expect(isValidSequence(emptySeq)).toBe(false);
  });

  test('isValidSequence rejects sequences exceeding MAX_SEQUENCE_STEPS', () => {
    const oversized: CollectionSequence = {
      sequenceId: 'oversized',
      steps: Array.from({ length: MAX_SEQUENCE_STEPS + 1 }, (_, i) => ({
        stepId: `step_${i}`,
        name: `Step ${i}`,
        templateId: `tpl_${i}`,
        delaySeconds: 0,
      })),
    };
    expect(isValidSequence(oversized)).toBe(false);
  });

  // ── Anchored example checks (unit) ─────────────────────────────────────────

  test('example: classic 3-step collection workflow advances step by step', () => {
    const sequence: CollectionSequence = {
      sequenceId: 'SEQ-001',
      steps: [
        { stepId: 'gentle', name: 'Gentle Reminder', templateId: 'TPL-G', delaySeconds: 0 },
        { stepId: 'followup', name: 'Follow-up', templateId: 'TPL-F', delaySeconds: 86400 },
        { stepId: 'final', name: 'Final Notice', templateId: 'TPL-FN', delaySeconds: 172800 },
      ],
    };

    const event: PaymentStatusChangeEvent = {
      invoiceId: 'INV-001',
      customerId: 'CUST-001',
      businessId: 'BIZ-001',
      outstandingAmountPaise: 50000,
      newStatus: 'overdue',
      timestamp: '2024-06-01T10:00:00Z',
    };

    // Step 1: Advances to step 0 (Gentle Reminder)
    const r1 = advanceWorkflow(event, sequence, null);
    expect(r1.action).toBe('advance');
    if (r1.action !== 'advance') return;
    expect(r1.updatedCursor.currentStepIndex).toBe(0);
    expect(r1.enqueueInstruction.templateId).toBe('TPL-G');
    expect(r1.enqueueInstruction.stepName).toBe('Gentle Reminder');

    // Step 2: Advances to step 1 (Follow-up)
    const event2 = { ...event, timestamp: '2024-06-02T10:00:00Z' };
    const r2 = advanceWorkflow(event2, sequence, r1.updatedCursor);
    expect(r2.action).toBe('advance');
    if (r2.action !== 'advance') return;
    expect(r2.updatedCursor.currentStepIndex).toBe(1);
    expect(r2.enqueueInstruction.templateId).toBe('TPL-F');

    // Step 3: Advances to step 2 (Final Notice)
    const event3 = { ...event, timestamp: '2024-06-03T10:00:00Z' };
    const r3 = advanceWorkflow(event3, sequence, r2.updatedCursor);
    expect(r3.action).toBe('advance');
    if (r3.action !== 'advance') return;
    expect(r3.updatedCursor.currentStepIndex).toBe(2);
    expect(r3.enqueueInstruction.templateId).toBe('TPL-FN');

    // Step 4: Exhausted — no more steps
    const event4 = { ...event, timestamp: '2024-06-04T10:00:00Z' };
    const r4 = advanceWorkflow(event4, sequence, r3.updatedCursor);
    expect(r4.action).toBe('exhausted');
  });

  test('example: payment clears outstanding mid-workflow', () => {
    const sequence: CollectionSequence = {
      sequenceId: 'SEQ-002',
      steps: [
        { stepId: 's1', name: 'Reminder 1', templateId: 'TPL-1', delaySeconds: 0 },
        { stepId: 's2', name: 'Reminder 2', templateId: 'TPL-2', delaySeconds: 3600 },
      ],
    };

    const event: PaymentStatusChangeEvent = {
      invoiceId: 'INV-002',
      customerId: 'CUST-002',
      businessId: 'BIZ-002',
      outstandingAmountPaise: 25000,
      newStatus: 'overdue',
      timestamp: '2024-06-01T08:00:00Z',
    };

    // Advance to step 0
    const r1 = advanceWorkflow(event, sequence, null);
    expect(r1.action).toBe('advance');
    if (r1.action !== 'advance') return;

    // Customer pays in full
    const paidEvent: PaymentStatusChangeEvent = {
      ...event,
      outstandingAmountPaise: 0,
      newStatus: 'paid',
      timestamp: '2024-06-01T12:00:00Z',
    };
    const r2 = advanceWorkflow(paidEvent, sequence, r1.updatedCursor);
    expect(r2.action).toBe('completed');
    if (r2.action !== 'completed') return;
    expect(r2.updatedCursor.completed).toBe(true);

    // Further events on completed workflow produce no action
    const r3 = advanceWorkflow(event, sequence, r2.updatedCursor);
    expect(r3.action).toBe('already_complete');
  });
});
