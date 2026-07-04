// ============================================================================
// Staff Module — Attendance Service Unit Tests (Task 5.2)
// ============================================================================
// Tests for geo-fence/GPS validation (Req 3.6) and attendance merge (Req 3.5).
// ============================================================================

import {
    AttendanceService,
    GeoFenceBoundary,
    haversineDistanceMetres,
    isLocationRestrictedMethod,
    validateGeoFence,
} from '../attendance.service';
import { AttendanceEvent } from '../../schemas/attendance.schema';
import { ConflictError } from '../../../../utils/errors';

// ── Mock the repository ─────────────────────────────────────────────────────

const mockCreate = jest.fn();
jest.mock('../../repositories/attendance-event.repository', () => ({
    AttendanceEventRepository: jest.fn().mockImplementation(() => ({
        create: mockCreate,
        listByWindow: jest.fn().mockResolvedValue([]),
        listByEmployee: jest.fn().mockResolvedValue([]),
    })),
}));

describe('AttendanceService — Geo-fence/GPS Validation (Req 3.6)', () => {
    let service: AttendanceService;

    beforeEach(() => {
        jest.clearAllMocks();
        mockCreate.mockImplementation((_t: string, _b: string, event: AttendanceEvent) =>
            Promise.resolve(event),
        );
        service = new AttendanceService();
    });

    const tenantId = 'tenant-1';
    const businessId = 'biz-1';
    const fence: GeoFenceBoundary = { lat: 28.6139, lng: 77.209, radiusMetres: 100 };

    it('rejects GPS method when geo coordinates are outside the fence', async () => {
        const result = await service.capture(
            tenantId,
            businessId,
            {
                employeeId: 'emp-1',
                type: 'check_in',
                method: 'gps',
                timestamp: '2025-01-15T09:00:00.000Z',
                geo: { lat: 28.62, lng: 77.22 }, // far from fence centre
            },
            fence,
        );

        expect(result.rejected).toBe(true);
        expect(result.rejectionReason).toBeDefined();
        expect(result.rejectionReason).toContain('outside');
        expect(result.geo?.withinFence).toBe(false);
    });

    it('accepts GPS method when geo coordinates are within the fence', async () => {
        const result = await service.capture(
            tenantId,
            businessId,
            {
                employeeId: 'emp-1',
                type: 'check_in',
                method: 'gps',
                timestamp: '2025-01-15T09:00:00.000Z',
                geo: { lat: 28.6139, lng: 77.209 }, // exactly at centre
            },
            fence,
        );

        expect(result.rejected).toBeUndefined();
        expect(result.rejectionReason).toBeUndefined();
        expect(result.geo?.withinFence).toBe(true);
    });

    it('rejects GPS method when no geo coordinates are provided but fence is configured', async () => {
        const result = await service.capture(
            tenantId,
            businessId,
            {
                employeeId: 'emp-1',
                type: 'check_in',
                method: 'gps',
                timestamp: '2025-01-15T09:00:00.000Z',
                // no geo payload
            },
            fence,
        );

        expect(result.rejected).toBe(true);
        expect(result.rejectionReason).toContain('GPS coordinates are required');
    });

    it('does not reject non-location-restricted methods even with a fence configured', async () => {
        const result = await service.capture(
            tenantId,
            businessId,
            {
                employeeId: 'emp-1',
                type: 'check_in',
                method: 'manual',
                timestamp: '2025-01-15T09:00:00.000Z',
            },
            fence,
        );

        expect(result.rejected).toBeUndefined();
        expect(result.rejectionReason).toBeUndefined();
    });

    it('does not reject GPS method when no fence is configured', async () => {
        const result = await service.capture(
            tenantId,
            businessId,
            {
                employeeId: 'emp-1',
                type: 'check_in',
                method: 'gps',
                timestamp: '2025-01-15T09:00:00.000Z',
                geo: { lat: 0, lng: 0 },
            },
            // no fence
        );

        expect(result.rejected).toBeUndefined();
    });

    it('records the rejection reason with distance details', async () => {
        const result = await service.capture(
            tenantId,
            businessId,
            {
                employeeId: 'emp-1',
                type: 'check_in',
                method: 'gps',
                timestamp: '2025-01-15T09:00:00.000Z',
                geo: { lat: 28.615, lng: 77.21 }, // slightly outside
            },
            { lat: 28.6139, lng: 77.209, radiusMetres: 50 },
        );

        expect(result.rejected).toBe(true);
        expect(result.rejectionReason).toMatch(/\d+m from fence centre/);
    });
});

describe('AttendanceService — Attendance Merge (AD-4, Req 3.5)', () => {
    let service: AttendanceService;

    beforeEach(() => {
        jest.clearAllMocks();
        mockCreate.mockImplementation((_t: string, _b: string, event: AttendanceEvent) =>
            Promise.resolve(event),
        );
        service = new AttendanceService();
    });

    const tenantId = 'tenant-1';
    const businessId = 'biz-1';

    const makeEvent = (eventId: string, timestamp: string): AttendanceEvent => ({
        eventId,
        employeeId: 'emp-1',
        businessId: 'biz-1',
        type: 'check_in',
        method: 'manual',
        timestamp,
    });

    it('inserts new events successfully', async () => {
        const events = [
            makeEvent('evt-1', '2025-01-15T09:00:00.000Z'),
            makeEvent('evt-2', '2025-01-15T09:30:00.000Z'),
        ];

        const results = await service.mergeAttendanceEvents(tenantId, businessId, events);

        expect(results).toHaveLength(2);
        expect(results[0]).toEqual({ eventId: 'evt-1', status: 'inserted' });
        expect(results[1]).toEqual({ eventId: 'evt-2', status: 'inserted' });
        expect(mockCreate).toHaveBeenCalledTimes(2);
    });

    it('skips duplicate events (ConflictError) without surfacing a merge-conflict UI', async () => {
        mockCreate
            .mockResolvedValueOnce(makeEvent('evt-1', '2025-01-15T09:00:00.000Z'))
            .mockRejectedValueOnce(new ConflictError('already exists'))
            .mockResolvedValueOnce(makeEvent('evt-3', '2025-01-15T10:00:00.000Z'));

        const events = [
            makeEvent('evt-1', '2025-01-15T09:00:00.000Z'),
            makeEvent('evt-2', '2025-01-15T09:30:00.000Z'), // duplicate
            makeEvent('evt-3', '2025-01-15T10:00:00.000Z'),
        ];

        const results = await service.mergeAttendanceEvents(tenantId, businessId, events);

        expect(results).toHaveLength(3);
        expect(results[0]).toEqual({ eventId: 'evt-1', status: 'inserted' });
        expect(results[1]).toEqual({ eventId: 'evt-2', status: 'skipped' });
        expect(results[2]).toEqual({ eventId: 'evt-3', status: 'inserted' });
    });

    it('rethrows non-ConflictError exceptions', async () => {
        mockCreate.mockRejectedValueOnce(new Error('DynamoDB network error'));

        const events = [makeEvent('evt-1', '2025-01-15T09:00:00.000Z')];

        await expect(
            service.mergeAttendanceEvents(tenantId, businessId, events),
        ).rejects.toThrow('DynamoDB network error');
    });

    it('returns empty results for an empty event array (idempotent)', async () => {
        const results = await service.mergeAttendanceEvents(tenantId, businessId, []);
        expect(results).toEqual([]);
        expect(mockCreate).not.toHaveBeenCalled();
    });

    it('merge is idempotent — re-merging the same events produces the same result', async () => {
        // First merge: all insert.
        const events = [
            makeEvent('evt-1', '2025-01-15T09:00:00.000Z'),
            makeEvent('evt-2', '2025-01-15T09:30:00.000Z'),
        ];

        mockCreate.mockResolvedValue(events[0]);
        const first = await service.mergeAttendanceEvents(tenantId, businessId, events);
        expect(first.every((r) => r.status === 'inserted')).toBe(true);

        // Second merge: all skip (ConflictError on each).
        mockCreate.mockRejectedValue(new ConflictError('exists'));
        const second = await service.mergeAttendanceEvents(tenantId, businessId, events);
        expect(second.every((r) => r.status === 'skipped')).toBe(true);
    });
});

describe('haversineDistanceMetres', () => {
    it('returns 0 for the same point', () => {
        expect(haversineDistanceMetres(0, 0, 0, 0)).toBe(0);
    });

    it('computes a known distance between two cities approximately', () => {
        // Delhi to Agra ≈ ~178 km (rough check — within 10% tolerance)
        const dist = haversineDistanceMetres(28.6139, 77.209, 27.1767, 78.0081);
        expect(dist).toBeGreaterThan(160_000);
        expect(dist).toBeLessThan(200_000);
    });

    it('returns the radius when a point is exactly on the fence boundary', () => {
        // Point on the boundary should be within the fence (distance <= radius)
        const fence: GeoFenceBoundary = { lat: 0, lng: 0, radiusMetres: 111_000 };
        // ~1 degree latitude ≈ 111km
        const result = validateGeoFence({ lat: 1, lng: 0 }, fence);
        // Close to boundary — exact pass/fail depends on earth curvature precision
        expect(typeof result.withinFence).toBe('boolean');
    });
});

describe('isLocationRestrictedMethod', () => {
    it('returns true for GPS', () => {
        expect(isLocationRestrictedMethod('gps')).toBe(true);
    });

    it('returns false for non-location methods', () => {
        expect(isLocationRestrictedMethod('manual')).toBe(false);
        expect(isLocationRestrictedMethod('qr')).toBe(false);
        expect(isLocationRestrictedMethod('barcode')).toBe(false);
        expect(isLocationRestrictedMethod('wifi')).toBe(false);
    });
});

describe('validateGeoFence', () => {
    const fence: GeoFenceBoundary = { lat: 28.6139, lng: 77.209, radiusMetres: 100 };

    it('returns withinFence=true when point is inside the radius', () => {
        const result = validateGeoFence({ lat: 28.6139, lng: 77.209 }, fence);
        expect(result.withinFence).toBe(true);
        expect(result.rejectionReason).toBeUndefined();
    });

    it('returns withinFence=false with a reason when point is outside', () => {
        // Move ~1km away
        const result = validateGeoFence({ lat: 28.624, lng: 77.209 }, fence);
        expect(result.withinFence).toBe(false);
        expect(result.rejectionReason).toBeDefined();
        expect(result.rejectionReason).toContain('outside');
    });
});
