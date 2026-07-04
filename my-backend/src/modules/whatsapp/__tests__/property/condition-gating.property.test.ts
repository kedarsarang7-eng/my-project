// ============================================================================
// Property-Based Test — Condition Gating
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 10
//
// Validates: Requirements 3.8
//
// Property 10 (design.md): Rule conditions gate enqueuing.
//
// Verifies:
// 1. When a rule's conditions are NOT satisfied by the event payload, no
//    outbound message is produced for that rule.
// 2. When conditions ARE satisfied, an outbound plan is produced.
// 3. Rules with empty conditions array always pass (no gating).
// 4. The condition evaluation is deterministic (same inputs → same outputs).
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  evaluateRules,
  evaluateCondition,
  evaluateConditions,
} from '../../services/rule-engine.service';
import type {
  BusinessEvent,
  EnabledAutomationsConfig,
} from '../../services/rule-engine.service';
import type { AutomationRule, CustomerProfile, RuleCondition } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a safe ID string (no '#', non-empty). */
const safeIdArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789_-'.split('')),
  { minLength: 3, maxLength: 20 },
);

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

/** Generates a condition operator. */
const operatorArb = fc.constantFrom(
  'eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'in', 'not_in', 'exists', 'not_exists',
) as fc.Arbitrary<RuleCondition['operator']>;

/** Generates a simple field name (no nesting for clarity). */
const fieldNameArb = fc.constantFrom('amount', 'status', 'type', 'count', 'category', 'level');

/** Generates a numeric value for comparison operators. */
const numericValueArb = fc.integer({ min: -10000, max: 10000 });

/** Generates a string value for eq/neq operators. */
const stringValueArb = fc.constantFrom('paid', 'pending', 'overdue', 'active', 'inactive');

/**
 * Generates a condition that IS satisfied by a given payload.
 * This builds a condition that we know will pass given the field value.
 */
function satisfiedConditionArb(payload: Record<string, unknown>): fc.Arbitrary<RuleCondition> {
  const conditions: RuleCondition[] = [
    // eq on a known field
    { field: 'amount', operator: 'eq', value: payload.amount },
    { field: 'status', operator: 'eq', value: payload.status },
    // gte: value <= actual
    { field: 'amount', operator: 'gte', value: (payload.amount as number ?? 0) - 1 },
    // lte: value >= actual
    { field: 'amount', operator: 'lte', value: (payload.amount as number ?? 0) + 1 },
    // in: include the actual value
    { field: 'status', operator: 'in', value: [payload.status, 'other1', 'other2'] },
    { field: 'amount', operator: 'in', value: [payload.amount, 99999] },
    // exists: on a known field
    { field: 'amount', operator: 'exists' },
    { field: 'status', operator: 'exists' },
    // not_exists: on a field that doesn't exist
    { field: '__nonexistent__', operator: 'not_exists' },
    // neq: value different from actual
    { field: 'amount', operator: 'neq', value: 'IMPOSSIBLE_VALUE' },
    // not_in: actual not in the array
    { field: 'status', operator: 'not_in', value: ['IMPOSSIBLE1', 'IMPOSSIBLE2'] },
  ];
  return fc.constantFrom(...conditions);
}

/**
 * Generates a condition that is NOT satisfied by a given payload.
 */
function unsatisfiedConditionArb(payload: Record<string, unknown>): fc.Arbitrary<RuleCondition> {
  const conditions: RuleCondition[] = [
    // eq: value that does NOT match
    { field: 'amount', operator: 'eq', value: 'IMPOSSIBLE_VALUE_XYZ' },
    { field: 'status', operator: 'eq', value: 'IMPOSSIBLE_STATUS_XYZ' },
    // neq: value that DOES match (neq actual == false)
    { field: 'amount', operator: 'neq', value: payload.amount },
    { field: 'status', operator: 'neq', value: payload.status },
    // gt: require > something impossibly large
    { field: 'amount', operator: 'gt', value: 999999 },
    // lt: require < something impossibly small
    { field: 'amount', operator: 'lt', value: -999999 },
    // not_in: include the actual value (so not_in fails)
    { field: 'status', operator: 'not_in', value: [payload.status] },
    { field: 'amount', operator: 'not_in', value: [payload.amount] },
    // exists: on a field that doesn't exist
    { field: '__nonexistent_field__', operator: 'exists' },
    // not_exists: on a field that DOES exist
    { field: 'amount', operator: 'not_exists' },
    { field: 'status', operator: 'not_exists' },
    // in: array that doesn't include actual value
    { field: 'status', operator: 'in', value: ['NOPE1', 'NOPE2'] },
  ];
  return fc.constantFrom(...conditions);
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

/** All-enabled config. */
const allEnabledConfig: EnabledAutomationsConfig = {
  enabledAutomationKeys: new Set([
    'invoice.generated', 'payment.received', 'order.confirmed',
    'quotation.issued', 'stock.below_threshold', 'receipt.generated', 'campaign.due',
  ]),
};

/** A standard payload with known fields for condition testing. */
const standardPayload: Record<string, unknown> = {
  customerId: 'cust-1',
  amount: 5000,
  status: 'paid',
  type: 'invoice',
  count: 3,
  category: 'transactional',
  level: 'premium',
};

// ── Property 10: Rule Conditions Gate Enqueuing ─────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 10: Rule conditions gate enqueuing', () => {

  // ── Sub-property 1: Conditions NOT satisfied → no outbound ──

  test('when a rule has conditions NOT satisfied by the event payload, no outbound plan is produced (Req 3.8)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        eventTypeArb, // eventType
        unsatisfiedConditionArb(standardPayload),
        (businessId, eventType, unsatisfiedCondition) => {
          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload: standardPayload,
          };

          const rule: AutomationRule = {
            id: 'rule-1',
            businessId,
            tenantId: 'tenant-1',
            eventType,
            conditions: [unsatisfiedCondition],
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

  // ── Sub-property 2: Conditions ARE satisfied → outbound plan produced ──

  test('when a rule has conditions satisfied by the event payload, an outbound plan is produced (Req 3.8)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        eventTypeArb, // eventType
        satisfiedConditionArb(standardPayload),
        (businessId, eventType, satisfiedCondition) => {
          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload: standardPayload,
          };

          const rule: AutomationRule = {
            id: 'rule-1',
            businessId,
            tenantId: 'tenant-1',
            eventType,
            conditions: [satisfiedCondition],
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
          expect(result.plans[0].ruleId).toBe('rule-1');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: Empty conditions array → always passes (no gating) ──

  test('rules with an empty conditions array always produce an outbound plan (no gating) (Req 3.8)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        eventTypeArb, // eventType
        fc.dictionary(fieldNameArb, fc.oneof(numericValueArb, stringValueArb)),
        (businessId, eventType, randomPayloadFields) => {
          const payload = { customerId: 'cust-1', ...randomPayloadFields };

          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload,
          };

          const rule: AutomationRule = {
            id: 'rule-1',
            businessId,
            tenantId: 'tenant-1',
            eventType,
            conditions: [], // EMPTY — no gating
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
          expect(result.plans[0].ruleId).toBe('rule-1');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: Condition evaluation is deterministic ──

  test('condition evaluation is deterministic — same inputs always produce the same result (Req 3.8)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        eventTypeArb, // eventType
        fc.oneof(
          satisfiedConditionArb(standardPayload),
          unsatisfiedConditionArb(standardPayload),
        ),
        (businessId, eventType, condition) => {
          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload: standardPayload,
          };

          const rule: AutomationRule = {
            id: 'rule-1',
            businessId,
            tenantId: 'tenant-1',
            eventType,
            conditions: [condition],
            templateId: 'tmpl-1',
            recipients: { type: 'customer', id: 'cust-1' },
            category: 'transactional',
            enabled: true,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };

          const profiles = makeProfiles(businessId);

          // Run evaluation multiple times with identical inputs
          const result1 = evaluateRules(event, [rule], allEnabledConfig, profiles);
          const result2 = evaluateRules(event, [rule], allEnabledConfig, profiles);
          const result3 = evaluateRules(event, [rule], allEnabledConfig, profiles);

          // All results must be identical
          expect(result1.valid).toBe(result2.valid);
          expect(result2.valid).toBe(result3.valid);
          expect(result1.plans.length).toBe(result2.plans.length);
          expect(result2.plans.length).toBe(result3.plans.length);

          if (result1.plans.length > 0) {
            expect(result1.plans[0].ruleId).toBe(result2.plans[0].ruleId);
            expect(result2.plans[0].ruleId).toBe(result3.plans[0].ruleId);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Additional: Multiple conditions use AND logic ──

  test('multiple conditions use AND logic — all must pass for the rule to produce a plan (Req 3.8)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        eventTypeArb, // eventType
        satisfiedConditionArb(standardPayload),
        unsatisfiedConditionArb(standardPayload),
        (businessId, eventType, goodCondition, badCondition) => {
          const event: BusinessEvent = {
            eventId: 'evt-1',
            businessId,
            eventType,
            payload: standardPayload,
          };

          // Rule with BOTH a satisfied and an unsatisfied condition
          const rule: AutomationRule = {
            id: 'rule-1',
            businessId,
            tenantId: 'tenant-1',
            eventType,
            conditions: [goodCondition, badCondition], // AND logic
            templateId: 'tmpl-1',
            recipients: { type: 'customer', id: 'cust-1' },
            category: 'transactional',
            enabled: true,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };

          const profiles = makeProfiles(businessId);
          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          // Because one condition fails, the whole rule should not fire
          expect(result.valid).toBe(true);
          expect(result.plans).toHaveLength(0);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Additional: All operators evaluated correctly ──

  test('each condition operator evaluates correctly against various payload values (Req 3.8)', () => {
    fc.assert(
      fc.property(
        numericValueArb,
        numericValueArb,
        stringValueArb,
        (val1, val2, strVal) => {
          const payload: Record<string, unknown> = {
            amount: val1,
            status: strVal,
          };

          // eq: exact match
          expect(evaluateCondition({ field: 'amount', operator: 'eq', value: val1 }, payload)).toBe(true);
          expect(evaluateCondition({ field: 'amount', operator: 'eq', value: val1 + 1 }, payload)).toBe(false);

          // neq: not equal
          expect(evaluateCondition({ field: 'amount', operator: 'neq', value: val1 + 1 }, payload)).toBe(true);
          expect(evaluateCondition({ field: 'amount', operator: 'neq', value: val1 }, payload)).toBe(false);

          // gt/gte/lt/lte
          if (val1 < val2) {
            expect(evaluateCondition({ field: 'amount', operator: 'lt', value: val2 }, payload)).toBe(true);
            expect(evaluateCondition({ field: 'amount', operator: 'lte', value: val2 }, payload)).toBe(true);
            expect(evaluateCondition({ field: 'amount', operator: 'gt', value: val2 }, payload)).toBe(false);
          }
          if (val1 > val2) {
            expect(evaluateCondition({ field: 'amount', operator: 'gt', value: val2 }, payload)).toBe(true);
            expect(evaluateCondition({ field: 'amount', operator: 'gte', value: val2 }, payload)).toBe(true);
            expect(evaluateCondition({ field: 'amount', operator: 'lt', value: val2 }, payload)).toBe(false);
          }

          // gte with equal value
          expect(evaluateCondition({ field: 'amount', operator: 'gte', value: val1 }, payload)).toBe(true);
          expect(evaluateCondition({ field: 'amount', operator: 'lte', value: val1 }, payload)).toBe(true);

          // in / not_in
          expect(evaluateCondition({ field: 'status', operator: 'in', value: [strVal, 'other'] }, payload)).toBe(true);
          expect(evaluateCondition({ field: 'status', operator: 'in', value: ['nope'] }, payload)).toBe(false);
          expect(evaluateCondition({ field: 'status', operator: 'not_in', value: ['nope'] }, payload)).toBe(true);
          expect(evaluateCondition({ field: 'status', operator: 'not_in', value: [strVal] }, payload)).toBe(false);

          // exists / not_exists
          expect(evaluateCondition({ field: 'amount', operator: 'exists' }, payload)).toBe(true);
          expect(evaluateCondition({ field: '__missing__', operator: 'exists' }, payload)).toBe(false);
          expect(evaluateCondition({ field: '__missing__', operator: 'not_exists' }, payload)).toBe(true);
          expect(evaluateCondition({ field: 'amount', operator: 'not_exists' }, payload)).toBe(false);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
