// ============================================================================
// WhatsApp Automation Module — Recipient Verification Service (Task 8.8)
// ============================================================================
// CRITICAL SAFETY COMPONENT: Ensures zero cross-customer document delivery.
//
// Before any Document_Automation message is dispatched, this service verifies:
// 1. The recipientId exists as a CustomerProfile in the sending business
// 2. The recipientNumber matches the profile's stored whatsappNumber
// 3. The profile is not soft-deleted
// 4. The profile's E.164 number is still valid
//
// If ANY verification fails → STOP delivery, return failure reason.
// The caller (engine/dispatcher) must then log the failure and notify the operator.
//
// DESIGN CONTRACTS:
// - PURE FUNCTION: deterministic, side-effect-free. Same inputs → same outputs.
// - Resolution is by unique customer identifier ONLY (never name/fuzzy match).
// - Fails closed on zero matches, multiple matches, or number mismatch.
// - Returns the verified (customerId, storedNumber) pair so dispatch targets
//   ONLY the verified number from the profile (Req 16.4, 16.5).
// - Evaluated independently per event (Req 16.9).
//
// Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.8, 16.9
// ============================================================================

import type { CustomerProfile } from '../schemas/entities';
import { validateE164 } from './phone.service';

// ── Types ─────────────────────────────────────────────────────────────────────

/**
 * The Business_Event fields relevant to recipient verification.
 * The engine passes in only the fields needed for verification.
 */
export interface RecipientVerificationInput {
  /** Unique customer identifier carried on the Business_Event (required). */
  readonly customerId: string;
  /** The BusinessID of the authenticated session (required). */
  readonly businessId: string;
  /**
   * Customer contact number carried on the Business_Event payload (optional).
   * When present, it MUST match the resolved profile's stored number after
   * E.164 normalization (Req 16.3).
   */
  readonly eventCarriedNumber?: string;
}

/**
 * Successful verification result — the dispatch may proceed using ONLY
 * the verified (customerId, storedNumber) pair.
 */
export interface VerificationSuccess {
  readonly verified: true;
  /** The resolved customer's unique identifier. */
  readonly customerId: string;
  /** The verified stored WhatsApp number from the profile (E.164). */
  readonly number: string;
}

/**
 * Verification failure — the dispatch MUST NOT proceed. The caller must
 * log the reason and raise an Operator_Alert.
 */
export interface VerificationFailure {
  readonly verified: false;
  /** The reason why verification failed. */
  readonly reason: string;
  /** The failure category for structured logging. */
  readonly failureType: RecipientVerificationFailureType;
}

/** Enumeration of failure categories for structured error handling. */
export type RecipientVerificationFailureType =
  | 'MISSING_CUSTOMER_ID'
  | 'MISSING_BUSINESS_ID'
  | 'PROFILE_NOT_FOUND'
  | 'MULTIPLE_PROFILES'
  | 'PROFILE_DELETED'
  | 'INVALID_STORED_NUMBER'
  | 'NUMBER_MISMATCH'
  | 'INVALID_EVENT_NUMBER';

/** Union result type returned by verifyRecipient. */
export type RecipientVerificationResult = VerificationSuccess | VerificationFailure;

// ── Core Verification Function ────────────────────────────────────────────────

/**
 * Verifies that a Document_Automation's target recipient is the correct
 * customer before dispatch proceeds.
 *
 * Resolution algorithm:
 * 1. Validate input: customerId and businessId must be present and non-empty.
 * 2. Resolve by unique customer identifier in the profilesById map (never by
 *    name or fuzzy match — Req 16.1).
 * 3. Fail closed on zero matches (profile not found — Req 16.2).
 * 4. Verify the resolved profile is not soft-deleted.
 * 5. Verify the profile's stored WhatsApp number is still valid E.164.
 * 6. If the event carries a customer contact number, verify it equals the
 *    profile's stored number after E.164 normalization (Req 16.3).
 * 7. On success, return the bound (customerId, verified stored number) so
 *    dispatch targets ONLY that number (Req 16.4, 16.5).
 *
 * This function is PURE: deterministic and side-effect-free (Req 16.8).
 * It is evaluated independently per event (Req 16.9).
 *
 * @param input - The verification input derived from the Business_Event
 * @param profilesById - Map of customerId → CustomerProfile for the business
 * @returns VerificationSuccess or VerificationFailure
 */
export function verifyRecipient(
  input: RecipientVerificationInput,
  profilesById: ReadonlyMap<string, CustomerProfile>,
): RecipientVerificationResult {
  // ── Step 1: Validate required input fields ──────────────────────────
  if (!input.customerId || input.customerId.trim().length === 0) {
    return {
      verified: false,
      reason: 'Business_Event does not carry a unique customer identifier (customerId is missing or empty)',
      failureType: 'MISSING_CUSTOMER_ID',
    };
  }

  if (!input.businessId || input.businessId.trim().length === 0) {
    return {
      verified: false,
      reason: 'BusinessID is missing or empty — cannot scope recipient lookup',
      failureType: 'MISSING_BUSINESS_ID',
    };
  }

  // ── Step 2: Resolve by unique customer identifier (Req 16.1) ────────
  // Resolution is ONLY by the exact customerId key. No name-based or fuzzy
  // matching is performed. The profilesById map is pre-scoped to the
  // sending business (enforced by the caller/engine).
  const profile = profilesById.get(input.customerId);

  // ── Step 3: Fail closed on zero matches (Req 16.2) ──────────────────
  if (!profile) {
    return {
      verified: false,
      reason: `No CustomerProfile found for customerId '${input.customerId}' within businessId '${input.businessId}'`,
      failureType: 'PROFILE_NOT_FOUND',
    };
  }

  // Verify the profile belongs to the sending business (defense-in-depth)
  if (profile.businessId !== input.businessId) {
    return {
      verified: false,
      reason: `CustomerProfile '${input.customerId}' belongs to a different business (expected '${input.businessId}', found '${profile.businessId}')`,
      failureType: 'PROFILE_NOT_FOUND',
    };
  }

  // ── Step 4: Verify not soft-deleted ─────────────────────────────────
  if (profile.isDeleted) {
    return {
      verified: false,
      reason: `CustomerProfile '${input.customerId}' is soft-deleted; cannot dispatch document to a deleted profile`,
      failureType: 'PROFILE_DELETED',
    };
  }

  // ── Step 5: Verify stored number is valid E.164 ─────────────────────
  const storedNumberValidation = validateE164(profile.whatsappNumber);
  if (!storedNumberValidation.valid) {
    return {
      verified: false,
      reason: `CustomerProfile '${input.customerId}' has an invalid stored WhatsApp number: ${storedNumberValidation.error}`,
      failureType: 'INVALID_STORED_NUMBER',
    };
  }

  const verifiedStoredNumber = storedNumberValidation.normalized!;

  // ── Step 6: Cross-check event-carried number (Req 16.3) ─────────────
  if (input.eventCarriedNumber !== undefined && input.eventCarriedNumber !== null) {
    const trimmedEventNumber = input.eventCarriedNumber.trim();

    // If the event carries a number, it must be valid E.164 too
    if (trimmedEventNumber.length > 0) {
      const eventNumberValidation = validateE164(trimmedEventNumber);

      if (!eventNumberValidation.valid) {
        return {
          verified: false,
          reason: `Event-carried customer number '${trimmedEventNumber}' is not valid E.164: ${eventNumberValidation.error}`,
          failureType: 'INVALID_EVENT_NUMBER',
        };
      }

      const normalizedEventNumber = eventNumberValidation.normalized!;

      // Compare after E.164 normalization (Req 16.3)
      if (normalizedEventNumber !== verifiedStoredNumber) {
        return {
          verified: false,
          reason: `Number mismatch: event carries '${normalizedEventNumber}' but profile '${input.customerId}' has stored number '${verifiedStoredNumber}'. The phone number may have been changed after the message was enqueued.`,
          failureType: 'NUMBER_MISMATCH',
        };
      }
    }
    // Empty string event number is treated as "not carried" — no cross-check needed
  }

  // ── Step 7: All checks passed — return verified binding (Req 16.4, 16.5) ─
  return {
    verified: true,
    customerId: input.customerId,
    number: verifiedStoredNumber,
  };
}

// ── Batch Verification (Req 16.9) ─────────────────────────────────────────────

/**
 * Verifies multiple recipients independently, one per event/plan.
 * Each verification is evaluated independently so the resolution for one event
 * is never used as the recipient for another event's document (Req 16.9).
 *
 * @param inputs - Array of verification inputs, one per Document_Automation
 * @param profilesById - Map of customerId → CustomerProfile for the business
 * @returns Array of results in the same order as inputs
 */
export function verifyRecipientsBatch(
  inputs: readonly RecipientVerificationInput[],
  profilesById: ReadonlyMap<string, CustomerProfile>,
): RecipientVerificationResult[] {
  return inputs.map((input) => verifyRecipient(input, profilesById));
}

// ── Helper: Extract verification input from an OutboundPlan ───────────────────

/**
 * Extracts the RecipientVerificationInput from an OutboundPlan and its
 * associated Business_Event payload. This is a convenience bridge for the
 * Automation Engine to use before enqueue.
 *
 * The customerId comes from the plan's recipientId (which was resolved by
 * the rule engine from the event's unique customer identifier).
 * The eventCarriedNumber comes from the event payload's customerNumber field
 * (if present).
 */
export function extractVerificationInput(
  recipientId: string,
  businessId: string,
  eventPayload?: Record<string, unknown>,
): RecipientVerificationInput {
  const eventCarriedNumber = eventPayload?.customerNumber as string | undefined
    ?? eventPayload?.customerPhone as string | undefined
    ?? eventPayload?.recipientNumber as string | undefined;

  return {
    customerId: recipientId,
    businessId,
    eventCarriedNumber,
  };
}
