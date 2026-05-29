/**
 * Unit tests — report dispatch worker due-window helper + tick smoke.
 */
import { isReportDispatchDue, runReportDispatchWorkerTick } from '../handlers/report-dispatch-worker';
import { queryItems, getItem } from '../config/dynamodb.config';
import { buildReportExportPayload, applyReportDispatchOutcome } from '../handlers/reports';

jest.mock('../config/dynamodb.config', () => ({
    Keys: {
        entityGSI1PK: (e: string) => `ENTITY#${e}`,
        tenantPK: (id: string) => `TENANT#${id}`,
    },
    getItem: jest.fn(),
    queryItems: jest.fn(),
}));

jest.mock('../handlers/reports', () => {
    const actual = jest.requireActual('../handlers/reports');
    return {
        ...actual,
        buildReportExportPayload: jest.fn(),
        applyReportDispatchOutcome: jest.fn(),
    };
});

const mockQueryItems = queryItems as jest.MockedFunction<typeof queryItems>;
const mockGetItem = getItem as jest.MockedFunction<typeof getItem>;
const mockBuild = buildReportExportPayload as jest.MockedFunction<typeof buildReportExportPayload>;
const mockApply = applyReportDispatchOutcome as jest.MockedFunction<typeof applyReportDispatchOutcome>;

describe('isReportDispatchDue', () => {
    const t0 = new Date('2026-04-29T10:00:00.000Z');

    it('ignores terminal states', () => {
        expect(isReportDispatchDue({ status: 'sent' }, t0)).toBe(false);
        expect(isReportDispatchDue({ status: 'failed' }, t0)).toBe(false);
        expect(isReportDispatchDue({ status: 'cancelled' }, t0)).toBe(false);
    });

    it('scheduled runs when scheduleAt is not after now', () => {
        expect(
            isReportDispatchDue(
                { status: 'scheduled', scheduleAt: '2026-04-29T09:00:00.000Z' },
                t0,
            ),
        ).toBe(true);
        expect(
            isReportDispatchDue(
                { status: 'scheduled', scheduleAt: '2026-04-29T11:00:00.000Z' },
                t0,
            ),
        ).toBe(false);
    });

    it('queued runs when no nextRetryAt or nextRetryAt in past', () => {
        expect(isReportDispatchDue({ status: 'queued' }, t0)).toBe(true);
        expect(
            isReportDispatchDue(
                { status: 'queued', nextRetryAt: '2026-04-29T09:00:00.000Z' },
                t0,
            ),
        ).toBe(true);
        expect(
            isReportDispatchDue(
                { status: 'queued', nextRetryAt: '2026-04-29T11:00:00.000Z' },
                t0,
            ),
        ).toBe(false);
    });
});

describe('runReportDispatchWorkerTick', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        process.env.REPORT_DISPATCH_WORKER_ENABLED = 'true';
        mockQueryItems.mockResolvedValue({ items: [] });
        mockGetItem.mockResolvedValue(null);
        mockBuild.mockResolvedValue({ ok: true, contentType: 'text/csv', contentDisposition: 'a', body: 'x' });
        mockApply.mockResolvedValue({ ok: true, data: {} } as any);
    });

    it('skips when disabled', async () => {
        process.env.REPORT_DISPATCH_WORKER_ENABLED = 'false';
        const r = await runReportDispatchWorkerTick();
        expect(r.skipped).toBe(true);
        expect(mockQueryItems).toHaveBeenCalledTimes(0);
    });

    it('processes one due job to sent', async () => {
        mockQueryItems.mockResolvedValue({
            items: [
                {
                    GSI1SK: '2026-04-29T08:00:00.000Z',
                    id: 'rpt_1',
                    tenantId: 't1',
                    status: 'queued',
                    reportType: 'sales',
                    format: 'csv',
                    channels: ['email'],
                    period: { from: '2026-04-01', to: '2026-04-30' },
                },
            ],
        });
        mockGetItem.mockResolvedValue({
            id: 'rpt_1',
            tenantId: 't1',
            status: 'queued',
            reportType: 'sales',
            format: 'csv',
            channels: ['email'],
            period: { from: '2026-04-01', to: '2026-04-30' },
        });

        const r = await runReportDispatchWorkerTick();
        expect(r.processed).toBe(1);
        expect(mockBuild).toHaveBeenCalled();
        expect(mockApply).toHaveBeenCalledWith(
            't1',
            'rpt_1',
            expect.objectContaining({ outcome: 'sent', requestSource: 'report-dispatch-worker' }),
        );
    });
});
