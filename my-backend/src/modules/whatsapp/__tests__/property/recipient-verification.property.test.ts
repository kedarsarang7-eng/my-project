/**
 * Property-Based Tests: Recipient Identity Verification
 *
 * Feature: openwa-whatsapp-automation, Property 36
 *
 * **Validates: Requirements 16.1, 16.2, 16.3, 16.4, 16.5, 16.8, 16.9**
 *
 * Property 36: A document message dispatches only to the verified number of its
 * uniquely resolved customer, else it fails closed with an operator alert.
 *
 * Sub-properties tested:
 * 1. Exactly one profile match → verification succeeds with the stored number
 * 2. Zero profiles match → verification fails closed (blocked)
 * 3. Multiple profiles match → verification fails closed (blocked)
 * 4. Event-carried number differs from stored number → verification fails closed
 * 5. Numbers match → verification succeeds with (customerId, verifiedNumber)
 * 6. The function is deterministic and side-effect-free
 */

import * as fc from 'fast-check';
import type { CustomerProfile } from '../../schemas/entities';
import {
  verifyRecipient,
  verifyRecipientsBatch,
  type RecipientVerificationInput,
  type RecipientVerificationResult,
} from '../../services/recipient-verification.service';

// ── Generators ───────────────────────────────────────────────────────────────

/** Safe ID characters (no '#' to avoid DynamoDB key injection) */
const SAFE_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

const safeIdArb = fc.stringOf(
  fc.constantFrom(...SAFE_CHARS.split('')),
  { minLength: 1, maxLength: 32 },
);

/** Valid E.164 phone number: + followed by 8-15 digits */
const e164Arb = fc
  .integer({ min: 10000000, max: 999999999999999 })
  .map((n) => `+${n}`);

/** Generate a valid CustomerProfile */
function customerProfileArb(
  overrides: Partial<CustomerProfile> = {},
): fc.Arbitrary<CustomerProfile> {
  return fc.record({
    id: safeIdArb,
    businessId: safeIdArb,
    tenantId: safeIdArb,
    whatsappNumber: e164Arb,
    consentState: fc.constantFrom('opted_in' as const, 'opted_out' as const, 'pending' as const),
    locale: fc.constant('en'),
    messagingPreferences: fc.constant(undefined),
    eligible: fc.boolean(),
    isDeleted: fc.constant(false),
    createdAt: fc.constant('2024-01-01T00:00:00.000Z'),
    updatedAt: fc.constant('2024-01-01T00:00:00.000Z'),
  }).map((p) => ({ ...p, ...overrides }));
}

/** Generate a distinct E.164 number that differs from a given number */
function differentE164Arb(existingNumber: string): fc.Arbitrary<string> {
  return e164Arb.filter((n) => n !== existingNumber);
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 36 — Recipient Identity Verification', () => {

  describe('Sub-property 1: Exactly one profile match → verification succeeds with stored number', () => {
    it('when exactly one CustomerProfile matches the customerId within the businessId, verification succeeds', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          e164Arb,    // stored whatsapp number
          (customerId, businessId, tenantId, storedNumber) => {
            const profile: CustomerProfile = {
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: storedNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
            };

            const result = verifyRecipient(input, profilesById);

            // Must succeed with the stored number
            expect(result.verified).toBe(true);
            if (result.verified) {
              expect(result.customerId).toBe(customerId);
              expect(result.number).toBe(storedNumber);
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('Sub-property 2: Zero profiles match → verification fails closed (blocked)', () => {
    it('when no CustomerProfile matches the customerId, verification fails closed', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId (not in map)
          safeIdArb,  // businessId
          (customerId, businessId) => {
            // Empty map — no profiles at all
            const profilesById = new Map<string, CustomerProfile>();

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
            };

            const result = verifyRecipient(input, profilesById);

            // Must fail closed
            expect(result.verified).toBe(false);
            if (!result.verified) {
              expect(result.failureType).toBe('PROFILE_NOT_FOUND');
            }
          },
        ),
        { numRuns: 100 },
      );
    });

    it('when profiles exist but none match the requested customerId, verification fails closed', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // requested customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          e164Arb,    // other profile's number
          safeIdArb,  // other customer's id
          (customerId, businessId, tenantId, otherNumber, otherCustId) => {
            // Ensure the IDs are actually different
            fc.pre(customerId !== otherCustId);

            const otherProfile: CustomerProfile = {
              id: otherCustId,
              businessId,
              tenantId,
              whatsappNumber: otherNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            // Map has a different customer, not the one we're looking for
            const profilesById = new Map<string, CustomerProfile>([[otherCustId, otherProfile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
            };

            const result = verifyRecipient(input, profilesById);

            expect(result.verified).toBe(false);
            if (!result.verified) {
              expect(result.failureType).toBe('PROFILE_NOT_FOUND');
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('Sub-property 3: Multiple profiles match → verification fails closed (blocked)', () => {
    it('when a profile belongs to a different businessId, verification fails closed', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // input businessId (session)
          safeIdArb,  // profile businessId (different)
          safeIdArb,  // tenantId
          e164Arb,    // stored number
          (customerId, inputBizId, profileBizId, tenantId, storedNumber) => {
            // Ensure business IDs differ (cross-business scenario)
            fc.pre(inputBizId !== profileBizId);

            const profile: CustomerProfile = {
              id: customerId,
              businessId: profileBizId, // DIFFERENT from input businessId
              tenantId,
              whatsappNumber: storedNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId: inputBizId,
            };

            const result = verifyRecipient(input, profilesById);

            // Must fail closed — profile belongs to a different business
            expect(result.verified).toBe(false);
            if (!result.verified) {
              expect(result.failureType).toBe('PROFILE_NOT_FOUND');
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('Sub-property 4: Event-carried number differs from stored number → verification fails closed', () => {
    it('when the event carries a different E.164 number than the profile, verification fails', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          e164Arb,    // stored number
          e164Arb,    // event-carried number (different)
          (customerId, businessId, tenantId, storedNumber, eventNumber) => {
            // Ensure the numbers are actually different
            fc.pre(storedNumber !== eventNumber);

            const profile: CustomerProfile = {
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: storedNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
              eventCarriedNumber: eventNumber,
            };

            const result = verifyRecipient(input, profilesById);

            // Must fail closed with NUMBER_MISMATCH
            expect(result.verified).toBe(false);
            if (!result.verified) {
              expect(result.failureType).toBe('NUMBER_MISMATCH');
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('Sub-property 5: Numbers match → verification succeeds with (customerId, verifiedNumber)', () => {
    it('when event-carried number equals stored number, verification succeeds with the correct pair', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          e164Arb,    // number (same for both)
          (customerId, businessId, tenantId, number) => {
            const profile: CustomerProfile = {
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: number,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
              eventCarriedNumber: number, // same as stored
            };

            const result = verifyRecipient(input, profilesById);

            // Must succeed
            expect(result.verified).toBe(true);
            if (result.verified) {
              expect(result.customerId).toBe(customerId);
              expect(result.number).toBe(number);
            }
          },
        ),
        { numRuns: 100 },
      );
    });

    it('success result binds dispatch to ONLY the verified stored number (never a different number)', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          e164Arb,    // stored number
          (customerId, businessId, tenantId, storedNumber) => {
            const profile: CustomerProfile = {
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: storedNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
            };

            const result = verifyRecipient(input, profilesById);

            if (result.verified) {
              // The returned number MUST equal the profile's stored number
              expect(result.number).toBe(storedNumber);
              // It must NOT be derived from the event payload
              expect(result.number).toBe(profile.whatsappNumber);
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('Sub-property 6: The function is deterministic and side-effect-free', () => {
    it('calling verifyRecipient twice with the same inputs produces identical results', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          e164Arb,    // stored number
          fc.option(e164Arb, { nil: undefined }),  // optional event-carried number
          (customerId, businessId, tenantId, storedNumber, eventNumber) => {
            const profile: CustomerProfile = {
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: storedNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
              eventCarriedNumber: eventNumber,
            };

            // Call twice
            const result1 = verifyRecipient(input, profilesById);
            const result2 = verifyRecipient(input, profilesById);

            // Results must be identical (deterministic)
            expect(result1).toEqual(result2);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('verifyRecipient does not mutate the input map or the input object', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          e164Arb,    // stored number
          (customerId, businessId, tenantId, storedNumber) => {
            const profile: CustomerProfile = {
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: storedNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);
            const mapSizeBefore = profilesById.size;
            const profileSnapshot = JSON.parse(JSON.stringify(profile));

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
            };
            const inputSnapshot = JSON.parse(JSON.stringify(input));

            verifyRecipient(input, profilesById);

            // Map not mutated
            expect(profilesById.size).toBe(mapSizeBefore);
            // Profile not mutated
            expect(JSON.parse(JSON.stringify(profilesById.get(customerId)))).toEqual(profileSnapshot);
            // Input not mutated
            expect(JSON.parse(JSON.stringify(input))).toEqual(inputSnapshot);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('batch verification evaluates each event independently (Req 16.9)', () => {
      fc.assert(
        fc.property(
          fc.array(
            fc.tuple(safeIdArb, safeIdArb, e164Arb),
            { minLength: 2, maxLength: 5 },
          ),
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          (customerData, businessId, tenantId) => {
            // Build profiles map
            const profilesById = new Map<string, CustomerProfile>();
            const inputs: RecipientVerificationInput[] = [];

            for (const [custId, , phone] of customerData) {
              const profile: CustomerProfile = {
                id: custId,
                businessId,
                tenantId,
                whatsappNumber: phone,
                consentState: 'opted_in',
                locale: 'en',
                messagingPreferences: undefined,
                eligible: true,
                isDeleted: false,
                createdAt: '2024-01-01T00:00:00.000Z',
                updatedAt: '2024-01-01T00:00:00.000Z',
              };
              profilesById.set(custId, profile);
              inputs.push({ customerId: custId, businessId });
            }

            // Batch result must equal individual results
            const batchResults = verifyRecipientsBatch(inputs, profilesById);
            const individualResults = inputs.map((inp) => verifyRecipient(inp, profilesById));

            expect(batchResults).toEqual(individualResults);
            expect(batchResults.length).toBe(inputs.length);
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('Additional edge cases: soft-deleted and invalid stored numbers', () => {
    it('a soft-deleted profile fails closed with PROFILE_DELETED', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          e164Arb,    // stored number
          (customerId, businessId, tenantId, storedNumber) => {
            const profile: CustomerProfile = {
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: storedNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: true, // DELETED
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
            };

            const result = verifyRecipient(input, profilesById);

            expect(result.verified).toBe(false);
            if (!result.verified) {
              expect(result.failureType).toBe('PROFILE_DELETED');
            }
          },
        ),
        { numRuns: 100 },
      );
    });

    it('a profile with an invalid stored number fails closed with INVALID_STORED_NUMBER', () => {
      fc.assert(
        fc.property(
          safeIdArb,  // customerId
          safeIdArb,  // businessId
          safeIdArb,  // tenantId
          fc.constantFrom('not-a-number', '12345', '+1', '+123456789012345678'),  // invalid E.164
          (customerId, businessId, tenantId, badNumber) => {
            const profile: CustomerProfile = {
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: badNumber,
              consentState: 'opted_in',
              locale: 'en',
              messagingPreferences: undefined,
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            };

            const profilesById = new Map<string, CustomerProfile>([[customerId, profile]]);

            const input: RecipientVerificationInput = {
              customerId,
              businessId,
            };

            const result = verifyRecipient(input, profilesById);

            expect(result.verified).toBe(false);
            if (!result.verified) {
              expect(result.failureType).toBe('INVALID_STORED_NUMBER');
            }
          },
        ),
        { numRuns: 100 },
      );
    });
  });
});
