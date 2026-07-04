// ============================================================================
// Property-Based Test — Credential Scoping
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 32
//
// **Validates: Requirements 12.5, 12.6, 13.7**
//
// Property 32 (design.md): Dispatch uses only the sending business's OpenWA
// credentials, and missing credentials block dispatch.
//
// Verified properties:
// 1) Dispatch resolves credentials specific to the sending business's tenantId
//    — the configResolver is called with exactly the input's tenantId.
// 2) Missing/null credentials block dispatch: no message sent, pre-dispatch
//    state retained (credentialUnavailable = true, success = false).
// 3) Credentials from one business are never used for another — each dispatch
//    call uses only the credentials resolved for its own tenantId.
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  WhatsAppDispatchService,
  DispatchMessageInput,
  DispatchResult,
  toOpenWAChatId,
} from '../../services/whatsapp-dispatch.service';
import type { OpenWAGatewayConfig } from '../../../staff/services/staff-notify.service';

// ── Generators ──────────────────────────────────────────────────────────────

/** Safe characters for IDs (no # injection). */
const SAFE_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

const safeIdArb = fc.stringOf(
  fc.constantFrom(...SAFE_CHARS.split('')),
  { minLength: 1, maxLength: 32 },
);

/** Valid E.164 phone number. */
const e164Arb = fc
  .integer({ min: 10000000, max: 999999999999999 })
  .map((n) => `+${n}`);

/** UUID-like session ID for OpenWA. */
const sessionIdArb = fc.uuid();

/** URL-safe base URL. */
const baseUrlArb = fc.constantFrom(
  'https://openwa-1.example.com',
  'https://openwa-2.example.com',
  'https://gw.tenant-a.io',
  'https://gw.tenant-b.io',
);

/** Arbitrary API key. */
const apiKeyArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'.split('')),
  { minLength: 16, maxLength: 64 },
);

/** Arbitrary webhook secret. */
const webhookSecretArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'.split('')),
  { minLength: 16, maxLength: 64 },
);

/** Generates a full OpenWAGatewayConfig. */
const gatewayConfigArb: fc.Arbitrary<OpenWAGatewayConfig> = fc.record({
  baseUrl: baseUrlArb,
  apiKey: apiKeyArb,
  webhookSecret: webhookSecretArb,
  sessionId: sessionIdArb,
});

/** Generates a DispatchMessageInput (excluding tenantId, set by caller). */
function buildDispatchInput(tenantId: string, businessId: string, phone: string): DispatchMessageInput {
  return {
    tenantId,
    businessId,
    to: phone,
    templateName: 'invoice_generated',
    params: { body: 'Your invoice is ready.' },
  };
}

// ── Tests ───────────────────────────────────────────────────────────────────

const NUM_RUNS = 100;

describe('Feature: openwa-whatsapp-automation, Property 32: Dispatch uses only the sending business\'s OpenWA credentials, and missing credentials block dispatch', () => {
  // ── 1) Dispatch resolves credentials specific to the sending business's tenantId ──

  describe('credential resolution is tenant-scoped', () => {
    test('configResolver is called with exactly the input tenantId', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          e164Arb,   // phone
          gatewayConfigArb,
          async (tenantId, businessId, phone, config) => {
            const resolverCalls: string[] = [];

            // Mock fetch to succeed
            const mockFetch = jest.fn().mockResolvedValue({
              ok: true,
              json: async () => ({ messageId: 'msg-123', timestamp: 1234567890 }),
            });
            global.fetch = mockFetch as unknown as typeof fetch;

            const resolver = async (tid: string): Promise<OpenWAGatewayConfig | null> => {
              resolverCalls.push(tid);
              return config;
            };

            const service = new WhatsAppDispatchService({ configResolver: resolver });
            const input = buildDispatchInput(tenantId, businessId, phone);

            await service.sendMessage(input);

            // The resolver MUST have been called exactly once, with the input's tenantId
            expect(resolverCalls).toHaveLength(1);
            expect(resolverCalls[0]).toBe(tenantId);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('the resolved credentials (sessionId, apiKey, baseUrl) are used in the outbound request', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          e164Arb,   // phone
          gatewayConfigArb,
          async (tenantId, businessId, phone, config) => {
            let capturedUrl = '';
            let capturedHeaders: Record<string, string> = {};

            const mockFetch = jest.fn().mockImplementation(async (url: string, opts: RequestInit) => {
              capturedUrl = url;
              capturedHeaders = (opts.headers ?? {}) as Record<string, string>;
              return {
                ok: true,
                json: async () => ({ messageId: 'msg-abc', timestamp: 1234567890 }),
              };
            });
            global.fetch = mockFetch as unknown as typeof fetch;

            const resolver = async (_tid: string): Promise<OpenWAGatewayConfig | null> => config;
            const service = new WhatsAppDispatchService({ configResolver: resolver });
            const input = buildDispatchInput(tenantId, businessId, phone);

            await service.sendMessage(input);

            // The request URL MUST contain the resolved config's baseUrl and sessionId
            expect(capturedUrl).toContain(config.baseUrl);
            expect(capturedUrl).toContain(config.sessionId);
            // The API key header MUST match the resolved config
            expect(capturedHeaders['X-API-Key']).toBe(config.apiKey);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 2) Missing/null credentials block dispatch ────────────────────────────

  describe('missing credentials block dispatch and retain pre-dispatch state', () => {
    test('null credentials → success=false, credentialUnavailable=true, no fetch called', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          e164Arb,   // phone
          async (tenantId, businessId, phone) => {
            const mockFetch = jest.fn();
            global.fetch = mockFetch as unknown as typeof fetch;

            // Resolver returns null — credentials unavailable
            const resolver = async (_tid: string): Promise<OpenWAGatewayConfig | null> => null;
            const service = new WhatsAppDispatchService({ configResolver: resolver });
            const input = buildDispatchInput(tenantId, businessId, phone);

            const result: DispatchResult = await service.sendMessage(input);

            // Dispatch MUST be blocked
            expect(result.success).toBe(false);
            expect(result.credentialUnavailable).toBe(true);
            expect(result.errorCode).toBe('CREDENTIALS_UNAVAILABLE');

            // No outbound request was made — message retained in pre-dispatch state
            expect(mockFetch).not.toHaveBeenCalled();
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('resolver throwing an error → same as missing credentials (no dispatch)', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          e164Arb,   // phone
          async (tenantId, businessId, phone) => {
            const mockFetch = jest.fn();
            global.fetch = mockFetch as unknown as typeof fetch;

            // Resolver throws — simulates secret store being unavailable (Req 13.7)
            const resolver = async (_tid: string): Promise<OpenWAGatewayConfig | null> => {
              throw new Error('Secret store connection timeout');
            };
            const service = new WhatsAppDispatchService({ configResolver: resolver });
            const input = buildDispatchInput(tenantId, businessId, phone);

            const result: DispatchResult = await service.sendMessage(input);

            // Dispatch MUST be blocked — retained in pre-dispatch state
            expect(result.success).toBe(false);
            expect(result.credentialUnavailable).toBe(true);

            // No outbound request was made
            expect(mockFetch).not.toHaveBeenCalled();
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('no providerMessageId is ever returned when credentials are missing', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb,
          safeIdArb,
          e164Arb,
          async (tenantId, businessId, phone) => {
            global.fetch = jest.fn() as unknown as typeof fetch;

            const resolver = async (_tid: string): Promise<OpenWAGatewayConfig | null> => null;
            const service = new WhatsAppDispatchService({ configResolver: resolver });
            const input = buildDispatchInput(tenantId, businessId, phone);

            const result = await service.sendMessage(input);

            // No provider message ID should be assigned — message not dispatched
            expect(result.providerMessageId).toBeUndefined();
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 3) Credentials from one business are never used for another ───────────

  describe('cross-business credential isolation', () => {
    test('each dispatch uses only its own tenantId credentials, never another tenant\'s', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId A
          safeIdArb, // tenantId B (different)
          safeIdArb, // businessId A
          safeIdArb, // businessId B
          e164Arb,   // phone A
          e164Arb,   // phone B
          gatewayConfigArb, // config A
          gatewayConfigArb, // config B
          async (tenantA, tenantB, bizA, bizB, phoneA, phoneB, configA, configB) => {
            // Skip the degenerate case where tenants happen to match
            fc.pre(tenantA !== tenantB);

            const resolvedConfigs: Map<string, OpenWAGatewayConfig> = new Map();
            resolvedConfigs.set(tenantA, configA);
            resolvedConfigs.set(tenantB, configB);

            const capturedRequests: Array<{ tenantId: string; url: string; apiKey: string }> = [];

            const mockFetch = jest.fn().mockImplementation(async (url: string, opts: RequestInit) => {
              const headers = (opts.headers ?? {}) as Record<string, string>;
              capturedRequests.push({
                tenantId: '', // filled post-call
                url,
                apiKey: headers['X-API-Key'] ?? '',
              });
              return {
                ok: true,
                json: async () => ({ messageId: 'msg-x', timestamp: 123 }),
              };
            });
            global.fetch = mockFetch as unknown as typeof fetch;

            const resolver = async (tid: string): Promise<OpenWAGatewayConfig | null> => {
              return resolvedConfigs.get(tid) ?? null;
            };

            const service = new WhatsAppDispatchService({ configResolver: resolver });

            // Dispatch for tenant A
            capturedRequests.length = 0;
            await service.sendMessage(buildDispatchInput(tenantA, bizA, phoneA));
            const reqA = capturedRequests[0];

            // Dispatch for tenant B
            capturedRequests.length = 0;
            await service.sendMessage(buildDispatchInput(tenantB, bizB, phoneB));
            const reqB = capturedRequests[0];

            // CORE PROPERTY: tenant A's request uses configA's credentials
            expect(reqA.url).toContain(configA.baseUrl);
            expect(reqA.url).toContain(configA.sessionId);
            expect(reqA.apiKey).toBe(configA.apiKey);

            // CORE PROPERTY: tenant B's request uses configB's credentials
            expect(reqB.url).toContain(configB.baseUrl);
            expect(reqB.url).toContain(configB.sessionId);
            expect(reqB.apiKey).toBe(configB.apiKey);

            // CROSS-CHECK: A never uses B's credentials, and vice versa
            if (configA.apiKey !== configB.apiKey) {
              expect(reqA.apiKey).not.toBe(configB.apiKey);
              expect(reqB.apiKey).not.toBe(configA.apiKey);
            }
            if (configA.sessionId !== configB.sessionId) {
              expect(reqA.url).not.toContain(configB.sessionId);
              expect(reqB.url).not.toContain(configA.sessionId);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('a tenant without credentials is blocked while other tenants dispatch normally', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantWithCreds
          safeIdArb, // tenantWithoutCreds
          safeIdArb, // businessId
          e164Arb,   // phone
          gatewayConfigArb,
          async (tenantWithCreds, tenantWithoutCreds, bizId, phone, config) => {
            fc.pre(tenantWithCreds !== tenantWithoutCreds);

            const mockFetch = jest.fn().mockResolvedValue({
              ok: true,
              json: async () => ({ messageId: 'msg-ok', timestamp: 123 }),
            });
            global.fetch = mockFetch as unknown as typeof fetch;

            const resolver = async (tid: string): Promise<OpenWAGatewayConfig | null> => {
              if (tid === tenantWithCreds) return config;
              return null; // Missing for the other tenant
            };

            const service = new WhatsAppDispatchService({ configResolver: resolver });

            // Dispatch for tenant WITH credentials → succeeds
            const resultA = await service.sendMessage(
              buildDispatchInput(tenantWithCreds, bizId, phone),
            );
            expect(resultA.success).toBe(true);

            // Dispatch for tenant WITHOUT credentials → blocked
            const resultB = await service.sendMessage(
              buildDispatchInput(tenantWithoutCreds, bizId, phone),
            );
            expect(resultB.success).toBe(false);
            expect(resultB.credentialUnavailable).toBe(true);

            // Fetch was called once (only for the tenant with credentials)
            expect(mockFetch).toHaveBeenCalledTimes(1);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('resolver is never called with a tenantId different from the input', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb,
          safeIdArb,
          e164Arb,
          gatewayConfigArb,
          async (tenantId, businessId, phone, config) => {
            const resolverArguments: string[] = [];

            const mockFetch = jest.fn().mockResolvedValue({
              ok: true,
              json: async () => ({ messageId: 'msg-z', timestamp: 123 }),
            });
            global.fetch = mockFetch as unknown as typeof fetch;

            const resolver = async (tid: string): Promise<OpenWAGatewayConfig | null> => {
              resolverArguments.push(tid);
              return config;
            };

            const service = new WhatsAppDispatchService({ configResolver: resolver });
            await service.sendMessage(buildDispatchInput(tenantId, businessId, phone));

            // CORE PROPERTY: resolver was only ever called with our tenantId
            expect(resolverArguments.length).toBe(1);
            expect(resolverArguments.every((t) => t === tenantId)).toBe(true);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });
});
