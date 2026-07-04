// ============================================================================
// WhatsApp Automation Module — Rule Engine Service (Task 8.2)
// ============================================================================
// Pure `evaluateRules(event, rules, config, profiles)` — the central decision
// function of the Automation Engine. Given a Business_Event and the full rule
// set + customer profiles, it produces an OutboundPlan[] describing which
// messages to enqueue and for whom.
//
// DESIGN CONTRACTS:
// - PURE FUNCTION: deterministic, side-effect-free. Same inputs → same outputs.
// - Subscription + BusinessID match: rules evaluated ONLY when they subscribe
//   to the event AND share its BusinessID (Req 3.1, 3.7).
// - Condition evaluation: conditions not satisfied → NO messaging action (Req 3.8).
// - Recipient resolution with consent gate: calls shouldSendMessage for each
//   recipient; the recipient number MUST come from the CustomerProfile, never
//   from the event payload directly (Req 3.2, 3.5).
// - Exactly ONE message per eligible recipient per triggering event (Req 3.2).
// - Branch scoping: branch-scoped rules only reach the originating branch's
//   recipients (Req 11.7).
// - Malformed-event discard: events missing required fields produce no
//   OutboundPlan and return a discard reason (Req 3.9).
//
// Requirements: 3.1, 3.2, 3.5, 3.7, 3.8, 3.9, 11.7
// ============================================================================

import type {
  AutomationRule,
  CustomerProfile,
  RuleCondition,
  MessageCategory,
} from '../schemas/entities';
import { shouldSendMessage } from './consent.service';

// ── Input Types ───────────────────────────────────────────────────────────────

/**
 * Represents a Business_Event received by the Automation Engine.
 * Required fields enforce malformed-event detection (Req 3.9).
 */
export interface BusinessEvent {
  /** Unique event identifier for idempotency (required). */
  readonly eventId: string;
  /** The BusinessID that emitted the event (required). */
  readonly businessId: string;
  /** The event type, e.g. 'invoice.generated' (required). */
  readonly eventType: string;
  /** The Branch that originated the event (optional; used for branch scoping). */
  readonly branchId?: string;
  /** The event payload containing template data and recipient info. */
  readonly payload: Record<string, unknown>;
}

/**
 * Enabled automations config — a simplified view indicating which event types
 * have active rules for the business. Passed from automation-config resolution.
 */
export interface EnabledAutomationsConfig {
  /** Set of automation keys that are enabled for this business. */
  readonly enabledAutomationKeys: ReadonlySet<string>;
}

// ── Output Types ──────────────────────────────────────────────────────────────

/**
 * A plan to enqueue a single Outbound_Message. The engine produces one per
 * eligible recipient per matched rule.
 */
export interface OutboundPlan {
  /** The rule that matched and produced this plan. */
  readonly ruleId: string;
  /** The recipient customer's ID (from the profile, not from the event). */
  readonly recipientId: string;
  /** The recipient's WhatsApp number (from the CustomerProfile, never event payload). */
  readonly recipientNumber: string;
  /** Template ID to render. */
  readonly templateId: string;
  /** Message category (transactional or non_transactional). */
  readonly category: MessageCategory;
  /** Branch scope (if applicable). */
  readonly branchId?: string;
  /** Schedule/delay configuration from the rule (if any). */
  readonly schedule?: { delaySeconds?: number; at?: string };
  /** The event ID for idempotency binding. */
  readonly eventId: string;
  /** The BusinessID for tenant scoping. */
  readonly businessId: string;
}

/**
 * The full result of rule evaluation for a single Business_Event.
 */
export interface RuleEvaluationResult {
  /** Whether the event was valid and evaluation proceeded. */
  readonly valid: boolean;
  /** Plans to enqueue — one per eligible recipient per matched rule. */
  readonly plans: OutboundPlan[];
  /** If the event was discarded, the reason (Req 3.9). */
  readonly discardReason?: string;
  /** Per-recipient suppression reasons (consent blocks, branch mismatch, etc.). */
  readonly suppressions: SuppressionEntry[];
}

/**
 * Records why a specific recipient was suppressed for a specific rule.
 */
export interface SuppressionEntry {
  readonly ruleId: string;
  readonly recipientId: string;
  readonly reason: string;
}

// ── Required Event Fields ─────────────────────────────────────────────────────

/** Fields that MUST be present on a Business_Event for it to be processable. */
const REQUIRED_EVENT_FIELDS: readonly (keyof BusinessEvent)[] = [
  'eventId',
  'businessId',
  'eventType',
];

// ── Malformed Event Detection (Req 3.9) ───────────────────────────────────────

/**
 * Validates that a Business_Event has all required fields.
 * Returns a discard reason string if malformed, or null if valid.
 */
export function validateEvent(event: unknown): string | null {
  if (event === null || event === undefined || typeof event !== 'object') {
    return 'Event is null, undefined, or not an object';
  }

  const e = event as Record<string, unknown>;

  for (const field of REQUIRED_EVENT_FIELDS) {
    const value = e[field];
    if (value === undefined || value === null) {
      return `Missing required field: ${field}`;
    }
    if (typeof value === 'string' && value.trim().length === 0) {
      return `Empty required field: ${field}`;
    }
  }

  // payload must be an object (may be empty but must exist)
  if (e.payload === undefined || e.payload === null || typeof e.payload !== 'object') {
    return 'Missing or invalid payload: must be a non-null object';
  }

  return null;
}

// ── Condition Evaluation (Req 3.8) ────────────────────────────────────────────

/**
 * Evaluates a single rule condition against the event payload.
 * Returns true if the condition is satisfied.
 *
 * Operator semantics:
 * - eq: field value strictly equals condition value
 * - neq: field value does not strictly equal condition value
 * - gt/gte/lt/lte: numeric comparison
 * - in: field value is one of the condition value array
 * - not_in: field value is NOT one of the condition value array
 * - exists: field is present and not null/undefined
 * - not_exists: field is absent, null, or undefined
 */
export function evaluateCondition(
  condition: RuleCondition,
  payload: Record<string, unknown>,
): boolean {
  const fieldValue = getNestedValue(payload, condition.field);

  switch (condition.operator) {
    case 'exists':
      return fieldValue !== undefined && fieldValue !== null;

    case 'not_exists':
      return fieldValue === undefined || fieldValue === null;

    case 'eq':
      return fieldValue === condition.value;

    case 'neq':
      return fieldValue !== condition.value;

    case 'gt':
      return typeof fieldValue === 'number' && typeof condition.value === 'number'
        && fieldValue > condition.value;

    case 'gte':
      return typeof fieldValue === 'number' && typeof condition.value === 'number'
        && fieldValue >= condition.value;

    case 'lt':
      return typeof fieldValue === 'number' && typeof condition.value === 'number'
        && fieldValue < condition.value;

    case 'lte':
      return typeof fieldValue === 'number' && typeof condition.value === 'number'
        && fieldValue <= condition.value;

    case 'in':
      return Array.isArray(condition.value) && condition.value.includes(fieldValue);

    case 'not_in':
      return Array.isArray(condition.value) && !condition.value.includes(fieldValue);

    default:
      // Unknown operator → condition fails (fail-closed)
      return false;
  }
}

/**
 * Evaluates ALL conditions for a rule. All conditions must be satisfied (AND logic).
 * An empty conditions array is treated as "always satisfied" (no conditions to gate).
 */
export function evaluateConditions(
  conditions: RuleCondition[],
  payload: Record<string, unknown>,
): boolean {
  if (conditions.length === 0) {
    return true;
  }
  return conditions.every((c) => evaluateCondition(c, payload));
}

// ── Recipient Resolution ──────────────────────────────────────────────────────

/**
 * Resolves the set of eligible recipients for a rule given the event and
 * the full set of CustomerProfiles for the business.
 *
 * Resolution rules:
 * - recipient type 'customer' with an id: target that specific customer
 * - recipient type 'customer' without id: use the customerId from event payload
 * - recipient type 'supplier'/'staff': use the id from recipient spec
 * - recipient type 'segment': filter profiles by segmentFilter (simplified)
 *
 * The recipient's number ALWAYS comes from the CustomerProfile, never from
 * the event payload.
 */
function resolveRecipients(
  rule: AutomationRule,
  event: BusinessEvent,
  profiles: ReadonlyMap<string, CustomerProfile>,
): CustomerProfile[] {
  const { recipients } = rule;

  switch (recipients.type) {
    case 'customer': {
      // Single customer — resolve by ID from recipient spec or event payload
      const customerId = recipients.id
        || (event.payload.customerId as string | undefined);
      if (!customerId) {
        return [];
      }
      const profile = profiles.get(customerId);
      return profile && !profile.isDeleted ? [profile] : [];
    }

    case 'supplier':
    case 'staff': {
      // Direct ID-based lookup
      if (!recipients.id) {
        return [];
      }
      const profile = profiles.get(recipients.id);
      return profile && !profile.isDeleted ? [profile] : [];
    }

    case 'segment': {
      // Filter all profiles by segment criteria
      const results: CustomerProfile[] = [];
      for (const profile of profiles.values()) {
        if (profile.isDeleted) continue;
        if (matchesSegmentFilter(profile, recipients.segmentFilter)) {
          results.push(profile);
        }
      }
      return results;
    }

    default:
      return [];
  }
}

/**
 * Simple segment filter matching. Checks that every key-value pair in the
 * filter matches the corresponding field on the profile or its payload.
 */
function matchesSegmentFilter(
  profile: CustomerProfile,
  filter?: Record<string, unknown>,
): boolean {
  if (!filter || Object.keys(filter).length === 0) {
    // No filter = all profiles in the segment
    return true;
  }

  for (const [key, expectedValue] of Object.entries(filter)) {
    const profileValue = (profile as unknown as Record<string, unknown>)[key];
    if (profileValue !== expectedValue) {
      return false;
    }
  }
  return true;
}

// ── Branch Scoping (Req 11.7) ─────────────────────────────────────────────────

/**
 * Checks whether a recipient passes branch scoping.
 *
 * Rules:
 * - If the rule has no branchId, it's not branch-scoped → all recipients pass
 * - If the rule has a branchId, the event must also have a matching branchId,
 *   AND the recipient must belong to that branch (profile.branchId or no
 *   branch restriction on the profile)
 */
function passesBranchScope(
  rule: AutomationRule,
  event: BusinessEvent,
  profile: CustomerProfile,
): boolean {
  // Rule is not branch-scoped → passes
  if (!rule.branchId) {
    return true;
  }

  // Rule is branch-scoped: event must come from the same branch
  if (event.branchId !== rule.branchId) {
    return false;
  }

  // Profile must belong to the originating branch
  // A profile without a branchId is accessible to all branches (shared customer)
  const profileBranchId = (profile as unknown as Record<string, unknown>).branchId as string | undefined;
  if (profileBranchId && profileBranchId !== rule.branchId) {
    return false;
  }

  return true;
}

// ── Core Rule Evaluation Function ─────────────────────────────────────────────

/**
 * Evaluates all automation rules against a Business_Event and produces an
 * OutboundPlan for each eligible recipient of each matching rule.
 *
 * This function is PURE: deterministic, side-effect-free.
 *
 * Algorithm:
 * 1. Validate the event (malformed → discard, Req 3.9)
 * 2. Filter rules to those that subscribe to the event type AND share its
 *    BusinessID (Req 3.1, 3.7)
 * 3. For each matching rule:
 *    a. Evaluate conditions (Req 3.8) — skip if not satisfied
 *    b. Resolve recipients
 *    c. For each recipient:
 *       - Branch scoping check (Req 11.7)
 *       - Consent gate via shouldSendMessage (Req 3.5)
 *       - Dedup: exactly one message per recipient per event (Req 3.2)
 * 4. Return OutboundPlan[] + suppressions + discard reason
 *
 * @param event - The Business_Event to evaluate
 * @param rules - All Automation_Rules for the business
 * @param config - The enabled automations configuration
 * @param profiles - Map of customerId → CustomerProfile for the business
 * @returns RuleEvaluationResult with plans and suppression records
 */
export function evaluateRules(
  event: unknown,
  rules: readonly AutomationRule[],
  config: EnabledAutomationsConfig,
  profiles: ReadonlyMap<string, CustomerProfile>,
): RuleEvaluationResult {
  // ── Step 1: Validate the event (Req 3.9) ────────────────────────────
  const discardReason = validateEvent(event);
  if (discardReason) {
    return {
      valid: false,
      plans: [],
      discardReason,
      suppressions: [],
    };
  }

  const validEvent = event as BusinessEvent;
  const plans: OutboundPlan[] = [];
  const suppressions: SuppressionEntry[] = [];

  // Track recipients already planned for this event to enforce exactly-one (Req 3.2)
  const plannedRecipients = new Set<string>();

  // ── Step 2: Filter rules by subscription + BusinessID (Req 3.1, 3.7) ─
  const matchingRules = rules.filter((rule) =>
    rule.enabled
    && rule.businessId === validEvent.businessId
    && rule.eventType === validEvent.eventType,
  );

  // No matching rules → no messaging action (Req 3.7)
  if (matchingRules.length === 0) {
    return {
      valid: true,
      plans: [],
      suppressions: [],
    };
  }

  // ── Step 3: Evaluate each matching rule ─────────────────────────────
  for (const rule of matchingRules) {
    // 3a. Evaluate conditions (Req 3.8)
    if (!evaluateConditions(rule.conditions, validEvent.payload)) {
      // Conditions not satisfied → no messaging action for this rule
      continue;
    }

    // 3b. Resolve recipients
    const recipients = resolveRecipients(rule, validEvent, profiles);

    // 3c. Process each recipient
    for (const profile of recipients) {
      const recipientId = profile.id;

      // Exactly-one-per-eligible-recipient (Req 3.2):
      // If we already planned a message for this recipient from this event, skip
      if (plannedRecipients.has(recipientId)) {
        continue;
      }

      // Branch scoping check (Req 11.7)
      if (!passesBranchScope(rule, validEvent, profile)) {
        suppressions.push({
          ruleId: rule.id,
          recipientId,
          reason: `Branch scope mismatch: rule scoped to branch '${rule.branchId}', recipient not in that branch`,
        });
        continue;
      }

      // Consent gate (Req 3.5): use shouldSendMessage from consent.service
      const consentResult = shouldSendMessage(
        { whatsappNumber: profile.whatsappNumber, consentState: profile.consentState },
        rule.category,
      );

      if (!consentResult.allowed) {
        suppressions.push({
          ruleId: rule.id,
          recipientId,
          reason: consentResult.reason || 'Consent gate blocked message',
        });
        continue;
      }

      // All checks passed — create outbound plan
      // The recipient number MUST come from the CustomerProfile (never event payload)
      plans.push({
        ruleId: rule.id,
        recipientId,
        recipientNumber: profile.whatsappNumber,
        templateId: rule.templateId,
        category: rule.category,
        branchId: rule.branchId || validEvent.branchId,
        schedule: rule.schedule,
        eventId: validEvent.eventId,
        businessId: validEvent.businessId,
      });

      // Mark recipient as planned (enforces exactly-one, Req 3.2)
      plannedRecipients.add(recipientId);
    }
  }

  return {
    valid: true,
    plans,
    suppressions,
  };
}

// ── Utility: nested value access ──────────────────────────────────────────────

/**
 * Accesses a potentially nested value in an object using dot-notation path.
 * e.g., 'customer.amount' → obj.customer.amount
 */
function getNestedValue(
  obj: Record<string, unknown>,
  path: string,
): unknown {
  const parts = path.split('.');
  let current: unknown = obj;

  for (const part of parts) {
    if (current === null || current === undefined || typeof current !== 'object') {
      return undefined;
    }
    current = (current as Record<string, unknown>)[part];
  }

  return current;
}
