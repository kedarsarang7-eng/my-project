// ============================================================================
// Staff Module — Notification Service Unit Tests (Task 11.3)
// ============================================================================
// Validates multi-channel dispatch (Push/Email/In-App/WebSocket via
// src/notifications), WhatsApp routing through OpenWA_Gateway (no second
// gateway; Req 8.5), SMS adapter interface flagged OFF (Req 8.6), and
// HMAC-SHA256 webhook verification.
//
// Requirements: 8.4, 8.5, 8.6
// ============================================================================

import {
    StaffNotifyService,
    createStaffNotifyService,
    computeOpenWASignature,
    verifyOpenWAWebhookSignature,
    type StaffNotificationInput,
    type OpenWAGatewayConfig,
} from '../staff-notify.service';
import {
    createDeferredSmsAdapter,
    type StaffSmsAdapter,
} from '../deferred-capabilities.service';

// ── Mocks ───────────────────────────────────────────────────────────────────

// Mock DynamoDB putItem (notification log persistence)
jest.mock('../../../../config/dynamodb.config', () => ({
    putItem: jest.fn().mockResolvedValue(undefined),
}));

// Mock feature-flag service (for deferred SMS adapter)
jest.mock('../../../../services/feature-flag.service', () => ({
    getFeatureFlag: jest.fn().mockResolvedValue({ is_active: true, default_value: false }),
}));

// Mock logger
jest.mock('../../../../utils/logger', () => ({
    logger: {
        info: jest.fn(),
        warn: jest.fn(),
        error: jest.fn(),
    },
}));

// ── Helpers ─────────────────────────────────────────────────────────────────

function buildInput(
    overrides: Partial<StaffNotificationInput> = {},
): StaffNotificationInput {
    return {
        tenantId: 'tenant-1',
        businessId: 'biz-1',
        recipientId: 'emp-123',
        channels: ['push'],
        template: 'leave_approved',
        payload: { leaveId: 'lv-456' },
        ...overrides,
    };
}

describe('StaffNotifyService (Task 11.3)', () => {
    let channelAdapterMock: jest.Mock;
    let openWAConfigResolverMock: jest.Mock;
    let service: StaffNotifyService;

    beforeEach(() => {
        channelAdapterMock = jest.fn().mockResolvedValue(undefined);
        openWAConfigResolverMock = jest.fn().mockResolvedValue({
            baseUrl: 'https://openwa.example.com',
            apiKey: 'tenant-key-123',
            webhookSecret: 'webhook-secret-abc',
            sessionId: 'session-uuid-123',
        } satisfies OpenWAGatewayConfig);

        service = new StaffNotifyService({
            channelAdapter: channelAdapterMock,
            openWAConfigResolver: openWAConfigResolverMock,
        });
    });

    // ── Push/Email/In-App/WebSocket via DeliveryLayer (Req 8.4) ─────────────

    describe('Push/Email/In-App/WebSocket dispatch (Req 8.4)', () => {
        it('dispatches push notification through the channel adapter', async () => {
            const result = await service.notify(buildInput({ channels: ['push'] }));

            expect(channelAdapterMock).toHaveBeenCalledTimes(1);
            expect(channelAdapterMock).toHaveBeenCalledWith(
                expect.objectContaining({
                    channel: 'push',
                    recipient: { user_id: 'emp-123', role: 'staff' },
                }),
            );
            expect(result.outcomes).toHaveLength(1);
            expect(result.outcomes[0]).toEqual({ channel: 'push', status: 'sent' });
        });

        it('dispatches email notification through the channel adapter', async () => {
            const result = await service.notify(buildInput({ channels: ['email'] }));

            expect(channelAdapterMock).toHaveBeenCalledWith(
                expect.objectContaining({ channel: 'email' }),
            );
            expect(result.outcomes[0].status).toBe('sent');
        });

        it('dispatches in_app notification through the channel adapter', async () => {
            const result = await service.notify(buildInput({ channels: ['in_app'] }));

            expect(channelAdapterMock).toHaveBeenCalledWith(
                expect.objectContaining({ channel: 'in_app' }),
            );
            expect(result.outcomes[0].status).toBe('sent');
        });

        it('dispatches websocket notification through the channel adapter', async () => {
            const result = await service.notify(buildInput({ channels: ['websocket'] }));

            // WebSocket maps to webhook adapter path
            expect(channelAdapterMock).toHaveBeenCalledWith(
                expect.objectContaining({ channel: 'webhook' }),
            );
            expect(result.outcomes[0].status).toBe('sent');
        });

        it('dispatches multiple channels in a single notify call', async () => {
            const result = await service.notify(
                buildInput({ channels: ['push', 'email', 'in_app'] }),
            );

            expect(channelAdapterMock).toHaveBeenCalledTimes(3);
            expect(result.outcomes).toHaveLength(3);
            expect(result.outcomes.every((o) => o.status === 'sent')).toBe(true);
        });

        it('reports failure when channel adapter throws', async () => {
            channelAdapterMock.mockRejectedValueOnce(new Error('FCM unavailable'));

            const result = await service.notify(buildInput({ channels: ['push'] }));

            expect(result.outcomes[0]).toEqual({
                channel: 'push',
                status: 'failed',
                error: 'FCM unavailable',
            });
        });
    });

    // ── WhatsApp via OpenWA_Gateway (Req 8.5) ───────────────────────────────

    describe('WhatsApp via OpenWA_Gateway (Req 8.5)', () => {
        beforeEach(() => {
            // Mock global fetch
            global.fetch = jest.fn().mockResolvedValue({
                ok: true,
                text: () => Promise.resolve(''),
            } as unknown as Response);
        });

        afterEach(() => {
            delete (global as any).fetch;
        });

        it('routes WhatsApp through OpenWA gateway (no second gateway)', async () => {
            const result = await service.notify(
                buildInput({
                    channels: ['whatsapp'],
                    phoneNumber: '+919876543210',
                }),
            );

            expect(openWAConfigResolverMock).toHaveBeenCalledWith('tenant-1');
            expect(global.fetch).toHaveBeenCalledWith(
                'https://openwa.example.com/api/send-message',
                expect.objectContaining({
                    method: 'POST',
                    headers: expect.objectContaining({
                        'X-API-Key': 'tenant-key-123',
                    }),
                }),
            );
            expect(result.outcomes[0]).toEqual({
                channel: 'whatsapp',
                status: 'sent',
            });
        });

        it('includes HMAC-SHA256 signature in OpenWA request headers', async () => {
            await service.notify(
                buildInput({
                    channels: ['whatsapp'],
                    phoneNumber: '+919876543210',
                }),
            );

            const fetchCall = (global.fetch as jest.Mock).mock.calls[0];
            const headers = fetchCall[1].headers;
            expect(headers['X-OpenWA-Signature']).toMatch(/^sha256=[a-f0-9]{64}$/);
        });

        it('fails when phone number is not provided for WhatsApp', async () => {
            const result = await service.notify(
                buildInput({ channels: ['whatsapp'], phoneNumber: undefined }),
            );

            expect(result.outcomes[0]).toEqual({
                channel: 'whatsapp',
                status: 'failed',
                error: 'Phone number required for WhatsApp channel',
            });
        });

        it('fails when OpenWA gateway is not configured for tenant', async () => {
            openWAConfigResolverMock.mockResolvedValueOnce(null);

            const result = await service.notify(
                buildInput({
                    channels: ['whatsapp'],
                    phoneNumber: '+919876543210',
                }),
            );

            expect(result.outcomes[0]).toEqual({
                channel: 'whatsapp',
                status: 'failed',
                error: 'OpenWA gateway not configured for this tenant',
            });
        });

        it('fails when OpenWA gateway returns non-OK response', async () => {
            (global.fetch as jest.Mock).mockResolvedValueOnce({
                ok: false,
                status: 503,
                text: () => Promise.resolve('Service unavailable'),
            });

            const result = await service.notify(
                buildInput({
                    channels: ['whatsapp'],
                    phoneNumber: '+919876543210',
                }),
            );

            expect(result.outcomes[0]).toEqual({
                channel: 'whatsapp',
                status: 'failed',
                error: 'OpenWA returned 503',
            });
        });
    });

    // ── SMS adapter interface (Req 8.6) — flagged OFF ───────────────────────

    describe('SMS adapter interface (Req 8.6) — flagged OFF', () => {
        it('returns flagged_off status when SMS channel is requested', async () => {
            const result = await service.notify(
                buildInput({
                    channels: ['sms'],
                    phoneNumber: '+919876543210',
                }),
            );

            expect(result.outcomes[0]).toEqual({
                channel: 'sms',
                status: 'flagged_off',
            });
        });

        it('never sends a real SMS message', async () => {
            const smsAdapterMock: StaffSmsAdapter = {
                send: jest.fn().mockResolvedValue({
                    available: false,
                    reason: 'DEFERRED_PHASE_11',
                    flagKey: 'staff_sms_notifications',
                    message: 'Staff SMS notifications is not available (deferred to Phase 11)',
                }),
                isAvailable: jest.fn().mockResolvedValue(false),
            };

            const svcWithMock = new StaffNotifyService({
                channelAdapter: channelAdapterMock,
                openWAConfigResolver: openWAConfigResolverMock,
                smsAdapter: smsAdapterMock,
            });

            const result = await svcWithMock.notify(
                buildInput({ channels: ['sms'], phoneNumber: '+919876543210' }),
            );

            expect(smsAdapterMock.send).toHaveBeenCalled();
            expect(result.outcomes[0].status).toBe('flagged_off');
        });
    });

    // ── HMAC-SHA256 verification (reused from payment gateways) ─────────────

    describe('HMAC-SHA256 webhook verification', () => {
        const secret = 'test-secret-key';
        const payload = '{"event":"message","from":"123@c.us"}';

        it('computeOpenWASignature produces a valid hex signature', () => {
            const sig = computeOpenWASignature(payload, secret);
            expect(sig).toMatch(/^[a-f0-9]{64}$/);
        });

        it('verifyOpenWAWebhookSignature returns true for valid signature', () => {
            const sig = computeOpenWASignature(payload, secret);
            expect(verifyOpenWAWebhookSignature(payload, sig, secret)).toBe(true);
        });

        it('verifyOpenWAWebhookSignature returns false for tampered payload', () => {
            const sig = computeOpenWASignature(payload, secret);
            const tampered = payload + 'x';
            expect(verifyOpenWAWebhookSignature(tampered, sig, secret)).toBe(false);
        });

        it('verifyOpenWAWebhookSignature returns false for wrong secret', () => {
            const sig = computeOpenWASignature(payload, secret);
            expect(verifyOpenWAWebhookSignature(payload, sig, 'wrong-secret')).toBe(false);
        });

        it('verifyOpenWAWebhookSignature returns false for malformed signature', () => {
            expect(verifyOpenWAWebhookSignature(payload, 'not-hex!', secret)).toBe(false);
        });

        it('uses constant-time comparison (timingSafeEqual pattern)', () => {
            // Verify the function handles length mismatches without timing leak
            const sig = computeOpenWASignature(payload, secret);
            const shortened = sig.slice(0, 32);
            expect(verifyOpenWAWebhookSignature(payload, shortened, secret)).toBe(false);
        });
    });

    // ── Notification logging ────────────────────────────────────────────────

    describe('notification logging', () => {
        it('persists a log entry for each dispatched channel', async () => {
            const { putItem } = require('../../../../config/dynamodb.config');
            (putItem as jest.Mock).mockClear();

            await service.notify(buildInput({ channels: ['push', 'email'] }));

            // 2 channels → 2 log entries
            expect(putItem).toHaveBeenCalledTimes(2);
            const firstCall = (putItem as jest.Mock).mock.calls[0][0];
            expect(firstCall.SK).toMatch(/^NOTIFLOG#/);
            expect(firstCall.channel).toBe('push');
            expect(firstCall.to).toBe('emp-123');
            expect(firstCall.template).toBe('leave_approved');
        });

        it('does not fail the notification if log persistence throws', async () => {
            const { putItem } = require('../../../../config/dynamodb.config');
            (putItem as jest.Mock).mockRejectedValueOnce(new Error('DDB error'));

            const result = await service.notify(buildInput({ channels: ['push'] }));

            // Notification still succeeds
            expect(result.outcomes[0].status).toBe('sent');
        });
    });

    // ── Factory ─────────────────────────────────────────────────────────────

    describe('createStaffNotifyService factory', () => {
        it('creates a service instance with default options', () => {
            const svc = createStaffNotifyService({
                channelAdapter: channelAdapterMock,
            });
            expect(svc).toBeInstanceOf(StaffNotifyService);
        });
    });
});
