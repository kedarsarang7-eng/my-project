// ============================================================================
// Property-Based Test — One Message Per Eligible Recipient
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 11
//
// Validates: Requirements 3.2, 4.1, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 11.1, 11.4, 11.5, 11.6, 11.8
//
// Property 11 (design.md): Exactly one message per eligible recipient per
// triggering event.
//
// Verifies:
// 1. For a given (eventId, recipientId) pair, exactly one outbound plan is
//    produced (never zero if eligible, never more than one)
// 2. Even if multiple rules match the same event and resolve to the same
//    recipient, only one plan per recipient is produced (dedup)
// 3. Non-eligible recipients produce zero plans
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import { evaluateRules } from '../../services/rule-engine.service';
import type { BusinessEvent, EnabledAutomationsConfig } from '../../services/rule-engine.service';
import type { AutomationRule, CustomerProfile } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a safe ID string (no '#', non-empty, max 20 chars). */
const safeIdArb = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789_-'.split('')), {
    minLength: 3,
    maxLength: 20,
  });

/** Generates a valid E.164 phone number. */
const e164Arb = fc.integer({ min: 10000000, max: 999999999999999 }).map((n) => `+${n}`);

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

/** Creates an eligible customer profile (valid E.164 + opted_in). */
function makeEligibleProfile(
  id: string,
  businessId: string,
  number: string,
): CustomerProfile {
  const now = new Date().toISOString();
  return {
    id,
    businessId,
    tenantId: 'tenant-1',
    whatsappNumber: number,
    consentState: 'opted_in',
    locale: 'en',
    messagingPreferences: undefined,
    eligible: true,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  };
}

/** Creates a non-eligible customer profile (opted_out). */
function makeOptedOutProfile(
  id: string,
  businessId: string,
  number: string,
): CustomerProfile {
  const now = new Date().toISOString();
  return {
    id,
    businessId,
    tenantId: 'tenant-1',
    whatsappNumber: number,
    consentState: 'opted_out',
    locale: 'en',
    messagingPreferences: undefined,
    eligible: false,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  };
}

/** Creates a pending consent profile. */
function makePendingProfile(
  id: string,
  businessId: string,
  number: string,
): CustomerProfile {
  const now = new Date().toISOString();
  return {
    id,
    businessId,
    tenantId: 'tenant-1',
    whatsappNumber: number,
    consentState: 'pending',
    locale: 'en',
    messagingPreferences: undefined,
    eligible: false,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  };
}

/** Creates an AutomationRule targeting a specific customer by ID. */
function makeRule(
  ruleId: string,
  businessId: string,
  eventType: string,
  recipientId: string,
  category: 'transactional' | 'non_transactional' = 'transactional',
): AutomationRule {
  const now = new Date().toISOString();
  return {
    id: ruleId,
    businessId,
    tenantId: 'tenant-1',
    eventType,
    conditions: [],
    templateId: 'tmpl-1',
    recipients: { type: 'customer', id: recipientId },
    category,
    enabled: true,
    createdAt: now,
    updatedAt: now,
  };
}

/** Creates an AutomationRule targeting a segment (all customers). */
function makeSegmentRule(
  ruleId: string,
  businessId: string,
  eventType: string,
  category: 'transactional' | 'non_transactional' = 'transactional',
): AutomationRule {
  const now = new Date().toISOString();
  return {
    id: ruleId,
    businessId,
    tenantId: 'tenant-1',
    eventType,
    conditions: [],
    templateId: 'tmpl-1',
    recipients: { type: 'segment', segmentFilter: {} },
    category,
    enabled: true,
    createdAt: now,
    updatedAt: now,
  };
}

// ── Property 11: Exactly One Message Per Eligible Recipient ─────────────────

describe('Feature: openwa-whatsapp-automation, Property 11: Exactly one message per eligible recipient per triggering event', () => {

  // ── Sub-property 1: Eligible recipient gets exactly one plan ──

  test('for a given (eventId, recipientId) pair with an eligible recipient, exactly one outbound plan is produced (Req 3.2, 4.1)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        safeIdArb, // eventId
        eventTypeArb, // eventType
        e164Arb, // recipient phone number
        (businessId, eventId, eventType, phoneNumber) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rule = makeRule('rule-1', businessId, eventType, 'cust-1');
          const profile = makeEligibleProfile('cust-1', businessId, phoneNumber);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // Exactly one plan for the eligible recipient
          expect(result.plans).toHaveLength(1);
          expect(result.plans[0].recipientId).toBe('cust-1');
          expect(result.plans[0].eventId).toBe(eventId);
          expect(result.plans[0].recipientNumber).toBe(phoneNumber);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: Multiple rules targeting same recipient produce exactly one plan (dedup) ──

  test('even if multiple rules match the same event and resolve to the same recipient, only one plan per recipient is produced (Req 3.2, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        safeIdArb, // eventId
        eventTypeArb, // eventType
        e164Arb, // phone number
        fc.integer({ min: 2, max: 10 }), // number of duplicate rules
        (businessId, eventId, eventType, phoneNumber, ruleCount) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          // Create multiple rules all targeting the same recipient
          const rules: AutomationRule[] = [];
          for (let i = 0; i < ruleCount; i++) {
            rules.push(makeRule(`rule-${i}`, businessId, eventType, 'cust-1'));
          }

          const profile = makeEligibleProfile('cust-1', businessId, phoneNumber);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, rules, allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // Despite multiple rules resolving to the same recipient,
          // exactly ONE plan is produced (dedup by recipientId per event)
          expect(result.plans).toHaveLength(1);
          expect(result.plans[0].recipientId).toBe('cust-1');
          expect(result.plans[0].eventId).toBe(eventId);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: Non-eligible recipients (opted_out) produce zero plans ──

  test('non-eligible recipients (opted_out) produce zero plans for non-transactional messages (Req 11.4, 11.5)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        safeIdArb, // eventId
        eventTypeArb, // eventType
        e164Arb, // phone number
        (businessId, eventId, eventType, phoneNumber) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          // Non-transactional rule → consent gate applies
          const rule = makeRule('rule-1', businessId, eventType, 'cust-1', 'non_transactional');
          const profile = makeOptedOutProfile('cust-1', businessId, phoneNumber);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // No plans — consent gate blocks opted_out for non-transactional
          expect(result.plans).toHaveLength(0);
          // Suppression should be recorded
          expect(result.suppressions.length).toBeGreaterThan(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Non-eligible recipients (pending consent) produce zero plans for non-transactional ──

  test('non-eligible recipients (pending consent) produce zero plans for non-transactional messages (Req 11.4, 11.6)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        safeIdArb, // eventId
        eventTypeArb, // eventType
        e164Arb, // phone number
        (businessId, eventId, eventType, phoneNumber) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rule = makeRule('rule-1', businessId, eventType, 'cust-1', 'non_transactional');
          const profile = makePendingProfile('cust-1', businessId, phoneNumber);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          expect(result.plans).toHaveLength(0);
          expect(result.suppressions.length).toBeGreaterThan(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Multiple eligible recipients each get exactly one plan ──

  test('multiple eligible recipients each receive exactly one plan even with overlapping segment rules (Req 3.2, 11.1, 11.8)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        safeIdArb, // eventId
        eventTypeArb, // eventType
        fc.integer({ min: 2, max: 8 }), // number of recipients
        fc.integer({ min: 1, max: 5 }), // number of segment rules
        (businessId, eventId, eventType, recipientCount, ruleCount) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: {},
          };

          // Create multiple segment rules (all match all profiles)
          const rules: AutomationRule[] = [];
          for (let i = 0; i < ruleCount; i++) {
            rules.push(makeSegmentRule(`rule-seg-${i}`, businessId, eventType));
          }

          // Create multiple eligible profiles
          const profiles = new Map<string, CustomerProfile>();
          for (let i = 0; i < recipientCount; i++) {
            const custId = `cust-${i}`;
            const number = `+9198765432${String(i).padStart(2, '0')}`;
            profiles.set(custId, makeEligibleProfile(custId, businessId, number));
          }

          const result = evaluateRules(event, rules, allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // Each eligible recipient gets exactly one plan (dedup)
          expect(result.plans).toHaveLength(recipientCount);

          // Verify uniqueness: no duplicate recipientIds in plans
          const recipientIds = result.plans.map((p) => p.recipientId);
          const uniqueRecipientIds = new Set(recipientIds);
          expect(uniqueRecipientIds.size).toBe(recipientCount);

          // Each plan references this event
          for (const plan of result.plans) {
            expect(plan.eventId).toBe(eventId);
            expect(plan.businessId).toBe(businessId);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Mix of eligible and non-eligible recipients ──

  test('in a mix of eligible and non-eligible recipients, only eligible ones produce exactly one plan each (Req 3.2, 11.4, 11.5, 11.6)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        safeIdArb, // eventId
        eventTypeArb, // eventType
        fc.integer({ min: 1, max: 4 }), // eligible count
        fc.integer({ min: 1, max: 4 }), // opted-out count
        fc.integer({ min: 0, max: 3 }), // pending count
        (businessId, eventId, eventType, eligibleCount, optedOutCount, pendingCount) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: {},
          };

          // Use a segment rule targeting all profiles (non-transactional to exercise consent)
          const rule = makeSegmentRule('rule-seg-1', businessId, eventType, 'non_transactional');

          // Build profiles map with a mix of consent states
          const profiles = new Map<string, CustomerProfile>();
          let idx = 0;

          for (let i = 0; i < eligibleCount; i++) {
            const custId = `cust-eligible-${idx}`;
            const number = `+919876500${String(idx).padStart(3, '0')}`;
            profiles.set(custId, makeEligibleProfile(custId, businessId, number));
            idx++;
          }

          for (let i = 0; i < optedOutCount; i++) {
            const custId = `cust-optedout-${idx}`;
            const number = `+919876500${String(idx).padStart(3, '0')}`;
            profiles.set(custId, makeOptedOutProfile(custId, businessId, number));
            idx++;
          }

          for (let i = 0; i < pendingCount; i++) {
            const custId = `cust-pending-${idx}`;
            const number = `+919876500${String(idx).padStart(3, '0')}`;
            profiles.set(custId, makePendingProfile(custId, businessId, number));
            idx++;
          }

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // Only eligible (opted_in) recipients get plans
          expect(result.plans).toHaveLength(eligibleCount);

          // All plans reference eligible recipients
          for (const plan of result.plans) {
            expect(plan.recipientId).toMatch(/^cust-eligible-/);
          }

          // Non-eligible recipients are suppressed
          expect(result.suppressions).toHaveLength(optedOutCount + pendingCount);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Invalid E.164 number produces zero plans ──

  test('recipients with invalid E.164 numbers produce zero plans regardless of consent state (Req 11.4)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        safeIdArb, // eventId
        eventTypeArb, // eventType
        fc.constantFrom('12345', 'abc', '+1', '+12', ''), // invalid numbers
        (businessId, eventId, eventType, badNumber) => {
          const event: BusinessEvent = {
            eventId,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rule = makeRule('rule-1', businessId, eventType, 'cust-1');

          // Profile with opted_in but invalid number
          const now = new Date().toISOString();
          const profile: CustomerProfile = {
            id: 'cust-1',
            businessId,
            tenantId: 'tenant-1',
            whatsappNumber: badNumber,
            consentState: 'opted_in',
            locale: 'en',
            messagingPreferences: undefined,
            eligible: false,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
          };
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // Invalid number → no plan
          expect(result.plans).toHaveLength(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Dedup is per-event (different events can send to same recipient) ──

  test('dedup is scoped per event: different eventIds produce independent plans for the same recipient (Req 3.2)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        safeIdArb, // eventId1
        safeIdArb, // eventId2
        eventTypeArb, // eventType
        e164Arb, // phone number
        (businessId, eventId1, eventId2, eventType, phoneNumber) => {
          fc.pre(eventId1 !== eventId2);

          const event1: BusinessEvent = {
            eventId: eventId1,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const event2: BusinessEvent = {
            eventId: eventId2,
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rule = makeRule('rule-1', businessId, eventType, 'cust-1');
          const profile = makeEligibleProfile('cust-1', businessId, phoneNumber);
          const profiles = new Map([['cust-1', profile]]);

          const result1 = evaluateRules(event1, [rule], allEnabledConfig, profiles);
          const result2 = evaluateRules(event2, [rule], allEnabledConfig, profiles);

          // Each event independently produces one plan for the same recipient
          expect(result1.plans).toHaveLength(1);
          expect(result1.plans[0].eventId).toBe(eventId1);
          expect(result2.plans).toHaveLength(1);
          expect(result2.plans[0].eventId).toBe(eventId2);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
