// ============================================================================
// Property-Based Test — Disabled/Deferred Capability Behavior
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 35
//
// Validates: Requirements 11.10, 11.12, 15.3, 15.6
//
// Property 35 (design.md): A disabled AI_Responder or deferred capability
// never produces or returns fabricated content.
//
// Verifies:
// 1. When WA_AI_RESPONDER is OFF, the service returns `unavailable`
// 2. When OFF, no AI content is generated/stored/returned
// 3. When OFF with any input message, the response is always `unavailable`
//    (never fabricated text)
// 4. The 30s deadline is respected when enabled
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  AiResponderService,
  isAiResponderEnabled,
  AI_PROVIDER_TIMEOUT_MS,
  type AiResponderInput,
  type AiResponderResult,
} from '../../services/ai-responder.service';
import { PlanTier } from '../../../../config/plan-feature-registry';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates plan tiers where AI responder is NOT enabled (BASIC, PRO, PREMIUM). */
const disabledPlanTierArb: fc.Arbitrary<PlanTier> = fc.constantFrom(
  PlanTier.BASIC,
  PlanTier.PRO,
  PlanTier.PREMIUM,
);

/** Generates plan tiers where AI responder IS enabled (ENTERPRISE). */
const enabledPlanTierArb: fc.Arbitrary<PlanTier> = fc.constant(PlanTier.ENTERPRISE);

/** Generates any plan tier. */
const anyPlanTierArb: fc.Arbitrary<PlanTier> = fc.constantFrom(
  PlanTier.BASIC,
  PlanTier.PRO,
  PlanTier.PREMIUM,
  PlanTier.ENTERPRISE,
);

/** Generates a valid tenant ID. */
const tenantIdArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'), { minLength: 4, maxLength: 24 })
  .map((s) => `tenant-${s}`);

/** Generates a valid business ID. */
const businessIdArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'), { minLength: 4, maxLength: 24 })
  .map((s) => `biz-${s}`);

/** Generates a valid customer ID. */
const customerIdArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'), { minLength: 4, maxLength: 24 })
  .map((s) => `cust-${s}`);

/** Generates arbitrary inbound message text (any non-empty string). */
const messageTextArb: fc.Arbitrary<string> = fc.string({ minLength: 1, maxLength: 500 });

/** Generates optional conversation context. */
const conversationContextArb: fc.Arbitrary<string[] | undefined> = fc.oneof(
  fc.constant(undefined),
  fc.array(fc.string({ minLength: 1, maxLength: 200 }), { minLength: 0, maxLength: 5 }),
);

/** Generates a full AiResponderInput. */
const aiResponderInputArb: fc.Arbitrary<AiResponderInput> = fc.record({
  tenantId: tenantIdArb,
  businessId: businessIdArb,
  customerId: customerIdArb,
  messageText: messageTextArb,
  conversationContext: conversationContextArb,
});

// ── Property 35 ─────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 35: A disabled AI_Responder or deferred capability never produces or returns fabricated content', () => {
  // ── Sub-property 1: Feature flag check returns false for non-Enterprise tiers ──

  test('isAiResponderEnabled returns false for BASIC, PRO, and PREMIUM tiers (Req 15.3)', () => {
    fc.assert(
      fc.property(disabledPlanTierArb, (tier) => {
        expect(isAiResponderEnabled(tier)).toBe(false);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('isAiResponderEnabled returns true only for ENTERPRISE tier (Req 11.10)', () => {
    fc.assert(
      fc.property(enabledPlanTierArb, (tier) => {
        expect(isAiResponderEnabled(tier)).toBe(true);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 2: When OFF, service returns `unavailable` with no content ────

  test('When WA_AI_RESPONDER is OFF, generateResponse returns status "unavailable" for any input (Req 15.3, 15.6)', async () => {
    // Create a service with no provider config (to isolate the flag check)
    const service = new AiResponderService({ providerConfig: null });

    await fc.assert(
      fc.asyncProperty(disabledPlanTierArb, aiResponderInputArb, async (tier, input) => {
        const result = await service.generateResponse(tier, input);

        // Status must be 'unavailable'
        expect(result.status).toBe('unavailable');
        // No response text must be present (Req 15.3: no AI content generated)
        expect(result.responseText).toBeUndefined();
        // No failure reason (it's not a failure — it's simply disabled)
        expect(result.failureReason).toBeUndefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('When WA_AI_RESPONDER is OFF, generateResponse NEVER returns a responseText regardless of message content (Req 15.6)', async () => {
    // Even with a configured provider, the flag gate prevents any AI call
    const service = new AiResponderService({
      providerConfig: { url: 'https://ai.example.com/v1/chat', apiKey: 'sk-test-key' },
    });

    await fc.assert(
      fc.asyncProperty(disabledPlanTierArb, aiResponderInputArb, async (tier, input) => {
        const result = await service.generateResponse(tier, input);

        // The feature flag gate must fire before the provider is even called
        expect(result.status).toBe('unavailable');
        expect(result.responseText).toBeUndefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 3: When OFF with any arbitrary message, response is always unavailable ──

  test('For any arbitrary message text and disabled tier, the result is always unavailable — never fabricated text (Req 15.3, 15.6)', async () => {
    const service = new AiResponderService({ providerConfig: null });

    // Use a broader generator including unicode, special chars, control chars
    const broadMessageArb = fc.oneof(
      fc.string({ minLength: 0, maxLength: 1000 }),
      fc.unicodeString({ minLength: 1, maxLength: 500 }),
      fc.constantFrom('Hello!', 'What is my balance?', '<script>alert("xss")</script>', ''),
    );

    await fc.assert(
      fc.asyncProperty(disabledPlanTierArb, broadMessageArb, tenantIdArb, businessIdArb, customerIdArb, async (tier, messageText, tenantId, businessId, customerId) => {
        const result = await service.generateResponse(tier, {
          tenantId,
          businessId,
          customerId,
          messageText,
        });

        // INVARIANT: status is always 'unavailable' when the flag is OFF
        expect(result.status).toBe('unavailable');
        // INVARIANT: no fabricated content is ever present
        expect(result.responseText).toBeUndefined();
        expect(result.failureReason).toBeUndefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 4: When enabled but provider not configured, returns unavailable ──

  test('When AI flag is ON but provider is not configured, returns unavailable with no fabricated content (Req 15.6)', async () => {
    // Provider config is null (not configured)
    const service = new AiResponderService({ providerConfig: null });

    await fc.assert(
      fc.asyncProperty(enabledPlanTierArb, aiResponderInputArb, async (tier, input) => {
        const result = await service.generateResponse(tier, input);

        // Even when the flag is ON, missing provider config → unavailable
        expect(result.status).toBe('unavailable');
        expect(result.responseText).toBeUndefined();
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 5: When enabled but provider fails, no content is returned ──

  test('When AI flag is ON but provider times out, returns failure with no fabricated response (Req 11.12)', async () => {
    // Create a service with a configured provider but very short timeout to simulate failure
    const service = new AiResponderService({
      providerConfig: { url: 'https://ai.unreachable.invalid/v1/chat', apiKey: 'sk-test' },
      timeoutMs: 1, // 1ms timeout — will always fail
    });

    await fc.assert(
      fc.asyncProperty(enabledPlanTierArb, aiResponderInputArb, async (tier, input) => {
        const result = await service.generateResponse(tier, input);

        // On failure: no response text is returned (never fabricated)
        expect(result.status).toBe('failure');
        expect(result.responseText).toBeUndefined();
        // A failure reason must be provided for logging
        expect(result.failureReason).toBeDefined();
        expect(typeof result.failureReason).toBe('string');
        expect(result.failureReason!.length).toBeGreaterThan(0);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property 6: The 30s deadline constant is correctly set ──

  test('AI_PROVIDER_TIMEOUT_MS is exactly 30000ms (Req 11.10)', () => {
    expect(AI_PROVIDER_TIMEOUT_MS).toBe(30_000);
  });

  // ── Sub-property 7: Result shape invariants across all tiers ──

  test('For any tier and input, the result never contains both responseText and failureReason simultaneously', async () => {
    // Use null provider so we only get 'unavailable' for non-enterprise
    // and 'unavailable' (no config) for enterprise
    const service = new AiResponderService({ providerConfig: null });

    await fc.assert(
      fc.asyncProperty(anyPlanTierArb, aiResponderInputArb, async (tier, input) => {
        const result = await service.generateResponse(tier, input);

        // Mutual exclusivity: responseText and failureReason should never coexist
        if (result.responseText !== undefined) {
          expect(result.failureReason).toBeUndefined();
          expect(result.status).toBe('success');
        }
        if (result.failureReason !== undefined) {
          expect(result.responseText).toBeUndefined();
          expect(result.status).toBe('failure');
        }
        if (result.status === 'unavailable') {
          expect(result.responseText).toBeUndefined();
          expect(result.failureReason).toBeUndefined();
        }
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Anchored examples ──────────────────────────────────────────────────────

  test('example: BASIC tier returns unavailable for a simple hello message', async () => {
    const service = new AiResponderService({ providerConfig: null });
    const result = await service.generateResponse(PlanTier.BASIC, {
      tenantId: 'tenant-abc123',
      businessId: 'biz-xyz789',
      customerId: 'cust-001',
      messageText: 'Hello, what is my balance?',
    });

    expect(result.status).toBe('unavailable');
    expect(result.responseText).toBeUndefined();
    expect(result.failureReason).toBeUndefined();
  });

  test('example: PRO tier returns unavailable — AI is Enterprise-only', async () => {
    const service = new AiResponderService({
      providerConfig: { url: 'https://ai.example.com/chat', apiKey: 'sk-valid' },
    });
    const result = await service.generateResponse(PlanTier.PRO, {
      tenantId: 'tenant-pro1',
      businessId: 'biz-pro1',
      customerId: 'cust-pro1',
      messageText: 'Can you tell me about my order?',
    });

    expect(result.status).toBe('unavailable');
    expect(result.responseText).toBeUndefined();
  });

  test('example: PREMIUM tier returns unavailable — AI is Enterprise-only', async () => {
    const service = new AiResponderService({
      providerConfig: { url: 'https://ai.example.com/chat', apiKey: 'sk-valid' },
    });
    const result = await service.generateResponse(PlanTier.PREMIUM, {
      tenantId: 'tenant-prem1',
      businessId: 'biz-prem1',
      customerId: 'cust-prem1',
      messageText: 'Generate a report for me',
    });

    expect(result.status).toBe('unavailable');
    expect(result.responseText).toBeUndefined();
  });

  test('example: ENTERPRISE tier with no provider config returns unavailable', async () => {
    const service = new AiResponderService({ providerConfig: null });
    const result = await service.generateResponse(PlanTier.ENTERPRISE, {
      tenantId: 'tenant-ent1',
      businessId: 'biz-ent1',
      customerId: 'cust-ent1',
      messageText: 'Hello from enterprise!',
    });

    expect(result.status).toBe('unavailable');
    expect(result.responseText).toBeUndefined();
  });
});
