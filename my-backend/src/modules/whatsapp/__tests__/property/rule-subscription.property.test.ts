// ============================================================================
// Property-Based Test — Rule Subscription / Scope Matching
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 9
//
// Validates: Requirements 3.1, 3.7
//
// Property 9 (design.md): Rules are evaluated only when they subscribe to the
// event and share its BusinessID.
//
// Verifies:
// 1. Only rules subscribing to the same eventType as the incoming event are evaluated
// 2. Only rules scoped to the same businessId as the event are evaluated
// 3. Rules with a different eventType or different businessId produce no outbound plan
// 4. A rule matching both eventType AND businessId IS evaluated
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import { evaluateRules } from '../../services/rule-engine.service';
import type { BusinessEvent, EnabledAutomationsConfig } from '../../services/rule-engine.service';
import type { AutomationRule, CustomerProfile } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a safe ID string (no '#', non-empty, max 64 chars). */
const safeIdArb = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789_-'.split('')), {
    minLength: 3,
    maxLength: 20,
  });

/** Generates a valid E.164 phone number. */
const e164Arb = fc.integer({ min: 10000000, max: 999999999999999 }).map((n) => `+${n}`);

/** Generates an event type string like 'invoice.generated', 'order.confirmed'. */
const eventTypeArb = fc.constantFrom(
  'invoice.generated',
  'payment.received',
  'order.confirmed',
  'quotation.issued',
  'stock.below_threshold',
  'receipt.generated',
  'campaign.due',
);

/** Generates a different event type from the given one. */
function differentEventTypeArb(excludeType: string): fc.Arbitrary<string> {
  return eventTypeArb.filter((t) => t !== excludeType);
}

/** Generates a minimal valid BusinessEvent. */
function businessEventArb(overrides?: Partial<BusinessEvent>): fc.Arbitrary<BusinessEvent> {
  return fc.record({
    eventId: safeIdArb,
    businessId: overrides?.businessId ? fc.constant(overrides.businessId) : safeIdArb,
    eventType: overrides?.eventType ? fc.constant(overrides.eventType) : eventTypeArb,
    payload: fc.constant({ customerId: 'cust-1' }),
  }) as fc.Arbitrary<BusinessEvent>;
}

/** Generates a minimal enabled AutomationRule. */
function automationRuleArb(overrides?: Partial<AutomationRule>): fc.Arbitrary<AutomationRule> {
  const now = new Date().toISOString();
  return fc.record({
    id: safeIdArb,
    businessId: overrides?.businessId ? fc.constant(overrides.businessId) : safeIdArb,
    tenantId: fc.constant('tenant-1'),
    eventType: overrides?.eventType ? fc.constant(overrides.eventType) : eventTypeArb,
    conditions: fc.constant([]),
    templateId: fc.constant('tmpl-1'),
    recipients: fc.constant({ type: 'customer' as const, id: 'cust-1' }),
    schedule: fc.constant(undefined),
    category: fc.constant('transactional' as const),
    maxReminders: fc.constant(undefined),
    enabled: fc.constant(overrides?.enabled ?? true),
    createdAt: fc.constant(now),
    updatedAt: fc.constant(now),
  }) as unknown as fc.Arbitrary<AutomationRule>;
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

/** All-enabled config (doesn't gate anything). */
const allEnabledConfig: EnabledAutomationsConfig = {
  enabledAutomationKeys: new Set(['invoice.generated', 'payment.received', 'order.confirmed', 'quotation.issued', 'stock.below_threshold', 'receipt.generated', 'campaign.due']),
};

// ── Property 9: Rule Subscription / Scope Matching ──────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 9: Rules are evaluated only when they subscribe to the event and share its BusinessID', () => {

  // ── Sub-property 1: Only rules subscribing to the same eventType are evaluated ──

  test('a rule with a DIFFERENT eventType than the event produces no outbound plan (Req 3.1)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId (shared between event and rule)
        eventTypeArb, // event's eventType
        (businessId, eventType) => {
          // Create an event with a specific eventType
          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          // Pick a different eventType for the rule
          const allTypes = ['invoice.generated', 'payment.received', 'order.confirmed', 'quotation.issued', 'stock.below_threshold', 'receipt.generated', 'campaign.due'];
          const otherTypes = allTypes.filter((t) => t !== eventType);
          if (otherTypes.length === 0) return; // skip if no alternative

          const rule: AutomationRule = {
            id: 'rule-1',
            businessId,  // same businessId
            tenantId: 'tenant-1',
            eventType: otherTypes[0], // DIFFERENT eventType
            conditions: [],
            templateId: 'tmpl-1',
            recipients: { type: 'customer', id: 'cust-1' },
            category: 'transactional',
            enabled: true,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };

          const profiles = makeProfiles(businessId);
          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          expect(result.plans).toHaveLength(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: Only rules scoped to the same businessId are evaluated ──

  test('a rule with a DIFFERENT businessId than the event produces no outbound plan (Req 3.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // event businessId
        safeIdArb, // rule businessId
        eventTypeArb, // shared eventType
        (eventBizId, ruleBizId, eventType) => {
          // Ensure they're actually different
          fc.pre(eventBizId !== ruleBizId);

          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId: eventBizId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rule: AutomationRule = {
            id: 'rule-1',
            businessId: ruleBizId, // DIFFERENT businessId
            tenantId: 'tenant-1',
            eventType, // same eventType
            conditions: [],
            templateId: 'tmpl-1',
            recipients: { type: 'customer', id: 'cust-1' },
            category: 'transactional',
            enabled: true,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };

          const profiles = makeProfiles(eventBizId);
          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          expect(result.plans).toHaveLength(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: Rules with different eventType OR different businessId produce no plan ──

  test('rules mismatching on EITHER eventType or businessId produce no outbound plan (Req 3.1, 3.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // event businessId
        safeIdArb, // rule businessId (may differ)
        eventTypeArb, // event eventType
        eventTypeArb, // rule eventType (may differ)
        (eventBizId, ruleBizId, eventEventType, ruleEventType) => {
          // At least one must differ for this property to be meaningful
          const eventTypeDiffers = eventEventType !== ruleEventType;
          const bizIdDiffers = eventBizId !== ruleBizId;
          fc.pre(eventTypeDiffers || bizIdDiffers);

          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId: eventBizId,
            eventType: eventEventType,
            payload: { customerId: 'cust-1' },
          };

          const rule: AutomationRule = {
            id: 'rule-1',
            businessId: ruleBizId,
            tenantId: 'tenant-1',
            eventType: ruleEventType,
            conditions: [],
            templateId: 'tmpl-1',
            recipients: { type: 'customer', id: 'cust-1' },
            category: 'transactional',
            enabled: true,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };

          const profiles = makeProfiles(eventBizId);
          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          expect(result.plans).toHaveLength(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: A rule matching both eventType AND businessId IS evaluated ──

  test('a rule matching BOTH eventType and businessId produces an outbound plan (Req 3.1, 3.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // shared businessId
        eventTypeArb, // shared eventType
        (businessId, eventType) => {
          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rule: AutomationRule = {
            id: 'rule-1',
            businessId, // SAME businessId
            tenantId: 'tenant-1',
            eventType, // SAME eventType
            conditions: [],
            templateId: 'tmpl-1',
            recipients: { type: 'customer', id: 'cust-1' },
            category: 'transactional',
            enabled: true,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };

          const profiles = makeProfiles(businessId);
          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          expect(result.plans.length).toBeGreaterThanOrEqual(1);
          // The plan must use the matching rule
          expect(result.plans[0].ruleId).toBe('rule-1');
          expect(result.plans[0].businessId).toBe(businessId);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Among mixed rules, only matching ones produce plans ──

  test('given a mix of matching and non-matching rules, only those with BOTH same eventType and businessId produce plans (Req 3.1, 3.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // event businessId
        eventTypeArb, // event eventType
        fc.integer({ min: 1, max: 5 }), // number of non-matching rules
        (businessId, eventType, extraRuleCount) => {
          const now = new Date().toISOString();

          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          // One matching rule
          const matchingRule: AutomationRule = {
            id: 'rule-match',
            businessId,
            tenantId: 'tenant-1',
            eventType,
            conditions: [],
            templateId: 'tmpl-1',
            recipients: { type: 'customer', id: 'cust-1' },
            category: 'transactional',
            enabled: true,
            createdAt: now,
            updatedAt: now,
          };

          // Non-matching rules: wrong businessId and/or wrong eventType
          const allTypes = ['invoice.generated', 'payment.received', 'order.confirmed', 'quotation.issued', 'stock.below_threshold', 'receipt.generated', 'campaign.due'];
          const otherTypes = allTypes.filter((t) => t !== eventType);
          const nonMatchingRules: AutomationRule[] = [];

          for (let i = 0; i < extraRuleCount; i++) {
            nonMatchingRules.push({
              id: `rule-nomatch-${i}`,
              businessId: i % 2 === 0 ? `other-biz-${i}` : businessId,
              tenantId: 'tenant-1',
              eventType: i % 2 === 0 ? eventType : (otherTypes[i % otherTypes.length] || 'unknown.event'),
              conditions: [],
              templateId: 'tmpl-1',
              recipients: { type: 'customer', id: 'cust-1' },
              category: 'transactional',
              enabled: true,
              createdAt: now,
              updatedAt: now,
            });
          }

          const allRules = [matchingRule, ...nonMatchingRules];
          const profiles = makeProfiles(businessId);
          const result = evaluateRules(event, allRules, allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // Exactly one plan from the matching rule (exactly-one-per-recipient dedup)
          expect(result.plans).toHaveLength(1);
          expect(result.plans[0].ruleId).toBe('rule-match');
          expect(result.plans[0].businessId).toBe(businessId);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Disabled rules with matching scope produce no plan ──

  test('a disabled rule matching both eventType and businessId produces no outbound plan (Req 3.1)', () => {
    fc.assert(
      fc.property(
        safeIdArb,
        eventTypeArb,
        (businessId, eventType) => {
          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload: { customerId: 'cust-1' },
          };

          const rule: AutomationRule = {
            id: 'rule-disabled',
            businessId,
            tenantId: 'tenant-1',
            eventType,
            conditions: [],
            templateId: 'tmpl-1',
            recipients: { type: 'customer', id: 'cust-1' },
            category: 'transactional',
            enabled: false, // DISABLED
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };

          const profiles = makeProfiles(businessId);
          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          expect(result.plans).toHaveLength(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
