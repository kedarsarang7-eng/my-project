// ============================================================================
// Property-Based Test — Malformed Event Handling
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 13
//
// Validates: Requirements 3.9
//
// Property 13 (design.md): Malformed events are discarded without messaging.
//
// Verifies:
// 1. Events missing required fields (eventId, businessId, eventType) are discarded
// 2. Discarded events produce zero outbound plans
// 3. The discard reason is recorded
// 4. Valid events are NOT discarded
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  evaluateRules,
  validateEvent,
} from '../../services/rule-engine.service';
import type {
  BusinessEvent,
  EnabledAutomationsConfig,
} from '../../services/rule-engine.service';
import type { AutomationRule, CustomerProfile } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a safe non-empty ID string (no '#', max 20 chars). */
const safeIdArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789_-'.split('')),
  { minLength: 3, maxLength: 20 },
);

/** Generates an event type string. */
const eventTypeArb = fc.constantFrom(
  'invoice.generated',
  'payment.received',
  'order.confirmed',
  'quotation.issued',
  'stock.below_threshold',
  'receipt.generated',
  'campaign.due',
);

/** Generates values that are "missing" (null, undefined, or empty string). */
const missingValueArb = fc.constantFrom(null, undefined, '', '  ', '\t');

/** Generates arbitrary non-object values to test non-object events. */
const nonObjectArb = fc.oneof(
  fc.constant(null),
  fc.constant(undefined),
  fc.integer(),
  fc.string(),
  fc.boolean(),
  fc.constant([]),
);

/** All-enabled config (doesn't gate anything). */
const allEnabledConfig: EnabledAutomationsConfig = {
  enabledAutomationKeys: new Set([
    'invoice.generated',
    'payment.received',
    'order.confirmed',
    'quotation.issued',
    'stock.below_threshold',
    'receipt.generated',
    'campaign.due',
  ]),
};

/** Creates a single matching rule for a given businessId and eventType. */
function makeRule(businessId: string, eventType: string): AutomationRule {
  const now = new Date().toISOString();
  return {
    id: 'rule-1',
    businessId,
    tenantId: 'tenant-1',
    eventType,
    conditions: [],
    templateId: 'tmpl-1',
    recipients: { type: 'customer' as const, id: 'cust-1' },
    category: 'transactional' as const,
    enabled: true,
    createdAt: now,
    updatedAt: now,
  };
}

/** Creates a profile map with a single eligible customer. */
function makeProfiles(businessId: string): ReadonlyMap<string, CustomerProfile> {
  const now = new Date().toISOString();
  const profile: CustomerProfile = {
    id: 'cust-1',
    businessId,
    tenantId: 'tenant-1',
    whatsappNumber: '+919876543210',
    consentState: 'opted_in',
    locale: 'en',
    messagingPreferences: undefined,
    eligible: true,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  };
  return new Map([['cust-1', profile]]);
}

// ── Property 13: Malformed events are discarded without messaging ────────────

describe('Feature: openwa-whatsapp-automation, Property 13: Malformed events are discarded without messaging', () => {

  // ── Sub-property 1: Events missing required fields are discarded ──

  describe('events missing required fields (eventId, businessId, eventType) are discarded', () => {

    test('event missing eventId is discarded (Req 3.9)', () => {
      fc.assert(
        fc.property(
          safeIdArb, // businessId
          eventTypeArb, // eventType
          missingValueArb, // invalid eventId
          (businessId, eventType, badEventId) => {
            const event = {
              eventId: badEventId,
              businessId,
              eventType,
              payload: { customerId: 'cust-1' },
            };

            const rules = [makeRule(businessId, eventType)];
            const profiles = makeProfiles(businessId);
            const result = evaluateRules(event, rules, allEnabledConfig, profiles);

            expect(result.valid).toBe(false);
            expect(result.plans).toHaveLength(0);
            expect(result.discardReason).toBeDefined();
            expect(result.discardReason!.length).toBeGreaterThan(0);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('event missing businessId is discarded (Req 3.9)', () => {
      fc.assert(
        fc.property(
          safeIdArb, // eventId
          eventTypeArb, // eventType
          missingValueArb, // invalid businessId
          (eventId, eventType, badBusinessId) => {
            const event = {
              eventId,
              businessId: badBusinessId,
              eventType,
              payload: { customerId: 'cust-1' },
            };

            const rules = [makeRule('some-biz', eventType)];
            const profiles = makeProfiles('some-biz');
            const result = evaluateRules(event, rules, allEnabledConfig, profiles);

            expect(result.valid).toBe(false);
            expect(result.plans).toHaveLength(0);
            expect(result.discardReason).toBeDefined();
            expect(result.discardReason!.length).toBeGreaterThan(0);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('event missing eventType is discarded (Req 3.9)', () => {
      fc.assert(
        fc.property(
          safeIdArb, // eventId
          safeIdArb, // businessId
          missingValueArb, // invalid eventType
          (eventId, businessId, badEventType) => {
            const event = {
              eventId,
              businessId,
              eventType: badEventType,
              payload: { customerId: 'cust-1' },
            };

            const rules = [makeRule(businessId, 'invoice.generated')];
            const profiles = makeProfiles(businessId);
            const result = evaluateRules(event, rules, allEnabledConfig, profiles);

            expect(result.valid).toBe(false);
            expect(result.plans).toHaveLength(0);
            expect(result.discardReason).toBeDefined();
            expect(result.discardReason!.length).toBeGreaterThan(0);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('event that is null, undefined, or not an object is discarded (Req 3.9)', () => {
      fc.assert(
        fc.property(nonObjectArb, (badEvent) => {
          const rules = [makeRule('biz-1', 'invoice.generated')];
          const profiles = makeProfiles('biz-1');
          const result = evaluateRules(badEvent, rules, allEnabledConfig, profiles);

          expect(result.valid).toBe(false);
          expect(result.plans).toHaveLength(0);
          expect(result.discardReason).toBeDefined();
          expect(result.discardReason!.length).toBeGreaterThan(0);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('event with missing or invalid payload is discarded (Req 3.9)', () => {
      fc.assert(
        fc.property(
          safeIdArb, // eventId
          safeIdArb, // businessId
          eventTypeArb, // eventType
          fc.constantFrom(null, undefined, 'string', 42, true), // bad payload
          (eventId, businessId, eventType, badPayload) => {
            const event = {
              eventId,
              businessId,
              eventType,
              payload: badPayload,
            };

            const rules = [makeRule(businessId, eventType)];
            const profiles = makeProfiles(businessId);
            const result = evaluateRules(event, rules, allEnabledConfig, profiles);

            expect(result.valid).toBe(false);
            expect(result.plans).toHaveLength(0);
            expect(result.discardReason).toBeDefined();
            expect(result.discardReason!.length).toBeGreaterThan(0);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── Sub-property 2: Discarded events produce zero outbound plans ──

  test('any malformed event always produces exactly zero outbound plans (Req 3.9)', () => {
    // Generate events with at least one required field corrupted
    const malformedEventArb = fc.oneof(
      // Missing eventId
      fc.record({
        businessId: safeIdArb,
        eventType: eventTypeArb,
        payload: fc.constant({ customerId: 'cust-1' }),
      }),
      // Missing businessId
      fc.record({
        eventId: safeIdArb,
        eventType: eventTypeArb,
        payload: fc.constant({ customerId: 'cust-1' }),
      }),
      // Missing eventType
      fc.record({
        eventId: safeIdArb,
        businessId: safeIdArb,
        payload: fc.constant({ customerId: 'cust-1' }),
      }),
      // Missing payload
      fc.record({
        eventId: safeIdArb,
        businessId: safeIdArb,
        eventType: eventTypeArb,
      }),
      // Completely empty object
      fc.constant({}),
    );

    fc.assert(
      fc.property(malformedEventArb, (malformedEvent) => {
        const rules = [makeRule('biz-1', 'invoice.generated')];
        const profiles = makeProfiles('biz-1');
        const result = evaluateRules(malformedEvent, rules, allEnabledConfig, profiles);

        // Must never produce plans for malformed events
        expect(result.plans).toHaveLength(0);
        expect(result.valid).toBe(false);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: The discard reason is recorded ──

  test('discarded events have a non-empty discard reason explaining the failure (Req 3.9)', () => {
    // Generate various types of malformed events
    const malformedWithReasonArb = fc.oneof(
      // null/undefined eventId
      fc.record({
        eventId: fc.constantFrom(null, undefined, ''),
        businessId: safeIdArb,
        eventType: eventTypeArb,
        payload: fc.constant({}),
      }),
      // null/undefined businessId
      fc.record({
        eventId: safeIdArb,
        businessId: fc.constantFrom(null, undefined, ''),
        eventType: eventTypeArb,
        payload: fc.constant({}),
      }),
      // null/undefined eventType
      fc.record({
        eventId: safeIdArb,
        businessId: safeIdArb,
        eventType: fc.constantFrom(null, undefined, ''),
        payload: fc.constant({}),
      }),
    );

    fc.assert(
      fc.property(malformedWithReasonArb, (malformedEvent) => {
        const rules = [makeRule('biz-1', 'invoice.generated')];
        const profiles = makeProfiles('biz-1');
        const result = evaluateRules(malformedEvent, rules, allEnabledConfig, profiles);

        // discardReason must be a non-empty string explaining what's wrong
        expect(result.discardReason).toBeDefined();
        expect(typeof result.discardReason).toBe('string');
        expect(result.discardReason!.trim().length).toBeGreaterThan(0);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('validateEvent returns a descriptive reason string for each type of malformed input', () => {
    fc.assert(
      fc.property(
        fc.constantFrom('eventId', 'businessId', 'eventType') as fc.Arbitrary<string>,
        safeIdArb,
        safeIdArb,
        eventTypeArb,
        (missingField, eventId, businessId, eventType) => {
          const event: Record<string, unknown> = {
            eventId,
            businessId,
            eventType,
            payload: {},
          };
          // Remove the targeted field
          delete event[missingField];

          const reason = validateEvent(event);

          expect(reason).not.toBeNull();
          expect(typeof reason).toBe('string');
          // Reason should reference the missing field
          expect(reason!.toLowerCase()).toContain(missingField.toLowerCase());
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: Valid events are NOT discarded ──

  test('events with all required fields present and valid are NOT discarded (Req 3.9)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // eventId
        safeIdArb, // businessId
        eventTypeArb, // eventType
        (eventId, businessId, eventType) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rules = [makeRule(businessId, eventType)];
          const profiles = makeProfiles(businessId);
          const result = evaluateRules(event, rules, allEnabledConfig, profiles);

          // Valid event must NOT be discarded
          expect(result.valid).toBe(true);
          expect(result.discardReason).toBeUndefined();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('valid events produce outbound plans when rules and profiles match (Req 3.9 inverse)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // eventId
        safeIdArb, // businessId
        eventTypeArb, // eventType
        (eventId, businessId, eventType) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rules = [makeRule(businessId, eventType)];
          const profiles = makeProfiles(businessId);
          const result = evaluateRules(event, rules, allEnabledConfig, profiles);

          // A valid event with matching rule and eligible recipient → plans
          expect(result.valid).toBe(true);
          expect(result.plans.length).toBeGreaterThanOrEqual(1);
          expect(result.discardReason).toBeUndefined();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('validateEvent returns null for fully valid event objects', () => {
    fc.assert(
      fc.property(
        safeIdArb,
        safeIdArb,
        eventTypeArb,
        (eventId, businessId, eventType) => {
          const event = {
            eventId,
            businessId,
            eventType,
            payload: { amount: 1000 },
          };

          const reason = validateEvent(event);
          expect(reason).toBeNull();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
