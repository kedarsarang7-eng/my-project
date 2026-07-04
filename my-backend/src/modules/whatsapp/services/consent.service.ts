// ============================================================================
// WhatsApp Automation Module — Consent Service (Task 5.3)
// ============================================================================
// Consent state machine, eligibility derivation, message category classification,
// and opt-out keyword detection.
//
// DESIGN CONTRACTS:
// - Consent_State is ALWAYS one of: 'opted_in' | 'opted_out' | 'pending'
// - Default state for a new profile is 'pending'
// - isEligible(profile) = valid E.164 AND opted_in (both must pass)
// - Transactional messages bypass consent opt-out (e.g., invoice receipts)
// - Non-transactional messages are blocked when opted_out or pending
// - Opt-out keyword detection is case-insensitive and whitespace-trimmed
//
// Requirements: 2.3, 2.4, 2.5, 2.6, 2.9, 2.10, 6.9, 13.5
// ============================================================================

import type { ConsentState, MessageCategory } from '../schemas/entities';

// ── Constants ─────────────────────────────────────────────────────────────────

/** The three legal consent state values. No other values are valid. */
export const CONSENT_STATES: readonly ConsentState[] = [
  'opted_in',
  'opted_out',
  'pending',
] as const;

/** Default consent state for a new customer profile (Req 2.4). */
export const DEFAULT_CONSENT_STATE: ConsentState = 'pending';

/**
 * Recognized opt-out keywords (Req 2.6).
 * Matching is case-insensitive and ignores leading/trailing whitespace.
 */
export const OPT_OUT_KEYWORDS: readonly string[] = [
  'stop',
  'unsubscribe',
  'cancel',
  'opt out',
  'optout',
  'quit',
  'end',
] as const;

// ── Types ─────────────────────────────────────────────────────────────────────

/** Minimal customer profile shape needed for consent checks. */
export interface ConsentProfile {
  whatsappNumber: string;
  consentState: ConsentState;
}

/** Result of a consent gate evaluation. */
export interface ConsentGateResult {
  allowed: boolean;
  reason?: string;
}

// ── E.164 validation (delegated from phone.service pattern) ───────────────────

const E164_REGEX = /^\+\d{8,15}$/;

/**
 * Validates whether a phone number is in E.164 format.
 * A valid E.164 number is a leading '+' followed by 8 to 15 digits.
 */
function isValidE164(number: string): boolean {
  return E164_REGEX.test(number);
}

// ── Consent State Machine ─────────────────────────────────────────────────────

/**
 * Validates that a consent state is one of the three legal values.
 * Returns true only for 'opted_in', 'opted_out', or 'pending'.
 */
export function isValidConsentState(state: unknown): state is ConsentState {
  return (
    typeof state === 'string' &&
    (CONSENT_STATES as readonly string[]).includes(state)
  );
}

/**
 * Resolves the consent state for a new profile.
 * Always returns 'pending' when no explicit state is provided (Req 2.4).
 */
export function resolveInitialConsentState(
  explicitState?: ConsentState | null,
): ConsentState {
  if (explicitState && isValidConsentState(explicitState)) {
    return explicitState;
  }
  return DEFAULT_CONSENT_STATE;
}

// ── Eligibility Derivation ────────────────────────────────────────────────────

/**
 * Determines if a customer profile is eligible for event-driven automations.
 *
 * Eligibility requires BOTH:
 * 1. A valid E.164 WhatsApp number
 * 2. Consent state of 'opted_in'
 *
 * If either condition fails, the customer must NOT receive messages (Req 2.9, 2.10).
 */
export function isEligible(profile: ConsentProfile): boolean {
  return isValidE164(profile.whatsappNumber) && profile.consentState === 'opted_in';
}

// ── Message Category Classification ──────────────────────────────────────────

/**
 * Classifies a message category as transactional or non-transactional.
 *
 * Transactional: messages required to complete or service a specific
 * customer-initiated transaction (invoices, receipts, order confirmations,
 * payment confirmations, refund confirmations).
 *
 * Non-transactional: marketing, promotional, relationship, and engagement
 * messages that are not required for a customer-initiated transaction.
 */
export function isTransactional(category: MessageCategory): boolean {
  return category === 'transactional';
}

/**
 * Classifies a message category as non-transactional.
 */
export function isNonTransactional(category: MessageCategory): boolean {
  return category === 'non_transactional';
}

// ── Consent Gate ──────────────────────────────────────────────────────────────

/**
 * Evaluates whether a message should be sent given the profile's consent state
 * and the message category.
 *
 * Rules (Req 2.5, 6.9, 13.5):
 * - Transactional messages are ALWAYS allowed regardless of consent state
 *   (e.g., invoice receipts are required to service the transaction)
 * - Non-transactional messages are ONLY allowed when consent is 'opted_in'
 * - Non-transactional messages are BLOCKED when consent is 'opted_out' or 'pending'
 *
 * Note: This checks consent state only. Full eligibility (E.164 + opted_in)
 * should be checked via `isEligible()` before reaching this gate for
 * non-transactional messages.
 */
export function evaluateConsentGate(
  consentState: ConsentState,
  category: MessageCategory,
): ConsentGateResult {
  // Transactional messages bypass the consent gate entirely
  if (isTransactional(category)) {
    return { allowed: true };
  }

  // Non-transactional: only allowed if opted_in
  if (consentState === 'opted_in') {
    return { allowed: true };
  }

  // Blocked: opted_out or pending
  return {
    allowed: false,
    reason:
      consentState === 'opted_out'
        ? 'Customer has opted out of non-transactional messages'
        : 'Customer consent is pending; non-transactional messages suppressed',
  };
}

// ── Opt-Out Keyword Detection ─────────────────────────────────────────────────

/**
 * Detects whether an inbound message text matches a recognized opt-out keyword.
 *
 * Detection is:
 * - Case-insensitive ("STOP", "Stop", "stop" all match)
 * - Whitespace-trimmed (" STOP ", "  stop  ", "\tstop\n" all match)
 *
 * Returns true if the trimmed, lowercased message exactly matches any
 * recognized opt-out keyword (Req 2.6).
 */
export function isOptOutKeyword(messageText: string): boolean {
  const normalized = messageText.trim().toLowerCase();
  if (normalized.length === 0) {
    return false;
  }
  return (OPT_OUT_KEYWORDS as readonly string[]).includes(normalized);
}

/**
 * Returns the matching opt-out keyword if found, or null if the message
 * does not match any recognized opt-out keyword.
 * Useful for logging/audit which keyword was detected.
 */
export function detectOptOutKeyword(messageText: string): string | null {
  const normalized = messageText.trim().toLowerCase();
  if (normalized.length === 0) {
    return null;
  }
  const match = OPT_OUT_KEYWORDS.find((kw) => kw === normalized);
  return match ?? null;
}

// ── Composite Consent Check (for the Automation Engine) ───────────────────────

/**
 * Full consent check combining eligibility and consent gate.
 *
 * For the Automation Engine to use before enqueuing an Outbound_Message:
 * 1. For transactional messages: checks only E.164 validity (transactional
 *    messages bypass consent opt-out but still require a valid number)
 * 2. For non-transactional messages: checks BOTH valid E.164 AND opted_in
 *
 * Returns whether the message should be sent and the reason if blocked (Req 2.9, 2.10, 6.9).
 */
export function shouldSendMessage(
  profile: ConsentProfile,
  category: MessageCategory,
): ConsentGateResult {
  // Always require a valid phone number
  if (!isValidE164(profile.whatsappNumber)) {
    return {
      allowed: false,
      reason: 'WhatsApp number is absent or invalid (not E.164)',
    };
  }

  // Transactional messages only need valid E.164, consent doesn't block them
  if (isTransactional(category)) {
    return { allowed: true };
  }

  // Non-transactional: require opted_in consent
  return evaluateConsentGate(profile.consentState, category);
}

// ── Consent State Transition ──────────────────────────────────────────────────

/**
 * Computes the new consent state when an opt-out keyword is detected.
 * Returns 'opted_out' if the message matches an opt-out keyword,
 * otherwise returns the current state unchanged.
 */
export function applyOptOut(
  currentState: ConsentState,
  messageText: string,
): ConsentState {
  if (isOptOutKeyword(messageText)) {
    return 'opted_out';
  }
  return currentState;
}
