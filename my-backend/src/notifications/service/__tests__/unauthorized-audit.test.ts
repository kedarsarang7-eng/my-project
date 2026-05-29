// ============================================================================
// UNS — `unauthorized_access_attempt` Audit_Log writes (Task 16.3)
// ============================================================================
// Validates: REQ 12.5, REQ 12.6, REQ 12.7 — every denied access attempt MUST
// write an `unauthorized_access_attempt` Audit_Log entry, and a transient
// audit-write failure MUST NOT change the user-visible denial behaviour.
//
// Coverage:
//   1. createNotification deny → audit + AuthorizationError thrown
//   2. createNotification permitted path → no `unauthorized_access_attempt`
//      audit entry written
//   3. dispatch per-recipient deny → audit per omitted recipient
//   4. markAsRead by non-recipient → audit + AuthorizationError thrown
//   5. markAsRead by recipient → success, no deny audit
//   6. getReplay out-of-window → audit + ReplayWindowExceededError thrown
//   7. getReplay malformed since → audit + ReplayWindowExceededError thrown
//   8. setUserPreferences by non-owner with caller context → audit + throw
//   9. getUserPreferences by non-owner with caller context → audit + throw
//  10. setUserPreferences by admin with caller context → permitted
//  11. AuditLog write failure does NOT turn a deny into a success
//      (the deny still throws, only the audit is best-effort)
// ============================================================================

import { describe, test, expect, beforeEach, jest } from '@jest/globals';

// ---- Mocks ---------------------------------------------------------------
// Mock `appendAuditLog` so we can assert what gets written without
// touching DynamoDB. Mock `getNotification` / `createNotification` /
// `updateLifecycle` / `getUserPreference` / `upsertUserPreference` so the
// service runs in a hermetic environment.

const mockAppendAuditLog =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockCreateNotificationRecord =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockGetNotification =
    jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockUpdateLifecycle =
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
    const actual = jest.requireActual('../../store') as Record<string, unknown>;
    return {
        ...actual,
        appendAuditLog: (...args: unknown[]) => mockAppendAuditLog(...args),
        createNotification: (...args: unknown[]) =>
            mockCreateNotificationRecord(...args),
        getNotification: (...args: unknown[]) => mockGetNotification(...args),
        updateLifecycle: (...args: unknown[]) => mockUpdateLifecycle(...args),
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
    AuthorizationError,
    NotificationService,
    PredicateRecipientAuthorizer,
    ReplayWindowExceededError,
    type CreateNotificationCaller,
    type CreateNotificationInput,
    type PreferencesCaller,
} from '../index';
import type { AuditLogRecord, NotificationRecord } from '../../store/types';

// ---- Helpers -------------------------------------------------------------

function adminCaller(): CreateNotificationCaller {
    return { user_id: 'admin-1', role: 'admin' };
}

function userCaller(userId: string, role = 'cashier'): CreateNotificationCaller {
    return { user_id: userId, role };
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

function notificationRecord(
    overrides: Partial<NotificationRecord> = {},
): NotificationRecord {
    return {
        notification_id: 'n-1',
        event_name: 'billing.invoice.created',
        category: 'billing',
        sub_category: '',
        priority: 'normal',
        actor_id: 'admin-1',
        target_id: '',
        recipients: [
            {
                user_id: 'recip-1',
                role: 'cashier',
                channels: ['in_app'],
                status: 'emitted',
                delivered_at: null,
                read_at: null,
            },
        ],
        payload: {},
        channels: ['in_app'],
        status: 'emitted',
        created_at: '2026-01-01T00:00:00.000Z',
        dispatched_at: null,
        delivered_at: null,
        read_at: null,
        dedup_key: 'dedup-1',
        source_module: 'billing',
        source_app: 'dukanx_desktop',
        ...overrides,
    };
}

/** Collect all `appendAuditLog` calls into an array of records. */
function appendedAuditRecords(): AuditLogRecord[] {
    return mockAppendAuditLog.mock.calls.map(
        (call) => call[0] as AuditLogRecord,
    );
}

function unauthorizedAuditRecords(): AuditLogRecord[] {
    return appendedAuditRecords().filter(
        (r) => r.lifecycle_state === 'unauthorized_access_attempt',
    );
}

beforeEach(() => {
    jest.clearAllMocks();
    mockAppendAuditLog.mockResolvedValue(undefined);
    mockCreateNotificationRecord.mockResolvedValue(undefined);
    mockUpdateLifecycle.mockImplementation(async (input: unknown) => {
        const i = input as { notificationId: string };
        return notificationRecord({ notification_id: i.notificationId });
    });
    mockListByUserCategory.mockResolvedValue({ items: [], next_cursor: null });
    mockFindByDedupKey.mockResolvedValue([]);
    mockGetUserPreference.mockResolvedValue(null);
    mockUpsertUserPreference.mockImplementation(async (input: unknown) => {
        const i = input as Record<string, unknown>;
        return {
            user_id: i.user_id,
            role: i.role ?? '',
            per_category_channels: {},
            per_event_channels: {},
            quiet_hours_start: null,
            quiet_hours_end: null,
            quiet_hours_timezone: null,
            mute_targets: [],
            updated_at: '2026-01-01T00:00:00.000Z',
            version: 1,
        };
    });
});

// ---------------------------------------------------------------------------
// 1. createNotification — caller authz deny audits + throws
// ---------------------------------------------------------------------------

describe('createNotification — caller authz deny', () => {
    test('writes unauthorized_access_attempt audit entry on deny', async () => {
        const svc = new NotificationService();
        // A non-privileged caller emitting on behalf of a different actor.
        await expect(
            svc.createNotification(
                validInput({ actor_id: 'someone-else' }),
                userCaller('cashier-1', 'cashier'),
            ),
        ).rejects.toBeInstanceOf(AuthorizationError);

        const denials = unauthorizedAuditRecords();
        expect(denials).toHaveLength(1);
        expect(denials[0].lifecycle_state).toBe('unauthorized_access_attempt');
        expect(denials[0].outcome).toBe('denied');
        expect(denials[0].recipient_id).toBe('cashier-1');
        expect(denials[0].error_reason).toMatch(/^caller_not_authorized/);
        // Persistent state untouched on a denied call (REQ 4.10).
        expect(mockCreateNotificationRecord).not.toHaveBeenCalled();
    });

    test('does NOT write a deny audit on a permitted createNotification', async () => {
        const svc = new NotificationService();
        await svc.createNotification(validInput(), adminCaller());

        // Permitted path → no `unauthorized_access_attempt` row.
        expect(unauthorizedAuditRecords()).toHaveLength(0);
        // The `emitted` lifecycle audit row IS written though.
        const emitted = appendedAuditRecords().filter(
            (r) => r.lifecycle_state === 'emitted',
        );
        expect(emitted).toHaveLength(1);
    });

    test('audits and rejects malformed event_name shape', async () => {
        const svc = new NotificationService();
        await expect(
            svc.createNotification(
                validInput({ event_name: 'NotCanonical' }),
                adminCaller(),
            ),
        ).rejects.toBeInstanceOf(AuthorizationError);

        const denials = unauthorizedAuditRecords();
        expect(denials).toHaveLength(1);
        expect(denials[0].error_reason).toContain('caller_not_authorized');
        expect(denials[0].error_reason).toContain('event_name_shape');
    });
});

// ---------------------------------------------------------------------------
// 2. dispatch — per-recipient authz deny audits
// ---------------------------------------------------------------------------

describe('dispatch — per-recipient authz deny', () => {
    test('writes one unauthorized_access_attempt audit per omitted recipient', async () => {
        const record = notificationRecord({
            recipients: [
                {
                    user_id: 'recip-allowed',
                    role: 'cashier',
                    channels: ['in_app'],
                    status: 'emitted',
                    delivered_at: null,
                    read_at: null,
                },
                {
                    user_id: 'recip-denied',
                    role: 'cashier',
                    channels: ['in_app'],
                    status: 'emitted',
                    delivered_at: null,
                    read_at: null,
                },
            ],
        });
        // dispatch loads the record, then transitionToDispatched re-loads
        // it for the lifecycle update — we mock both reads.
        mockGetNotification.mockResolvedValue(record);

        const denyOnlyDenied = new PredicateRecipientAuthorizer(
            (args) => args.user_id !== 'recip-denied',
        );

        const svc = new NotificationService({
            recipientAuthorizer: denyOnlyDenied,
            dispatchChannelAdapter: async () => undefined,
        });

        const result = await svc.dispatch('n-1');

        // Allowed recipient delivered, denied recipient omitted.
        expect(result.recipients).toHaveLength(2);
        const denyOutcome = result.recipients.find(
            (r) => r.user_id === 'recip-denied',
        );
        expect(denyOutcome?.outcome).toBe('denied_unauthorized');

        // Audit trail: one `unauthorized_access_attempt` row for the denied
        // recipient, AND no row for the allowed one.
        const denials = unauthorizedAuditRecords();
        expect(denials).toHaveLength(1);
        expect(denials[0].recipient_id).toBe('recip-denied');
        expect(denials[0].notification_id).toBe('n-1');
        expect(denials[0].outcome).toBe('denied');
        expect(denials[0].error_reason).toMatch(/^recipient_not_authorized/);
    });
});

// ---------------------------------------------------------------------------
// 3. markAsRead — non-recipient deny audits
// ---------------------------------------------------------------------------

describe('markAsRead — non-recipient deny', () => {
    test('writes audit and throws AuthorizationError when caller is not a recipient', async () => {
        mockGetNotification.mockResolvedValueOnce(
            notificationRecord({
                recipients: [
                    {
                        user_id: 'real-recip',
                        role: 'cashier',
                        channels: ['in_app'],
                        status: 'emitted',
                        delivered_at: null,
                        read_at: null,
                    },
                ],
            }),
        );

        const svc = new NotificationService();

        await expect(
            svc.markAsRead('n-1', 'attacker-id'),
        ).rejects.toBeInstanceOf(AuthorizationError);

        const denials = unauthorizedAuditRecords();
        expect(denials).toHaveLength(1);
        expect(denials[0].recipient_id).toBe('attacker-id');
        expect(denials[0].notification_id).toBe('n-1');
        expect(denials[0].error_reason).toMatch(/^not_recipient/);
        // No state advance on the persisted record.
        expect(mockUpdateLifecycle).not.toHaveBeenCalled();
    });

    test('permitted recipient markAsRead does NOT write a deny audit', async () => {
        mockGetNotification.mockResolvedValue(
            notificationRecord({
                recipients: [
                    {
                        user_id: 'real-recip',
                        role: 'cashier',
                        channels: ['in_app'],
                        status: 'emitted',
                        delivered_at: null,
                        read_at: null,
                    },
                ],
            }),
        );

        const svc = new NotificationService();
        await svc.markAsRead('n-1', 'real-recip');

        // No `unauthorized_access_attempt` rows.
        expect(unauthorizedAuditRecords()).toHaveLength(0);
    });
});

// ---------------------------------------------------------------------------
// 4. getReplay — out-of-window / malformed since deny audits
// ---------------------------------------------------------------------------

describe('getReplay — replay-window deny', () => {
    test('audits + throws when since is older than the replay window', async () => {
        const svc = new NotificationService();
        const tenDaysAgo = new Date(
            Date.now() - 10 * 24 * 60 * 60 * 1000,
        ).toISOString();

        await expect(
            svc.getReplay({
                since: tenDaysAgo,
                app: 'dukanx_desktop',
                userIds: ['user-1'],
            }),
        ).rejects.toBeInstanceOf(ReplayWindowExceededError);

        const denials = unauthorizedAuditRecords();
        expect(denials).toHaveLength(1);
        expect(denials[0].recipient_id).toBe('user-1');
        expect(denials[0].error_reason).toMatch(/^replay_window_exceeded/);
    });

    test('audits + throws when since is malformed', async () => {
        const svc = new NotificationService();

        await expect(
            svc.getReplay({
                since: 'not-a-date',
                app: 'dukanx_desktop',
                userIds: ['user-1'],
            }),
        ).rejects.toBeInstanceOf(ReplayWindowExceededError);

        const denials = unauthorizedAuditRecords();
        expect(denials).toHaveLength(1);
        expect(denials[0].error_reason).toContain('replay_window_exceeded');
    });

    test('does NOT write a deny audit on an in-window replay', async () => {
        const svc = new NotificationService();
        await svc.getReplay({
            since: new Date(Date.now() - 60_000).toISOString(),
            app: 'dukanx_desktop',
            userIds: ['user-1'],
        });

        expect(unauthorizedAuditRecords()).toHaveLength(0);
    });
});

// ---------------------------------------------------------------------------
// 5. preferences — non-owner deny audits when caller context supplied
// ---------------------------------------------------------------------------

describe('getUserPreferences / setUserPreferences — owner check', () => {
    test('non-owner getUserPreferences with caller → audit + throw', async () => {
        const svc = new NotificationService();
        const caller: PreferencesCaller = {
            user_id: 'attacker',
            role: 'cashier',
        };

        await expect(
            svc.getUserPreferences('victim-id', caller),
        ).rejects.toBeInstanceOf(AuthorizationError);

        const denials = unauthorizedAuditRecords();
        expect(denials).toHaveLength(1);
        expect(denials[0].recipient_id).toBe('attacker');
        expect(denials[0].error_reason).toMatch(/^not_owner/);
        expect(mockGetUserPreference).not.toHaveBeenCalled();
    });

    test('non-owner setUserPreferences with caller → audit + throw', async () => {
        const svc = new NotificationService();
        const caller: PreferencesCaller = {
            user_id: 'attacker',
            role: 'cashier',
        };

        await expect(
            svc.setUserPreferences('victim-id', { role: 'cashier' }, caller),
        ).rejects.toBeInstanceOf(AuthorizationError);

        const denials = unauthorizedAuditRecords();
        expect(denials).toHaveLength(1);
        expect(denials[0].recipient_id).toBe('attacker');
        expect(denials[0].error_reason).toMatch(/^not_owner/);
        expect(mockUpsertUserPreference).not.toHaveBeenCalled();
    });

    test('owner setUserPreferences with caller → permitted, no deny audit', async () => {
        const svc = new NotificationService();
        const caller: PreferencesCaller = {
            user_id: 'self',
            role: 'cashier',
        };

        await svc.setUserPreferences('self', { role: 'cashier' }, caller);

        expect(unauthorizedAuditRecords()).toHaveLength(0);
        expect(mockUpsertUserPreference).toHaveBeenCalled();
    });

    test('admin setUserPreferences for another user with caller → permitted', async () => {
        const svc = new NotificationService();
        const caller: PreferencesCaller = {
            user_id: 'admin-1',
            role: 'admin',
        };

        await svc.setUserPreferences('victim-id', { role: 'cashier' }, caller);

        expect(unauthorizedAuditRecords()).toHaveLength(0);
        expect(mockUpsertUserPreference).toHaveBeenCalled();
    });
});

// ---------------------------------------------------------------------------
// 6. AuditLog write failure does NOT turn a denial into a success
// ---------------------------------------------------------------------------

describe('audit-write failure — denial behaviour preserved', () => {
    test('createNotification still throws AuthorizationError when audit append fails', async () => {
        // appendAuditLog rejects on every call.
        mockAppendAuditLog.mockRejectedValue(
            new Error('audit-log unavailable'),
        );

        const svc = new NotificationService();
        await expect(
            svc.createNotification(
                validInput({ actor_id: 'someone-else' }),
                userCaller('cashier-1', 'cashier'),
            ),
        ).rejects.toBeInstanceOf(AuthorizationError);
    });

    test('markAsRead still throws AuthorizationError when audit append fails', async () => {
        mockAppendAuditLog.mockRejectedValue(
            new Error('audit-log unavailable'),
        );
        mockGetNotification.mockResolvedValueOnce(
            notificationRecord({
                recipients: [
                    {
                        user_id: 'real-recip',
                        role: 'cashier',
                        channels: ['in_app'],
                        status: 'emitted',
                        delivered_at: null,
                        read_at: null,
                    },
                ],
            }),
        );

        const svc = new NotificationService();
        await expect(
            svc.markAsRead('n-1', 'attacker-id'),
        ).rejects.toBeInstanceOf(AuthorizationError);
    });

    test('getReplay still throws ReplayWindowExceededError when audit append fails', async () => {
        mockAppendAuditLog.mockRejectedValue(
            new Error('audit-log unavailable'),
        );

        const svc = new NotificationService();
        await expect(
            svc.getReplay({
                since: new Date(
                    Date.now() - 10 * 24 * 60 * 60 * 1000,
                ).toISOString(),
                app: 'dukanx_desktop',
                userIds: ['user-1'],
            }),
        ).rejects.toBeInstanceOf(ReplayWindowExceededError);
    });

    test('setUserPreferences still throws AuthorizationError when audit append fails', async () => {
        mockAppendAuditLog.mockRejectedValue(
            new Error('audit-log unavailable'),
        );

        const svc = new NotificationService();
        await expect(
            svc.setUserPreferences(
                'victim-id',
                { role: 'cashier' },
                { user_id: 'attacker', role: 'cashier' },
            ),
        ).rejects.toBeInstanceOf(AuthorizationError);
    });
});
