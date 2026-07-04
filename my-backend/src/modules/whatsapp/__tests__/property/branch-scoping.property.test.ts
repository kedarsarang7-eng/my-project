// ============================================================================
// Property-Based Test — Branch Scoping
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 34
//
// Validates: Requirements 11.7
//
// Property 34 (design.md): Branch notifications are scoped to the originating
// branch's recipients.
//
// Verifies:
// 1. A rule with branchId only matches events from that branch
// 2. A rule with branchId does NOT match events from a different branch
// 3. A rule WITHOUT branchId matches events regardless of the event's branch
// 4. Recipients are scoped to the rule's branch when applicable
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
const safeIdArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789_-'.split('')),
  { minLength: 3, maxLength: 20 },
);

/** Generates a branch ID. */
const branchIdArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789_-'.split('')),
  { minLength: 3, maxLength: 15 },
).map((s) => `branch-${s}`);

/** Generates a valid E.164 phone number. */
const e164Arb = fc.integer({ min: 10000000, max: 999999999999999 }).map((n) => `+${n}`);

/** Shared event type for all tests (keeps focus on branch scoping). */
const EVENT_TYPE = 'invoice.generated';

/** All-enabled config. */
const allEnabledConfig: EnabledAutomationsConfig = {
  enabledAutomationKeys: new Set([EVENT_TYPE]),
};

/** Creates a CustomerProfile with an optional branchId. */
function makeProfile(
  id: string,
  businessId: string,
  branchId?: string,
): CustomerProfile {
  const now = new Date().toISOString();
  const profile: Record<string, unknown> = {
    id,
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
  if (branchId) {
    profile.branchId = branchId;
  }
  return profile as unknown as CustomerProfile;
}

/** Creates a minimal AutomationRule. */
function makeRule(overrides: {
  businessId: string;
  branchId?: string;
}): AutomationRule {
  const now = new Date().toISOString();
  return {
    id: 'rule-1',
    businessId: overrides.businessId,
    tenantId: 'tenant-1',
    branchId: overrides.branchId,
    eventType: EVENT_TYPE,
    conditions: [],
    templateId: 'tmpl-1',
    recipients: { type: 'customer', id: 'cust-1' },
    category: 'transactional',
    enabled: true,
    createdAt: now,
    updatedAt: now,
  } as unknown as AutomationRule;
}

/** Creates a BusinessEvent with an optional branchId. */
function makeEvent(businessId: string, branchId?: string): BusinessEvent {
  return {
    eventId: 'evt-1',
    businessId,
    eventType: EVENT_TYPE,
    branchId,
    payload: { customerId: 'cust-1' },
  };
}

// ── Property 34: Branch Scoping ─────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 34: Branch notifications are scoped to the originating branch\'s recipients', () => {

  // ── Sub-property 1: A rule with branchId only matches events from that branch ──

  test('a branch-scoped rule matches an event from the SAME branch and the recipient is in that branch (Req 11.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        branchIdArb, // branch (shared between rule, event, and profile)
        (businessId, branch) => {
          const rule = makeRule({ businessId, branchId: branch });
          const event = makeEvent(businessId, branch);
          const profile = makeProfile('cust-1', businessId, branch);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          expect(result.plans).toHaveLength(1);
          expect(result.plans[0].recipientId).toBe('cust-1');
          // The outbound plan's branchId is set
          expect(result.plans[0].branchId).toBe(branch);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: A rule with branchId does NOT match events from a different branch ──

  test('a branch-scoped rule does NOT match an event from a DIFFERENT branch (Req 11.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        branchIdArb, // rule's branch
        branchIdArb, // event's branch
        (businessId, ruleBranch, eventBranch) => {
          // Ensure branches are actually different
          fc.pre(ruleBranch !== eventBranch);

          const rule = makeRule({ businessId, branchId: ruleBranch });
          const event = makeEvent(businessId, eventBranch);
          // Profile is in the rule's branch (but event is from a different branch)
          const profile = makeProfile('cust-1', businessId, ruleBranch);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // No plans — the branch scope check blocks delivery
          expect(result.plans).toHaveLength(0);
          // Should have a suppression record for branch mismatch
          expect(result.suppressions.length).toBeGreaterThanOrEqual(1);
          expect(result.suppressions[0].reason).toContain('Branch scope mismatch');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: A rule WITHOUT branchId matches events regardless of event's branch ──

  test('a rule without branchId matches events regardless of the event branch (Req 11.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        fc.option(branchIdArb, { nil: undefined }), // event may or may not have a branch
        (businessId, eventBranch) => {
          // Rule has NO branchId — not branch-scoped
          const rule = makeRule({ businessId, branchId: undefined });
          const event = makeEvent(businessId, eventBranch);
          // Profile may or may not have a branch — doesn't matter for non-scoped rule
          const profile = makeProfile('cust-1', businessId, eventBranch);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // Non-branch-scoped rule should produce a plan regardless
          expect(result.plans).toHaveLength(1);
          expect(result.plans[0].recipientId).toBe('cust-1');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: Recipients are scoped — a profile in a different branch is excluded ──

  test('a branch-scoped rule excludes a recipient whose profile belongs to a different branch (Req 11.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        branchIdArb, // rule's branch (and event's branch)
        branchIdArb, // profile's branch (different)
        (businessId, ruleBranch, profileBranch) => {
          // Ensure branches differ
          fc.pre(ruleBranch !== profileBranch);

          const rule = makeRule({ businessId, branchId: ruleBranch });
          const event = makeEvent(businessId, ruleBranch); // event matches rule's branch
          // Profile belongs to a DIFFERENT branch
          const profile = makeProfile('cust-1', businessId, profileBranch);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // The recipient is excluded because their branch doesn't match
          expect(result.plans).toHaveLength(0);
          expect(result.suppressions.length).toBeGreaterThanOrEqual(1);
          expect(result.suppressions[0].reason).toContain('Branch scope mismatch');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 5: A branch-scoped rule accepts a "shared" profile (no branchId on profile) ──

  test('a branch-scoped rule accepts a shared customer (profile with no branchId) when event matches (Req 11.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        branchIdArb, // shared branch for rule and event
        (businessId, branch) => {
          const rule = makeRule({ businessId, branchId: branch });
          const event = makeEvent(businessId, branch);
          // Profile has NO branchId — shared customer, accessible to all branches
          const profile = makeProfile('cust-1', businessId, undefined);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // Shared customers pass branch scope when event matches rule
          expect(result.plans).toHaveLength(1);
          expect(result.plans[0].recipientId).toBe('cust-1');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 6: Branch-scoped rule with event missing branchId produces no plan ──

  test('a branch-scoped rule produces no plan when the event has no branchId (Req 11.7)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // businessId
        branchIdArb, // rule's branch
        (businessId, ruleBranch) => {
          const rule = makeRule({ businessId, branchId: ruleBranch });
          // Event has NO branchId
          const event = makeEvent(businessId, undefined);
          const profile = makeProfile('cust-1', businessId, ruleBranch);
          const profiles = new Map([['cust-1', profile]]);

          const result = evaluateRules(event, [rule], allEnabledConfig, profiles);

          expect(result.valid).toBe(true);
          // event.branchId is undefined, rule.branchId is set → mismatch
          expect(result.plans).toHaveLength(0);
          expect(result.suppressions.length).toBeGreaterThanOrEqual(1);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
