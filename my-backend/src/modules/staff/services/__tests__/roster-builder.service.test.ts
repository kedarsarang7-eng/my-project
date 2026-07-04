// ============================================================================
// Staff Module — Roster Builder Service Unit Tests (Task 5.3)
// ============================================================================
// Tests for the pure shift-rule enforcement logic (Property 11, Req 3.3, 3.7).
// ============================================================================

import {
    validateRosterAssignment,
    buildRoster,
    shiftsOverlap,
    timeToMinutes,
    haversineDistanceMeters,
    isWithinGeoFence,
    type AssignmentContext,
    type EmployeeContext,
    type RosterBuildInput,
} from '../roster-builder.service';
import type { Shift } from '../../schemas/shift.schema';

// ── Helpers ─────────────────────────────────────────────────────────────────

function makeShift(overrides: Partial<Shift> = {}): Shift {
    return {
        id: 'shift-1',
        businessId: 'biz-1',
        name: 'Morning',
        start: '09:00',
        end: '17:00',
        status: 'active',
        ...overrides,
    };
}

function makeEmployee(overrides: Partial<EmployeeContext> = {}): EmployeeContext {
    return {
        employeeId: 'emp-1',
        status: 'active',
        ...overrides,
    };
}

function makeContext(overrides: Partial<AssignmentContext> = {}): AssignmentContext {
    return {
        shift: makeShift(),
        employee: makeEmployee(),
        existingAssignments: [],
        ...overrides,
    };
}

// ── timeToMinutes ───────────────────────────────────────────────────────────

describe('timeToMinutes', () => {
    it('converts 00:00 to 0', () => {
        expect(timeToMinutes('00:00')).toBe(0);
    });

    it('converts 09:30 to 570', () => {
        expect(timeToMinutes('09:30')).toBe(570);
    });

    it('converts 23:59 to 1439', () => {
        expect(timeToMinutes('23:59')).toBe(1439);
    });
});

// ── shiftsOverlap ───────────────────────────────────────────────────────────

describe('shiftsOverlap', () => {
    it('detects overlap for identical shifts', () => {
        expect(shiftsOverlap('09:00', '17:00', '09:00', '17:00')).toBe(true);
    });

    it('detects overlap for partially overlapping shifts', () => {
        expect(shiftsOverlap('09:00', '17:00', '12:00', '20:00')).toBe(true);
    });

    it('returns false for non-overlapping shifts', () => {
        expect(shiftsOverlap('09:00', '12:00', '13:00', '17:00')).toBe(false);
    });

    it('returns false for adjacent shifts (end == start boundary)', () => {
        // [09:00, 12:00) and [12:00, 17:00) — boundary touches but no overlap
        expect(shiftsOverlap('09:00', '12:00', '12:00', '17:00')).toBe(false);
    });

    it('handles overnight shifts that wrap around midnight', () => {
        // Night shift 22:00-06:00 overlaps with early morning 05:00-09:00
        expect(shiftsOverlap('22:00', '06:00', '05:00', '09:00')).toBe(true);
    });

    it('two overnight shifts overlap', () => {
        expect(shiftsOverlap('22:00', '06:00', '23:00', '07:00')).toBe(true);
    });

    it('overnight shift does not overlap with a midday shift', () => {
        expect(shiftsOverlap('22:00', '06:00', '10:00', '14:00')).toBe(false);
    });
});

// ── haversineDistanceMeters ──────────────────────────────────────────────────

describe('haversineDistanceMeters', () => {
    it('returns 0 for the same point', () => {
        expect(haversineDistanceMeters(28.6, 77.2, 28.6, 77.2)).toBe(0);
    });

    it('computes roughly 111km per degree latitude at equator', () => {
        const dist = haversineDistanceMeters(0, 0, 1, 0);
        expect(dist).toBeGreaterThan(110_000);
        expect(dist).toBeLessThan(112_000);
    });
});

// ── isWithinGeoFence ────────────────────────────────────────────────────────

describe('isWithinGeoFence', () => {
    it('returns true when point is at the centre', () => {
        expect(isWithinGeoFence({ lat: 28.6, lng: 77.2 }, { lat: 28.6, lng: 77.2, radiusMeters: 100 })).toBe(true);
    });

    it('returns false when point is far outside', () => {
        expect(isWithinGeoFence({ lat: 29.0, lng: 78.0 }, { lat: 28.6, lng: 77.2, radiusMeters: 100 })).toBe(false);
    });
});

// ── validateRosterAssignment ────────────────────────────────────────────────

describe('validateRosterAssignment', () => {
    it('accepts a valid assignment to an active shift for an active employee', () => {
        const result = validateRosterAssignment(makeContext());
        expect(result.accepted).toBe(true);
        expect(result.code).toBeUndefined();
    });

    it('rejects assignment to an inactive shift', () => {
        const result = validateRosterAssignment(
            makeContext({ shift: makeShift({ status: 'inactive' }) }),
        );
        expect(result.accepted).toBe(false);
        expect(result.code).toBe('SHIFT_INACTIVE');
    });

    it('rejects assignment for an inactive employee', () => {
        const result = validateRosterAssignment(
            makeContext({ employee: makeEmployee({ status: 'inactive' }) }),
        );
        expect(result.accepted).toBe(false);
        expect(result.code).toBe('EMPLOYEE_INACTIVE');
    });

    it('rejects duplicate assignment (same employee, same shift)', () => {
        const shift = makeShift();
        const result = validateRosterAssignment(
            makeContext({
                shift,
                existingAssignments: [{ employeeId: 'emp-1', shiftId: 'shift-1', shift }],
            }),
        );
        expect(result.accepted).toBe(false);
        expect(result.code).toBe('DUPLICATE_ASSIGNMENT');
    });

    it('rejects overlapping shift for same employee', () => {
        const morningShift = makeShift({ id: 'shift-morning', start: '09:00', end: '17:00' });
        const overlappingShift = makeShift({ id: 'shift-2', start: '12:00', end: '20:00' });
        const result = validateRosterAssignment(
            makeContext({
                shift: overlappingShift,
                existingAssignments: [
                    { employeeId: 'emp-1', shiftId: 'shift-morning', shift: morningShift },
                ],
            }),
        );
        expect(result.accepted).toBe(false);
        expect(result.code).toBe('OVERLAPPING_SHIFT');
    });

    it('accepts non-overlapping shifts for same employee', () => {
        const morningShift = makeShift({ id: 'shift-morning', start: '06:00', end: '12:00' });
        const eveningShift = makeShift({ id: 'shift-2', start: '14:00', end: '20:00' });
        const result = validateRosterAssignment(
            makeContext({
                shift: eveningShift,
                existingAssignments: [
                    { employeeId: 'emp-1', shiftId: 'shift-morning', shift: morningShift },
                ],
            }),
        );
        expect(result.accepted).toBe(true);
    });

    it('rejects when employee is outside geo-fence', () => {
        const shift = makeShift({
            geoFence: { lat: 28.6, lng: 77.2, radiusMeters: 100 },
        });
        const employee = makeEmployee({
            location: { lat: 29.0, lng: 78.0 }, // far away
        });
        const result = validateRosterAssignment(makeContext({ shift, employee }));
        expect(result.accepted).toBe(false);
        expect(result.code).toBe('OUTSIDE_GEO_FENCE');
    });

    it('accepts when employee is within geo-fence', () => {
        const shift = makeShift({
            geoFence: { lat: 28.6, lng: 77.2, radiusMeters: 1000 },
        });
        const employee = makeEmployee({
            location: { lat: 28.6, lng: 77.2 }, // at centre
        });
        const result = validateRosterAssignment(makeContext({ shift, employee }));
        expect(result.accepted).toBe(true);
    });

    it('skips geo-fence check when employee has no location', () => {
        const shift = makeShift({
            geoFence: { lat: 28.6, lng: 77.2, radiusMeters: 100 },
        });
        const employee = makeEmployee(); // no location
        const result = validateRosterAssignment(makeContext({ shift, employee }));
        expect(result.accepted).toBe(true);
    });

    it('rejects when approval is required but not given', () => {
        const shift = makeShift({
            approvalRule: { mode: 'manager_required' },
        });
        const result = validateRosterAssignment(makeContext({ shift, approved: false }));
        expect(result.accepted).toBe(false);
        expect(result.code).toBe('APPROVAL_REQUIRED');
    });

    it('accepts when approval is required and given', () => {
        const shift = makeShift({
            approvalRule: { mode: 'manager_required' },
        });
        const result = validateRosterAssignment(makeContext({ shift, approved: true }));
        expect(result.accepted).toBe(true);
    });

    it('does not require approval when mode is auto', () => {
        const shift = makeShift({
            approvalRule: { mode: 'auto' },
        });
        const result = validateRosterAssignment(makeContext({ shift }));
        expect(result.accepted).toBe(true);
    });
});

// ── buildRoster (orchestration) ──────────────────────────────────────────────

describe('buildRoster', () => {
    it('accepts all valid assignments', () => {
        const shift = makeShift();
        const input: RosterBuildInput = {
            proposedAssignments: [
                { employeeId: 'emp-1', shiftId: 'shift-1' },
                { employeeId: 'emp-2', shiftId: 'shift-1' },
            ],
            shiftsById: new Map([['shift-1', shift]]),
            employeesById: new Map([
                ['emp-1', makeEmployee({ employeeId: 'emp-1' })],
                ['emp-2', makeEmployee({ employeeId: 'emp-2' })],
            ]),
        };

        const result = buildRoster(input);
        expect(result.accepted).toHaveLength(2);
        expect(result.rejected).toHaveLength(0);
    });

    it('rejects assignments to unknown shifts', () => {
        const input: RosterBuildInput = {
            proposedAssignments: [{ employeeId: 'emp-1', shiftId: 'unknown' }],
            shiftsById: new Map(),
            employeesById: new Map([['emp-1', makeEmployee()]]),
        };

        const result = buildRoster(input);
        expect(result.accepted).toHaveLength(0);
        expect(result.rejected).toHaveLength(1);
        expect(result.rejected[0].code).toBe('SHIFT_INACTIVE');
    });

    it('rejects assignments for unknown employees', () => {
        const shift = makeShift();
        const input: RosterBuildInput = {
            proposedAssignments: [{ employeeId: 'unknown', shiftId: 'shift-1' }],
            shiftsById: new Map([['shift-1', shift]]),
            employeesById: new Map(),
        };

        const result = buildRoster(input);
        expect(result.accepted).toHaveLength(0);
        expect(result.rejected).toHaveLength(1);
        expect(result.rejected[0].code).toBe('EMPLOYEE_INACTIVE');
    });

    it('rejects second overlapping assignment for same employee', () => {
        const morning = makeShift({ id: 'shift-morning', start: '09:00', end: '17:00' });
        const afternoon = makeShift({ id: 'shift-afternoon', start: '14:00', end: '22:00' });

        const input: RosterBuildInput = {
            proposedAssignments: [
                { employeeId: 'emp-1', shiftId: 'shift-morning' },
                { employeeId: 'emp-1', shiftId: 'shift-afternoon' }, // overlaps
            ],
            shiftsById: new Map([
                ['shift-morning', morning],
                ['shift-afternoon', afternoon],
            ]),
            employeesById: new Map([['emp-1', makeEmployee()]]),
        };

        const result = buildRoster(input);
        expect(result.accepted).toHaveLength(1);
        expect(result.accepted[0].shiftId).toBe('shift-morning');
        expect(result.rejected).toHaveLength(1);
        expect(result.rejected[0].code).toBe('OVERLAPPING_SHIFT');
    });

    it('mixes accepted and rejected correctly', () => {
        const activeShift = makeShift({ id: 'shift-active' });
        const inactiveShift = makeShift({ id: 'shift-inactive', status: 'inactive' });

        const input: RosterBuildInput = {
            proposedAssignments: [
                { employeeId: 'emp-1', shiftId: 'shift-active' },
                { employeeId: 'emp-2', shiftId: 'shift-inactive' },
            ],
            shiftsById: new Map([
                ['shift-active', activeShift],
                ['shift-inactive', inactiveShift],
            ]),
            employeesById: new Map([
                ['emp-1', makeEmployee({ employeeId: 'emp-1' })],
                ['emp-2', makeEmployee({ employeeId: 'emp-2' })],
            ]),
        };

        const result = buildRoster(input);
        expect(result.accepted).toHaveLength(1);
        expect(result.accepted[0].employeeId).toBe('emp-1');
        expect(result.rejected).toHaveLength(1);
        expect(result.rejected[0].employeeId).toBe('emp-2');
        expect(result.rejected[0].code).toBe('SHIFT_INACTIVE');
    });

    it('handles empty proposals', () => {
        const result = buildRoster({
            proposedAssignments: [],
            shiftsById: new Map(),
            employeesById: new Map(),
        });
        expect(result.accepted).toEqual([]);
        expect(result.rejected).toEqual([]);
    });
});
