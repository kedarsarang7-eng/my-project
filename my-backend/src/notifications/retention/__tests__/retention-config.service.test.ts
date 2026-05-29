// ============================================================================
// Tests — Retention Configuration Service (REQ 13.4, 13.4a)
// ============================================================================
// Covers:
//   - getRetentionConfig returns env default when no row exists
//   - getRetentionConfig returns persisted record when present
//   - resolveDefaultArchivePeriodDays falls back to spec default on bad env
//   - setRetentionConfig validates input bounds
//   - setRetentionConfig writes audit-log first, then persists
//   - setRetentionConfig rejects with AuditLogUnavailableError when audit
//     fails AND leaves persistent state untouched (REQ 13.4a)
//   - same-value writes are no-ops and skip the audit entry
// ============================================================================

import { describe, test, expect, beforeEach, jest } from '@jest/globals';

// ---- Mocks ---------------------------------------------------------------

const mockReadRetentionConfig = jest.fn<(...args: unknown[]) => Promise<unknown>>();
const mockWriteRetentionConfig = jest.fn<(...args: unknown[]) => Promise<unknown>>();

jest.mock('../retention-config.repo', () => {
    const actual = jest.requireActual('../retention-config.repo') as Record<
        string,
        unknown
    >;
    return {
        ...actual,
        readRetentionConfig: (...args: unknown[]) =>
            mockReadRetentionConfig(...args),
        writeRetentionConfig: (...args: unknown[]) =>
            mockWriteRetentionConfig(...args),
    };
});

const mockAppendAuditLog = jest.fn<(...args: unknown[]) => Promise<unknown>>();

jest.mock('../../store', () => {
    const actual = jest.requireActual('../../store') as Record<string, unknown>;
    return {
        ...actual,
        appendAuditLog: (...args: unknown[]) => mockAppendAuditLog(...args),
    };
});

// Import AFTER the mocks are wired.
import {
    ARCHIVE_PERIOD_ENV_VAR,
    AuditLogUnavailableError,
    InvalidRetentionValueError,
    MAX_ARCHIVE_PERIOD_DAYS,
    MIN_ARCHIVE_PERIOD_DAYS,
    getRetentionConfig,
    resolveDefaultArchivePeriodDays,
    setRetentionConfig,
} from '../index';

beforeEach(() => {
    jest.clearAllMocks();
    delete process.env[ARCHIVE_PERIOD_ENV_VAR];
});

// ---------------------------------------------------------------------------
// resolveDefaultArchivePeriodDays
// ---------------------------------------------------------------------------

describe('resolveDefaultArchivePeriodDays', () => {
    test('returns spec default 90 days when env var is unset', () => {
        expect(resolveDefaultArchivePeriodDays({})).toBe(90);
    });

    test('respects env override when in range', () => {
        expect(
            resolveDefaultArchivePeriodDays({
                [ARCHIVE_PERIOD_ENV_VAR]: '180',
            }),
        ).toBe(180);
    });

    test('falls back to spec default when env value is non-numeric', () => {
        expect(
            resolveDefaultArchivePeriodDays({
                [ARCHIVE_PERIOD_ENV_VAR]: 'not-a-number',
            }),
        ).toBe(90);
    });

    test('falls back to spec default when env value is below MIN', () => {
        expect(
            resolveDefaultArchivePeriodDays({
                [ARCHIVE_PERIOD_ENV_VAR]: '0',
            }),
        ).toBe(90);
    });

    test('falls back to spec default when env value exceeds MAX', () => {
        expect(
            resolveDefaultArchivePeriodDays({
                [ARCHIVE_PERIOD_ENV_VAR]: String(MAX_ARCHIVE_PERIOD_DAYS + 1),
            }),
        ).toBe(90);
    });
});

// ---------------------------------------------------------------------------
// getRetentionConfig
// ---------------------------------------------------------------------------

describe('getRetentionConfig', () => {
    test('returns env-default record when no row is persisted', async () => {
        mockReadRetentionConfig.mockResolvedValueOnce(null);

        const result = await getRetentionConfig({
            env: { [ARCHIVE_PERIOD_ENV_VAR]: '120' },
        });

        expect(result.archive_period_days).toBe(120);
        expect(result.version).toBe(0);
        expect(result.updated_by).toBeNull();
    });

    test('returns persisted record when one exists', async () => {
        const persisted = {
            archive_period_days: 200,
            updated_at: '2026-01-01T00:00:00.000Z',
            updated_by: 'admin-1',
            version: 3,
        };
        mockReadRetentionConfig.mockResolvedValueOnce(persisted);

        const result = await getRetentionConfig();

        expect(result).toEqual(persisted);
    });
});

// ---------------------------------------------------------------------------
// setRetentionConfig — validation
// ---------------------------------------------------------------------------

describe('setRetentionConfig — validation', () => {
    test('rejects non-integer archive_period_days', async () => {
        await expect(
            setRetentionConfig({
                archive_period_days: 30.5,
                actor_id: 'admin-1',
            }),
        ).rejects.toBeInstanceOf(InvalidRetentionValueError);
        expect(mockAppendAuditLog).not.toHaveBeenCalled();
        expect(mockWriteRetentionConfig).not.toHaveBeenCalled();
    });

    test('rejects archive_period_days below MIN', async () => {
        await expect(
            setRetentionConfig({
                archive_period_days: MIN_ARCHIVE_PERIOD_DAYS - 1,
                actor_id: 'admin-1',
            }),
        ).rejects.toBeInstanceOf(InvalidRetentionValueError);
    });

    test('rejects archive_period_days above MAX', async () => {
        await expect(
            setRetentionConfig({
                archive_period_days: MAX_ARCHIVE_PERIOD_DAYS + 1,
                actor_id: 'admin-1',
            }),
        ).rejects.toBeInstanceOf(InvalidRetentionValueError);
    });

    test('rejects empty actor_id', async () => {
        await expect(
            setRetentionConfig({
                archive_period_days: 90,
                actor_id: '   ',
            }),
        ).rejects.toBeInstanceOf(InvalidRetentionValueError);
    });
});

// ---------------------------------------------------------------------------
// setRetentionConfig — happy path
// ---------------------------------------------------------------------------

describe('setRetentionConfig — happy path', () => {
    test('writes audit-log entry first, then persists with version bump', async () => {
        mockReadRetentionConfig.mockResolvedValueOnce({
            archive_period_days: 90,
            updated_at: '2026-01-01T00:00:00.000Z',
            updated_by: null,
            version: 0,
        });
        mockAppendAuditLog.mockResolvedValueOnce({ audit_id: 'audit-1' });
        mockWriteRetentionConfig.mockImplementationOnce(
            async (record: unknown) => record,
        );

        const fixedNow = new Date('2026-04-01T12:34:56.000Z');
        const result = await setRetentionConfig(
            { archive_period_days: 180, actor_id: 'admin-1' },
            { now: () => fixedNow },
        );

        expect(result).toEqual({
            archive_period_days: 180,
            updated_at: fixedNow.toISOString(),
            updated_by: 'admin-1',
            version: 1,
        });

        // Audit must be called BEFORE write (REQ 13.4a ordering).
        const auditCallOrder =
            mockAppendAuditLog.mock.invocationCallOrder[0];
        const writeCallOrder =
            mockWriteRetentionConfig.mock.invocationCallOrder[0];
        expect(auditCallOrder).toBeLessThan(writeCallOrder);

        // Audit record should name actor + previous + new + timestamp.
        const auditRecord = mockAppendAuditLog.mock.calls[0][0] as {
            recipient_id: string;
            timestamp: string;
            error_reason: string;
        };
        expect(auditRecord.recipient_id).toBe('admin-1');
        expect(auditRecord.timestamp).toBe(fixedNow.toISOString());
        const reason = JSON.parse(auditRecord.error_reason);
        expect(reason.action).toBe('retention_config_changed');
        expect(reason.previous_archive_period_days).toBe(90);
        expect(reason.new_archive_period_days).toBe(180);
        expect(reason.actor_id).toBe('admin-1');

        // Write should pass expectedVersion = previous version (0).
        expect(mockWriteRetentionConfig.mock.calls[0][1]).toBe(0);
    });

    test('skips audit + write when value is unchanged', async () => {
        mockReadRetentionConfig.mockResolvedValueOnce({
            archive_period_days: 120,
            updated_at: '2026-01-01T00:00:00.000Z',
            updated_by: 'admin-1',
            version: 2,
        });

        const result = await setRetentionConfig({
            archive_period_days: 120,
            actor_id: 'admin-2',
        });

        expect(result.archive_period_days).toBe(120);
        expect(mockAppendAuditLog).not.toHaveBeenCalled();
        expect(mockWriteRetentionConfig).not.toHaveBeenCalled();
    });
});

// ---------------------------------------------------------------------------
// setRetentionConfig — REQ 13.4a (Audit_Log unavailable)
// ---------------------------------------------------------------------------

describe('setRetentionConfig — REQ 13.4a Audit_Log unavailable', () => {
    test('rejects the change when appendAuditLog throws and does NOT persist', async () => {
        mockReadRetentionConfig.mockResolvedValueOnce({
            archive_period_days: 90,
            updated_at: '2026-01-01T00:00:00.000Z',
            updated_by: null,
            version: 0,
        });
        mockAppendAuditLog.mockRejectedValueOnce(
            new Error('DynamoDB unavailable'),
        );

        await expect(
            setRetentionConfig({
                archive_period_days: 180,
                actor_id: 'admin-1',
            }),
        ).rejects.toBeInstanceOf(AuditLogUnavailableError);

        // The persistent state MUST remain untouched.
        expect(mockWriteRetentionConfig).not.toHaveBeenCalled();
    });

    test('persistence error after successful audit propagates without further audit retries', async () => {
        mockReadRetentionConfig.mockResolvedValueOnce({
            archive_period_days: 90,
            updated_at: '2026-01-01T00:00:00.000Z',
            updated_by: null,
            version: 0,
        });
        mockAppendAuditLog.mockResolvedValueOnce({ audit_id: 'audit-1' });
        mockWriteRetentionConfig.mockRejectedValueOnce(
            new Error('Conditional check failed'),
        );

        await expect(
            setRetentionConfig({
                archive_period_days: 180,
                actor_id: 'admin-1',
            }),
        ).rejects.toThrow('Conditional check failed');

        // The audit was written exactly once; no retry.
        expect(mockAppendAuditLog).toHaveBeenCalledTimes(1);
    });
});
