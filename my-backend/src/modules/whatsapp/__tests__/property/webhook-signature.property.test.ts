// ============================================================================
// Property-Based Test — Webhook Signature Verification
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 26
//
// Validates: Requirements 8.5, 10.4, 10.5
//
// Property 26 (design.md): Webhook signature verification accepts iff the HMAC matches.
//
// For any payload and secret:
// - A correctly computed HMAC-SHA256 signature ALWAYS passes verification
// - An incorrect signature ALWAYS fails verification
// - Verification uses constant-time comparison (timingSafeEqual)
// - Different payloads produce different signatures (collision resistance)
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  computeOpenWASignature,
  verifyOpenWAWebhookSignature,
} from '../../../staff/services/staff-notify.service';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a non-empty payload string (simulating JSON webhook bodies). */
const payloadArb: fc.Arbitrary<string> = fc.string({ minLength: 1, maxLength: 2048 });

/** Generates a non-empty secret string (simulating webhook secrets). */
const secretArb: fc.Arbitrary<string> = fc.string({ minLength: 8, maxLength: 128 });

/** Generates a valid hex string of length 64 (SHA-256 output size). */
const validHexSignatureArb: fc.Arbitrary<string> = fc
  .array(fc.integer({ min: 0, max: 15 }), { minLength: 64, maxLength: 64 })
  .map((nums) => nums.map((n) => n.toString(16)).join(''));

/** Generates a string that is NOT a valid 64-character hex string. */
const invalidSignatureArb: fc.Arbitrary<string> = fc.oneof(
  // Too short
  fc.string({ minLength: 0, maxLength: 63 }),
  // Too long hex
  fc.array(fc.integer({ min: 0, max: 15 }), { minLength: 65, maxLength: 128 })
    .map((nums) => nums.map((n) => n.toString(16)).join('')),
  // Contains non-hex characters
  fc.string({ minLength: 64, maxLength: 64 }).filter((s) => !/^[0-9a-f]{64}$/.test(s)),
);

/**
 * Generates a pair of distinct payloads (guaranteed different).
 */
const distinctPayloadsArb: fc.Arbitrary<[string, string]> = fc
  .tuple(
    fc.string({ minLength: 1, maxLength: 1024 }),
    fc.string({ minLength: 1, maxLength: 1024 }),
  )
  .filter(([a, b]) => a !== b);

// ── Property 26 Tests ───────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 26: Webhook signature verification accepts iff the HMAC matches', () => {
  // ─────────────────────────────────────────────────────────────────────────
  // 1) Correct HMAC-SHA256 signature always passes verification
  // ─────────────────────────────────────────────────────────────────────────

  describe('**Validates: Requirements 10.4, 10.5** — Correct HMAC always passes', () => {
    test('verifyOpenWAWebhookSignature returns true when signature matches computed HMAC', () => {
      fc.assert(
        fc.property(payloadArb, secretArb, (payload, secret) => {
          const signature = computeOpenWASignature(payload, secret);
          const result = verifyOpenWAWebhookSignature(payload, signature, secret);
          expect(result).toBe(true);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('verification is symmetric: compute then verify always succeeds', () => {
      fc.assert(
        fc.property(
          payloadArb,
          secretArb,
          (payload, secret) => {
            // Compute signature for a payload
            const sig = computeOpenWASignature(payload, secret);
            // Verify with the SAME payload and secret must always pass
            expect(verifyOpenWAWebhookSignature(payload, sig, secret)).toBe(true);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2) Incorrect signature always fails verification
  // ─────────────────────────────────────────────────────────────────────────

  describe('**Validates: Requirements 8.5, 10.5** — Incorrect signature always fails', () => {
    test('wrong secret produces a different signature that fails verification', () => {
      fc.assert(
        fc.property(
          payloadArb,
          secretArb,
          secretArb.filter((s) => s.length >= 8),
          (payload, correctSecret, wrongSecret) => {
            // Skip if the two secrets happen to be equal
            fc.pre(correctSecret !== wrongSecret);

            const correctSig = computeOpenWASignature(payload, correctSecret);
            const wrongSig = computeOpenWASignature(payload, wrongSecret);

            // Verification with wrong signature fails
            expect(verifyOpenWAWebhookSignature(payload, wrongSig, correctSecret)).toBe(false);
            // And the signatures themselves are different
            expect(correctSig).not.toBe(wrongSig);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('tampered payload fails verification with original signature', () => {
      fc.assert(
        fc.property(
          distinctPayloadsArb,
          secretArb,
          ([originalPayload, tamperedPayload], secret) => {
            const signature = computeOpenWASignature(originalPayload, secret);
            // Verifying with a different payload must fail
            const result = verifyOpenWAWebhookSignature(tamperedPayload, signature, secret);
            expect(result).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('arbitrary non-matching hex signatures fail verification', () => {
      fc.assert(
        fc.property(
          payloadArb,
          secretArb,
          validHexSignatureArb,
          (payload, secret, randomSig) => {
            const correctSig = computeOpenWASignature(payload, secret);
            // Skip if random sig happens to match (astronomically unlikely but be safe)
            fc.pre(randomSig !== correctSig);

            const result = verifyOpenWAWebhookSignature(payload, randomSig, secret);
            expect(result).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('malformed signatures (non-hex, wrong length) fail verification gracefully', () => {
      fc.assert(
        fc.property(
          payloadArb,
          secretArb,
          invalidSignatureArb,
          (payload, secret, badSig) => {
            // Must not throw — returns false gracefully
            const result = verifyOpenWAWebhookSignature(payload, badSig, secret);
            expect(result).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3) Verification is constant-time (timingSafeEqual)
  // ─────────────────────────────────────────────────────────────────────────

  describe('**Validates: Requirements 10.5** — Constant-time verification (timingSafeEqual)', () => {
    test('verification uses timingSafeEqual: length mismatch returns false without throw', () => {
      fc.assert(
        fc.property(
          payloadArb,
          secretArb,
          (payload, secret) => {
            // Feed a signature that is not 64 hex chars (different buffer length)
            const shortSig = 'ab'.repeat(16); // 32 hex chars → 16 bytes (not 32)
            const result = verifyOpenWAWebhookSignature(payload, shortSig, secret);
            expect(result).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('verification handles empty signature gracefully', () => {
      fc.assert(
        fc.property(payloadArb, secretArb, (payload, secret) => {
          const result = verifyOpenWAWebhookSignature(payload, '', secret);
          expect(result).toBe(false);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('the implementation checks buffer lengths before timingSafeEqual to prevent length-oracle', () => {
      // timingSafeEqual throws on length mismatch — the implementation must
      // guard with a length check first. We verify this by passing signatures
      // of various incorrect byte-lengths and confirming false (not throw).
      fc.assert(
        fc.property(
          payloadArb,
          secretArb,
          fc.integer({ min: 1, max: 128 }).map((len) => 'a'.repeat(len)),
          (payload, secret, varLenSig) => {
            // Should never throw, always return false for wrong-length sigs
            expect(() => verifyOpenWAWebhookSignature(payload, varLenSig, secret)).not.toThrow();
            // Correct length is always 64 hex chars; if varLenSig isn't that, must be false
            const correctSig = computeOpenWASignature(payload, secret);
            if (varLenSig !== correctSig) {
              expect(verifyOpenWAWebhookSignature(payload, varLenSig, secret)).toBe(false);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4) Different payloads produce different signatures
  // ─────────────────────────────────────────────────────────────────────────

  describe('**Validates: Requirements 8.5, 10.4** — Different payloads produce different signatures', () => {
    test('distinct payloads with the same secret produce distinct signatures', () => {
      fc.assert(
        fc.property(
          distinctPayloadsArb,
          secretArb,
          ([payloadA, payloadB], secret) => {
            const sigA = computeOpenWASignature(payloadA, secret);
            const sigB = computeOpenWASignature(payloadB, secret);
            expect(sigA).not.toBe(sigB);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('same payload with distinct secrets produces distinct signatures', () => {
      fc.assert(
        fc.property(
          payloadArb,
          secretArb,
          secretArb,
          (payload, secretA, secretB) => {
            fc.pre(secretA !== secretB);
            const sigA = computeOpenWASignature(payload, secretA);
            const sigB = computeOpenWASignature(payload, secretB);
            expect(sigA).not.toBe(sigB);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('computeOpenWASignature output is always a 64-character lowercase hex string', () => {
      fc.assert(
        fc.property(payloadArb, secretArb, (payload, secret) => {
          const sig = computeOpenWASignature(payload, secret);
          expect(sig).toMatch(/^[0-9a-f]{64}$/);
        }),
        { numRuns: NUM_RUNS },
      );
    });

    test('computeOpenWASignature is deterministic: same inputs always yield same output', () => {
      fc.assert(
        fc.property(payloadArb, secretArb, (payload, secret) => {
          const sig1 = computeOpenWASignature(payload, secret);
          const sig2 = computeOpenWASignature(payload, secret);
          expect(sig1).toBe(sig2);
        }),
        { numRuns: NUM_RUNS },
      );
    });
  });
});
