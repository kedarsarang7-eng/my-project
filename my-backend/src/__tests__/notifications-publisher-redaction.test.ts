// ============================================================================
// Unit Tests — UNS Event_Bus Payload Redaction Boundary (REQ 12.8, Task 16.4)
// ============================================================================
// Covers:
//   - Publishes that embed a raw credit card / PAN / Aadhaar / Bearer token
//     / AWS access key are REJECTED at the bus boundary BEFORE SNS is touched.
//   - The rejection throws an `EventContractValidationError` whose `issues`
//     name the offending field path AND identify the matched pattern via
//     `keyword` (so caller tooling can branch on the structured taxonomy).
//   - Clean payloads still publish successfully (no regression of the
//     happy path).
//   - publishBatch reports redaction violations per-entry with
//     `code: 'validation_error'` and structured `issues`.
//   - The redaction-validator module's public surface (called directly,
//     bypassing the publisher) has the same throwing semantics.
// ============================================================================

// ── Mock SNS so no AWS call is ever made ────────────────────────────────────
const mockSnsSend = jest.fn();

jest.mock('@aws-sdk/client-sns', () => ({
    SNSClient: jest.fn().mockImplementation(() => ({ send: mockSnsSend })),
    PublishCommand: jest.fn().mockImplementation((input: unknown) => ({
        input,
        _type: 'Publish',
    })),
}));

// Mock the logger so test output stays clean.
const mockLoggerWarn = jest.fn();
const mockLoggerInfo = jest.fn();
const mockLoggerError = jest.fn();
const mockLoggerDebug = jest.fn();
jest.mock('../utils/logger', () => ({
    logger: {
        info: (...args: unknown[]) => mockLoggerInfo(...args),
        warn: (...args: unknown[]) => mockLoggerWarn(...args),
        error: (...args: unknown[]) => mockLoggerError(...args),
        debug: (...args: unknown[]) => mockLoggerDebug(...args),
    },
}));

// ── Required env vars for publisher ─────────────────────────────────────────
process.env.UNS_SNS_TOPIC_ARN =
    'arn:aws:sns:ap-south-1:000000000000:uns-events-test';

// ── Imports after mocks ─────────────────────────────────────────────────────
import {
    EventContractValidationError,
    publishBatch,
    publishEvent,
    tryValidatePayloadRedaction,
    validatePayloadRedaction,
    _setSharedRateLimiterForTests,
} from '../notifications/event-bus';
import { _setSnsClientForTests } from '../notifications/event-bus/publisher';
import type { EventContract, Recipient } from '../notifications/event-bus';

// ============================================================================
// Helpers
// ============================================================================

const VALID_RECIPIENT: Recipient = {
    user_id: 'user-1',
    role: 'admin',
};

let eventCounter = 0;

/** Build a known-valid Event_Contract envelope. */
function buildEvent(overrides: Partial<EventContract> = {}): EventContract {
    eventCounter++;
    // Use distinct UUIDs per call so a retry of a single test does not
    // collide with a previous publish in the rate-limiter bucket.
    const id = `1111111${(eventCounter % 10).toString()}-2222-4333-8444-555555555555`;
    return {
        id,
        event_name: 'billing.invoice.created',
        category: 'billing',
        sub_category: 'invoice',
        priority: 'normal',
        actor_id: 'actor-1',
        target_id: 'invoice-1',
        recipients: [VALID_RECIPIENT],
        payload: { invoiceId: 'invoice-1' },
        channels: ['in_app'],
        source_module: 'my-backend/src/__tests__/redaction-test.ts',
        source_app: 'dukanx_backend',
        created_at: new Date().toISOString(),
        dedup_key: `dedup-${id}`,
        ...overrides,
    };
}

// ============================================================================
// Tests
// ============================================================================

describe('UNS Event_Bus — payload redaction boundary (REQ 12.8)', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        mockSnsSend.mockResolvedValue({ MessageId: 'sns-msg-id' });
        // Reset rate limiter between tests so a single producer in a test
        // bucket does not bleed across tests.
        _setSharedRateLimiterForTests(null);
        _setSnsClientForTests(null);
    });

    afterEach(() => {
        _setSharedRateLimiterForTests(null);
        _setSnsClientForTests(null);
    });

    // ------------------------------------------------------------------
    // publishEvent — single-publish rejection paths
    // ------------------------------------------------------------------

    describe('publishEvent — rejection on raw sensitive values', () => {
        test('rejects a payload containing a raw Luhn-valid credit card', async () => {
            const event = buildEvent({
                payload: { card: '4111111111111111' },
            });
            await expect(publishEvent(event)).rejects.toBeInstanceOf(
                EventContractValidationError,
            );
            // Bus boundary MUST run BEFORE SNS publish — no AWS call.
            expect(mockSnsSend).not.toHaveBeenCalled();
        });

        test('rejection error names the offending field path and pattern', async () => {
            const event = buildEvent({
                payload: { customer: { card: '4111111111111111' } },
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                expect(err).toBeInstanceOf(EventContractValidationError);
                const e = err as EventContractValidationError;
                expect(e.issues.length).toBeGreaterThan(0);
                const issue = e.issues[0];
                expect(issue.field).toBe('payload.customer.card');
                expect(issue.keyword).toBe('credit_card');
                // Message must NOT echo the raw card; only last-4 hint is OK.
                expect(issue.message).not.toContain('4111111111111111');
                expect(issue.message).toContain('1111');
            }
        });

        test('rejects a payload containing a raw PAN', async () => {
            const event = buildEvent({
                payload: { kyc: { pan: 'ABCDE1234F' } },
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                expect(err).toBeInstanceOf(EventContractValidationError);
                const e = err as EventContractValidationError;
                expect(e.issues[0].field).toBe('payload.kyc.pan');
                expect(e.issues[0].keyword).toBe('pan_india');
                // No raw PAN in the rejection message.
                expect(e.issues[0].message).not.toContain('ABCDE1234F');
            }
            expect(mockSnsSend).not.toHaveBeenCalled();
        });

        test('rejects a payload containing a raw Aadhaar', async () => {
            const event = buildEvent({
                payload: { aadhaar: '1234 1234 1235' },
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                expect(err).toBeInstanceOf(EventContractValidationError);
                const e = err as EventContractValidationError;
                expect(e.issues[0].field).toBe('payload.aadhaar');
                expect(e.issues[0].keyword).toBe('aadhaar');
            }
            expect(mockSnsSend).not.toHaveBeenCalled();
        });

        test('rejects a payload containing a raw Bearer token', async () => {
            const event = buildEvent({
                payload: {
                    note: 'Authorization: Bearer abcdef0123456789xyz',
                },
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                expect(err).toBeInstanceOf(EventContractValidationError);
                const e = err as EventContractValidationError;
                expect(e.issues[0].field).toBe('payload.note');
                expect(e.issues[0].keyword).toBe('bearer_token');
            }
            expect(mockSnsSend).not.toHaveBeenCalled();
        });

        test('rejects a payload containing a raw AWS access key', async () => {
            const event = buildEvent({
                payload: { creds: 'AKIAIOSFODNN7EXAMPLE' },
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                expect(err).toBeInstanceOf(EventContractValidationError);
                const e = err as EventContractValidationError;
                expect(e.issues[0].field).toBe('payload.creds');
                expect(e.issues[0].keyword).toBe('aws_access_key');
            }
            expect(mockSnsSend).not.toHaveBeenCalled();
        });

        test('rejects a payload with a sensitive-named field carrying any value', async () => {
            const event = buildEvent({
                payload: { token: 'short-but-nonempty' },
            });
            await expect(publishEvent(event)).rejects.toBeInstanceOf(
                EventContractValidationError,
            );
            expect(mockSnsSend).not.toHaveBeenCalled();
        });

        test('reports every offending field in the issues array', async () => {
            // Multiple violations — bus rejection lists them all so the
            // producer can fix them in one round trip.
            const event = buildEvent({
                payload: {
                    customer: { pan: 'ABCDE1234F' },
                    payment: { card: '4111111111111111' },
                },
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                const e = err as EventContractValidationError;
                expect(e.issues.length).toBe(2);
                const fields = e.issues.map((i) => i.field).sort();
                expect(fields).toEqual([
                    'payload.customer.pan',
                    'payload.payment.card',
                ]);
            }
        });

        test('rejects a payload that contains a card inside an array element', async () => {
            const event = buildEvent({
                payload: {
                    cards: [
                        { number: '4111111111111111', expires: '12/30' },
                    ],
                },
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                const e = err as EventContractValidationError;
                expect(e.issues[0].field).toBe(
                    'payload.cards[0].number',
                );
                expect(e.issues[0].keyword).toBe('credit_card');
            }
        });
    });

    // ------------------------------------------------------------------
    // publishEvent — happy path (no regression)
    // ------------------------------------------------------------------

    describe('publishEvent — happy path with redacted references', () => {
        test('publishes a payload that already contains redacted references', async () => {
            const event = buildEvent({
                payload: {
                    cardLast4: '****1111',
                    panLast4: '****234F',
                    aadhaarLast4: '****1235',
                },
            });
            const ack = await publishEvent(event);
            expect(ack.messageId).toBe('sns-msg-id');
            expect(mockSnsSend).toHaveBeenCalledTimes(1);
        });

        test('publishes a regular non-sensitive payload', async () => {
            const event = buildEvent({
                payload: {
                    customerName: 'Alice',
                    invoiceNo: 'INV-001',
                    amount: '500.00',
                },
            });
            const ack = await publishEvent(event);
            expect(ack.messageId).toBe('sns-msg-id');
            expect(mockSnsSend).toHaveBeenCalledTimes(1);
        });
    });

    // ------------------------------------------------------------------
    // publishBatch — per-entry rejection
    // ------------------------------------------------------------------

    describe('publishBatch — per-entry redaction rejections', () => {
        test('clean entries publish, dirty entries are reported as failed', async () => {
            const clean = buildEvent({
                payload: { invoiceNo: 'INV-1' },
            });
            const dirty = buildEvent({
                payload: { card: '4111111111111111' },
            });

            const result = await publishBatch([clean, dirty]);

            expect(result.messageIds).toHaveLength(1);
            expect(result.failed).toHaveLength(1);
            expect(result.failed[0]).toMatchObject({
                index: 1,
                eventId: dirty.id,
                code: 'validation_error',
                message: expect.stringContaining('redaction'),
            });
            expect(result.failed[0].issues?.[0].field).toBe('payload.card');
            expect(result.failed[0].issues?.[0].keyword).toBe('credit_card');
        });

        test('SNS is called once per clean entry, never for dirty ones', async () => {
            const clean1 = buildEvent({ payload: { ok: 1 } });
            const clean2 = buildEvent({ payload: { ok: 2 } });
            const dirty = buildEvent({
                payload: { pan: 'ABCDE1234F' },
            });

            const result = await publishBatch([clean1, dirty, clean2]);

            expect(result.messageIds).toHaveLength(2);
            expect(result.failed).toHaveLength(1);
            expect(mockSnsSend).toHaveBeenCalledTimes(2);
        });
    });

    // ------------------------------------------------------------------
    // validatePayloadRedaction (direct surface)
    // ------------------------------------------------------------------

    describe('validatePayloadRedaction — direct surface', () => {
        test('throws on a forbidden value', () => {
            const event = buildEvent({
                payload: { card: '4111111111111111' },
            });
            expect(() => validatePayloadRedaction(event)).toThrow(
                EventContractValidationError,
            );
        });

        test('returns the same event on a clean payload', () => {
            const event = buildEvent({
                payload: { invoiceNo: 'INV-1' },
            });
            expect(validatePayloadRedaction(event)).toBe(event);
        });

        test('tryValidatePayloadRedaction returns ok on clean payload', () => {
            const event = buildEvent({ payload: { ok: true } });
            expect(tryValidatePayloadRedaction(event)).toEqual({ ok: true });
        });

        test('tryValidatePayloadRedaction returns issues on dirty payload', () => {
            const event = buildEvent({
                payload: { pan: 'ABCDE1234F' },
            });
            const result = tryValidatePayloadRedaction(event);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                expect(result.issues[0].field).toBe('payload.pan');
                expect(result.issues[0].keyword).toBe('pan_india');
            }
        });
    });

    // ------------------------------------------------------------------
    // Defense-in-depth scope — recipient.target_id and target_id
    // ------------------------------------------------------------------

    describe('redaction validator — covers target_id and recipient slots', () => {
        test('rejects a publish with a raw card embedded in target_id', async () => {
            const event = buildEvent({
                target_id: '4111111111111111',
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                const e = err as EventContractValidationError;
                expect(e.issues[0].field).toBe('target_id');
                expect(e.issues[0].keyword).toBe('credit_card');
            }
            expect(mockSnsSend).not.toHaveBeenCalled();
        });

        test('rejects a publish with a raw PAN embedded in recipient.target_id', async () => {
            const event = buildEvent({
                recipients: [
                    { user_id: 'user-1', role: 'admin', target_id: 'ABCDE1234F' },
                ],
            });
            try {
                await publishEvent(event);
                fail('expected EventContractValidationError');
            } catch (err) {
                const e = err as EventContractValidationError;
                expect(e.issues[0].field).toBe('recipients[0].target_id');
                expect(e.issues[0].keyword).toBe('pan_india');
            }
            expect(mockSnsSend).not.toHaveBeenCalled();
        });
    });
});
