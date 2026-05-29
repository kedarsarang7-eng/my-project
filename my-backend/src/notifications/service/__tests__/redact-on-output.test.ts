// ============================================================================
// UNS — Defense-in-depth redaction at Notification_Service.createNotification
// (Task 16.4, REQ 12.8)
// ============================================================================
// Validates: REQ 12.8 — payloads MUST NOT include secret values, full PAN,
// or full government-issued identifiers; only redacted references.
//
// The Event_Bus boundary REJECTS publishes that embed raw sensitive
// values (covered by `notifications-publisher-redaction.test.ts`).
// `Notification_Service.createNotification` is the second line of
// defense: it is reachable from in-process callers that did not go
// through the bus (legacy producers, internal Lambdas, test seeds), so
// it runs the same redactor over the payload AFTER sanitization (16.2)
// and BEFORE persistence.
//
// What this test pins:
//
//   1. The persisted Notification record never carries a raw card / PAN
//      / Aadhaar / Bearer token / AWS access key / sensitive-named
//      field, even when the caller bypasses the bus.
//   2. The redaction runs AFTER sanitization, so a payload that
//      contains both `<script>` markup and a raw card has both the
//      markup stripped and the card replaced.
//   3. Caller's input.payload is not mutated.
//   4. Clean payloads pass through with their non-sensitive content
//      intact (no regression).
// ============================================================================

import { describe, expect, jest, test } from '@jest/globals';

// ---- Mocks ---------------------------------------------------------------
// Mock the store so we can capture what would have been persisted
// without spinning up DynamoDB.

const mockAppendAuditLog =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockCreateNotificationRecord =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockGetNotification =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockListByUserCategory =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockFindByDedupKey =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockGetUserPreference =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockUpsertUserPreference =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();

jest.mock('../../store', () => {
    const actual = jest.requireActual('../../store') as Record<
        string,
        unknown
    >;
    return {
        ...actual,
        appendAuditLog: (...args: unknown[]) => mockAppendAuditLog(...args),
        createNotification: (...args: unknown[]) =>
            mockCreateNotificationRecord(...args),
        getNotification: (...args: unknown[]) => mockGetNotification(...args),
        listByUserCategory: (...args: unknown[]) =>
            mockListByUserCategory(...args),
        findByDedupKey: (...args: unknown[]) => mockFindByDedupKey(...args),
        getUserPreference: (...args: unknown[]) =>
            mockGetUserPreference(...args),
        upsertUserPreference: (...args: unknown[]) =>
            mockUpsertUserPreference(...args),
    };
});

// Import AFTER the mocks are wired.
import {
    NotificationService,
    type CreateNotificationCaller,
    type CreateNotificationInput,
} from '../index';
import type { NotificationRecord } from '../../store/types';

// ---- Helpers -------------------------------------------------------------

function adminCaller(): CreateNotificationCaller {
    return { user_id: 'admin-1', role: 'admin' };
}

function validInput(
    overrides: Partial<CreateNotificationInput> = {},
): CreateNotificationInput {
    return {
        event_name: 'billing.invoice.created',
        category: 'billing',
        priority: 'normal',
        actor_id: 'admin-1',
        recipients: [
            {
                user_id: 'recip-1',
                role: 'cashier',
                channels: ['in_app'],
            },
        ],
        payload: { invoice_id: 'inv-1' },
        channels: ['in_app'],
        source_module: 'billing',
        source_app: 'dukanx_desktop',
        ...overrides,
    };
}

/** Pull the persisted NotificationRecord out of the mocked store call. */
function persistedRecord(): NotificationRecord {
    expect(mockCreateNotificationRecord.mock.calls.length).toBeGreaterThan(0);
    const call = mockCreateNotificationRecord.mock.calls[0];
    return call[0] as NotificationRecord;
}

beforeEach(() => {
    jest.clearAllMocks();
    mockAppendAuditLog.mockResolvedValue(undefined);
    mockCreateNotificationRecord.mockResolvedValue(undefined);
});

// ============================================================================
// Tests
// ============================================================================

describe('Notification_Service.createNotification — defense-in-depth redaction (REQ 12.8)', () => {
    test('redacts a raw credit card before persistence', async () => {
        const service = new NotificationService();
        const input = validInput({
            payload: { card: '4111111111111111' },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        expect(record.payload.card).toBe('****1111');
        // Raw value MUST NOT appear anywhere in the persisted record.
        expect(JSON.stringify(record.payload)).not.toContain(
            '4111111111111111',
        );
    });

    test('redacts a raw PAN before persistence', async () => {
        const service = new NotificationService();
        const input = validInput({
            payload: { kyc: { pan: 'ABCDE1234F' } },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        const pan = (record.payload.kyc as Record<string, unknown>).pan;
        expect(pan).toBe('****234F');
        expect(JSON.stringify(record.payload)).not.toContain('ABCDE1234F');
    });

    test('redacts a raw Aadhaar before persistence', async () => {
        const service = new NotificationService();
        const input = validInput({
            payload: { aadhaar: '1234 1234 1235' },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        expect(record.payload.aadhaar).toBe('****1235');
        expect(JSON.stringify(record.payload)).not.toContain(
            '1234 1234 1235',
        );
        expect(JSON.stringify(record.payload)).not.toContain(
            '123412341235',
        );
    });

    test('redacts a raw Bearer token before persistence', async () => {
        const service = new NotificationService();
        const input = validInput({
            payload: { auth: 'Bearer abcdef0123456789xyz' },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        // The auth field's KEY does not contain a sensitive token, so the
        // value-driven Bearer-token detector handles it.
        expect(record.payload.auth).toBe('[REDACTED]');
        expect(JSON.stringify(record.payload)).not.toContain(
            'abcdef0123456789xyz',
        );
    });

    test('redacts a raw AWS access key before persistence', async () => {
        const service = new NotificationService();
        const input = validInput({
            payload: { creds: 'AKIAIOSFODNN7EXAMPLE' },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        expect(record.payload.creds).toBe('[REDACTED]');
        expect(JSON.stringify(record.payload)).not.toContain(
            'AKIAIOSFODNN7EXAMPLE',
        );
    });

    test('redacts a sensitive-named field (defense-in-depth at key level)', async () => {
        const service = new NotificationService();
        const input = validInput({
            payload: { password: 'opaque-but-secret' },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        expect(record.payload.password).toBe('[REDACTED]');
    });

    test('redaction runs AFTER sanitization — both sweeps apply', async () => {
        // Sanitization (16.2) strips the `<script>` markup; redaction
        // (16.4) replaces the card with the redacted reference. Both
        // must run on the same payload.
        const service = new NotificationService();
        const input = validInput({
            payload: {
                note: '<script>alert(1)</script>card 4111111111111111 charged',
            },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        const note = record.payload.note as string;
        // Sanitization removes the <script> block AND its inner text.
        expect(note).not.toContain('<script>');
        expect(note).not.toContain('alert(1)');
        // Redaction replaces the card.
        expect(note).toContain('****1111');
        expect(note).not.toContain('4111111111111111');
    });

    test('does not mutate the caller-provided payload', async () => {
        const service = new NotificationService();
        const original = {
            card: '4111111111111111',
            nested: { pan: 'ABCDE1234F' },
        };
        const before = JSON.parse(JSON.stringify(original));
        const input = validInput({ payload: original });

        await service.createNotification(input, adminCaller());

        // Original input is untouched.
        expect(original).toEqual(before);
        // Persisted record is redacted.
        const record = persistedRecord();
        expect(record.payload.card).toBe('****1111');
    });

    test('clean payloads are persisted unchanged (no regression)', async () => {
        const service = new NotificationService();
        const input = validInput({
            payload: {
                customerName: 'Alice',
                invoiceNo: 'INV-001',
                amount: '500.00',
            },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        expect(record.payload).toEqual({
            customerName: 'Alice',
            invoiceNo: 'INV-001',
            amount: '500.00',
        });
    });

    test('redacts every recipient-relevant field across nested arrays', async () => {
        const service = new NotificationService();
        const input = validInput({
            payload: {
                cards: [
                    { number: '4111111111111111', last4: '1111' },
                    { number: '5500000000000004', last4: '0004' },
                ],
            },
        });

        await service.createNotification(input, adminCaller());

        const record = persistedRecord();
        expect(record.payload.cards).toEqual([
            { number: '****1111', last4: '1111' },
            { number: '****0004', last4: '0004' },
        ]);
    });
});
